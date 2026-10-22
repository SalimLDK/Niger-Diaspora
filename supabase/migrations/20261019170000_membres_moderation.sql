-- Membres : vérification motivée, avertissement, suspension à durée, déconnexion
-- forcée — par des fonctions qui exigent permission, motif, et écrivent
-- l'audit et l'historique du membre.
--
-- Référentiel d'administration § 5, § 6.4–6.6 et spécification d'interfaces § 10.
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- • Vérifier un profil, retirer le badge et forcer une déconnexion étaient
--   des `UPDATE users` envoyés par PostgREST sous la policy
--   `users_update_admin` (`is_admin()`), que le déclencheur
--   `users_garde_privileges` laissait passer par une exemption « admin » :
--   n'importe quel administrateur — financeMod compris — écrivait n'importe
--   quelle colonne de n'importe quel compte, y compris les compagnons du
--   bannissement. Aucun motif, aucune source, aucun historique du membre ; le
--   journal client avalait ses erreurs.
-- • Pas d'avertissement, pas de suspension à durée : bannir ou rien. Le
--   référentiel les veut distincts (§ 6.4, § 6.5) : la durée est obligatoire,
--   le motif aussi, et l'expiration se traite.
-- • L'historique d'un membre n'existait pas.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `member_moderation_events` : l'historique d'un membre, en ajout seul
--   (vérifié, badge retiré, averti, suspendu, réactivé, déconnecté), avec
--   l'auteur, le motif et la date. Lisible avec `community.members.view`.
-- • Six fonctions : vérifier (une BASE obligatoire, comme pour les fiches),
--   retirer le badge, avertir, suspendre (1 à 30 jours), réactiver, forcer la
--   déconnexion. Elles refusent de viser soi-même, et un compte
--   administrateur n'est visé que par un superAdmin.
-- • L'avertissement est notifié au membre par une notification `system` dont
--   le TITRE est écrit par le serveur ; le texte est celui de l'agent, borné.
-- • La suspension pose les mêmes drapeaux que le bannissement
--   (`is_banned`, sentinelle de session) pour que les builds installés
--   éjectent le compte — c'est ce qu'ils lisent — plus `suspended_until`. Un
--   job `pg_cron` toutes les dix minutes lève les suspensions échues.
--   Garde-fou : il ne lève QUE ce qui porte encore la marque « Suspension : » ;
--   un bannissement posé ensuite par la callable `setUserBanned` n'est jamais
--   levé par une échéance.
-- • Trois permissions, mappées à contentMod : `moderation.warnings.create`,
--   `community.accounts.suspend`, `community.sessions.revoke`.
-- • Le déclencheur `users_garde_privileges` perd son exemption `is_admin()` :
--   un administrateur ne pose plus `is_verified` ni les colonnes du
--   bannissement par PostgREST. La policy `users_update_admin` est retirée.
--   Le bannissement lui-même continue de passer par la callable (clé de
--   service) ; ces fonctions ne le remplacent pas.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Pas de seconde approbation du BANNISSEMENT : il passe par une Cloud
--   Function Firebase (`setUserBanned`) qu'il faudrait modifier et
--   redéployer, ce que cette session ne peut pas faire. Écrite dans le
--   panneau seul, la double validation ne serait qu'une façade — la callable
--   resterait appelable directement.
-- • La suspension ne désactive pas le compte Firebase : le jeton reste valide
--   jusqu'à son expiration, l'éjection repose sur le drapeau lu par l'app.
-- • Pas de lien automatique entre un signalement et la sanction prise.
-- • Pas de contestation d'une suspension : le parcours de recours des
--   signalements ne la couvre pas encore.
--
-- Banc : tools/rls_tests/membres_moderation.sql.

SET lock_timeout = '5s';

-- ── 1. Colonnes ─────────────────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS suspended_until     timestamptz,
  ADD COLUMN IF NOT EXISTS verified_by         text,
  ADD COLUMN IF NOT EXISTS verification_source text;

-- ── 2. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('moderation.warnings.create',  'moderation', 'Envoyer un avertissement à un membre',           NULL),
  ('community.accounts.suspend',  'community',  'Suspendre un compte (durée et motif obligatoires)', NULL),
  ('community.sessions.revoke',   'community',  'Forcer la déconnexion d''un membre',             NULL)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'moderation.warnings.create'),
  ('contentMod', 'community.accounts.suspend'),
  ('contentMod', 'community.sessions.revoke')
ON CONFLICT DO NOTHING;

-- ── 3. L'historique du membre ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.member_moderation_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id   text NOT NULL,           -- pas de FK : survit à la suppression du compte
  kind        text NOT NULL CHECK (kind IN ('verified', 'unverified', 'warned',
                                            'suspended', 'unsuspended', 'session_revoked')),
  actor_id    text,                    -- NULL : le système (échéance d'une suspension)
  reason      text,
  metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS member_moderation_events_member_idx
  ON public.member_moderation_events (member_id, occurred_at DESC);

ALTER TABLE public.member_moderation_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.member_moderation_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.member_moderation_events TO authenticated;
DROP POLICY IF EXISTS member_moderation_events_select ON public.member_moderation_events;
CREATE POLICY member_moderation_events_select ON public.member_moderation_events
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('community.members.view'));

CREATE OR REPLACE FUNCTION public.member_moderation_events_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'member_moderation_events est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS member_moderation_events_no_rewrite ON public.member_moderation_events;
CREATE TRIGGER member_moderation_events_no_rewrite
  BEFORE UPDATE OR DELETE ON public.member_moderation_events
  FOR EACH ROW EXECUTE FUNCTION public.member_moderation_events_append_only();

-- ── 4. Plus d'exemption « admin » sur les colonnes de modération ────────────
-- Corps de `users_garde_privileges` tel que lu en production le 2026-10-19,
-- moins `IF is_admin() THEN RETURN NEW`. Les chemins de confiance (migrations,
-- SECURITY DEFINER, service_role) passent toujours : la callable de
-- bannissement et ces fonctions écrivent donc normalement.
CREATE OR REPLACE FUNCTION public.users_garde_privileges()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  v_caller := public.firebase_uid();
  IF v_caller IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.is_banned := false;
    NEW.ban_reason := NULL;
    NEW.banned_at := NULL;
    NEW.banned_by := NULL;
    NEW.is_verified := false;
    NEW.verified_at := NULL;
    NEW.admin_role := NULL;
    NEW.suspended_until := NULL;
    NEW.verified_by := NULL;
    NEW.verification_source := NULL;
    RETURN NEW;
  END IF;

  IF NEW.is_banned IS DISTINCT FROM OLD.is_banned
     OR NEW.ban_reason IS DISTINCT FROM OLD.ban_reason
     OR NEW.banned_at IS DISTINCT FROM OLD.banned_at
     OR NEW.banned_by IS DISTINCT FROM OLD.banned_by
     OR NEW.is_verified IS DISTINCT FROM OLD.is_verified
     OR NEW.verified_at IS DISTINCT FROM OLD.verified_at
     OR NEW.suspended_until IS DISTINCT FROM OLD.suspended_until
     OR NEW.verified_by IS DISTINCT FROM OLD.verified_by
     OR NEW.verification_source IS DISTINCT FROM OLD.verification_source
  THEN
    RAISE EXCEPTION
      'users : le bannissement, la suspension et le badge vérifié sont posés par les fonctions d''administration, pas par un compte (même administrateur)'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END $$;

DROP POLICY IF EXISTS users_update_admin ON public.users;

-- ── 5. Vérifier qui l'on vise ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.member_cible_check(text, text);

CREATE FUNCTION public.member_cible_check(p_id text, p_caller text) RETURNS public.users
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  u public.users%ROWTYPE;
BEGIN
  SELECT * INTO u FROM public.users WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'membre : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF p_id = p_caller THEN
    RAISE EXCEPTION 'membre : vous ne pouvez pas vous viser vous-même' USING ERRCODE = '42501';
  END IF;
  -- Un compte administrateur ne se modère que par un superAdmin (même règle
  -- que la callable de bannissement).
  IF coalesce(u.is_admin, false) AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'membre : un compte administrateur ne se modère que par un superAdmin'
      USING ERRCODE = '42501';
  END IF;
  RETURN u;
END $$;

REVOKE ALL ON FUNCTION public.member_cible_check(text, text) FROM PUBLIC, anon, authenticated;

-- ── 6. Vérifier / retirer le badge ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.member_admin_verify(text, text);

CREATE FUNCTION public.member_admin_verify(p_id text, p_source text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  u        public.users%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'membre : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('community.members.verify');

  IF p_source IS NULL OR length(btrim(p_source)) < 5 OR length(p_source) > 500 THEN
    RAISE EXCEPTION 'membre : base de la vérification requise (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;
  u := public.member_cible_check(p_id, v_caller);
  IF coalesce(u.is_banned, false) THEN
    RAISE EXCEPTION 'membre : un compte banni ou suspendu ne se vérifie pas' USING ERRCODE = '55000';
  END IF;
  IF coalesce(u.is_verified, false) THEN
    RAISE EXCEPTION 'membre : déjà vérifié' USING ERRCODE = '55000';
  END IF;

  UPDATE public.users SET
    is_verified = true, verified_at = now(), verified_by = v_caller,
    verification_source = btrim(p_source)
   WHERE id = p_id;
  INSERT INTO public.member_moderation_events (member_id, kind, actor_id, reason)
  VALUES (p_id, 'verified', v_caller, btrim(p_source));

  PERFORM public.write_admin_audit(
    'MEMBER_VERIFIED', 'user', p_id, 'success', NULL, p_id, '{}'::jsonb);
  RETURN 'verified';
END $$;

DROP FUNCTION IF EXISTS public.member_admin_unverify(text, text);

CREATE FUNCTION public.member_admin_unverify(p_id text, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  u        public.users%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'membre : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('community.members.verify');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'membre : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  u := public.member_cible_check(p_id, v_caller);
  IF NOT coalesce(u.is_verified, false) THEN
    RAISE EXCEPTION 'membre : pas vérifié' USING ERRCODE = '55000';
  END IF;

  UPDATE public.users SET
    is_verified = false, verified_at = NULL, verified_by = NULL, verification_source = NULL
   WHERE id = p_id;
  INSERT INTO public.member_moderation_events (member_id, kind, actor_id, reason)
  VALUES (p_id, 'unverified', v_caller, btrim(p_reason));

  PERFORM public.write_admin_audit(
    'MEMBER_UNVERIFIED', 'user', p_id, 'success', NULL, p_id, '{}'::jsonb);
  RETURN 'unverified';
END $$;

-- ── 7. Avertir ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.member_admin_warn(text, text, text);

CREATE FUNCTION public.member_admin_warn(p_id text, p_reason text, p_message text) RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  u        public.users%ROWTYPE;
  v_n      integer;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'membre : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('moderation.warnings.create');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'membre : motif interne requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_message IS NULL OR length(btrim(p_message)) < 10 OR length(p_message) > 300 THEN
    RAISE EXCEPTION 'membre : message au membre requis (10 à 300 caractères)' USING ERRCODE = '22023';
  END IF;
  u := public.member_cible_check(p_id, v_caller);

  -- Le titre est écrit ici, jamais par l'agent : une notification de la
  -- modération ne peut pas se faire passer pour autre chose.
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_id, 'system', 'Avertissement de la modération', btrim(p_message),
          jsonb_build_object('moderation', 'warning'));
  INSERT INTO public.member_moderation_events (member_id, kind, actor_id, reason)
  VALUES (p_id, 'warned', v_caller, btrim(p_reason));
  SELECT count(*) INTO v_n FROM public.member_moderation_events
   WHERE member_id = p_id AND kind = 'warned';

  PERFORM public.write_admin_audit(
    'MEMBER_WARNED', 'user', p_id, 'success', NULL, p_id,
    jsonb_build_object('warnings_total', v_n));
  RETURN v_n;
END $$;

-- ── 8. Suspendre / réactiver ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.member_admin_suspend(text, integer, text);

CREATE FUNCTION public.member_admin_suspend(p_id text, p_days integer, p_reason text) RETURNS timestamptz
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  u        public.users%ROWTYPE;
  v_fin    timestamptz;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'membre : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('community.accounts.suspend');

  IF p_days IS NULL OR p_days < 1 OR p_days > 30 THEN
    RAISE EXCEPTION 'membre : durée de suspension requise (1 à 30 jours)' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'membre : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;
  u := public.member_cible_check(p_id, v_caller);
  IF coalesce(u.is_banned, false) THEN
    RAISE EXCEPTION 'membre : déjà banni ou suspendu' USING ERRCODE = '55000';
  END IF;

  v_fin := now() + make_interval(days => p_days);
  -- Mêmes drapeaux que le bannissement : c'est ce que les builds installés
  -- lisent pour éjecter le compte.
  UPDATE public.users SET
    is_banned = true, banned_at = now(), banned_by = v_caller,
    ban_reason = 'Suspension : ' || btrim(p_reason),
    suspended_until = v_fin,
    session_id = 'banned_' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint
   WHERE id = p_id;
  INSERT INTO public.member_moderation_events (member_id, kind, actor_id, reason, metadata)
  VALUES (p_id, 'suspended', v_caller, btrim(p_reason),
          jsonb_build_object('days', p_days, 'until', v_fin));

  PERFORM public.write_admin_audit(
    'MEMBER_SUSPENDED', 'user', p_id, 'success', NULL, p_id,
    jsonb_build_object('days', p_days));
  RETURN v_fin;
END $$;

DROP FUNCTION IF EXISTS public.member_admin_unsuspend(text, text);

CREATE FUNCTION public.member_admin_unsuspend(p_id text, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  u        public.users%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'membre : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('community.accounts.suspend');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'membre : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;
  u := public.member_cible_check(p_id, v_caller);
  -- Un bannissement ne se lève pas ici : c'est la callable « Débannir ».
  IF NOT (coalesce(u.is_banned, false) AND u.suspended_until IS NOT NULL
          AND coalesce(u.ban_reason, '') LIKE 'Suspension : %') THEN
    RAISE EXCEPTION 'membre : pas suspendu (un bannissement se lève par « Débannir »)'
      USING ERRCODE = '55000';
  END IF;

  UPDATE public.users SET
    is_banned = false, banned_at = NULL, banned_by = NULL, ban_reason = NULL,
    suspended_until = NULL, session_id = NULL
   WHERE id = p_id;
  INSERT INTO public.member_moderation_events (member_id, kind, actor_id, reason)
  VALUES (p_id, 'unsuspended', v_caller, btrim(p_reason));

  PERFORM public.write_admin_audit(
    'MEMBER_UNSUSPENDED', 'user', p_id, 'success', NULL, p_id, '{}'::jsonb);
  RETURN 'unsuspended';
END $$;

-- ── 9. Forcer la déconnexion ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.member_admin_force_logout(text, text);

CREATE FUNCTION public.member_admin_force_logout(p_id text, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  u        public.users%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'membre : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('community.sessions.revoke');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'membre : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;
  u := public.member_cible_check(p_id, v_caller);

  UPDATE public.users SET
    session_id = 'force_logout_' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint
   WHERE id = p_id;
  INSERT INTO public.member_moderation_events (member_id, kind, actor_id, reason)
  VALUES (p_id, 'session_revoked', v_caller, btrim(p_reason));

  PERFORM public.write_admin_audit(
    'MEMBER_SESSION_REVOKED', 'user', p_id, 'success', NULL, p_id, '{}'::jsonb);
  RETURN 'session_revoked';
END $$;

-- ── 10. L'échéance des suspensions ──────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.lever_suspensions_expirees()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_n integer := 0;
  r   record;
BEGIN
  -- Seulement ce qui porte encore la marque d'une suspension : un
  -- bannissement posé depuis (callable) a réécrit `ban_reason`.
  FOR r IN
    UPDATE public.users SET
      is_banned = false, banned_at = NULL, banned_by = NULL, ban_reason = NULL,
      suspended_until = NULL, session_id = NULL
     WHERE is_banned AND suspended_until IS NOT NULL AND suspended_until <= now()
       AND coalesce(ban_reason, '') LIKE 'Suspension : %'
    RETURNING id
  LOOP
    INSERT INTO public.member_moderation_events (member_id, kind, actor_id, reason)
    VALUES (r.id, 'unsuspended', NULL, 'Échéance de la suspension');
    v_n := v_n + 1;
  END LOOP;

  -- Une échéance qui ne correspond plus à une suspension (bannissement
  -- ultérieur, débannissement) ne doit pas rester pendante.
  UPDATE public.users SET suspended_until = NULL
   WHERE suspended_until IS NOT NULL AND suspended_until <= now();
  RETURN v_n;
END $$;

REVOKE ALL ON FUNCTION private.lever_suspensions_expirees() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'lever-suspensions-expirees') THEN
    PERFORM cron.schedule('lever-suspensions-expirees', '*/10 * * * *',
                          'SELECT private.lever_suspensions_expirees()');
  END IF;
END $$;

-- ── 11. Droits d'exécution ──────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.member_admin_verify(text, text)            FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.member_admin_unverify(text, text)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.member_admin_warn(text, text, text)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.member_admin_suspend(text, integer, text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.member_admin_unsuspend(text, text)         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.member_admin_force_logout(text, text)      FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.member_admin_verify(text, text)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.member_admin_unverify(text, text)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.member_admin_warn(text, text, text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.member_admin_suspend(text, integer, text)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.member_admin_unsuspend(text, text)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.member_admin_force_logout(text, text)      TO authenticated;

NOTIFY pgrst, 'reload schema';
