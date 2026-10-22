-- Événements : annulation motivée, suppression encadrée, historique des
-- changements.
--
-- Référentiel d'administration § 8 et spécification d'interfaces § 13.
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- Le panneau annulait un événement par `UPDATE events SET status='cancelled'`
-- et le supprimait par `DELETE`, sous deux policies `is_admin()` : tout
-- administrateur, financeMod compris, sans motif, sans trace de ce qui avait
-- changé, et sans retour possible pour la suppression (les inscriptions
-- partent avec la ligne). Rien ne gardait l'historique d'un déplacement ou
-- d'une annulation décidés par l'organisateur lui-même. Table vivante : 5
-- événements au 2026-10-18.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `event_history` : un déclencheur consigne tout changement de statut, de
--   date, de lieu, de lien en ligne, de visibilité, de capacité ou de prix —
--   par l'organisateur comme par un administrateur — avec l'ancienne et la
--   nouvelle valeur, l'auteur, son rôle (organisateur / administrateur /
--   système) et le motif quand il y en a un. Une suppression laisse un
--   instantané. Ajout seul, comme le journal d'audit.
-- • `event_admin_cancel(id, motif)` et `event_admin_delete(id, motif)` : les
--   seules portes d'administration. Motif obligatoire (5 à 1000 caractères),
--   audit dans la même transaction, refus d'un statut qui n'a pas de sens
--   (annuler un événement déjà annulé ou terminé : 55000).
-- • `events.cancel` (contentMod) et `events.delete` (superAdmin seul : non
--   mappée aux rôles, le superAdmin porte tout le catalogue). Le référentiel
--   veut la suppression « exceptionnelle, strictement encadrée ».
-- • Les policies `events_admin_update` et `events_admin_delete` sont retirées.
--   Les politiques de l'organisateur ne changent pas.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Pas de notification des inscrits à l'annulation : `create_user_notification`
--   n'accepte qu'une liste fermée de types dont les textes sont écrits côté
--   serveur, et en ajouter un touche la chaîne push entière. Les inscrits
--   voient le statut « annulé » à l'ouverture de l'événement, pas avant.
-- • Pas d'approbation préalable : un événement d'organisateur se publie
--   directement (le référentiel la veut « selon le rôle et le niveau de
--   risque » — décision produit, pas technique). Un brouillon reste invisible
--   des autres (policy `events_select_visible`, inchangée).
-- • Pas de statistiques d'inscription (`events.analytics.view`).
--
-- Banc : tools/rls_tests/evenements_moderation.sql.

SET lock_timeout = '5s';

-- ── 1. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('events.cancel', 'events', 'Annuler un événement (motif obligatoire)',      NULL),
  ('events.delete', 'events', 'Supprimer un événement (exceptionnel)',         NULL)
ON CONFLICT (key) DO NOTHING;

-- Le catalogue contient déjà `events.moderate` (lecture de l'historique).
INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'events.cancel')
ON CONFLICT DO NOTHING;

-- ── 2. L'historique ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.event_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid NOT NULL,           -- pas de FK : l'historique survit à la suppression
  event_title text,
  kind        text NOT NULL CHECK (kind IN ('changed', 'deleted')),
  actor_id    text,
  actor_role  text NOT NULL CHECK (actor_role IN ('organizer', 'admin', 'system')),
  changes     jsonb NOT NULL,
  reason      text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS event_history_event_idx
  ON public.event_history (event_id, occurred_at DESC);

ALTER TABLE public.event_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_history FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.event_history TO authenticated;
DROP POLICY IF EXISTS event_history_select ON public.event_history;
CREATE POLICY event_history_select ON public.event_history
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('events.moderate'));

CREATE OR REPLACE FUNCTION public.event_history_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'event_history est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS event_history_no_rewrite ON public.event_history;
CREATE TRIGGER event_history_no_rewrite
  BEFORE UPDATE OR DELETE ON public.event_history
  FOR EACH ROW EXECUTE FUNCTION public.event_history_append_only();

-- ── 3. Le déclencheur qui consigne ──────────────────────────────────────────
-- SECURITY DEFINER : l'organisateur qui modifie son événement n'a aucun droit
-- sur le journal, et ne doit pas en avoir. Les colonnes suivies sont celles
-- que le référentiel veut « confirmées et auditées » (§ 8) ; les compteurs
-- (inscrits) bougent sans cesse et ne sont pas suivis.
CREATE OR REPLACE FUNCTION public.events_record_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     text := (SELECT public.firebase_uid());
  v_role    text;
  v_changes jsonb := '{}'::jsonb;
  v_reason  text := nullif(current_setting('app.event_reason', true), '');
  c         text;
  v_old     jsonb;
  v_new     jsonb;
  v_suivies constant text[] := ARRAY['status', 'title', 'starts_at', 'ends_at',
    'address', 'city', 'country_code', 'is_online', 'online_url', 'meeting_url',
    'visibility', 'max_attendees', 'price'];
BEGIN
  v_role := CASE
    WHEN current_setting('app.event_rpc', true) = 'on' THEN 'admin'
    WHEN v_uid IS NULL THEN 'system'
    WHEN TG_OP = 'DELETE' AND v_uid = OLD.organizer_id THEN 'organizer'
    WHEN TG_OP = 'UPDATE' AND v_uid = OLD.organizer_id THEN 'organizer'
    ELSE 'admin' END;

  IF TG_OP = 'DELETE' THEN
    INSERT INTO public.event_history (event_id, event_title, kind, actor_id, actor_role, changes, reason)
    VALUES (OLD.id, OLD.title, 'deleted', v_uid, v_role,
            jsonb_build_object('title', OLD.title, 'organizer_id', OLD.organizer_id,
                               'starts_at', OLD.starts_at, 'status', OLD.status,
                               'attendee_count', OLD.attendee_count),
            v_reason);
    RETURN OLD;
  END IF;

  v_old := to_jsonb(OLD);
  v_new := to_jsonb(NEW);
  FOREACH c IN ARRAY v_suivies LOOP
    IF v_old -> c IS DISTINCT FROM v_new -> c THEN
      v_changes := v_changes || jsonb_build_object(
        c, jsonb_build_object('from', v_old -> c, 'to', v_new -> c));
    END IF;
  END LOOP;

  IF v_changes <> '{}'::jsonb THEN
    INSERT INTO public.event_history (event_id, event_title, kind, actor_id, actor_role, changes, reason)
    VALUES (NEW.id, NEW.title, 'changed', v_uid, v_role, v_changes, v_reason);
  END IF;
  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION public.events_record_history() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_events_record_history_upd ON public.events;
CREATE TRIGGER trg_events_record_history_upd
  AFTER UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.events_record_history();
DROP TRIGGER IF EXISTS trg_events_record_history_del ON public.events;
CREATE TRIGGER trg_events_record_history_del
  BEFORE DELETE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.events_record_history();

-- ── 4. Annuler ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.event_admin_cancel(uuid, text);

CREATE FUNCTION public.event_admin_cancel(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e        public.events%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événement : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.cancel');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'événement : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO e FROM public.events WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'événement : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF e.status IN ('cancelled', 'ended') THEN
    RAISE EXCEPTION 'événement : annulation impossible depuis le statut %', e.status
      USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('app.event_rpc', 'on', true);
  PERFORM set_config('app.event_reason', btrim(p_reason), true);
  UPDATE public.events SET status = 'cancelled' WHERE id = p_id;
  PERFORM set_config('app.event_rpc', 'off', true);
  PERFORM set_config('app.event_reason', '', true);

  PERFORM public.write_admin_audit(
    'EVENT_CANCELLED', 'event', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('from', e.status, 'attendees', e.attendee_count));
  RETURN 'cancelled';
END $$;

-- ── 5. Supprimer (exceptionnel) ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.event_admin_delete(uuid, text);

CREATE FUNCTION public.event_admin_delete(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e        public.events%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événement : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.delete');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'événement : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO e FROM public.events WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'événement : introuvable' USING ERRCODE = 'P0002';
  END IF;

  PERFORM set_config('app.event_rpc', 'on', true);
  PERFORM set_config('app.event_reason', btrim(p_reason), true);
  DELETE FROM public.events WHERE id = p_id;
  PERFORM set_config('app.event_rpc', 'off', true);
  PERFORM set_config('app.event_reason', '', true);

  PERFORM public.write_admin_audit(
    'EVENT_DELETED', 'event', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('status', e.status, 'attendees', e.attendee_count));
  RETURN 'deleted';
END $$;

-- ── 6. Plus d'écriture directe pour les administrateurs ─────────────────────
DROP POLICY IF EXISTS events_admin_update ON public.events;
DROP POLICY IF EXISTS events_admin_delete ON public.events;

-- ── 7. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.event_admin_cancel(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.event_admin_delete(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.event_admin_cancel(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.event_admin_delete(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
