-- Événements : validation avant publication, EN OPTION (désactivée par défaut).
--
-- Référentiel d'administration § 8 et spécification d'interfaces § 13.
--
-- ═══ LE PRINCIPE ═══════════════════════════════════════════════════════════
--
-- Un réglage unique, `event_moderation_settings.require_approval`, naît à
-- FAUX. Tant qu'il est faux, cette migration ne change rien pour personne :
-- chaque événement existant est `approved`, chaque nouvel événement naît
-- `approved`, et les policies de lecture ne retiennent que les événements qui
-- ne le sont pas — il n'y en a aucun.
--
-- Une fois le réglage vrai (superAdmin, audité, `events.approval.configure`) :
--   • un événement PUBLIC qui devient publié — créé hors brouillon, ou sorti
--     de brouillon, ou rendu public — naît `pending` ;
--   • un événement `pending` ou `rejected` n'est lisible que de son
--     organisateur et des administrateurs qui modèrent (`events.moderate`) ;
--     ni les autres membres, ni leurs inscriptions, ne le voient ;
--   • un administrateur `events.approve` l'approuve, ou le refuse avec un
--     motif ; il n'approuve jamais son propre événement ;
--   • l'organisateur d'un événement refusé le soumet de nouveau
--     (`event_resubmit`) après correction.
-- Les événements non publics (discussion, groupes, personnes) ne passent
-- jamais par la file : ils ne sont visibles que de leurs invités.
--
-- ═══ À SAVOIR AVANT D'ACTIVER ══════════════════════════════════════════════
--
-- L'APPLICATION NE SAIT PAS ENCORE DIRE À L'ORGANISATEUR que son événement est
-- en attente ou refusé (ni le motif) : il le verrait tel quel, sans que les
-- autres le voient. Tant que l'écran organisateur n'affiche pas cet état, ne
-- pas activer le réglage en production. Rien dans cette migration n'envoie de
-- notification non plus.
--
-- Les événements déjà publiés ne repassent pas en validation lorsqu'on active
-- le réglage, et modifier un événement approuvé ne le remet pas en attente :
-- seule une nouvelle publication (brouillon → publié, privé → public) le fait.
--
-- Banc : tools/rls_tests/evenements_validation_option.sql.

SET lock_timeout = '5s';

-- ── 1. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('events.approve',            'events', 'Approuver ou refuser un événement avant publication', NULL),
  ('events.approval.configure', 'events', 'Activer ou désactiver la validation avant publication', NULL)
ON CONFLICT (key) DO NOTHING;

-- configure : aucun rôle, donc superAdmin seul.
INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'events.approve')
ON CONFLICT DO NOTHING;

-- ── 2. Le réglage ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.event_moderation_settings (
  id               boolean PRIMARY KEY DEFAULT true CHECK (id),
  require_approval boolean NOT NULL DEFAULT false,
  updated_by       text,
  updated_at       timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.event_moderation_settings (id) VALUES (true) ON CONFLICT DO NOTHING;

ALTER TABLE public.event_moderation_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_moderation_settings FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.event_moderation_settings TO authenticated;
DROP POLICY IF EXISTS event_moderation_settings_select ON public.event_moderation_settings;
CREATE POLICY event_moderation_settings_select ON public.event_moderation_settings
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('events.moderate'));

DROP FUNCTION IF EXISTS public.event_set_approval_required(boolean);
CREATE FUNCTION public.event_set_approval_required(p_on boolean) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  v_before boolean;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événement : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.approval.configure');
  IF p_on IS NULL THEN
    RAISE EXCEPTION 'événement : valeur requise' USING ERRCODE = '22023';
  END IF;
  SELECT require_approval INTO v_before FROM public.event_moderation_settings WHERE id FOR UPDATE;
  UPDATE public.event_moderation_settings
     SET require_approval = p_on, updated_by = v_caller, updated_at = now() WHERE id;
  PERFORM public.write_admin_audit(
    'EVENT_APPROVAL_SETTING_CHANGED', 'event_settings', 'require_approval', 'success',
    NULL, NULL, jsonb_build_object('from', v_before, 'to', p_on));
  RETURN p_on;
END $$;

-- ── 3. Colonnes d'approbation ──────────────────────────────────────────────
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS approval_status     text NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS approval_decided_by text,
  ADD COLUMN IF NOT EXISTS approval_decided_at timestamptz,
  ADD COLUMN IF NOT EXISTS approval_note       text;

ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_approval_status_check;
ALTER TABLE public.events ADD CONSTRAINT events_approval_status_check
  CHECK (approval_status IN ('approved', 'pending', 'rejected'));

CREATE INDEX IF NOT EXISTS events_approval_pending_idx
  ON public.events (created_at) WHERE approval_status = 'pending';

-- ── 4. Garde : seul le serveur décide de l'approbation ──────────────────────
-- Nommé après `trg_events_sync_visibility` (ordre alphabétique des
-- déclencheurs BEFORE) : la visibilité est déjà recalculée quand il juge.
CREATE OR REPLACE FUNCTION public.events_approval_guard()
RETURNS trigger
LANGUAGE plpgsql
-- DEFINER : l'organisateur ne lit pas le réglage (policy `events.moderate`), mais
-- le déclencheur doit le lire pour lui.
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_on        boolean;
  v_publie    boolean;
  v_etait     boolean;
BEGIN
  -- Les RPC d'approbation, les migrations et le service_role passent.
  IF current_setting('app.event_approval_rpc', true) = 'on'
     OR (SELECT public.firebase_uid()) IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.approval_status <> 'approved' OR NEW.approval_decided_by IS NOT NULL
       OR NEW.approval_decided_at IS NOT NULL OR NEW.approval_note IS NOT NULL THEN
      RAISE EXCEPTION 'événement : l''approbation est réservée à la modération'
        USING ERRCODE = '42501';
    END IF;
    v_etait := false;
  ELSE
    IF NEW.approval_status IS DISTINCT FROM OLD.approval_status
       OR NEW.approval_decided_by IS DISTINCT FROM OLD.approval_decided_by
       OR NEW.approval_decided_at IS DISTINCT FROM OLD.approval_decided_at
       OR NEW.approval_note IS DISTINCT FROM OLD.approval_note THEN
      RAISE EXCEPTION 'événement : l''approbation est réservée à la modération'
        USING ERRCODE = '42501';
    END IF;
    v_etait := OLD.visibility = 'public' AND OLD.status <> 'draft';
  END IF;

  v_publie := NEW.visibility = 'public' AND NEW.status <> 'draft';
  IF v_publie AND NOT v_etait THEN
    SELECT require_approval INTO v_on FROM public.event_moderation_settings WHERE id;
    IF coalesce(v_on, false) THEN
      NEW.approval_status := 'pending';
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_events_zz_approval_guard ON public.events;
CREATE TRIGGER trg_events_zz_approval_guard
  BEFORE INSERT OR UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.events_approval_guard();

-- ── 5. Lecture : un événement non approuvé n'est lisible que de son organisateur
--      (et de la modération, par `can_see_event`) ───────────────────────────
DROP POLICY IF EXISTS events_select_visible ON public.events;
CREATE POLICY events_select_visible ON public.events
  FOR SELECT
  USING (
    (status <> 'draft' AND visibility = 'public' AND approval_status = 'approved')
    OR organizer_id = (SELECT public.firebase_uid())
    OR public.can_see_event(id)
  );

-- Corps de 20261019190000, avec `approval_status = 'approved'` exigé de tout
-- lecteur autre que l'organisateur.
CREATE OR REPLACE FUNCTION public.can_see_event_as_member(p_event_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH moi AS (SELECT public.firebase_uid() AS uid)
  SELECT EXISTS (
    SELECT 1
      FROM events e, moi
     WHERE e.id = p_event_id
       AND (
         e.organizer_id = moi.uid
         OR (
           e.status <> 'draft'
           AND e.approval_status = 'approved'
           AND (
             e.visibility = 'public'
             OR (e.conversation_id IS NOT NULL AND EXISTS (
                   SELECT 1 FROM conversations c
                    WHERE c.id = e.conversation_id
                      AND moi.uid = ANY (c.participant_ids)))
             OR (e.group_id IS NOT NULL AND EXISTS (
                   SELECT 1 FROM group_members gm
                    WHERE gm.group_id = e.group_id AND gm.user_id = moi.uid))
             OR EXISTS (
                   SELECT 1 FROM event_attendees ea
                    WHERE ea.event_id = e.id AND ea.user_id = moi.uid)
             OR (e.visibility = 'people' AND EXISTS (
                   SELECT 1 FROM event_audience a
                    WHERE a.event_id = e.id AND a.user_id = moi.uid))
             OR (e.visibility = 'groups' AND EXISTS (
                   SELECT 1 FROM event_audience a
                     JOIN group_members gm ON gm.group_id = a.group_id
                    WHERE a.event_id = e.id AND gm.user_id = moi.uid))
           )
         )
       )
  );
$function$;

-- ── 6. Approuver, refuser, soumettre de nouveau ────────────────────────────
DROP FUNCTION IF EXISTS public.event_admin_approve(uuid, text);
CREATE FUNCTION public.event_admin_approve(p_id uuid, p_note text DEFAULT NULL) RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e public.events%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événement : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.approve');
  IF p_note IS NOT NULL AND length(p_note) > 1000 THEN
    RAISE EXCEPTION 'événement : note de 1000 caractères au plus' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO e FROM public.events WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'événement : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF e.approval_status <> 'pending' THEN
    RAISE EXCEPTION 'événement : pas en attente de validation (%)', e.approval_status
      USING ERRCODE = '55000';
  END IF;
  IF e.organizer_id = v_caller THEN
    RAISE EXCEPTION 'événement : on n''approuve pas son propre événement' USING ERRCODE = '42501';
  END IF;
  PERFORM set_config('app.event_approval_rpc', 'on', true);
  UPDATE public.events SET approval_status = 'approved', approval_decided_by = v_caller,
    approval_decided_at = now(), approval_note = nullif(btrim(coalesce(p_note, '')), '')
   WHERE id = p_id;
  PERFORM set_config('app.event_approval_rpc', 'off', true);
  PERFORM public.write_admin_audit(
    'EVENT_APPROVED', 'event', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'approved';
END $$;

DROP FUNCTION IF EXISTS public.event_admin_reject(uuid, text);
CREATE FUNCTION public.event_admin_reject(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e public.events%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événement : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.approve');
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'événement : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO e FROM public.events WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'événement : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF e.approval_status <> 'pending' THEN
    RAISE EXCEPTION 'événement : pas en attente de validation (%)', e.approval_status
      USING ERRCODE = '55000';
  END IF;
  PERFORM set_config('app.event_approval_rpc', 'on', true);
  UPDATE public.events SET approval_status = 'rejected', approval_decided_by = v_caller,
    approval_decided_at = now(), approval_note = btrim(p_reason)
   WHERE id = p_id;
  PERFORM set_config('app.event_approval_rpc', 'off', true);
  -- Le motif est écrit sur l'événement (pour l'organisateur), pas dans l'audit.
  PERFORM public.write_admin_audit(
    'EVENT_REJECTED', 'event', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN 'rejected';
END $$;

-- L'organisateur d'un événement refusé le soumet de nouveau.
DROP FUNCTION IF EXISTS public.event_resubmit(uuid);
CREATE FUNCTION public.event_resubmit(p_id uuid) RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  e public.events%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'événement : connexion requise' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO e FROM public.events WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR e.organizer_id <> v_caller THEN
    RAISE EXCEPTION 'événement : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF e.approval_status <> 'rejected' THEN
    RAISE EXCEPTION 'événement : seul un événement refusé se soumet de nouveau' USING ERRCODE = '55000';
  END IF;
  PERFORM set_config('app.event_approval_rpc', 'on', true);
  UPDATE public.events SET approval_status = 'pending', approval_decided_by = NULL,
    approval_decided_at = NULL, approval_note = NULL WHERE id = p_id;
  PERFORM set_config('app.event_approval_rpc', 'off', true);
  RETURN 'pending';
END $$;

-- La file de validation. Le titre et l'organisateur suffisent à décider ;
-- la description complète se lit dans la fiche.
DROP FUNCTION IF EXISTS public.event_admin_pending();
CREATE FUNCTION public.event_admin_pending() RETURNS TABLE (
  id uuid, title text, starts_at timestamptz, city text, organizer_id text,
  organizer_name text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événement : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.approve');
  RETURN QUERY
    SELECT e.id, e.title, e.starts_at, e.city, e.organizer_id, e.organizer_name, e.created_at
      FROM public.events e
     WHERE e.approval_status = 'pending'
     ORDER BY e.created_at
     LIMIT 200;
END $$;

-- ── 7. Le calendrier dit quand un événement n'est pas encore approuvé ──────
CREATE OR REPLACE FUNCTION public.event_admin_calendar(p_from timestamptz, p_to timestamptz) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_events jsonb;
  v_prives int;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événements : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.moderate');

  IF p_from IS NULL OR p_to IS NULL OR p_to <= p_from OR p_to - p_from > interval '100 days' THEN
    RAISE EXCEPTION 'événements : période invalide (100 jours au plus)' USING ERRCODE = '22023';
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', e.id, 'title', e.title, 'starts_at', e.starts_at, 'ends_at', e.ends_at,
           'status', e.status, 'city', e.city, 'country_code', e.country_code,
           'is_online', e.is_online, 'attendee_count', e.attendee_count,
           'max_attendees', e.max_attendees, 'organizer_name', e.organizer_name,
           'approval_status', e.approval_status)
         ORDER BY e.starts_at), '[]'::jsonb)
    INTO v_events
    FROM public.events e
   WHERE e.starts_at >= p_from AND e.starts_at < p_to
     AND e.visibility = 'public' AND e.status <> 'draft';

  SELECT count(*) INTO v_prives
    FROM public.events e
   WHERE e.starts_at >= p_from AND e.starts_at < p_to
     AND (e.visibility <> 'public' OR e.status = 'draft');

  RETURN jsonb_build_object('events', v_events, 'hidden_private', v_prives);
END $$;

-- ── 7 bis. La file « à traiter » compte les événements à valider ────────────
-- Même fonction que 20261019230000, avec un bloc de plus.
DROP FUNCTION IF EXISTS public.admin_attention_queue();
CREATE FUNCTION public.admin_attention_queue()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_out jsonb := '[]'::jsonb;
  v_total integer;
  v_late  integer;
  v_old   timestamptz;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'file : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;

  IF public.admin_has_permission('moderation.reports.view') THEN
    SELECT count(*), count(*) FILTER (WHERE due_at IS NOT NULL AND due_at < now()), min(created_at)
      INTO v_total, v_late, v_old
      FROM public.reports WHERE status IN ('pending', 'escalated');
    v_out := v_out || jsonb_build_object('key', 'reports', 'total', v_total, 'late', v_late, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('moderation.appeals.view') THEN
    SELECT count(*), 0, min(received_at) INTO v_total, v_late, v_old
      FROM public.moderation_appeals WHERE status IN ('received', 'under_review');
    v_out := v_out || jsonb_build_object('key', 'appeals', 'total', v_total, 'late', 0, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('support.tickets.view') THEN
    SELECT count(*), count(*) FILTER (WHERE has_unread_user_messages), min(created_at)
      INTO v_total, v_late, v_old
      FROM public.support_tickets WHERE status IN ('open', 'in_progress');
    v_out := v_out || jsonb_build_object('key', 'tickets', 'total', v_total, 'late', v_late, 'oldest', v_old);

    SELECT count(*), 0, min(escalated_at) INTO v_total, v_late, v_old
      FROM public.support_tickets WHERE escalated_at IS NOT NULL AND status IN ('open', 'in_progress');
    v_out := v_out || jsonb_build_object('key', 'tickets_escalated', 'total', v_total, 'late', 0, 'oldest', v_old);

    SELECT count(*) INTO v_total FROM public.support_sla_status()
     WHERE coalesce(first_response_late, false) OR coalesce(resolution_late, false);
    v_out := v_out || jsonb_build_object('key', 'tickets_overdue', 'total', v_total, 'late', v_total, 'oldest', NULL);
  END IF;

  IF public.admin_has_permission('privacy.requests.manage') THEN
    SELECT count(*), count(*) FILTER (WHERE due_at IS NOT NULL AND due_at < now()), min(created_at)
      INTO v_total, v_late, v_old
      FROM public.privacy_requests WHERE status IN ('received', 'identity_verified', 'in_progress');
    v_out := v_out || jsonb_build_object('key', 'privacy', 'total', v_total, 'late', v_late, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('consular.procedures.approve') THEN
    SELECT count(*), 0, min(submitted_at) INTO v_total, v_late, v_old
      FROM public.demarches_brouillons WHERE status = 'pending';
    v_out := v_out || jsonb_build_object('key', 'procedures', 'total', v_total, 'late', 0, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('communications.send') THEN
    SELECT count(*), 0, min(updated_at) INTO v_total, v_late, v_old
      FROM public.campaigns WHERE status = 'pending_approval';
    v_out := v_out || jsonb_build_object('key', 'campaigns', 'total', v_total, 'late', 0, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('directory.listings.view') THEN
    SELECT count(*), count(*), min(next_review_at) INTO v_total, v_late, v_old
      FROM public.businesses WHERE archived_at IS NULL AND next_review_at IS NOT NULL AND next_review_at < now();
    v_out := v_out || jsonb_build_object('key', 'businesses_review', 'total', v_total, 'late', v_late, 'oldest', v_old);
  END IF;

  IF public.admin_has_permission('events.approve') THEN
    SELECT count(*), 0, min(created_at) INTO v_total, v_late, v_old
      FROM public.events WHERE approval_status = 'pending';
    v_out := v_out || jsonb_build_object('key', 'events_pending', 'total', v_total, 'late', 0, 'oldest', v_old);
  END IF;

  RETURN v_out;
END $$;

REVOKE ALL ON FUNCTION public.admin_attention_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_attention_queue() TO authenticated;

-- ── 8. Droits d'exécution ──────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.event_set_approval_required(boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.event_admin_approve(uuid, text)      FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.event_admin_reject(uuid, text)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.event_resubmit(uuid)                 FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.event_admin_pending()                FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.event_set_approval_required(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.event_admin_approve(uuid, text)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.event_admin_reject(uuid, text)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.event_resubmit(uuid)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.event_admin_pending()                TO authenticated;

NOTIFY pgrst, 'reload schema';
