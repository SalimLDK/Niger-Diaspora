-- =============================================================================
-- Préparer `public.events` à devenir la source unique des événements.
--
-- Constat du 2026-09-09 : le module Événements de l'app
-- (`EventRemoteDataSourceImpl`, liste + fiche + création + participation) parle
-- **Firestore**, alors que le back-office admin (`admin_provider.dart`) parle
-- `public.events`. Un événement créé d'un côté n'existe pas de l'autre, et un
-- lien `/events/<uuid Supabase>` ne peut pas s'ouvrir dans l'app.
--
-- Salim a tranché : c'est Supabase qui fait foi. Cette migration comble les
-- trois écarts qui empêchaient le module de basculer, et rien de plus. Elle est
-- sans effet sur le code actuel : elle ajoute une colonne à défaut, une clé
-- étrangère, et élargit une lecture.
-- =============================================================================

-- ── 1. `price` n'existait pas ───────────────────────────────────────────────
--
-- `EventModel.price` est affiché sur la fiche (`event_detail_screen.dart`) et
-- saisi à la création (`create_event_screen.dart`). Sans colonne, la valeur
-- serait perdue en silence à chaque écriture — la famille de défaut décrite
-- dans `project_widgets_alimentes_en_dur`.
--
-- `numeric` et non `double precision` : c'est un montant.

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS price NUMERIC(12, 2) NOT NULL DEFAULT 0;

-- ── 2. `event_attendees` n'était rattachée à rien ───────────────────────────
--
-- La table n'avait que sa clé primaire `(event_id, user_id)` : supprimer un
-- événement laissait ses participants derrière lui. `events` porte déjà
-- `ON DELETE CASCADE` vers `groups` et `conversations`, on aligne.
--
-- Les orphelins existants doivent partir d'abord, sinon la contrainte est
-- refusée à la création.

DELETE FROM event_attendees ea
 WHERE NOT EXISTS (SELECT 1 FROM events e WHERE e.id = ea.event_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.event_attendees'::regclass
       AND conname = 'event_attendees_event_id_fkey'
  ) THEN
    ALTER TABLE event_attendees
      ADD CONSTRAINT event_attendees_event_id_fkey
      FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ── 3. La liste des participants était invisible ────────────────────────────
--
-- `event_attendees_own` est une policy FOR ALL dont le USING vaut
-- `firebase_uid() = user_id` : chacun ne voyait que **sa** ligne. L'app, elle,
-- se sert de la liste entière pour décider si un événement est complet :
--
--   events_screen.dart:554  event.attendeeIds.length < event.maxAttendees
--   events_screen.dart:836  event.attendeeIds.length >= event.maxAttendees
--
-- Avec une seule ligne lisible, aucun événement n'aurait jamais été annoncé
-- complet. C'est mot pour mot le défaut corrigé sur les groupes par
-- `20260806190000` (« Membres · 0 » au-dessus d'un membre bien affiché).
--
-- L'élargissement ne publie rien de plus que ce qui l'est déjà :
-- `events_select` rend tout événement non-brouillon lisible par n'importe qui,
-- donc « qui participe à cet événement » est du même ordre que « qui est
-- membre de ce groupe public ». Les brouillons restent hors de portée.
--
-- ⚠️ Fonction SECURITY DEFINER, et ce n'est pas un ornement : lire
-- `event_attendees` déclencherait la RLS de `events`, dont une policy
-- interroge `conversations`… et Postgres refuse de rentrer une seconde fois
-- dans une RLS déjà en cours d'application (42P17). Même remède que
-- `20260804120000` sur `groups`. `search_path` figé : une fonction SECURITY
-- DEFINER sans search_path explicite est détournable par un appelant qui place
-- une table homonyme en tête du sien.

CREATE OR REPLACE FUNCTION is_event_readable(p_event_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM events e
     WHERE e.id = p_event_id
       AND e.status <> 'draft'
  )
$$;

REVOKE ALL ON FUNCTION is_event_readable(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_event_readable(UUID) TO authenticated, anon;

-- `event_attendees_own` reste : c'est elle qui porte INSERT/UPDATE/DELETE, et
-- son USING d'écriture ne doit PAS s'élargir — sinon n'importe qui inscrirait
-- n'importe qui. On lui retire seulement la lecture, confiée à une policy
-- dédiée.
DROP POLICY IF EXISTS "event_attendees_own" ON event_attendees;
CREATE POLICY "event_attendees_own" ON event_attendees
  FOR ALL USING ((SELECT firebase_uid()) = user_id)
  WITH CHECK ((SELECT firebase_uid()) = user_id);

DROP POLICY IF EXISTS "event_attendees_select" ON event_attendees;
CREATE POLICY "event_attendees_select" ON event_attendees FOR SELECT
  USING (
    (SELECT firebase_uid()) = user_id
    OR is_event_readable(event_id)
  );

-- ── 4. Vocabulaire de `status` : rien à changer ici, tout est côté app ──────
--
-- `events_status_check` accepte draft | upcoming | ongoing | ended | cancelled.
-- L'enum Dart `EventStatus` dit upcoming | ongoing | **completed** | cancelled.
-- Écrire `completed` violerait la contrainte (23514), et `recentPastEventProvider`
-- qui filtre sur `completed` ne trouverait jamais rien.
--
-- La contrainte n'est PAS élargie : `draft` et `ended` sont le vocabulaire de
-- la base, `draft` n'a même pas d'équivalent Dart. La traduction se fait dans
-- le datasource (`completed` ⇄ `ended`), au seul endroit qui connaît les deux
-- vocabulaires.

NOTIFY pgrst, 'reload schema';
