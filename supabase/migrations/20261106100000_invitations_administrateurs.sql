-- Invitations d'administrateurs : un rôle ne s'active qu'APRÈS acceptation par la personne. NON APPLIQUÉE.
-- À répéter par tools/rls_tests/invitations_administrateurs.sql avant toute application.
--
-- PROCESSUS
--   1. un super-administrateur cherche un membre (e-mail MASQUÉ, résultats bornés, recherches comptées) ;
--   2. il l'invite à un rôle ; pour `superAdmin`, un SECOND super-administrateur doit approuver ;
--   3. le membre reçoit une notification neutre et voit l'invitation à sa prochaine connexion à la console
--      (après son second facteur) ; l'invitation expire au bout de 7 jours ;
--   4. il accepte : la Cloud Function `accepterInvitationAdmin` (clé de service) revérifie, marque l'invitation
--      acceptée, puis écrit le rôle dans les TROIS registres comme `setAdminRole` ; il peut aussi refuser ;
--   5. tout est journalisé : qui a invité, qui a approuvé, qui a révoqué, qui a accepté ou refusé.
--
-- CE QUE CETTE MIGRATION N'ENLÈVE PAS : `setAdminRole` reste la voie du retrait immédiat et du dépannage. Elle ne
-- passe pas par une invitation : un retrait d'accès ne doit jamais attendre l'accord de la personne.
--
-- ÉCRITURES : uniquement par les fonctions ci-dessous (SECURITY DEFINER). La table n'est lisible ni écrivable
-- directement par `authenticated`.

SET lock_timeout = '5s';

-- ── 1. La table ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_invitations (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  invitee_id  text        NOT NULL,
  role        text        NOT NULL
              CHECK (role IN ('superAdmin', 'contentMod', 'businessMod', 'financeMod',
                              'supportAgent', 'validator', 'auditor', 'analyst')),
  invited_by  text        NOT NULL,
  approved_by text,
  status      text        NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending_approval', 'pending', 'accepted', 'declined', 'revoked', 'expired')),
  expires_at  timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  decided_at  timestamptz,
  CHECK (approved_by IS NULL OR approved_by <> invited_by)
);

-- Une seule invitation ouverte par personne : pas d'empilement.
CREATE UNIQUE INDEX IF NOT EXISTS admin_invitations_une_ouverte
  ON public.admin_invitations (invitee_id) WHERE status IN ('pending_approval', 'pending');

ALTER TABLE public.admin_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_invitations FROM PUBLIC, anon, authenticated;

-- ── 2. Outils internes ─────────────────────────────────────────────────────
-- Journal pour un acteur qui n'est PAS administrateur (l'invité) : write_admin_audit le refuserait.
CREATE OR REPLACE FUNCTION public.admin_invitation_journal(p_actor text, p_action text, p_target text, p_details jsonb)
RETURNS void
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  INSERT INTO public.admin_audit_logs (admin_id, admin_name, action, target_type, target_id, details)
  VALUES (p_actor, (SELECT display_name FROM public.users WHERE id = p_actor), p_action, 'admin_invitation', p_target, p_details)
$$;
REVOKE ALL ON FUNCTION public.admin_invitation_journal(text, text, text, jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_invitation_expirer()
RETURNS void
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE public.admin_invitations SET status = 'expired', decided_at = now()
   WHERE status IN ('pending_approval', 'pending') AND expires_at < now()
$$;
REVOKE ALL ON FUNCTION public.admin_invitation_expirer() FROM PUBLIC, anon, authenticated;

-- ── 3. Recherche d'un membre (e-mail masqué, bornée, comptée) ──────────────
DROP FUNCTION IF EXISTS public.admin_member_search(text);

CREATE FUNCTION public.admin_member_search(p_term text)
RETURNS TABLE (id text, display_name text, email_masked text, created_at timestamptz, is_admin boolean, admin_role text)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  v_term   text := btrim(coalesce(p_term, ''));
  v_motif  text;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'recherche : réservée aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.admins.promote');
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'recherche : réservée aux super-administrateurs' USING ERRCODE = '42501';
  END IF;
  IF length(v_term) < 3 OR length(v_term) > 60 THEN
    RAISE EXCEPTION 'recherche : 3 à 60 caractères' USING ERRCODE = '22023';
  END IF;

  -- Pas d'énumération : 30 recherches par administrateur et par 10 minutes. Le terme n'est pas journalisé.
  IF (SELECT count(*) FROM public.admin_audit_logs
       WHERE admin_id = v_caller AND action = 'ADMIN_MEMBER_SEARCH' AND created_at > now() - interval '10 minutes') >= 30 THEN
    RAISE EXCEPTION 'recherche : trop de recherches, réessayez dans quelques minutes' USING ERRCODE = '55000';
  END IF;
  PERFORM public.write_admin_audit('ADMIN_MEMBER_SEARCH', 'user', NULL, 'success', NULL, NULL, '{}'::jsonb);

  v_motif := replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';

  RETURN QUERY
    SELECT u.id, u.display_name,
           CASE WHEN u.email IS NULL OR u.email = '' THEN NULL
                ELSE regexp_replace(u.email, '^(.).*@(.).*(\.[^.]+)$', '\1•••@\2•••\3') END,
           u.created_at, coalesce(u.is_admin, false), u.admin_role
      FROM public.users u
     WHERE NOT coalesce(u.is_banned, false)
       AND (u.display_name ILIKE v_motif OR lower(coalesce(u.email, '')) LIKE lower(v_motif))
     ORDER BY u.created_at DESC
     LIMIT 10;
END $$;

REVOKE ALL ON FUNCTION public.admin_member_search(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_member_search(text) TO authenticated;

-- ── 4. Inviter ─────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_invitation_create(text, text);

CREATE FUNCTION public.admin_invitation_create(p_member_id text, p_role text) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  u        public.users%ROWTYPE;
  v_id     uuid;
  v_statut text;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'invitation : réservée aux super-administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.admins.promote');
  PERFORM public.admin_invitation_expirer();

  IF p_role IS NULL OR p_role NOT IN ('superAdmin', 'contentMod', 'businessMod', 'financeMod',
                                       'supportAgent', 'validator', 'auditor', 'analyst') THEN
    RAISE EXCEPTION 'invitation : rôle inconnu' USING ERRCODE = '22023';
  END IF;
  IF p_member_id = v_caller THEN
    RAISE EXCEPTION 'invitation : vous ne pouvez pas vous inviter vous-même' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO u FROM public.users WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation : compte introuvable (la personne doit s''être connectée une première fois)' USING ERRCODE = 'P0002';
  END IF;
  IF coalesce(u.is_banned, false) THEN
    RAISE EXCEPTION 'invitation : ce compte est suspendu' USING ERRCODE = '55000';
  END IF;
  IF u.admin_role IS NOT DISTINCT FROM p_role AND coalesce(u.is_admin, false) THEN
    RAISE EXCEPTION 'invitation : ce compte a déjà ce rôle' USING ERRCODE = '55000';
  END IF;

  v_statut := CASE WHEN p_role = 'superAdmin' THEN 'pending_approval' ELSE 'pending' END;
  BEGIN
    INSERT INTO public.admin_invitations (invitee_id, role, invited_by, status, expires_at)
    VALUES (p_member_id, p_role, v_caller, v_statut, now() + interval '7 days')
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'invitation : une invitation est déjà en cours pour cette personne' USING ERRCODE = '55000';
  END;

  IF v_statut = 'pending' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (p_member_id, 'system', 'Invitation à l''équipe d''administration',
            'Vous êtes invité à rejoindre l''équipe. Ouvrez la console d''administration pour répondre.',
            jsonb_build_object('admin_invitation', v_id::text));
  END IF;

  PERFORM public.write_admin_audit('ADMIN_INVITED', 'user', p_member_id, 'success', p_role, v_id::text,
                                   jsonb_build_object('invitation', v_id::text, 'role', p_role, 'status', v_statut));
  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.admin_invitation_create(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_invitation_create(text, text) TO authenticated;

-- ── 5. Approuver (second super-administrateur, pour le rôle superAdmin) ────
DROP FUNCTION IF EXISTS public.admin_invitation_approve(uuid);

CREATE FUNCTION public.admin_invitation_approve(p_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  i        public.admin_invitations%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'invitation : réservée aux super-administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.admins.promote');
  PERFORM public.admin_invitation_expirer();

  SELECT * INTO i FROM public.admin_invitations WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invitation : introuvable' USING ERRCODE = 'P0002'; END IF;
  IF i.status <> 'pending_approval' THEN
    RAISE EXCEPTION 'invitation : pas en attente d''approbation (statut %)', i.status USING ERRCODE = '55000';
  END IF;
  IF i.invited_by = v_caller THEN
    RAISE EXCEPTION 'invitation : l''approbation doit venir d''un AUTRE super-administrateur' USING ERRCODE = '42501';
  END IF;

  UPDATE public.admin_invitations SET status = 'pending', approved_by = v_caller WHERE id = p_id;
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (i.invitee_id, 'system', 'Invitation à l''équipe d''administration',
          'Vous êtes invité à rejoindre l''équipe. Ouvrez la console d''administration pour répondre.',
          jsonb_build_object('admin_invitation', p_id::text));
  PERFORM public.write_admin_audit('ADMIN_INVITATION_APPROVED', 'user', i.invitee_id, 'success', i.role, p_id::text,
                                   jsonb_build_object('invitation', p_id::text, 'role', i.role));
  RETURN 'pending';
END $$;

REVOKE ALL ON FUNCTION public.admin_invitation_approve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_invitation_approve(uuid) TO authenticated;

-- ── 6. Révoquer ────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_invitation_revoke(uuid);

CREATE FUNCTION public.admin_invitation_revoke(p_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  i        public.admin_invitations%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'invitation : réservée aux super-administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.admins.promote');
  SELECT * INTO i FROM public.admin_invitations WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invitation : introuvable' USING ERRCODE = 'P0002'; END IF;
  IF i.status NOT IN ('pending_approval', 'pending') THEN
    RAISE EXCEPTION 'invitation : déjà clôturée (statut %)', i.status USING ERRCODE = '55000';
  END IF;
  UPDATE public.admin_invitations SET status = 'revoked', decided_at = now() WHERE id = p_id;
  PERFORM public.write_admin_audit('ADMIN_INVITATION_REVOKED', 'user', i.invitee_id, 'success', i.role, p_id::text,
                                   jsonb_build_object('invitation', p_id::text));
  RETURN 'revoked';
END $$;

REVOKE ALL ON FUNCTION public.admin_invitation_revoke(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_invitation_revoke(uuid) TO authenticated;

-- ── 7. Lister (côté administration) ────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_invitation_list();

CREATE FUNCTION public.admin_invitation_list()
RETURNS TABLE (id uuid, invitee_id text, invitee_name text, invitee_email_masked text, role text, status text,
               invited_by_name text, approved_by_name text, expires_at timestamptz, created_at timestamptz, decided_at timestamptz)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() OR NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'invitation : réservée aux super-administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('security.admins.promote');
  PERFORM public.admin_invitation_expirer();
  RETURN QUERY
    SELECT i.id, i.invitee_id, ui.display_name,
           CASE WHEN ui.email IS NULL OR ui.email = '' THEN NULL
                ELSE regexp_replace(ui.email, '^(.).*@(.).*(\.[^.]+)$', '\1•••@\2•••\3') END,
           i.role, i.status, ub.display_name, ua.display_name, i.expires_at, i.created_at, i.decided_at
      FROM public.admin_invitations i
      LEFT JOIN public.users ui ON ui.id = i.invitee_id
      LEFT JOIN public.users ub ON ub.id = i.invited_by
      LEFT JOIN public.users ua ON ua.id = i.approved_by
     ORDER BY i.created_at DESC
     LIMIT 100;
END $$;

REVOKE ALL ON FUNCTION public.admin_invitation_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_invitation_list() TO authenticated;

-- ── 8. Côté invité : voir ses invitations, refuser ─────────────────────────
DROP FUNCTION IF EXISTS public.admin_invitation_mine();

CREATE FUNCTION public.admin_invitation_mine()
RETURNS TABLE (id uuid, role text, invited_by_name text, expires_at timestamptz)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_caller text := (SELECT public.firebase_uid());
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'invitation : connexion requise' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_invitation_expirer();
  -- Seules les invitations PRÊTES (approuvées si besoin) sont visibles par la personne.
  RETURN QUERY
    SELECT i.id, i.role, ub.display_name, i.expires_at
      FROM public.admin_invitations i
      LEFT JOIN public.users ub ON ub.id = i.invited_by
     WHERE i.invitee_id = v_caller AND i.status = 'pending'
     ORDER BY i.created_at DESC;
END $$;

REVOKE ALL ON FUNCTION public.admin_invitation_mine() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_invitation_mine() TO authenticated;

DROP FUNCTION IF EXISTS public.admin_invitation_decline(uuid);

CREATE FUNCTION public.admin_invitation_decline(p_id uuid) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  i        public.admin_invitations%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'invitation : connexion requise' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO i FROM public.admin_invitations WHERE id = p_id AND invitee_id = v_caller FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invitation : introuvable' USING ERRCODE = 'P0002'; END IF;
  IF i.status <> 'pending' THEN
    RAISE EXCEPTION 'invitation : plus en attente de votre réponse (statut %)', i.status USING ERRCODE = '55000';
  END IF;
  UPDATE public.admin_invitations SET status = 'declined', decided_at = now() WHERE id = p_id;
  PERFORM public.admin_invitation_journal(v_caller, 'ADMIN_INVITATION_DECLINED', p_id::text,
                                          jsonb_build_object('invitation', p_id::text, 'role', i.role));
  RETURN 'declined';
END $$;

REVOKE ALL ON FUNCTION public.admin_invitation_decline(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_invitation_decline(uuid) TO authenticated;

-- ── 9. Acceptation : réservée à la Cloud Function (clé de service) ─────────
-- `claim` marque l'invitation acceptée ET rend le rôle ; `unclaim` la rouvre si l'écriture du rôle a échoué.
DROP FUNCTION IF EXISTS public.admin_invitation_claim(uuid, text);

CREATE FUNCTION public.admin_invitation_claim(p_id uuid, p_invitee text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE i public.admin_invitations%ROWTYPE;
BEGIN
  PERFORM public.admin_invitation_expirer();
  SELECT * INTO i FROM public.admin_invitations WHERE id = p_id AND invitee_id = p_invitee FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invitation : introuvable' USING ERRCODE = 'P0002'; END IF;
  IF i.status <> 'pending' THEN
    RAISE EXCEPTION 'invitation : plus en attente de votre réponse (statut %)', i.status USING ERRCODE = '55000';
  END IF;
  UPDATE public.admin_invitations SET status = 'accepted', decided_at = now() WHERE id = p_id;
  PERFORM public.admin_invitation_journal(p_invitee, 'ADMIN_INVITATION_ACCEPTED', p_id::text,
                                          jsonb_build_object('invitation', p_id::text, 'role', i.role,
                                                             'invited_by', i.invited_by, 'approved_by', i.approved_by));
  RETURN i.role;
END $$;

DROP FUNCTION IF EXISTS public.admin_invitation_unclaim(uuid);

CREATE FUNCTION public.admin_invitation_unclaim(p_id uuid) RETURNS void
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE public.admin_invitations SET status = 'pending', decided_at = NULL
   WHERE id = p_id AND status = 'accepted' AND decided_at > now() - interval '5 minutes'
$$;

REVOKE ALL ON FUNCTION public.admin_invitation_claim(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_invitation_unclaim(uuid)     FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_invitation_claim(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_invitation_unclaim(uuid)     TO service_role;

NOTIFY pgrst, 'reload schema';
