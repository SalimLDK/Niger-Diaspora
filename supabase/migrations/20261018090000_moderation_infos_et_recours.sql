-- Modération des signalements, tranche 3 : demandes d'informations et recours.
--
-- Référentiel d'administration § 6.1 (demander des informations) et § 6.8
-- (traiter un recours). Suite de 20261017100000 (workflow des signalements).
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `moderation_info_requests` : une demande d'informations rattachée à un
--   signalement, adressée au signalant OU au membre signalé (jamais aux deux
--   dans la même ligne : « demandes distinctes »). Cycle : draft → sent →
--   answered, ou cancelled. L'échéance est obligatoire ; « en retard » se
--   DÉDUIT de `due_at` (sent et échéance passée), aucun statut stocké ne ment.
-- • `moderation_appeals` : un recours contre une décision `resolved`. La
--   ligne FIGE la décision contestée (`contested_decider`, `contested_action`,
--   `contested_reason`) : une décision ultérieure sur le dossier ne l'écrase
--   pas (§ 6.8 pas 7 : conserver la décision initiale et celle du recours).
-- • Six RPC, seules portes d'écriture, qui verrouillent la ligne (FOR UPDATE),
--   vérifient la permission, refusent un passage absent du cycle (55000) et
--   écrivent l'audit DANS LA MÊME TRANSACTION.
-- • Cinq permissions, mappées à contentMod (superAdmin a tout le catalogue).
--
-- ═══ RÈGLES QUI NE SE NÉGOCIENT PAS ═══════════════════════════════════════
--
-- • Séparation des tâches : celui qui a décidé le dossier ne prend pas et ne
--   tranche pas son recours — superAdmin compris (§ 2 : « ne peut pas examiner
--   un recours impliquant sa propre décision »). Refus 42501.
-- • Le dossier doit être `reviewing` et au nom de l'appelant (ou superAdmin)
--   pour y poser une demande d'informations.
-- • Un recours « renvoyé pour réexamen » remet le dossier en `escalated`
--   (statut existant : repris ensuite par `assign`, par quelqu'un d'autre que
--   le décideur initial puisque celui-ci ne peut plus le prendre).
--
-- ═══ CE QU'ELLE NE FAIT PAS (décisions ouvertes, voir le guide § 7) ════════
--
-- • Aucun DÉLAI de recours n'est imposé : c'est une décision juridique, pas
--   technique. `received_at` est conservé pour qu'un délai puisse être ajouté
--   sans migration de données.
-- • Aucune notification : elles passeront par l'outbox (cf. tranche 1). Le
--   destinataire d'une demande ne la voit donc pas encore dans l'application ;
--   la réponse est consignée par le modérateur (`..._record_response`), faute
--   d'écran côté membre. Ne pas présenter cela comme un échange de bout en bout.
-- • Elle n'EXÉCUTE pas la décision de recours (lever une sanction) : elle
--   consigne l'issue. L'exécution suit avec les sanctions côté serveur.
-- • Le texte d'une demande est libre : rien ne peut vérifier qu'il ne révèle
--   pas le signalant. L'écran devra imposer l'aperçu (§ 6.1 pas 6).
--
-- Banc : tools/rls_tests/moderation_infos_et_recours.sql.

SET lock_timeout = '5s';

-- ── 1. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('moderation.info_requests.create', 'moderation', 'Rédiger une demande d''informations', NULL),
  ('moderation.info_requests.send',   'moderation', 'Envoyer une demande d''informations', NULL),
  ('moderation.appeals.view',         'moderation', 'Voir les recours',                    NULL),
  ('moderation.appeals.review',       'moderation', 'Enregistrer et examiner un recours',  NULL),
  ('moderation.appeals.decide',       'moderation', 'Trancher un recours',                 NULL)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'moderation.info_requests.create'),
  ('contentMod', 'moderation.info_requests.send'),
  ('contentMod', 'moderation.appeals.view'),
  ('contentMod', 'moderation.appeals.review'),
  ('contentMod', 'moderation.appeals.decide')
ON CONFLICT DO NOTHING;

-- ── 2. Demandes d'informations ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.moderation_info_requests (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id      uuid NOT NULL REFERENCES public.reports (id),
  recipient_kind text NOT NULL CHECK (recipient_kind IN ('reporter', 'reported')),
  recipient_id   text NOT NULL,
  questions      text NOT NULL CHECK (length(btrim(questions)) BETWEEN 10 AND 2000),
  due_at         timestamptz NOT NULL,
  status         text NOT NULL DEFAULT 'draft'
                 CHECK (status IN ('draft', 'sent', 'answered', 'cancelled')),
  created_by     text NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  sent_by        text,
  sent_at        timestamptz,
  response       text CHECK (response IS NULL OR length(response) <= 4000),
  responded_at   timestamptz,
  recorded_by    text
);

-- Une seule demande ouverte par dossier ET par destinataire : un double clic
-- sur « Rédiger » ne fabrique pas deux demandes.
CREATE UNIQUE INDEX IF NOT EXISTS moderation_info_requests_open_uidx
  ON public.moderation_info_requests (report_id, recipient_kind)
  WHERE status IN ('draft', 'sent');
CREATE INDEX IF NOT EXISTS moderation_info_requests_due_idx
  ON public.moderation_info_requests (due_at) WHERE status = 'sent';

-- ── 3. Recours ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.moderation_appeals (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id         uuid NOT NULL REFERENCES public.reports (id),
  appellant_id      text NOT NULL,
  argument          text NOT NULL CHECK (length(btrim(argument)) BETWEEN 10 AND 4000),
  received_at       timestamptz NOT NULL DEFAULT now(),
  registered_by     text NOT NULL,
  -- La décision contestée, figée à l'enregistrement.
  contested_decider text NOT NULL,
  contested_action  text,
  contested_reason  text,
  status            text NOT NULL DEFAULT 'received'
                    CHECK (status IN ('received', 'under_review',
                                      'upheld', 'reduced', 'annulled', 'sent_back')),
  reviewer_id       text,
  review_started_at timestamptz,
  decision_note     text CHECK (decision_note IS NULL OR length(decision_note) <= 2000),
  decided_at        timestamptz
);

-- Un seul recours en cours par dossier.
CREATE UNIQUE INDEX IF NOT EXISTS moderation_appeals_open_uidx
  ON public.moderation_appeals (report_id)
  WHERE status IN ('received', 'under_review');

-- ── 4. Droits : REVOKE d'abord (le défaut Supabase accorde ALL) ─────────────
ALTER TABLE public.moderation_info_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_appeals       ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.moderation_info_requests FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.moderation_appeals       FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.moderation_info_requests TO authenticated;
GRANT SELECT ON public.moderation_appeals       TO authenticated;

DROP POLICY IF EXISTS moderation_info_requests_select ON public.moderation_info_requests;
CREATE POLICY moderation_info_requests_select ON public.moderation_info_requests
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('moderation.reports.view'));

DROP POLICY IF EXISTS moderation_appeals_select ON public.moderation_appeals;
CREATE POLICY moderation_appeals_select ON public.moderation_appeals
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('moderation.appeals.view'));

-- ── 5. Rédiger une demande ──────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.moderation_info_request_create(uuid, text, text, timestamptz);

CREATE FUNCTION public.moderation_info_request_create(
  p_report_id      uuid,
  p_recipient_kind text,
  p_questions      text,
  p_due_at         timestamptz
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller    text := (SELECT public.firebase_uid());
  r           public.reports%ROWTYPE;
  v_recipient text;
  v_id        uuid;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'demande d''informations : réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('moderation.info_requests.create');

  IF p_recipient_kind IS NULL OR p_recipient_kind NOT IN ('reporter', 'reported') THEN
    RAISE EXCEPTION 'demande d''informations : destinataire invalide (reporter, reported)'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO r FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demande d''informations : signalement introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF r.status <> 'reviewing' THEN
    RAISE EXCEPTION 'demande d''informations : le dossier doit être en examen (statut %)', r.status
      USING ERRCODE = '55000';
  END IF;
  IF r.assigned_to IS DISTINCT FROM v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'demande d''informations : dossier attribué à un autre modérateur'
      USING ERRCODE = '42501';
  END IF;

  v_recipient := CASE p_recipient_kind
                   WHEN 'reporter' THEN r.reporter_id
                   ELSE r.reported_user_id END;
  IF v_recipient IS NULL THEN
    RAISE EXCEPTION 'demande d''informations : ce dossier n''a pas de membre signalé identifié'
      USING ERRCODE = '22023';
  END IF;

  IF p_questions IS NULL OR length(btrim(p_questions)) < 10 OR length(p_questions) > 2000 THEN
    RAISE EXCEPTION 'demande d''informations : questions requises (10 à 2000 caractères)'
      USING ERRCODE = '22023';
  END IF;
  IF p_due_at IS NULL OR p_due_at <= now() OR p_due_at > now() + interval '60 days' THEN
    RAISE EXCEPTION 'demande d''informations : échéance requise, dans le futur et sous 60 jours'
      USING ERRCODE = '22023';
  END IF;

  BEGIN
    INSERT INTO public.moderation_info_requests
      (report_id, recipient_kind, recipient_id, questions, due_at, created_by)
    VALUES
      (p_report_id, p_recipient_kind, v_recipient, btrim(p_questions), p_due_at, v_caller)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'demande d''informations : une demande est déjà ouverte pour ce destinataire'
      USING ERRCODE = '55000';
  END;

  PERFORM public.write_admin_audit(
    'INFO_REQUEST_DRAFTED', 'report', p_report_id::text, 'success',
    NULL, p_report_id::text,
    jsonb_build_object('request', v_id, 'recipient_kind', p_recipient_kind,
                       'due_at', p_due_at));
  RETURN v_id;
END $$;

-- ── 6. Envoyer ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.moderation_info_request_send(uuid);

CREATE FUNCTION public.moderation_info_request_send(p_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  q        public.moderation_info_requests%ROWTYPE;
  r        public.reports%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'demande d''informations : réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('moderation.info_requests.send');

  SELECT * INTO q FROM public.moderation_info_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demande d''informations : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF q.status <> 'draft' THEN
    RAISE EXCEPTION 'demande d''informations : envoi impossible depuis le statut %', q.status
      USING ERRCODE = '55000';
  END IF;
  IF q.due_at <= now() THEN
    RAISE EXCEPTION 'demande d''informations : l''échéance est passée, la corriger avant l''envoi'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO r FROM public.reports WHERE id = q.report_id FOR UPDATE;
  IF r.status <> 'reviewing' THEN
    RAISE EXCEPTION 'demande d''informations : le dossier n''est plus en examen (statut %)', r.status
      USING ERRCODE = '55000';
  END IF;
  IF r.assigned_to IS DISTINCT FROM v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'demande d''informations : dossier attribué à un autre modérateur'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.moderation_info_requests
     SET status = 'sent', sent_by = v_caller, sent_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'INFO_REQUEST_SENT', 'report', q.report_id::text, 'success',
    NULL, q.report_id::text,
    jsonb_build_object('request', p_id, 'recipient_kind', q.recipient_kind,
                       'due_at', q.due_at));
  RETURN 'sent';
END $$;

-- ── 7. Consigner une réponse ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.moderation_info_request_record_response(uuid, text);

CREATE FUNCTION public.moderation_info_request_record_response(
  p_id       uuid,
  p_response text
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  q        public.moderation_info_requests%ROWTYPE;
  r        public.reports%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'demande d''informations : réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('moderation.reports.review');

  IF p_response IS NULL OR length(btrim(p_response)) < 1 OR length(p_response) > 4000 THEN
    RAISE EXCEPTION 'demande d''informations : réponse requise (4000 caractères au plus)'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO q FROM public.moderation_info_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demande d''informations : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF q.status <> 'sent' THEN
    RAISE EXCEPTION 'demande d''informations : réponse impossible depuis le statut %', q.status
      USING ERRCODE = '55000';
  END IF;

  SELECT * INTO r FROM public.reports WHERE id = q.report_id;
  IF r.assigned_to IS DISTINCT FROM v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'demande d''informations : dossier attribué à un autre modérateur'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.moderation_info_requests
     SET status = 'answered', response = btrim(p_response),
         responded_at = now(), recorded_by = v_caller
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'RESPONSE_RECEIVED', 'report', q.report_id::text, 'success',
    NULL, q.report_id::text,
    jsonb_build_object('request', p_id, 'recipient_kind', q.recipient_kind,
                       'late', now() > q.due_at));
  RETURN 'answered';
END $$;

-- ── 8. Enregistrer un recours ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.moderation_appeal_register(uuid, text);

CREATE FUNCTION public.moderation_appeal_register(
  p_report_id uuid,
  p_argument  text
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  r        public.reports%ROWTYPE;
  v_id     uuid;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'recours : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('moderation.appeals.review');

  IF p_argument IS NULL OR length(btrim(p_argument)) < 10 OR length(p_argument) > 4000 THEN
    RAISE EXCEPTION 'recours : arguments requis (10 à 4000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO r FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'recours : signalement introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF r.status <> 'resolved' THEN
    RAISE EXCEPTION 'recours : seul un dossier ayant donné lieu à une mesure se conteste (statut %)', r.status
      USING ERRCODE = '55000';
  END IF;
  IF r.reported_user_id IS NULL OR r.reviewed_by IS NULL THEN
    RAISE EXCEPTION 'recours : membre concerné ou décideur inconnu sur ce dossier'
      USING ERRCODE = '22023';
  END IF;

  BEGIN
    INSERT INTO public.moderation_appeals
      (report_id, appellant_id, argument, registered_by,
       contested_decider, contested_action, contested_reason)
    VALUES
      (p_report_id, r.reported_user_id, btrim(p_argument), v_caller,
       r.reviewed_by, r.action_taken, r.reason_code)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'recours : un recours est déjà en cours sur ce dossier' USING ERRCODE = '55000';
  END;

  PERFORM public.write_admin_audit(
    'APPEAL_REGISTERED', 'report', p_report_id::text, 'success',
    r.reason_code, p_report_id::text,
    jsonb_build_object('appeal', v_id));
  RETURN v_id;
END $$;

-- ── 9. Prendre un recours en examen ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.moderation_appeal_take(uuid);

CREATE FUNCTION public.moderation_appeal_take(p_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  a        public.moderation_appeals%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'recours : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('moderation.appeals.review');

  SELECT * INTO a FROM public.moderation_appeals WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'recours : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF a.status <> 'received' THEN
    RAISE EXCEPTION 'recours : prise en charge impossible depuis le statut %', a.status
      USING ERRCODE = '55000';
  END IF;

  -- Séparation des tâches : pas même le superAdmin.
  IF v_caller = a.contested_decider THEN
    RAISE EXCEPTION 'recours : vous avez pris la décision contestée, un autre administrateur doit l''examiner'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.moderation_appeals
     SET status = 'under_review', reviewer_id = v_caller, review_started_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'APPEAL_REVIEW_STARTED', 'report', a.report_id::text, 'success',
    NULL, a.report_id::text, jsonb_build_object('appeal', p_id));
  RETURN 'under_review';
END $$;

-- ── 10. Trancher ────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.moderation_appeal_decide(uuid, text, text);

CREATE FUNCTION public.moderation_appeal_decide(
  p_id      uuid,
  p_outcome text,
  p_note    text
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  a        public.moderation_appeals%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'recours : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('moderation.appeals.decide');

  IF p_outcome IS NULL OR p_outcome NOT IN ('upheld', 'reduced', 'annulled', 'sent_back') THEN
    RAISE EXCEPTION 'recours : issue invalide (upheld, reduced, annulled, sent_back)'
      USING ERRCODE = '22023';
  END IF;
  IF p_note IS NULL OR length(btrim(p_note)) < 1 OR length(p_note) > 2000 THEN
    RAISE EXCEPTION 'recours : motif final requis (2000 caractères au plus)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO a FROM public.moderation_appeals WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'recours : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF a.status <> 'under_review' THEN
    RAISE EXCEPTION 'recours : décision impossible depuis le statut %', a.status
      USING ERRCODE = '55000';
  END IF;
  IF a.reviewer_id IS DISTINCT FROM v_caller THEN
    RAISE EXCEPTION 'recours : examiné par un autre administrateur' USING ERRCODE = '42501';
  END IF;
  IF v_caller = a.contested_decider THEN
    RAISE EXCEPTION 'recours : vous avez pris la décision contestée' USING ERRCODE = '42501';
  END IF;

  UPDATE public.moderation_appeals
     SET status = p_outcome, decision_note = btrim(p_note), decided_at = now()
   WHERE id = p_id;

  -- Renvoi pour réexamen : le dossier repart en `escalated`, d'où quelqu'un
  -- le reprend par `assign`. Rien n'empêche encore le décideur initial de le
  -- reprendre : l'attribution ne porte pas de règle de séparation. À fermer
  -- avec l'exécution des sanctions, pas ici.
  IF p_outcome = 'sent_back' THEN
    UPDATE public.reports
       SET status = 'escalated', assigned_to = NULL, assigned_at = NULL
     WHERE id = a.report_id AND status = 'resolved';
  END IF;

  PERFORM public.write_admin_audit(
    'APPEAL_DECIDED', 'report', a.report_id::text, 'success',
    p_outcome, a.report_id::text,
    jsonb_build_object('appeal', p_id, 'outcome', p_outcome));
  RETURN p_outcome;
END $$;

-- ── 11. Droits d'exécution ──────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.moderation_info_request_create(uuid, text, text, timestamptz)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.moderation_info_request_send(uuid)               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.moderation_info_request_record_response(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.moderation_appeal_register(uuid, text)           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.moderation_appeal_take(uuid)                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.moderation_appeal_decide(uuid, text, text)       FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.moderation_info_request_create(uuid, text, text, timestamptz)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.moderation_info_request_send(uuid)               TO authenticated;
GRANT EXECUTE ON FUNCTION public.moderation_info_request_record_response(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.moderation_appeal_register(uuid, text)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.moderation_appeal_take(uuid)                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.moderation_appeal_decide(uuid, text, text)       TO authenticated;

NOTIFY pgrst, 'reload schema';
