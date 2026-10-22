-- Demandes relatives aux données : un point d'entrée pour l'utilisateur, une
-- file à prendre en charge, et un effacement qui ne se déclare plus « terminé »
-- sur la parole de l'agent.
--
-- Suite de 20261018230000. Elle corrige deux limites que celle-ci avait
-- nommées :
--
-- ═══ 1. « Pas de point d'entrée côté application » ═════════════════════════
--
-- Une demande ne pouvait naître que dans le panneau, à partir d'un ticket ou
-- d'un courriel. `privacy_request_submit` la laisse naître du compte lui-même
-- (accès, rectification, opposition) : l'identité du demandeur est alors celle
-- de sa session, jamais un paramètre. L'effacement et la portabilité n'y sont
-- PAS : l'utilisateur a déjà ses parcours (suppression de compte par phases,
-- export), qui font ce que la demande réclamerait — la fonction le dit.
-- Garde-fous : un seul dossier ouvert par nature, trois demandes par 24 h au
-- plus, périmètre libre borné. `privacy_request_mine` rend à l'utilisateur
-- l'état de SES demandes (jamais les notes internes), `privacy_request_withdraw`
-- lui permet de retirer une demande encore ouverte.
-- `assigned_to` devient nullable : une demande de l'application attend dans la
-- file, `privacy_request_take` la prend. Les deux fonctions de traitement
-- exigent désormais cette prise en charge (elles laissaient passer un
-- `assigned_to` nul par une comparaison `<>` qui vaut NULL).
--
-- ═══ 2. « Une demande d'effacement terminée ne supprime rien » ══════════════
--
-- La suivre ne l'exécute pas, et l'agent peut seulement consigner. Mais rien
-- n'empêchait de la déclarer « terminée » alors que le compte existait
-- toujours. Désormais, pour une demande d'effacement liée à un compte,
-- « terminée » exige que le compte ait RÉELLEMENT disparu (plus de ligne
-- `users`) ou que sa suppression soit `completed` dans
-- `account_deletion_requests`. `privacy_request_erasure_status` montre à
-- l'agent où en est la suppression (compte présent ? délai de grâce ?).
-- Elle n'exécute toujours rien : la suppression se lance depuis le compte de la
-- personne, avec son délai de grâce de 30 jours, ce que ni un agent ni cette
-- migration ne contournent.
--
-- ═══ CE QUE CELA NE FAIT TOUJOURS PAS ═══════════════════════════════════════
--
-- • Pas de notification au demandeur quand sa demande avance (il lit son état
--   dans l'application, c'est tout).
-- • La demande d'accès n'est pas exécutée non plus : l'agent compose la
--   réponse. Pour la portabilité, c'est l'export en libre-service.
-- • Pas de pièce jointe pour prouver l'identité.
--
-- Banc : tools/rls_tests/demandes_donnees_depuis_l_app.sql.

SET lock_timeout = '5s';

-- ── 1. Colonnes ─────────────────────────────────────────────────────────────
ALTER TABLE public.privacy_requests ALTER COLUMN assigned_to DROP NOT NULL;
ALTER TABLE public.privacy_requests
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'panel';
ALTER TABLE public.privacy_requests DROP CONSTRAINT IF EXISTS privacy_requests_source_check;
ALTER TABLE public.privacy_requests ADD CONSTRAINT privacy_requests_source_check
  CHECK (source IN ('panel', 'app'));

-- Une demande ouverte par compte ET par nature (celles de l'application).
CREATE UNIQUE INDEX IF NOT EXISTS privacy_requests_app_ouverte_uidx
  ON public.privacy_requests (requester_id, kind)
  WHERE source = 'app' AND status IN ('received', 'identity_verified', 'in_progress');

-- ── 2. Côté utilisateur ─────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.privacy_request_submit(text, text);

CREATE FUNCTION public.privacy_request_submit(p_kind text, p_details text) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := (SELECT public.firebase_uid());
  v_id  uuid;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'demande : connexion requise' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_uid) THEN
    RAISE EXCEPTION 'demande : compte introuvable' USING ERRCODE = '42501';
  END IF;

  IF p_kind IN ('erasure', 'portability') THEN
    RAISE EXCEPTION 'demande : utilisez « Supprimer mon compte » ou « Exporter mes données », qui font ce que cette demande réclamerait'
      USING ERRCODE = '22023';
  END IF;
  IF p_kind IS NULL OR p_kind NOT IN ('access', 'rectification', 'objection') THEN
    RAISE EXCEPTION 'demande : nature invalide (access, rectification, objection)'
      USING ERRCODE = '22023';
  END IF;
  IF p_details IS NULL OR length(btrim(p_details)) < 10 OR length(p_details) > 1000 THEN
    RAISE EXCEPTION 'demande : précisez votre demande (10 à 1000 caractères)'
      USING ERRCODE = '22023';
  END IF;

  IF (SELECT count(*) FROM public.privacy_requests
       WHERE requester_id = v_uid AND source = 'app'
         AND created_at > now() - interval '24 hours') >= 3 THEN
    RAISE EXCEPTION 'demande : trois demandes par jour au plus, réessayez demain'
      USING ERRCODE = '55000';
  END IF;

  BEGIN
    -- L'échéance est un objectif INTERNE (30 jours), pas un engagement légal
    -- affiché à l'utilisateur ; le panneau la reprend et l'agent l'ajuste.
    INSERT INTO public.privacy_requests
      (kind, requester_id, scope, source, due_at, assigned_to, created_by)
    VALUES
      (p_kind, v_uid, btrim(p_details), 'app', now() + interval '30 days', NULL, v_uid)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'demande : une demande de cette nature est déjà en cours'
      USING ERRCODE = '55000';
  END;
  RETURN v_id;
END $$;

DROP FUNCTION IF EXISTS public.privacy_request_mine();

CREATE FUNCTION public.privacy_request_mine()
RETURNS TABLE (id uuid, kind text, status text, created_at timestamptz, closed_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  -- L'état seulement : ni les notes internes, ni l'agent, ni l'échéance interne.
  SELECT r.id, r.kind, r.status, r.created_at, r.closed_at
    FROM public.privacy_requests r
   WHERE r.requester_id = (SELECT public.firebase_uid())
   ORDER BY r.created_at DESC
   LIMIT 50
$$;

DROP FUNCTION IF EXISTS public.privacy_request_withdraw(uuid);

CREATE FUNCTION public.privacy_request_withdraw(p_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := (SELECT public.firebase_uid());
  r     public.privacy_requests%ROWTYPE;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'demande : connexion requise' USING ERRCODE = '42501';
  END IF;
  -- La demande d'un autre est introuvable, pas « interdite » : on ne confirme
  -- pas son existence.
  SELECT * INTO r FROM public.privacy_requests
   WHERE id = p_id AND requester_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demande : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF r.status NOT IN ('received', 'identity_verified', 'in_progress') THEN
    RAISE EXCEPTION 'demande : déjà clôturée' USING ERRCODE = '55000';
  END IF;
  UPDATE public.privacy_requests SET
    status = 'cancelled', result_note = 'Retirée par le demandeur',
    closed_at = now(), updated_at = now()
   WHERE id = p_id;
  RETURN 'cancelled';
END $$;

-- ── 3. Côté agent : prendre en charge, et ne plus traiter une demande sans l'avoir prise ──
DROP FUNCTION IF EXISTS public.privacy_request_take(uuid);

CREATE FUNCTION public.privacy_request_take(p_id uuid) RETURNS text
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

  SELECT * INTO r FROM public.privacy_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demande : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF r.status NOT IN ('received', 'identity_verified', 'in_progress') THEN
    RAISE EXCEPTION 'demande : déjà clôturée' USING ERRCODE = '55000';
  END IF;
  IF r.assigned_to IS NOT NULL AND r.assigned_to <> v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'demande : attribuée à un autre agent' USING ERRCODE = '42501';
  END IF;

  UPDATE public.privacy_requests SET assigned_to = v_caller, updated_at = now() WHERE id = p_id;
  PERFORM public.write_admin_audit(
    'PRIVACY_REQUEST_TAKEN', 'privacy_request', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('kind', r.kind, 'source', r.source));
  RETURN 'taken';
END $$;

-- Mêmes corps qu'en 20261018230000, avec la prise en charge exigée (`IS
-- DISTINCT FROM` : un `assigned_to` nul n'est plus une porte ouverte).
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
  IF r.assigned_to IS NULL THEN
    RAISE EXCEPTION 'demande : à prendre en charge d''abord' USING ERRCODE = '55000';
  END IF;
  IF r.assigned_to IS DISTINCT FROM v_caller AND NOT public.is_super_admin() THEN
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
  IF r.assigned_to IS NULL THEN
    RAISE EXCEPTION 'demande : à prendre en charge d''abord' USING ERRCODE = '55000';
  END IF;
  IF r.assigned_to IS DISTINCT FROM v_caller AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'demande : attribuée à un autre agent' USING ERRCODE = '42501';
  END IF;

  IF NOT (
       (r.status = 'identity_verified' AND p_to = 'in_progress')
    OR (r.status = 'in_progress'       AND p_to = 'completed')
    OR (r.status IN ('received', 'identity_verified', 'in_progress') AND p_to IN ('refused', 'cancelled'))
  ) THEN
    RAISE EXCEPTION 'demande : passage % → % impossible', r.status, p_to USING ERRCODE = '55000';
  END IF;

  IF p_to IN ('completed', 'refused', 'cancelled')
     AND nullif(btrim(coalesce(p_note, '')), '') IS NULL THEN
    RAISE EXCEPTION 'demande : %',
      CASE p_to WHEN 'completed' THEN 'compte rendu du traitement requis (systèmes traités, résultat)'
                ELSE 'motif requis' END
      USING ERRCODE = '22023';
  END IF;

  -- Effacement : « terminée » se prouve. Le compte doit avoir disparu, ou sa
  -- suppression être achevée ; sinon l'agent consigne un état qui n'existe pas.
  IF p_to = 'completed' AND r.kind = 'erasure' AND r.requester_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.users WHERE id = r.requester_id)
     AND NOT EXISTS (SELECT 1 FROM public.account_deletion_requests
                      WHERE user_id = r.requester_id AND status = 'completed') THEN
    RAISE EXCEPTION 'demande : le compte existe encore et sa suppression n''est pas achevée ; une demande d''effacement ne se termine qu''une fois le compte effacé'
      USING ERRCODE = '55000';
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

-- Où en est la suppression du compte visé par une demande d'effacement.
DROP FUNCTION IF EXISTS public.privacy_request_erasure_status(uuid);

CREATE FUNCTION public.privacy_request_erasure_status(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r public.privacy_requests%ROWTYPE;
  d public.account_deletion_requests%ROWTYPE;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'demande : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('privacy.requests.manage');

  SELECT * INTO r FROM public.privacy_requests WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demande : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF r.requester_id IS NULL THEN
    RETURN jsonb_build_object('linked', false);
  END IF;

  SELECT * INTO d FROM public.account_deletion_requests WHERE user_id = r.requester_id;
  RETURN jsonb_build_object(
    'linked', true,
    'account_exists', EXISTS (SELECT 1 FROM public.users WHERE id = r.requester_id),
    'deletion_status', d.status,
    'execute_at', d.execute_at);
END $$;

-- ── 4. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.privacy_request_submit(text, text)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_mine()                   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_withdraw(uuid)           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_take(uuid)               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_verify_identity(uuid, text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_transition(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_erasure_status(uuid)     FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.privacy_request_submit(text, text)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_mine()                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_withdraw(uuid)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_take(uuid)               TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_verify_identity(uuid, text)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_transition(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_erasure_status(uuid)     TO authenticated;

NOTIFY pgrst, 'reload schema';
