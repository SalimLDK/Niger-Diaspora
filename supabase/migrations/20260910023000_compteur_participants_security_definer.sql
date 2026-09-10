-- =============================================================================
-- `update_event_attendee_count()` doit être SECURITY DEFINER.
--
-- Ma faute, dans `20260910010000` : j'ai réécrit la fonction pour qu'elle
-- cesse de lire une colonne `status` inexistante, sans lui rendre le droit
-- d'écrire dans `events`.
--
-- Mesuré sur SM A515F le 2026-09-09, en appuyant sur « Participer » à
-- « Tabaski 2026 » depuis un compte qui n'en est pas l'organisateur :
--
--   event_attendees  →  1 ligne     (l'inscription passe)
--   events.attendee_count  →  0     (le compteur n'a pas bougé)
--
-- La fonction est SECURITY INVOKER : son `UPDATE events SET attendee_count`
-- s'exécute sous l'identité du participant, et `events_manage_own` est un
-- `FOR ALL USING (firebase_uid() = organizer_id)`. La RLS ne fait pas échouer
-- l'UPDATE — elle lui donne **zéro ligne**. Aucune erreur, nulle part.
--
-- C'est la forme d'échec muet la mieux connue de ce projet, et je l'ai
-- réintroduite : un trigger qui n'est pas DEFINER n'écrit rien dès que sa
-- cible est protégée par une policy que l'appelant ne satisfait pas.
--
-- `search_path` reste figé : une fonction SECURITY DEFINER sans search_path
-- explicite est détournable par un appelant qui place une table homonyme en
-- tête du sien.
-- =============================================================================

CREATE OR REPLACE FUNCTION update_event_attendee_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE events SET attendee_count = GREATEST(attendee_count + 1, 0)
     WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE events SET attendee_count = GREATEST(attendee_count - 1, 0)
     WHERE id = OLD.event_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.event_id IS DISTINCT FROM OLD.event_id THEN
    UPDATE events SET attendee_count = GREATEST(attendee_count - 1, 0)
     WHERE id = OLD.event_id;
    UPDATE events SET attendee_count = GREATEST(attendee_count + 1, 0)
     WHERE id = NEW.event_id;
  END IF;
  RETURN NULL;
END;
$$;

-- Recaler les compteurs sur le décompte réel : les inscriptions faites entre
-- `20260910010000` et cette migration n'ont rien incrémenté.
UPDATE events e
   SET attendee_count = c.n
  FROM (
    SELECT ev.id,
           (SELECT count(*) FROM event_attendees a WHERE a.event_id = ev.id) AS n
      FROM events ev
  ) c
 WHERE c.id = e.id
   AND e.attendee_count IS DISTINCT FROM c.n;

NOTIFY pgrst, 'reload schema';
