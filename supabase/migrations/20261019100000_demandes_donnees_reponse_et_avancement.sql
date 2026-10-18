-- Demandes relatives aux données : le demandeur est prévenu, lit une RÉPONSE,
-- et l'agent compose cette réponse sur un état des lieux, pas de mémoire.
--
-- Suite de 20261018230000 et 20261018250000. Corrige deux des trois limites
-- que celles-ci nommaient ; la troisième est une décision, pas un défaut (voir
-- en bas).
--
-- ═══ 1. « Le demandeur n'est pas prévenu quand sa demande avance » ═════════
--
-- Chaque étape décidée par un agent (identité vérifiée, traitement commencé,
-- demande traitée, refusée, clôturée) crée une notification pour le compte
-- demandeur. Le texte est fixe, écrit ici, et NEUTRE : ni la nature de la
-- demande, ni le motif ne figurent dans l'aperçu d'un push affiché sur un
-- écran verrouillé — le demandeur ouvre l'application pour lire. Type
-- `general` : ces messages sont indispensables au service (le référentiel veut
-- ne pas les mélanger avec le promotionnel), ils ne dépendent donc pas de la
-- bascule « Messages système ». Pas de notification pour un retrait fait par le
-- demandeur lui-même, ni pour une demande sans compte.
--
-- ═══ 2. « La demande d'accès n'est pas exécutée : l'agent compose la réponse » ═
--
-- Faire sortir des données personnelles du système par une fonction
-- d'administration est exactement ce que le référentiel interdit d'ouvrir à la
-- légère. Deux choses à la place :
--   • `privacy_request_data_summary` : un ÉTAT DES LIEUX en nombres (messages
--     envoyés, publications, appareils…), sans aucun contenu, et seulement une
--     fois l'identité vérifiée. L'agent s'appuie dessus pour répondre.
--   • `answer` : la RÉPONSE adressée au demandeur, distincte de la note
--     interne. Obligatoire pour terminer ou refuser une demande liée à un
--     compte, lisible par le seul demandeur dans « Mes demandes ». La note
--     interne, elle, ne sort jamais.
-- Les données elles-mêmes restent accessibles au demandeur par l'export en
-- libre-service (`export-my-data`), qui ne passe par aucun agent.
--
-- ═══ 3. « L'échéance de 30 jours n'est pas un engagement affiché » ══════════
--
-- Volontaire, et laissé tel quel : annoncer un délai à l'utilisateur est un
-- engagement juridique dont la valeur dépend du droit applicable (le Niger, la
-- France et les autres pays de la diaspora n'ont pas le même). Ce n'est pas à
-- une migration de le fixer. Si l'équipe arrête un délai, il suffit d'ajouter
-- une phrase à l'écran « Mes demandes » ; rien d'autre ne change.
--
-- Banc : tools/rls_tests/demandes_donnees_reponse_et_avancement.sql.

SET lock_timeout = '5s';

-- ── 1. La réponse ───────────────────────────────────────────────────────────
ALTER TABLE public.privacy_requests
  ADD COLUMN IF NOT EXISTS answer text
  CHECK (answer IS NULL OR length(answer) <= 2000);

-- ── 2. La notification du demandeur ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.privacy_notify_requester(uuid, text);

CREATE FUNCTION public.privacy_notify_requester(p_request uuid, p_event text) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r      public.privacy_requests%ROWTYPE;
  v_body text;
BEGIN
  SELECT * INTO r FROM public.privacy_requests WHERE id = p_request;
  IF NOT FOUND OR r.requester_id IS NULL THEN
    RETURN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = r.requester_id) THEN
    RETURN;
  END IF;

  v_body := CASE p_event
    WHEN 'identity_verified' THEN 'Votre identité a été vérifiée. Votre demande va être traitée.'
    WHEN 'in_progress'       THEN 'Votre demande est en cours de traitement.'
    WHEN 'completed'         THEN 'Votre demande a été traitée. Ouvrez « Mes demandes » pour lire la réponse.'
    WHEN 'refused'           THEN 'Votre demande a reçu une réponse. Ouvrez « Mes demandes » pour la lire.'
    WHEN 'cancelled'         THEN 'Votre demande a été clôturée.'
    ELSE NULL END;
  IF v_body IS NULL THEN
    RETURN;
  END IF;

  -- Aperçu neutre : jamais la nature de la demande, jamais le motif.
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (r.requester_id, 'general', 'Votre demande sur vos données', v_body,
          jsonb_build_object('privacy_request', p_request::text));
END $$;

REVOKE ALL ON FUNCTION public.privacy_notify_requester(uuid, text) FROM PUBLIC, anon, authenticated;

-- ── 3. L'identité vérifiée prévient le demandeur ────────────────────────────
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

  PERFORM public.privacy_notify_requester(p_id, 'identity_verified');
  PERFORM public.write_admin_audit(
    'PRIVACY_IDENTITY_VERIFIED', 'privacy_request', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'identity_verified';
END $$;

-- ── 4. Les transitions : réponse au demandeur, et notification ──────────────
DROP FUNCTION IF EXISTS public.privacy_request_transition(uuid, text, text);
DROP FUNCTION IF EXISTS public.privacy_request_transition(uuid, text, text, text);

CREATE FUNCTION public.privacy_request_transition(
  p_id     uuid,
  p_to     text,
  p_note   text DEFAULT NULL,
  p_answer text DEFAULT NULL
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

  IF length(coalesce(p_note, '')) > 2000 OR length(coalesce(p_answer, '')) > 2000 THEN
    RAISE EXCEPTION 'demande : texte trop long (2000 max)' USING ERRCODE = '22001';
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

  -- Une personne qui a un compte reçoit une RÉPONSE écrite avec la décision :
  -- on ne lui annonce pas « traitée » ou « refusée » sans lui dire quoi.
  IF p_to IN ('completed', 'refused') AND r.requester_id IS NOT NULL
     AND length(btrim(coalesce(p_answer, ''))) < 10 THEN
    RAISE EXCEPTION 'demande : une réponse au demandeur est requise (10 caractères au moins)'
      USING ERRCODE = '22023';
  END IF;

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
    answer = CASE WHEN p_to IN ('completed', 'refused') THEN nullif(btrim(p_answer), '') ELSE answer END,
    closed_at = CASE WHEN v_clos THEN now() ELSE closed_at END,
    updated_at = now()
   WHERE id = p_id;

  PERFORM public.privacy_notify_requester(p_id, p_to);
  PERFORM public.write_admin_audit(
    CASE p_to WHEN 'in_progress' THEN 'PRIVACY_REQUEST_STARTED'
              WHEN 'completed'   THEN 'PRIVACY_REQUEST_COMPLETED'
              WHEN 'refused'     THEN 'PRIVACY_REQUEST_REFUSED'
              ELSE 'PRIVACY_REQUEST_CANCELLED' END,
    'privacy_request', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('kind', r.kind, 'from', r.status, 'late', now() > r.due_at));
  RETURN p_to;
END $$;

-- ── 5. Ce que le demandeur lit ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.privacy_request_mine();

CREATE FUNCTION public.privacy_request_mine()
RETURNS TABLE (id uuid, kind text, status text, created_at timestamptz, closed_at timestamptz, answer text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  -- L'état et la RÉPONSE adressée au demandeur ; jamais la note interne, ni
  -- l'agent, ni l'échéance interne.
  SELECT r.id, r.kind, r.status, r.created_at, r.closed_at,
         CASE WHEN r.status IN ('completed', 'refused') THEN r.answer END
    FROM public.privacy_requests r
   WHERE r.requester_id = (SELECT public.firebase_uid())
   ORDER BY r.created_at DESC
   LIMIT 50
$$;

-- ── 6. L'état des lieux pour l'agent : des nombres, aucun contenu ───────────
DROP FUNCTION IF EXISTS public.privacy_request_data_summary(uuid);

CREATE FUNCTION public.privacy_request_data_summary(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r public.privacy_requests%ROWTYPE;
  u text;
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
    RAISE EXCEPTION 'demande : pas de compte lié, rien à dénombrer' USING ERRCODE = '22023';
  END IF;
  -- Pas d'état des lieux avant que l'identité soit établie : un décompte sur le
  -- compte de quelqu'un d'autre est déjà une fuite.
  IF r.identity_verified_at IS NULL THEN
    RAISE EXCEPTION 'demande : vérifiez d''abord l''identité du demandeur' USING ERRCODE = '55000';
  END IF;
  u := r.requester_id;

  RETURN jsonb_build_object(
    'account_exists', EXISTS (SELECT 1 FROM public.users WHERE id = u),
    'messages_sent',      (SELECT count(*) FROM public.messages WHERE sender_id = u),
    'posts',              (SELECT count(*) FROM public.posts WHERE author_id = u),
    'post_comments',      (SELECT count(*) FROM public.post_comments WHERE author_id = u),
    'stories',            (SELECT count(*) FROM public.stories WHERE author_id = u),
    'friends',            (SELECT count(*) FROM public.friends WHERE user_id = u),
    'groups',             (SELECT count(*) FROM public.group_members WHERE user_id = u),
    'notifications',      (SELECT count(*) FROM public.notifications WHERE user_id = u),
    'events_organized',   (SELECT count(*) FROM public.events WHERE organizer_id = u),
    'businesses',         (SELECT count(*) FROM public.businesses WHERE owner_id = u),
    'support_tickets',    (SELECT count(*) FROM public.support_tickets WHERE user_id = u),
    'reports_filed',      (SELECT count(*) FROM public.reports WHERE reporter_id = u),
    'blocked_users',      (SELECT count(*) FROM public.blocked_users WHERE blocker_id = u),
    'devices',            (SELECT count(*) FROM public.e2ee_devices WHERE user_id = u)
                        + (SELECT count(*) FROM public.mls_devices WHERE user_id = u),
    'note', 'Nombres seulement. Les messages sont chiffrés de bout en bout : le serveur n''en détient pas le contenu.');
END $$;

-- ── 7. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.privacy_request_verify_identity(uuid, text)               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_transition(uuid, text, text, text)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_mine()                                    FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.privacy_request_data_summary(uuid)                        FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.privacy_request_verify_identity(uuid, text)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_transition(uuid, text, text, text)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_mine()                                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.privacy_request_data_summary(uuid)                     TO authenticated;

NOTIFY pgrst, 'reload schema';
