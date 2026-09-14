-- Une audience restreinte à personne n'est pas une audience.
--
-- Trouvé en production le 2026-09-14 par `tools/invariants_donnees.py` : un
-- événement `visibility = 'people'` avec ZÉRO ligne dans `event_audience`,
-- créé le matin même par un compte de douze minutes. Un événement que personne
-- ne peut voir, y compris les personnes qu'on croyait avoir invitées.
--
-- `set_event_audience` filtre ses entrées en silence — elle ne garde que les
-- ids présents dans `public.users` et différents de l'organisateur :
--
--     WHERE u.id = ANY (p_user_ids[1:200]) AND u.id <> v_uid
--
-- Ce filtrage est juste : on ne veut pas inviter un compte qui n'existe pas.
-- Mais quand il ne reste RIEN, la fonction écrivait quand même
-- `events.visibility = 'people'` et rendait VOID. L'appelant lisait un succès.
-- C'est la forme la plus coûteuse d'échec de ce projet : non pas une erreur
-- qu'on n'affiche pas, mais un **succès qui n'a rien fait**.
--
-- Le garde ci-dessous lève quand une demande « groups » ou « people » aboutit
-- à une audience vide. La fonction est une seule transaction : la levée annule
-- aussi les DELETE du début, donc une audience existante n'est jamais perdue
-- par une tentative ratée. Le client, lui, sait déjà traiter l'échec — il
-- affiche « les groupes ou personnes choisis n'ont pas été enregistrés ».
--
-- `CREATE OR REPLACE` suffit : ni la signature ni le type de retour ne
-- changent, donc aucun `DROP` — et aucun risque du 42723 « already exists with
-- same argument types » qui bloque toute la file `db push`.

CREATE OR REPLACE FUNCTION public.set_event_audience(
  p_event_id   UUID,
  p_visibility TEXT,
  p_group_ids  UUID[] DEFAULT '{}',
  p_user_ids   TEXT[] DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     TEXT := public.firebase_uid();
  v_event   RECORD;
  v_nom     TEXT;
  v_nouveau TEXT;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'set_event_audience: not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_visibility NOT IN ('public', 'discussion', 'groups', 'people') THEN
    RAISE EXCEPTION 'set_event_audience: invalid visibility' USING ERRCODE = '22023';
  END IF;

  SELECT id, organizer_id, title, status, conversation_id, group_id
    INTO v_event
    FROM events WHERE id = p_event_id;

  IF NOT FOUND OR v_event.organizer_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'set_event_audience: not the organizer' USING ERRCODE = '42501';
  END IF;

  IF p_visibility = 'discussion'
     AND v_event.conversation_id IS NULL AND v_event.group_id IS NULL THEN
    RAISE EXCEPTION 'set_event_audience: no discussion to restrict to'
      USING ERRCODE = '22023';
  END IF;

  -- Groupes : seulement ceux dont l'organisateur est membre.
  DELETE FROM event_audience
   WHERE event_id = p_event_id AND group_id IS NOT NULL
     AND (p_visibility <> 'groups'
          OR NOT (group_id = ANY (COALESCE(p_group_ids, '{}'))));

  IF p_visibility = 'groups' THEN
    INSERT INTO event_audience (event_id, group_id)
    SELECT p_event_id, gm.group_id
      FROM group_members gm
     WHERE gm.user_id = v_uid
       AND gm.group_id = ANY (COALESCE(p_group_ids, '{}'))
    ON CONFLICT (event_id, group_id) WHERE group_id IS NOT NULL DO NOTHING;
  END IF;

  -- Personnes : comptes existants, hors soi-même, 200 au plus.
  DELETE FROM event_audience
   WHERE event_id = p_event_id AND user_id IS NOT NULL
     AND (p_visibility <> 'people'
          OR NOT (user_id = ANY (COALESCE(p_user_ids, '{}'))));

  IF p_visibility = 'people' THEN
    SELECT COALESCE(NULLIF(display_name, ''), 'Quelqu''un') INTO v_nom
      FROM users WHERE id = v_uid;

    FOR v_nouveau IN
      SELECT u.id
        FROM users u
       WHERE u.id = ANY ((COALESCE(p_user_ids, '{}'))[1:200])
         AND u.id <> v_uid
         AND NOT EXISTS (
               SELECT 1 FROM event_audience a
                WHERE a.event_id = p_event_id AND a.user_id = u.id)
    LOOP
      INSERT INTO event_audience (event_id, user_id)
      VALUES (p_event_id, v_nouveau)
      ON CONFLICT (event_id, user_id) WHERE user_id IS NOT NULL DO NOTHING;

      -- Une invitation dont on n'est pas prévenu ne sert à rien : l'événement
      -- n'apparaît dans aucune liste qu'on consulte par hasard.
      IF v_event.status <> 'draft' THEN
        BEGIN
          INSERT INTO notifications (user_id, type, title, body, data, is_read)
          VALUES (
            v_nouveau,
            'eventUpdate',
            'Invitation à un événement',
            COALESCE(v_nom, 'Quelqu''un') || ' vous invite : ' || v_event.title,
            jsonb_build_object(
              'type',     'eventUpdate',
              'eventId',  p_event_id::TEXT,
              'targetId', p_event_id::TEXT,
              'target_id', p_event_id::TEXT,
              'senderId', v_uid,
              'actor_id', v_uid
            ),
            FALSE
          );
        EXCEPTION WHEN OTHERS THEN
          RAISE WARNING 'set_event_audience (notification): %', SQLERRM;
        END;
      END IF;
    END LOOP;
  END IF;

  -- ── LE GARDE ────────────────────────────────────────────────────────────
  -- Restreindre à un ensemble vide, c'est cacher l'événement à tout le monde.
  -- Mieux vaut refuser bruyamment que réussir dans le vide.
  IF p_visibility IN ('groups', 'people')
     AND NOT EXISTS (SELECT 1 FROM event_audience a WHERE a.event_id = p_event_id)
  THEN
    RAISE EXCEPTION
      'set_event_audience: audience vide apres filtrage (visibilite %, % groupe(s), % personne(s) demandes)',
      p_visibility,
      COALESCE(array_length(p_group_ids, 1), 0),
      COALESCE(array_length(p_user_ids, 1), 0)
      USING ERRCODE = '22023';
  END IF;

  UPDATE events SET visibility = p_visibility WHERE id = p_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_event_audience(UUID, TEXT, UUID[], TEXT[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_event_audience(UUID, TEXT, UUID[], TEXT[])
  TO authenticated;
