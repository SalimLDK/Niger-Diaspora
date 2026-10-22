-- Sécurité et conformité : demandes relatives aux données personnelles et
-- incidents de sécurité.
--
-- Référentiel d'administration § 12 et § 19, spécification d'interfaces § 17.
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- Rien. L'utilisateur a deux gestes isolés — `export-my-data` (portabilité) et
-- `account_deletion_requests` (suppression de compte par phases) — mais rien
-- ne tient une demande d'accès, de rectification ou d'opposition, rien ne dit
-- qui l'a traitée, si l'identité du demandeur a été vérifiée, ni quand elle a
-- été close. Et rien ne tient les incidents de sécurité : le premier (la
-- compromission du VPS coturn du 2026-07-16) vivait dans des notes. Le
-- référentiel : « les demandes de données sont suivies jusqu'à résolution »,
-- « les incidents ont un responsable, un statut, des actions et un
-- historique ».
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `privacy_requests` : une demande (accès, rectification, effacement,
--   portabilité, opposition), le demandeur (un compte, et/ou un contact), le
--   ticket d'origine, le périmètre, une échéance INTERNE, la vérification
--   d'identité (méthode, qui, quand) et le résultat. Cycle : reçue →
--   identité vérifiée → en traitement → terminée, ou refusée / annulée.
--   On ne passe pas en traitement sans identité vérifiée ; un refus et une
--   annulation exigent un motif ; une clôture « terminée » exige le compte
--   rendu (quels systèmes, quoi). Les échéances légales ne sont PAS inventées :
--   `due_at` est un objectif interne choisi par l'agent.
-- • `security_incidents` + `security_incident_events` : un incident (gravité,
--   responsable, impact, dates de détection / confinement / résolution), sa
--   chronologie en ajout seul, et une clôture qui exige cause, mesures
--   correctives et enseignements.
-- • Sept RPC, audit dans la même transaction, sans le contenu des notes ni
--   l'identité du demandeur.
-- • `privacy.requests.manage` et `security.incidents.manage` : au catalogue,
--   mappées à AUCUN rôle — seul le superAdmin les porte. Ces écrans touchent
--   des données personnelles et des preuves ; les ouvrir à un rôle est une
--   décision à prendre, pas un défaut.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Elle n'EXÉCUTE rien : une demande d'effacement « terminée » ne supprime
--   pas le compte, elle consigne que quelqu'un l'a fait (par le parcours de
--   suppression de compte, déjà en phases). Ne pas présenter ce suivi comme
--   une exécution automatique.
-- • Aucun point d'entrée côté application : une demande se crée dans le panneau
--   à partir d'un ticket ou d'un courriel. Un formulaire utilisateur est une
--   tranche à part.
-- • Pas de notification du demandeur, pas de pièces jointes, pas de relance
--   automatique des échéances (aucun exécuteur planifié sur ce projet).
-- • Les incidents ne sont pas reliés automatiquement aux alertes techniques
--   (Crashlytics, journaux serveur).
--
-- Banc : tools/rls_tests/securite_conformite.sql.

SET lock_timeout = '5s';

-- ── 1. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('privacy.requests.manage',   'security', 'Traiter les demandes relatives aux données personnelles', NULL),
  ('security.incidents.manage', 'security', 'Ouvrir et traiter les incidents de sécurité',             NULL)
ON CONFLICT (key) DO NOTHING;
-- Volontairement aucun INSERT dans admin_role_permissions (voir l'en-tête).

-- ── 2. Demandes relatives aux données ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.privacy_requests (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind                   text NOT NULL
                         CHECK (kind IN ('access', 'rectification', 'erasure',
                                         'portability', 'objection')),
  requester_id           text,
  requester_contact      text CHECK (requester_contact IS NULL OR length(requester_contact) <= 200),
  ticket_id              uuid,
  scope                  text CHECK (scope IS NULL OR length(scope) <= 1000),
  status                 text NOT NULL DEFAULT 'received'
                         CHECK (status IN ('received', 'identity_verified', 'in_progress',
                                           'completed', 'refused', 'cancelled')),
  due_at                 timestamptz NOT NULL,
  assigned_to            text NOT NULL,
  identity_method        text,
  identity_verified_at   timestamptz,
  identity_verified_by   text,
  result_note            text CHECK (result_note IS NULL OR length(result_note) <= 2000),
  created_by             text NOT NULL,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  closed_at              timestamptz,
  CONSTRAINT privacy_requests_demandeur CHECK (requester_id IS NOT NULL OR requester_contact IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS privacy_requests_file_idx
  ON public.privacy_requests (status, due_at)
  WHERE status IN ('received', 'identity_verified', 'in_progress');

-- ── 3. Incidents de sécurité ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.security_incidents (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title              text NOT NULL CHECK (length(btrim(title)) BETWEEN 5 AND 120),
  severity           text NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  status             text NOT NULL DEFAULT 'open'
                     CHECK (status IN ('open', 'contained', 'resolved', 'closed')),
  summary            text NOT NULL CHECK (length(btrim(summary)) BETWEEN 10 AND 2000),
  impact             text CHECK (impact IS NULL OR length(impact) <= 1000),
  owner_id           text NOT NULL,
  detected_at        timestamptz NOT NULL DEFAULT now(),
  contained_at       timestamptz,
  resolved_at        timestamptz,
  closed_at          timestamptz,
  cause              text CHECK (cause IS NULL OR length(cause) <= 2000),
  corrective_actions text CHECK (corrective_actions IS NULL OR length(corrective_actions) <= 2000),
  lessons            text CHECK (lessons IS NULL OR length(lessons) <= 2000),
  created_by         text NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS security_incidents_file_idx
  ON public.security_incidents (status, severity, detected_at DESC);

CREATE TABLE IF NOT EXISTS public.security_incident_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES public.security_incidents (id),
  kind        text NOT NULL CHECK (kind IN ('opened', 'note', 'status', 'severity')),
  body        text CHECK (body IS NULL OR length(body) <= 4000),
  actor_id    text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS security_incident_events_idx
  ON public.security_incident_events (incident_id, occurred_at);

CREATE OR REPLACE FUNCTION public.security_incident_events_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'security_incident_events est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS security_incident_events_no_rewrite ON public.security_incident_events;
CREATE TRIGGER security_incident_events_no_rewrite
  BEFORE UPDATE OR DELETE ON public.security_incident_events
  FOR EACH ROW EXECUTE FUNCTION public.security_incident_events_append_only();

-- ── 4. Droits : lecture par permission, écriture par RPC seulement ──────────
ALTER TABLE public.privacy_requests          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_incidents        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_incident_events  ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.privacy_requests          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.security_incidents        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.security_incident_events  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.privacy_requests          TO authenticated;
GRANT SELECT ON public.security_incidents        TO authenticated;
GRANT SELECT ON public.security_incident_events  TO authenticated;

DROP POLICY IF EXISTS privacy_requests_select ON public.privacy_requests;
CREATE POLICY privacy_requests_select ON public.privacy_requests
  FOR SELECT TO authenticated USING (public.admin_has_permission('privacy.requests.manage'));
DROP POLICY IF EXISTS security_incidents_select ON public.security_incidents;
CREATE POLICY security_incidents_select ON public.security_incidents
  FOR SELECT TO authenticated USING (public.admin_has_permission('security.incidents.manage'));
DROP POLICY IF EXISTS security_incident_events_select ON public.security_incident_events;
CREATE POLICY security_incident_events_select ON public.security_incident_events
  FOR SELECT TO authenticated USING (public.admin_has_permission('security.incidents.manage'));

-- ═══ Demandes relatives aux données ════════════════════════════════════════
DROP FUNCTION IF EXISTS public.privacy_request_create(text, text, text, uuid, text, timestamptz);

CREATE FUNCTION public.privacy_request_create(
  p_kind         text,
  p_requester_id text,
  p_contact      text,
  p_ticket_id    uuid,
  p_scope        text,
  p_due_at       timestamptz
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  v_id     uuid;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'demande : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('privacy.requests.manage');

  IF p_kind IS NULL OR p_kind NOT IN ('access', 'rectification', 'erasure', 'portability', 'objection') THEN
    RAISE EXCEPTION 'demande : nature invalide' USING ERRCODE = '22023';
  END IF;
  IF nullif(btrim(coalesce(p_requester_id, '')), '') IS NULL
     AND nullif(btrim(coalesce(p_contact, '')), '') IS NULL THEN
    RAISE EXCEPTION 'demande : un compte ou un contact du demandeur est requis' USING ERRCODE = '22023';
  END IF;
  IF p_requester_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_requester_id) THEN
    RAISE EXCEPTION 'demande : compte inconnu' USING ERRCODE = '22023';
  END IF;
  IF length(coalesce(p_contact, '')) > 200 OR length(coalesce(p_scope, '')) > 1000 THEN
    RAISE EXCEPTION 'demande : champ trop long' USING ERRCODE = '22001';
  END IF;
  -- Une échéance INTERNE, choisie par l'agent : le délai légal n'est pas
  -- calculé ici, il dépend du droit applicable et de la nature de la demande.
  IF p_due_at IS NULL OR p_due_at <= now() OR p_due_at > now() + interval '120 days' THEN
    RAISE EXCEPTION 'demande : échéance interne requise, dans le futur et sous 120 jours'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.privacy_requests
    (kind, requester_id, requester_contact, ticket_id, scope, due_at, assigned_to, created_by)
  VALUES
    (p_kind, nullif(btrim(p_requester_id), ''), nullif(btrim(p_contact), ''), p_ticket_id,
     nullif(btrim(p_scope), ''), p_due_at, v_caller, v_caller)
  RETURNING id INTO v_id;

  -- Ni l'identité du demandeur ni le périmètre dans l'audit.
  PERFORM public.write_admin_audit(
    'PRIVACY_REQUEST_CREATED', 'privacy_request', v_id::text, 'success', p_kind, v_id::text,
    jsonb_build_object('kind', p_kind));
  RETURN v_id;
END $$;

DROP FUNCTION IF EXISTS public.privacy_request_verify_identity(uuid, text);

CREATE FUNCTION public.privacy_request_verify_identity(p_id uuid, p_method text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  r        public.privacy_requests%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'demande : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('privacy.requests.manage');

  IF p_method IS NULL OR length(btrim(p_method)) < 5 OR length(p_method) > 200 THEN
    RAISE EXCEPTION 'demande : méthode de vérification requise (5 à 200 caractères)'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO r FROM public.privacy_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demande : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF r.status <> 'received' THEN
    RAISE EXCEPTION 'demande : vérification impossible depuis le statut %', r.status
      USING ERRCODE = '55000';
  END IF;
  IF r.assigned_to <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'demande : attribuée à un autre agent' USING ERRCODE = '42501';
  END IF;

  UPDATE public.privacy_requests SET
    status = 'identity_verified', identity_method = btrim(p_method),
    identity_verified_at = now(), identity_verified_by = v_caller, updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'PRIVACY_IDENTITY_VERIFIED', 'privacy_request', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'identity_verified';
END $$;

DROP FUNCTION IF EXISTS public.privacy_request_transition(uuid, text, text);

CREATE FUNCTION public.privacy_request_transition(
  p_id   uuid,
  p_to   text,
  p_note text DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  r        public.privacy_requests%ROWTYPE;
  v_clos   boolean;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'demande : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('privacy.requests.manage');

  IF length(coalesce(p_note, '')) > 2000 THEN
    RAISE EXCEPTION 'demande : note trop longue (2000 max)' USING ERRCODE = '22001';
  END IF;

  SELECT * INTO r FROM public.privacy_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demande : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF r.assigned_to <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'demande : attribuée à un autre agent' USING ERRCODE = '42501';
  END IF;

  IF NOT (
       (r.status = 'identity_verified' AND p_to = 'in_progress')
    OR (r.status = 'in_progress'       AND p_to = 'completed')
    OR (r.status IN ('received', 'identity_verified', 'in_progress') AND p_to IN ('refused', 'cancelled'))
  ) THEN
    -- Notamment : on ne passe jamais en traitement sans identité vérifiée.
    RAISE EXCEPTION 'demande : passage % → % impossible', r.status, p_to USING ERRCODE = '55000';
  END IF;

  -- Terminée : le compte rendu ; refusée / annulée : le motif.
  IF p_to IN ('completed', 'refused', 'cancelled')
     AND nullif(btrim(coalesce(p_note, '')), '') IS NULL THEN
    RAISE EXCEPTION 'demande : %',
      CASE p_to WHEN 'completed' THEN 'compte rendu du traitement requis (systèmes traités, résultat)'
                ELSE 'motif requis' END
      USING ERRCODE = '22023';
  END IF;

  v_clos := p_to IN ('completed', 'refused', 'cancelled');
  UPDATE public.privacy_requests SET
    status = p_to,
    result_note = CASE WHEN v_clos THEN btrim(p_note) ELSE result_note END,
    closed_at = CASE WHEN v_clos THEN now() ELSE closed_at END,
    updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    CASE p_to WHEN 'in_progress' THEN 'PRIVACY_REQUEST_STARTED'
              WHEN 'completed'   THEN 'PRIVACY_REQUEST_COMPLETED'
              WHEN 'refused'     THEN 'PRIVACY_REQUEST_REFUSED'
              ELSE 'PRIVACY_REQUEST_CANCELLED' END,
    'privacy_request', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('kind', r.kind, 'from', r.status, 'late', now() > r.due_at));
  RETURN p_to;
END $$;

-- ═══ Incidents de sécurité ═════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.security_incident_open(text, text, text, text, timestamptz);

CREATE FUNCTION public.security_incident_open(
  p_title       text,
  p_severity    text,
  p_summary     text,
  p_impact      text,
  p_detected_at timestamptz DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  v_id     uuid;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'incident : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.incidents.manage');

  IF p_title IS NULL OR length(btrim(p_title)) NOT BETWEEN 5 AND 120 THEN
    RAISE EXCEPTION 'incident : titre requis (5 à 120 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_severity IS NULL OR p_severity NOT IN ('low', 'medium', 'high', 'critical') THEN
    RAISE EXCEPTION 'incident : gravité invalide' USING ERRCODE = '22023';
  END IF;
  IF p_summary IS NULL OR length(btrim(p_summary)) NOT BETWEEN 10 AND 2000 THEN
    RAISE EXCEPTION 'incident : résumé requis (10 à 2000 caractères)' USING ERRCODE = '22023';
  END IF;
  IF length(coalesce(p_impact, '')) > 1000 THEN
    RAISE EXCEPTION 'incident : impact trop long (1000 max)' USING ERRCODE = '22001';
  END IF;
  IF p_detected_at IS NOT NULL AND p_detected_at > now() THEN
    RAISE EXCEPTION 'incident : la détection est dans le futur' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.security_incidents
    (title, severity, summary, impact, owner_id, detected_at, created_by)
  VALUES
    (btrim(p_title), p_severity, btrim(p_summary), nullif(btrim(p_impact), ''), v_caller,
     coalesce(p_detected_at, now()), v_caller)
  RETURNING id INTO v_id;
  INSERT INTO public.security_incident_events (incident_id, kind, body, actor_id)
  VALUES (v_id, 'opened', btrim(p_summary), v_caller);

  PERFORM public.write_admin_audit(
    'INCIDENT_OPENED', 'security_incident', v_id::text, 'success', p_severity, v_id::text,
    jsonb_build_object('severity', p_severity));
  RETURN v_id;
END $$;

DROP FUNCTION IF EXISTS public.security_incident_note(uuid, text);

CREATE FUNCTION public.security_incident_note(p_id uuid, p_body text) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  i        public.security_incidents%ROWTYPE;
  v_id     uuid;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'incident : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.incidents.manage');

  IF p_body IS NULL OR length(btrim(p_body)) < 1 OR length(p_body) > 4000 THEN
    RAISE EXCEPTION 'incident : note requise (4000 caractères au plus)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO i FROM public.security_incidents WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'incident : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF i.status = 'closed' THEN
    RAISE EXCEPTION 'incident : clos, la chronologie ne bouge plus' USING ERRCODE = '55000';
  END IF;

  INSERT INTO public.security_incident_events (incident_id, kind, body, actor_id)
  VALUES (p_id, 'note', btrim(p_body), v_caller) RETURNING id INTO v_id;
  UPDATE public.security_incidents SET updated_at = now() WHERE id = p_id;

  -- Le texte d'une note peut contenir des éléments de preuve : pas dans l'audit.
  PERFORM public.write_admin_audit(
    'INCIDENT_NOTE_ADDED', 'security_incident', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('event', v_id));
  RETURN v_id;
END $$;

DROP FUNCTION IF EXISTS public.security_incident_set_severity(uuid, text, text);

CREATE FUNCTION public.security_incident_set_severity(
  p_id       uuid,
  p_severity text,
  p_reason   text
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  i        public.security_incidents%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'incident : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.incidents.manage');

  IF p_severity IS NULL OR p_severity NOT IN ('low', 'medium', 'high', 'critical') THEN
    RAISE EXCEPTION 'incident : gravité invalide' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'incident : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO i FROM public.security_incidents WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'incident : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF i.status = 'closed' THEN
    RAISE EXCEPTION 'incident : clos' USING ERRCODE = '55000';
  END IF;
  IF i.severity = p_severity THEN
    RAISE EXCEPTION 'incident : gravité inchangée' USING ERRCODE = '55000';
  END IF;

  UPDATE public.security_incidents SET severity = p_severity, updated_at = now() WHERE id = p_id;
  INSERT INTO public.security_incident_events (incident_id, kind, body, actor_id)
  VALUES (p_id, 'severity', i.severity || ' → ' || p_severity || ' : ' || btrim(p_reason), v_caller);

  PERFORM public.write_admin_audit(
    'INCIDENT_SEVERITY_CHANGED', 'security_incident', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('from', i.severity, 'to', p_severity));
  RETURN p_severity;
END $$;

DROP FUNCTION IF EXISTS public.security_incident_transition(uuid, text, text, text, text, text);

CREATE FUNCTION public.security_incident_transition(
  p_id      uuid,
  p_to      text,
  p_note    text,
  p_cause   text DEFAULT NULL,
  p_actions text DEFAULT NULL,
  p_lessons text DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  i        public.security_incidents%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'incident : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.incidents.manage');

  SELECT * INTO i FROM public.security_incidents WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'incident : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF i.owner_id <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'incident : confié à un autre responsable' USING ERRCODE = '42501';
  END IF;

  IF NOT (
       (i.status = 'open'      AND p_to IN ('contained', 'resolved'))
    OR (i.status = 'contained' AND p_to = 'resolved')
    OR (i.status = 'resolved'  AND p_to = 'closed')
  ) THEN
    RAISE EXCEPTION 'incident : passage % → % impossible', i.status, p_to USING ERRCODE = '55000';
  END IF;

  IF p_note IS NULL OR length(btrim(p_note)) < 5 OR length(p_note) > 2000 THEN
    RAISE EXCEPTION 'incident : note du passage requise (5 à 2000 caractères)' USING ERRCODE = '22023';
  END IF;
  -- La clôture exige l'analyse : cause, mesures correctives, enseignements.
  IF p_to = 'closed' AND (
       length(btrim(coalesce(p_cause, ''))) < 10
    OR length(btrim(coalesce(p_actions, ''))) < 10
    OR length(btrim(coalesce(p_lessons, ''))) < 10) THEN
    RAISE EXCEPTION 'incident : cause, mesures correctives et enseignements requis (10 caractères chacun)'
      USING ERRCODE = '22023';
  END IF;
  IF length(coalesce(p_cause, '')) > 2000 OR length(coalesce(p_actions, '')) > 2000
     OR length(coalesce(p_lessons, '')) > 2000 THEN
    RAISE EXCEPTION 'incident : texte trop long (2000 max)' USING ERRCODE = '22001';
  END IF;

  UPDATE public.security_incidents SET
    status = p_to,
    contained_at = CASE WHEN p_to = 'contained' THEN now() ELSE contained_at END,
    resolved_at  = CASE WHEN p_to = 'resolved'  THEN now() ELSE resolved_at END,
    closed_at    = CASE WHEN p_to = 'closed'    THEN now() ELSE closed_at END,
    cause = CASE WHEN p_to = 'closed' THEN btrim(p_cause) ELSE cause END,
    corrective_actions = CASE WHEN p_to = 'closed' THEN btrim(p_actions) ELSE corrective_actions END,
    lessons = CASE WHEN p_to = 'closed' THEN btrim(p_lessons) ELSE lessons END,
    updated_at = now()
   WHERE id = p_id;
  INSERT INTO public.security_incident_events (incident_id, kind, body, actor_id)
  VALUES (p_id, 'status', i.status || ' → ' || p_to || ' : ' || btrim(p_note), v_caller);

  PERFORM public.write_admin_audit(
    CASE p_to WHEN 'contained' THEN 'INCIDENT_CONTAINED'
              WHEN 'resolved'  THEN 'INCIDENT_RESOLVED'
              ELSE 'INCIDENT_CLOSED' END,
    'security_incident', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('severity', i.severity, 'from', i.status));
  RETURN p_to;
END $$;

-- ── 5. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.privacy_request_create(text, text, text, uuid, text, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_verify_identity(uuid, text)      FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_transition(uuid, text, text)     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.security_incident_open(text, text, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.security_incident_note(uuid, text)               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.security_incident_set_severity(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.security_incident_transition(uuid, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.privacy_request_create(text, text, text, uuid, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_verify_identity(uuid, text)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_transition(uuid, text, text)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.security_incident_open(text, text, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.security_incident_note(uuid, text)               TO authenticated;
GRANT EXECUTE ON FUNCTION public.security_incident_set_severity(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.security_incident_transition(uuid, text, text, text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
