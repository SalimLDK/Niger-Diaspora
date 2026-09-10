-- =============================================================================
-- Deux choses, dans cet ordre, avant de basculer le module Événements sur
-- Supabase : réparer le trigger qui rendait toute inscription impossible, puis
-- reprendre le contenu de la collection Firestore `events`.
-- =============================================================================

-- ── 1. `update_event_attendee_count()` ne pouvait pas s'exécuter ────────────
--
-- La fonction lit `NEW.status = 'going'`. La table `event_attendees`, elle,
-- n'a que `(event_id, user_id, joined_at)` : **aucune colonne `status`**.
-- Tout INSERT partait donc en
--
--   42703: record "new" has no field "status"
--
-- Autrement dit : s'inscrire à un événement était impossible, pour tout le
-- monde, depuis toujours. Personne ne l'avait vu parce que **rien n'écrit
-- encore dans cette table** — le module de l'app est sur Firestore, et le
-- back-office admin ne gère pas les inscriptions. Le défaut se serait réveillé
-- au premier « Participer » après la bascule.
--
-- Trouvé en rejouant la reprise ci-dessous en transaction annulée.
--
-- La fonction est réécrite sur la table telle qu'elle est : **une ligne = un
-- participant**. On n'ajoute pas la colonne `status` que la fonction
-- supposait — le modèle Dart n'a pas de notion de RSVP (`attendeeIds` est une
-- liste plate), et introduire un concept que personne ne lit serait la même
-- erreur qu'un champ d'état jamais alimenté.

CREATE OR REPLACE FUNCTION update_event_attendee_count()
RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE events SET attendee_count = GREATEST(attendee_count + 1, 0)
     WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE events SET attendee_count = GREATEST(attendee_count - 1, 0)
     WHERE id = OLD.event_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.event_id IS DISTINCT FROM OLD.event_id THEN
    -- Ne devrait pas arriver (la clé primaire porte event_id), mais un
    -- compteur qui se tait sur un cas qu'il ne prévoit pas dérive en silence.
    UPDATE events SET attendee_count = GREATEST(attendee_count - 1, 0)
     WHERE id = OLD.event_id;
    UPDATE events SET attendee_count = GREATEST(attendee_count + 1, 0)
     WHERE id = NEW.event_id;
  END IF;
  RETURN NULL;
END;
$$;

-- ── 2. Resynchroniser les compteurs ────────────────────────────────────────
--
-- Le trigger n'ayant jamais tourné, `events.attendee_count` ne reflète rien.
-- On le recale sur le décompte réel plutôt que de laisser une valeur écrite à
-- la main faire autorité.

UPDATE events e
   SET attendee_count = COALESCE(c.n, 0)
  FROM (
    SELECT ev.id, (SELECT count(*) FROM event_attendees a WHERE a.event_id = ev.id) AS n
      FROM events ev
  ) c
 WHERE c.id = e.id
   AND e.attendee_count IS DISTINCT FROM COALESCE(c.n, 0);

-- ── 3. Reprise de la collection Firestore `events` ─────────────────────────
--
-- Inventaire fait le 2026-09-09 via l'API REST Firestore
-- (`gcloud auth print-access-token`, projet `diaspo-niger`) : la collection
-- contient **un seul document**, `LmCs74hv84NSbKM7TDrx`.
--
-- Les deux onglets de l'écran Événements l'affichaient vide, et ça n'était pas
-- une preuve : « À venir » filtre `startDate >= now` (ce document est daté du
-- 2026-08-24, donc passé) et « Passés » filtre `status == 'completed'` (il est
-- resté `upcoming`). Un événement peut donc tomber entre les deux — défaut
-- d'affichage à part entière, noté dans TESTS_APPAREIL_A_FAIRE.md.
--
-- L'identifiant Firestore fait 20 caractères et `events.id` est un `uuid` : la
-- ligne reçoit un nouvel identifiant. Rien ne pointe vers l'ancien —
-- `conversation_id` va dans l'autre sens.
--
-- Idempotente et sans effet ailleurs : les conditions du WHERE échouent sur
-- une base neuve (ni l'utilisateur ni la conversation n'y existent), et sur
-- celle-ci elles n'accepteront la ligne qu'une fois.

INSERT INTO events (
  id, organizer_id, organizer_name, organizer_photo_url,
  title, description, category, city,
  starts_at, status, is_online, is_public,
  max_attendees, price, conversation_id, created_at
)
SELECT
  gen_random_uuid(),
  'vQZE49dTdyRtLwSG6lMIbhAqoFG2',
  'Sim A',
  'https://lh3.googleusercontent.com/a/ACg8ocKQ4RuL9KKzG8UQREiioCDJ70ddcUDV0gcuN8uCwFbeMjxjJg=s96-c',
  'testeur',
  'yyyyyyyyyeerghhghhjjjjjffvvbbnnlkkyfff',
  'networking',
  'Montréal',
  TIMESTAMPTZ '2026-08-24T22:00:00Z',
  'upcoming',
  FALSE,
  FALSE,
  0,
  0,
  'debef5f0-2fa0-4775-b1ed-85a4d6411102',
  TIMESTAMPTZ '2026-08-23T04:03:09.033Z'
WHERE EXISTS (SELECT 1 FROM users WHERE id = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2')
  AND EXISTS (
    SELECT 1 FROM conversations
     WHERE id = 'debef5f0-2fa0-4775-b1ed-85a4d6411102'
  )
  AND NOT EXISTS (
    SELECT 1 FROM events
     WHERE title = 'testeur'
       AND organizer_id = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'
       AND starts_at = TIMESTAMPTZ '2026-08-24T22:00:00Z'
  );

-- L'inscription de l'organisateur. Côté Firestore elle vivait dans
-- `attendeeIds` du document lui-même ; ici c'est une table à part, et sans
-- cette ligne l'événement ne ressortirait pas par la voie des inscriptions.
INSERT INTO event_attendees (event_id, user_id)
SELECT e.id, 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'
  FROM events e
 WHERE e.title = 'testeur'
   AND e.organizer_id = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'
   AND e.starts_at = TIMESTAMPTZ '2026-08-24T22:00:00Z'
ON CONFLICT (event_id, user_id) DO NOTHING;

-- ⚠️ Le document Firestore n'est PAS supprimé par cette migration. Tant que
-- personne n'a confirmé la bascule sur un vrai téléphone, la source d'origine
-- reste la seule copie de secours. La suppression est un geste séparé, à faire
-- une fois la recette passée.

NOTIFY pgrst, 'reload schema';
