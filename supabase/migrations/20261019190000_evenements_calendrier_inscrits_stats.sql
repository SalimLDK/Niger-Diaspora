-- Événements, côté administration : calendrier, liste des inscrits, statistiques.
--
-- Référentiel d'administration § 8 (« Les listes de participants ne sont
-- accessibles qu'aux rôles autorisés », « Les statistiques utilisent des
-- définitions explicites et une période connue »), spécification d'interfaces
-- § 13 (vues liste et calendrier, dates et fuseau explicites).
--
-- ═══ CE QUI EXISTAIT ═══════════════════════════════════════════════════════
--
-- Le panneau lisait `events` par un SELECT sous les policies de l'application :
-- 50 lignes, sans calendrier, sans voir qui s'inscrit, sans chiffre. Les
-- inscriptions (`event_attendees`, 65 lignes) n'étaient lisibles que par les
-- intéressés.
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • `event_admin_calendar(du, au)` : les événements PUBLICS d'une période, avec
--   statut, lieu, capacité et nom de l'organisateur ; les événements non
--   publics (réservés à des invités, un groupe, une discussion) n'y sont pas
--   listés, seulement COMPTÉS — un administrateur n'a pas à lire l'agenda
--   privé de quelqu'un pour modérer. Le résultat dit combien sont masqués.
-- • `event_admin_attendees(id)` : la liste des inscrits d'UN événement, public
--   ou non. C'est une donnée personnelle : permission dédiée
--   `events.attendance.view`, superAdmin seul (mappée à aucun rôle), et la
--   consultation est JOURNALISÉE (qui, quel événement, combien de lignes —
--   jamais les noms). Précision mesurée par le banc : pour un événement PUBLIC,
--   la policy `event_attendees_select` laisse déjà tout membre qui peut lire
--   l'événement lire la liste de ses inscrits (« qui y va » est une
--   fonctionnalité de l'application) ; la fonction n'ouvre donc rien de
--   nouveau là. Elle apporte la TRACE, et l'accès aux listes des événements
--   non publics, que la RLS réserve aux intéressés.
-- • `event_admin_stats(jours)` : des agrégats sur une fenêtre de 1 à 365 jours,
--   chaque indicateur avec sa définition dans la réponse. Permission
--   `events.analytics.view` (contentMod, superAdmin).
--
-- ═══ UNE FUITE TROUVÉE PAR LE BANC, FERMÉE ICI ════════════════════════════
--
-- `can_see_event()` — qui décide ce que lit la policy `events_select_visible`
-- ET ce que lit `event_attendees_select` (via `is_event_readable`) — portait
-- `OR is_admin()` : TOUT administrateur, financeMod compris, lisait tous les
-- événements, brouillons et événements privés compris, et la liste de leurs
-- inscrits. L'exemption datait des policies `events_admin_*`, retirées par
-- 20261018170000 : elle ne servait plus à rien et fuyait.
--   • `can_see_event` : l'exemption devient `admin_has_permission('events.moderate')`
--     (contentMod, superAdmin) — modérer exige de voir.
--   • `is_event_readable` (policy des inscrits) : redéfinie par une fonction
--     de MEMBRE, sans exemption. Un administrateur lit donc les inscrits comme
--     n'importe quel membre — ceux des événements publics, que l'application
--     affiche déjà — et la liste d'un événement privé passe par
--     `event_admin_attendees`, qui exige `events.attendance.view` et trace.
--
-- ═══ CE QU'ELLE NE FAIT PAS, ET LE DIT ══════════════════════════════════════
--
-- • Pas de validation AVANT publication : un organisateur publie directement
--   (policy `events_manage_own`). L'imposer change le parcours de tous les
--   organisateurs (un événement public resterait invisible jusqu'à
--   l'approbation d'un administrateur) ; le référentiel la veut « selon le
--   rôle et le niveau de risque », ce qui est une décision de produit. Elle
--   n'est pas prise ici.
-- • Pas de distinction « inscriptions / annulations d'inscription /
--   participations confirmées » : la base ne garde que les inscriptions
--   vivantes (une désinscription supprime la ligne) et aucune présence. Les
--   statistiques ne prétendent donc pas à ces chiffres ; la réponse les
--   déclare non mesurés.
-- • Les annulations d'ÉVÉNEMENT ne sont comptées que depuis la mise en place de
--   `event_history` (2026-10-18).
-- • Pas d'export.
--
-- Banc : tools/rls_tests/evenements_calendrier_inscrits_stats.sql.

SET lock_timeout = '5s';

-- ── 1. Permissions ──────────────────────────────────────────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('events.attendance.view', 'events', 'Voir la liste des inscrits d''un événement (donnée personnelle)', NULL),
  ('events.analytics.view',  'events', 'Voir les statistiques des événements',                              NULL)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission) VALUES
  ('contentMod', 'events.analytics.view')
ON CONFLICT DO NOTHING;
-- `events.attendance.view` : volontairement aucun rôle (voir l'en-tête).

-- ── 2. Calendrier ───────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.event_admin_calendar(timestamptz, timestamptz);

CREATE FUNCTION public.event_admin_calendar(p_from timestamptz, p_to timestamptz) RETURNS jsonb
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
           'max_attendees', e.max_attendees, 'organizer_name', e.organizer_name)
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

-- ── 3. Inscrits d'un événement ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.event_admin_attendees(uuid);

CREATE FUNCTION public.event_admin_attendees(p_id uuid)
RETURNS TABLE (user_id text, display_name text, joined_at timestamptz)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_n int;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événements : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.attendance.view');

  IF NOT EXISTS (SELECT 1 FROM public.events WHERE id = p_id) THEN
    RAISE EXCEPTION 'événements : introuvable' USING ERRCODE = 'P0002';
  END IF;

  SELECT count(*) INTO v_n FROM public.event_attendees WHERE event_id = p_id;
  -- La consultation d'une liste de personnes est tracée : qui, quel événement,
  -- combien de lignes. Jamais les noms.
  PERFORM public.write_admin_audit(
    'EVENT_ATTENDEES_VIEWED', 'event', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('count', v_n));

  RETURN QUERY
  SELECT a.user_id, coalesce(u.display_name, ''), a.joined_at
    FROM public.event_attendees a
    LEFT JOIN public.users u ON u.id = a.user_id
   WHERE a.event_id = p_id
   ORDER BY a.joined_at
   LIMIT 500;
END $$;

-- ── 4. Statistiques ─────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.event_admin_stats(integer);

CREATE FUNCTION public.event_admin_stats(p_days integer DEFAULT 30) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_since   timestamptz;
  v_status  jsonb;
  v_created int;
  v_upcoming int;
  v_regs    int;
  v_cancel  int;
  v_fill    numeric;
BEGIN
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'événements : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('events.analytics.view');

  IF p_days IS NULL OR p_days < 1 OR p_days > 365 THEN
    RAISE EXCEPTION 'événements : fenêtre de 1 à 365 jours' USING ERRCODE = '22023';
  END IF;
  v_since := now() - make_interval(days => p_days);

  SELECT coalesce(jsonb_object_agg(status, n), '{}'::jsonb)
    INTO v_status FROM (SELECT status, count(*) n FROM public.events GROUP BY status) s;
  SELECT count(*) INTO v_created  FROM public.events WHERE created_at >= v_since;
  SELECT count(*) INTO v_upcoming FROM public.events
   WHERE status IN ('upcoming', 'ongoing') AND starts_at >= now();
  SELECT count(*) INTO v_regs FROM public.event_attendees WHERE joined_at >= v_since;
  SELECT count(DISTINCT event_id) INTO v_cancel FROM public.event_history
   WHERE kind = 'changed' AND occurred_at >= v_since
     AND changes -> 'status' ->> 'to' = 'cancelled';
  SELECT round(avg(attendee_count::numeric / max_attendees), 3) INTO v_fill
    FROM public.events
   WHERE status IN ('upcoming', 'ongoing') AND starts_at >= now()
     AND max_attendees IS NOT NULL AND max_attendees > 0;

  RETURN jsonb_build_object(
    'window_days', p_days,
    'since', v_since,
    'by_status_now', v_status,
    'events_created', v_created,
    'events_upcoming', v_upcoming,
    'registrations', v_regs,
    'events_cancelled', v_cancel,
    'fill_rate_upcoming', v_fill,
    'definitions', jsonb_build_object(
      'events_created', 'événements dont la création date de la fenêtre',
      'events_upcoming', 'événements à venir (statut upcoming ou ongoing, début dans le futur), à l''instant',
      'registrations', 'inscriptions encore valides dont la date tombe dans la fenêtre : une désinscription retire la ligne, elle n''est pas comptée à part',
      'events_cancelled', 'événements annulés dans la fenêtre, d''après l''historique des changements (en place depuis le 2026-10-18)',
      'fill_rate_upcoming', 'moyenne des inscrits sur la capacité, événements à venir avec capacité fixée'),
    'not_measured', jsonb_build_array('désinscriptions', 'participations confirmées'));
END $$;

-- ── 4 bis. Qui voit quel événement ──────────────────────────────────────────
-- Corps de `can_see_event` relevé en production le 2026-10-19, moins
-- l'exemption `is_admin()`.
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

REVOKE ALL ON FUNCTION public.can_see_event_as_member(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.is_event_readable(p_event_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.can_see_event_as_member(p_event_id);
$function$;

CREATE OR REPLACE FUNCTION public.can_see_event(p_event_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.can_see_event_as_member(p_event_id)
      OR (EXISTS (SELECT 1 FROM public.events WHERE id = p_event_id)
          AND public.admin_has_permission('events.moderate'));
$function$;

-- ── 5. Droits d'exécution ───────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.event_admin_calendar(timestamptz, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.event_admin_attendees(uuid)                    FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.event_admin_stats(integer)                     FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.event_admin_calendar(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.event_admin_attendees(uuid)                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.event_admin_stats(integer)                     TO authenticated;

NOTIFY pgrst, 'reload schema';
