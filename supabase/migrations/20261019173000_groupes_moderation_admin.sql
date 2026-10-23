-- Groupes : modération par fonctions serveur — confidentialité et suppression
-- avec permission, motif, historique et audit ; lecture admin des groupes privés.
--
-- Référentiel d'administration § 6.7 et spécification d'interfaces § 11.
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- • « Changer la confidentialité » et « Supprimer » étaient des `UPDATE` /
--   `DELETE` envoyés par PostgREST. Les policies ne laissent passer que
--   l'administrateur du groupe (`groups_update_admin`), un groupe OFFICIEL
--   (`is_official AND is_admin()`) ou, pour la suppression, le créateur
--   (`groups_delete`). Un administrateur de plateforme sur un groupe ordinaire
--   obtenait « non modifié » : le geste ne marchait que par hasard.
-- • La lecture ne montrait pas les groupes privés à un administrateur de
--   plateforme qui n'en est pas membre : l'écran listait une fraction des
--   groupes sans le dire.
-- • Aucun motif, aucun historique du groupe.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `group_moderation_events` : l'historique, en ajout seul (confidentialité
--   changée, groupe supprimé), avec le NOM du groupe au moment du geste — la
--   suppression emporte la ligne `groups`, pas son historique.
-- • `group_admin_set_privacy(id, privé, motif)` et `group_admin_delete(id,
--   motif)` : permission `community.groups.manage`, motif de 5 à 500
--   caractères, groupe verrouillé (FOR UPDATE), audit dans la même transaction.
--   Un groupe OFFICIEL ne se modifie ni ne se supprime que par un superAdmin.
-- • La suppression dit ce qu'elle emporte : le nombre d'événements et de
--   sondages du groupe (clés étrangères en cascade) est inscrit dans
--   l'historique et l'audit.
-- • Une policy SELECT pour `community.groups.manage` : les métadonnées de tous
--   les groupes, privés compris (nom, description, effectifs, listes de
--   membres). Elle ne donne accès à AUCUN message : ceux-ci sont ailleurs, et
--   chiffrés.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Elle ne ferme pas `groups_update_admin` : un administrateur peut encore
--   modifier directement un groupe OFFICIEL par PostgREST (colonnes
--   comprises), hors motif et hors historique. Ce chemin sert peut-être
--   l'édition des groupes officiels ; le fermer demande de le vérifier
--   d'abord.
-- • Elle ne prévient pas les membres ni l'administrateur du groupe d'une
--   suppression : le déclencheur existant nettoie les notifications du groupe,
--   rien n'est envoyé.
-- • Elle ne modère pas le contenu du groupe (messages, médias).
--
-- Banc : tools/rls_tests/groupes_moderation_admin.sql.

SET lock_timeout = '5s';

-- ── 1. L'historique du groupe ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.group_moderation_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    text NOT NULL,           -- pas de FK : survit à la suppression
  group_name  text,
  kind        text NOT NULL CHECK (kind IN ('privacy_changed', 'deleted')),
  actor_id    text,
  reason      text,
  metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS group_moderation_events_group_idx
  ON public.group_moderation_events (group_id, occurred_at DESC);

ALTER TABLE public.group_moderation_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.group_moderation_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.group_moderation_events TO authenticated;
DROP POLICY IF EXISTS group_moderation_events_select ON public.group_moderation_events;
CREATE POLICY group_moderation_events_select ON public.group_moderation_events
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('community.groups.manage'));

CREATE OR REPLACE FUNCTION public.group_moderation_events_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'group_moderation_events est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS group_moderation_events_no_rewrite ON public.group_moderation_events;
CREATE TRIGGER group_moderation_events_no_rewrite
  BEFORE UPDATE OR DELETE ON public.group_moderation_events
  FOR EACH ROW EXECUTE FUNCTION public.group_moderation_events_append_only();

DROP TRIGGER IF EXISTS group_moderation_events_no_truncate ON public.group_moderation_events;
CREATE TRIGGER group_moderation_events_no_truncate
  BEFORE TRUNCATE ON public.group_moderation_events
  FOR EACH STATEMENT EXECUTE FUNCTION public.group_moderation_events_append_only();

-- ── 2. Lecture des groupes par la modération ────────────────────────────────
DROP POLICY IF EXISTS groups_select_admin ON public.groups;
CREATE POLICY groups_select_admin ON public.groups
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('community.groups.manage'));

-- ── 3. Confidentialité ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.group_admin_set_privacy(text, boolean, text);

CREATE FUNCTION public.group_admin_set_privacy(p_id text, p_private boolean, p_reason text)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  g        public.groups%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'groupe : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('community.groups.manage');

  IF p_private IS NULL THEN
    RAISE EXCEPTION 'groupe : valeur de confidentialité requise' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'groupe : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_id IS NULL OR p_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'groupe : identifiant invalide' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO g FROM public.groups WHERE id = p_id::uuid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'groupe : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF coalesce(g.is_official, false) AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'groupe : un groupe officiel ne se modifie que par un superAdmin'
      USING ERRCODE = '42501';
  END IF;
  IF g.is_private IS NOT DISTINCT FROM p_private THEN
    RAISE EXCEPTION 'groupe : déjà %', CASE WHEN p_private THEN 'privé' ELSE 'public' END
      USING ERRCODE = '55000';
  END IF;

  UPDATE public.groups SET is_private = p_private, updated_at = now() WHERE id = g.id;

  INSERT INTO public.group_moderation_events (group_id, group_name, kind, actor_id, reason, metadata)
  VALUES (g.id::text, g.name, 'privacy_changed', v_caller, btrim(p_reason),
          jsonb_build_object('from_private', g.is_private, 'to_private', p_private,
                             'members', coalesce(g.member_count, 0)));

  PERFORM public.write_admin_audit(
    'GROUP_PRIVACY_CHANGED', 'group', g.id::text, 'success', NULL, g.id::text,
    jsonb_build_object('to_private', p_private, 'official', coalesce(g.is_official, false)));
  RETURN p_private;
END $$;

-- ── 4. Suppression ──────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.group_admin_delete(text, text);

CREATE FUNCTION public.group_admin_delete(p_id text, p_reason text)
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller  text := (SELECT public.firebase_uid());
  g         public.groups%ROWTYPE;
  v_events  integer;
  v_polls   integer;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'groupe : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('community.groups.manage');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 500 THEN
    RAISE EXCEPTION 'groupe : motif requis (5 à 500 caractères)' USING ERRCODE = '22023';
  END IF;
  IF p_id IS NULL OR p_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'groupe : identifiant invalide' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO g FROM public.groups WHERE id = p_id::uuid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'groupe : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF coalesce(g.is_official, false) AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'groupe : un groupe officiel ne se supprime que par un superAdmin'
      USING ERRCODE = '42501';
  END IF;

  -- La clé étrangère de `events` est en cascade : on compte ce qui part.
  SELECT count(*)::integer INTO v_events FROM public.events WHERE group_id = g.id;
  SELECT count(*)::integer INTO v_polls  FROM public.post_polls WHERE group_id = g.id;

  -- Historique et audit D'ABORD : si l'un échoue, rien n'est supprimé.
  INSERT INTO public.group_moderation_events (group_id, group_name, kind, actor_id, reason, metadata)
  VALUES (g.id::text, g.name, 'deleted', v_caller, btrim(p_reason),
          jsonb_build_object('members', coalesce(g.member_count, 0),
                             'events_deleted', v_events,
                             'polls_deleted', v_polls,
                             'was_private', coalesce(g.is_private, false),
                             'official', coalesce(g.is_official, false)));
  PERFORM public.write_admin_audit(
    'GROUP_DELETED', 'group', g.id::text, 'success', NULL, g.id::text,
    jsonb_build_object('events_deleted', v_events, 'polls_deleted', v_polls,
                       'members', coalesce(g.member_count, 0)));

  DELETE FROM public.groups WHERE id = g.id;
  RETURN v_events;
END $$;

-- ── 5. Droits ───────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.group_admin_set_privacy(text, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.group_admin_delete(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.group_admin_set_privacy(text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.group_admin_delete(text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
