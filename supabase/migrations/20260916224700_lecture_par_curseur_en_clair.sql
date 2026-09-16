-- Conversations en clair : la lecture avance par curseur, comme en MLS.
--
-- Depuis le 2026-09-16 (8d81cce), l'écran ne marque plus « lu » à
-- l'ouverture : une bulle est lue quand elle a été montrée, et le séparateur
-- « N messages non lus » est la représentation d'un curseur. Côté MLS, le
-- curseur vit dans `mls_message_receipts`. Côté legacy, il n'y avait rien :
-- `mark_messages_as_read` ne connaît que « toute la conversation ». L'écran
-- l'appelait donc au premier coup d'œil, et tout ce qui restait sous le pli
-- partait « Lu » chez l'expéditeur.
--
-- Mesuré en production avant d'écrire (2026-09-16) :
--   · 20 conversations legacy ont encore reçu des messages cette semaine ;
--   · `data.unreadCount` stocké diverge déjà du réel : dans le groupe de 24,
--     16 messages non lus pour un compteur à 14, 12 ou 8 selon le membre ;
--     ailleurs 2 non lus pour un compteur à 0. D'où le RECALCUL plus bas ;
--   · 7 conversations basculées portent 14 messages legacy non lus — toutes
--     entre comptes `banc_b_…` (banc MLS de phase 3), aucune entre vrais
--     comptes. Le cas reste possible : une bascule survient quand un
--     participant envoie, pas quand l'autre a tout lu. Le repère ci-dessous
--     lit donc les DEUX magasins d'un coup ; ça ne coûte rien de plus.
--
-- ---------------------------------------------------------------------------
-- 0. La faille des deux RPC d'accusés
-- ---------------------------------------------------------------------------
-- `mark_messages_as_read(p_conversation_id, p_user_id)` et
-- `mark_messages_as_delivered(…)` vérifient que `p_user_id` est participant —
-- pas que l'APPELANT l'est, ni qu'il est `p_user_id`. Elles sont
-- `SECURITY DEFINER` : tout compte connecté qui connaît un identifiant de
-- conversation et celui d'un de ses membres peut poser « Lu » ou « Distribué »
-- en son nom. Seul le bloc des notifications (ajouté le 2026-09-12) comparait
-- à `firebase_uid()`.
--
-- Corps repris À L'IDENTIQUE de ce qui tourne (lu dans `pg_proc` le
-- 2026-09-16, identique à 20260912200000 et 20260813130000), plus la garde
-- d'identité. Les appelants de l'app passent tous leur propre uid : rien ne
-- change pour eux. Aucune Edge Function ne les appelle (vérifié par grep) —
-- une garde sur `firebase_uid()` ne casse donc pas un appel `service_role`.
--
-- Hors périmètre, relevé en passant : l'ajout à `deliveredTo` ne vérifie pas
-- la présence, d'où 83 messages avec des doublons ; et `mark_messages_as_read`
-- réécrit `deliveredAt` d'un message déjà livré. Non corrigé ici pour que ce
-- fichier ne change que ce qu'il annonce.

CREATE OR REPLACE FUNCTION public.mark_messages_as_delivered(
  p_conversation_id TEXT,
  p_user_id         TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now TEXT := NOW()::TEXT;
BEGIN
  IF p_user_id IS NULL OR p_user_id = '' THEN
    RAISE EXCEPTION 'mark_messages_as_delivered: user_id is required';
  END IF;

  -- Ajout 2026-09-16 : on n'accuse réception que pour soi.
  IF p_user_id IS DISTINCT FROM (SELECT public.firebase_uid()) THEN
    RAISE EXCEPTION 'mark_messages_as_delivered: on n''accuse réception que pour soi'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM conversations c
    WHERE c.id = p_conversation_id
      AND p_user_id = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'mark_messages_as_delivered: user is not a participant';
  END IF;

  UPDATE messages
  SET data = jsonb_set(
        jsonb_set(
          COALESCE(data, '{}'::jsonb),
          '{deliveredTo}',
          COALESCE(
            (data->'deliveredTo') || to_jsonb(p_user_id),
            jsonb_build_array(p_user_id)
          )
        ),
        '{deliveredAt}',
        COALESCE(
          jsonb_set(
            COALESCE(data->'deliveredAt', '{}'::jsonb),
            ARRAY[p_user_id],
            to_jsonb(v_now)
          ),
          jsonb_build_object(p_user_id, v_now)
        )
      )
  WHERE conversation_id = p_conversation_id
    AND sender_id <> p_user_id
    AND (
      data->'deliveredTo' IS NULL
      OR NOT (data->'deliveredTo') ? p_user_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.mark_messages_as_delivered(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_delivered(TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_messages_as_read(
  p_conversation_id TEXT,
  p_user_id         TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now TEXT := NOW()::TEXT;
BEGIN
  IF p_user_id IS NULL OR p_user_id = '' THEN
    RAISE EXCEPTION 'mark_messages_as_read: user_id is required';
  END IF;

  -- Ajout 2026-09-16 : on ne marque lu que pour soi.
  IF p_user_id IS DISTINCT FROM (SELECT public.firebase_uid()) THEN
    RAISE EXCEPTION 'mark_messages_as_read: on ne marque lu que pour soi'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM conversations c
    WHERE c.id = p_conversation_id
      AND p_user_id = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'mark_messages_as_read: user is not a participant';
  END IF;

  -- Lire implique avoir reçu : on pose aussi deliveredTo/deliveredAt, pour
  -- les messages ouverts directement (sans étape de livraison push).
  UPDATE messages
  SET data = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              COALESCE(data, '{}'::jsonb),
              '{deliveredTo}',
              COALESCE(
                (data->'deliveredTo') || to_jsonb(p_user_id),
                jsonb_build_array(p_user_id)
              )
            ),
            '{deliveredAt}',
            COALESCE(
              jsonb_set(
                COALESCE(data->'deliveredAt', '{}'::jsonb),
                ARRAY[p_user_id],
                to_jsonb(v_now)
              ),
              jsonb_build_object(p_user_id, v_now)
            )
          ),
          '{readBy}',
          COALESCE(
            (data->'readBy') || to_jsonb(p_user_id),
            jsonb_build_array(p_user_id)
          )
        ),
        '{readAt}',
        COALESCE(
          jsonb_set(
            COALESCE(data->'readAt', '{}'::jsonb),
            ARRAY[p_user_id],
            to_jsonb(v_now)
          ),
          jsonb_build_object(p_user_id, v_now)
        )
      )
  WHERE conversation_id = p_conversation_id
    AND sender_id <> p_user_id
    AND (
      data->'readBy' IS NULL
      OR NOT (data->'readBy') ? p_user_id
    );

  -- 2026-09-12 : la discussion est lue, ses notifications aussi — messages et
  -- réactions (`messageReaction`, 20260912220000). La condition
  -- `p_user_id = firebase_uid()` qui gardait ce bloc est désormais vraie par
  -- construction (garde d'identité ci-dessus).
  UPDATE notifications
  SET is_read = TRUE
  WHERE user_id = p_user_id
    AND NOT is_read
    AND type IN ('message', 'messageReaction')
    AND data->>'conversationId' = p_conversation_id;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_messages_as_read(TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 1. Le repère de lecture, sur les deux magasins
-- ---------------------------------------------------------------------------
-- Répond en UNE lecture aux trois questions que l'écran posait en trois
-- allers-retours côté MLS (`curseurDeLecture`, `premierNonLu`, `nonLus`) :
--
--   curseur        le message d'autrui le plus récent que j'ai lu ;
--   premier non-lu le plus ancien message d'autrui non lu APRÈS le curseur —
--                  c'est lui que le séparateur désigne, chargé ou non ;
--   non_lus        combien de non-lus après le curseur — donc combien sous le
--                  séparateur, ce que son libellé annonce.
--
-- Une seule instruction : les trois décrivent le même instantané. En trois
-- requêtes, un message arrivé entre deux lectures décalait le compte.
--
-- Ce qui compte comme « à lire » est aligné sur la vue `mls_unread_counts` :
-- ni mes messages, ni les supprimés, ni ce que j'ai masqué pour moi, ni —
-- côté MLS — les messages de contrôle (`kind <> 'content'`). Côté legacy,
-- les messages `system` non plus (aucun en base aujourd'hui, mesuré ; la règle
-- est posée pour qu'un futur n'en fasse pas du courrier).
--
-- `SECURITY INVOKER` : la RLS de chaque table s'applique. On ne lit que ce que
-- l'appelant voit déjà ; la fonction ne lui apprend rien de plus, elle lui
-- épargne des allers-retours.
CREATE OR REPLACE FUNCTION public.repere_de_lecture(p_conversation_id TEXT)
RETURNS TABLE (
  curseur_id       TEXT,
  curseur_a        TIMESTAMPTZ,
  premier_non_lu_id TEXT,
  premier_non_lu_a TIMESTAMPTZ,
  non_lus          INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid TEXT := public.firebase_uid();
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'repere_de_lecture: session requise' USING ERRCODE = '42501';
  END IF;

  -- Un refus doit se voir. Sans cette garde, un non-participant recevrait un
  -- repère vide — « rien à lire » — indiscernable d'une conversation lue.
  IF NOT EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = p_conversation_id
      AND v_uid = ANY (c.participant_ids)
  ) THEN
    RAISE EXCEPTION 'repere_de_lecture: pas participant' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH fil AS (
    SELECT m.id AS id,
           m.created_at AS quand,
           COALESCE((m.data->'readBy') ? v_uid, FALSE) AS lu
      FROM messages m
     WHERE m.conversation_id = p_conversation_id
       AND m.sender_id <> v_uid
       AND m.type IS DISTINCT FROM 'system'
       AND NOT COALESCE(m.is_deleted, FALSE)
       AND NOT COALESCE((m.data->'deletedFor') ? v_uid, FALSE)
    UNION ALL
    SELECT mm.id::TEXT,
           mm.created_at,
           r.read_at IS NOT NULL
      FROM mls_messages mm
      LEFT JOIN mls_message_receipts r
             ON r.message_id = mm.id AND r.user_id = v_uid
      LEFT JOIN mls_message_hidden h
             ON h.message_id = mm.id AND h.user_id = v_uid
     WHERE mm.conversation_id = p_conversation_id
       AND mm.kind = 'content'
       AND NOT mm.is_deleted
       AND mm.sender_id <> v_uid
       AND h.message_id IS NULL
  ),
  curseur AS (
    SELECT f.id, f.quand FROM fil f
     WHERE f.lu
     ORDER BY f.quand DESC, f.id DESC
     LIMIT 1
  ),
  apres AS (
    SELECT f.id, f.quand FROM fil f
     WHERE NOT f.lu
       AND f.quand > COALESCE((SELECT c.quand FROM curseur c), '-infinity'::timestamptz)
  )
  SELECT (SELECT c.id FROM curseur c),
         (SELECT c.quand FROM curseur c),
         (SELECT a.id FROM apres a ORDER BY a.quand, a.id LIMIT 1),
         (SELECT a.quand FROM apres a ORDER BY a.quand, a.id LIMIT 1),
         (SELECT count(*)::INTEGER FROM apres);
END;
$$;

REVOKE ALL ON FUNCTION public.repere_de_lecture(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.repere_de_lecture(TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Avancer le curseur, en clair
-- ---------------------------------------------------------------------------
-- Marque lus les messages legacy d'autrui JUSQU'AU message donné inclus, et
-- pas au-delà. C'est le pendant de `MlsMetadonnees.marquerLusJusqua`.
--
-- L'identité vient de `firebase_uid()`, plus d'un paramètre : la faille du
-- § 0 ne peut pas se reproduire ici.
--
-- La borne est un IDENTIFIANT, pas une date envoyée par le client : c'est le
-- serveur qui lit sa `created_at`, sans question de précision ni d'horloge.
-- Il peut désigner un message MLS — dans une conversation basculée, le
-- dernier message vu est chiffré, et les legacy non lus qui le précèdent
-- doivent partir avec lui.
--
-- Ce qui est déjà posé n'est jamais réécrit : `readAt` garde l'heure du
-- premier coup d'œil (même règle que `MlsMetadonnees.marquer`), `deliveredAt`
-- aussi, et `deliveredTo` ne prend pas de doublon.
--
-- `unreadCount` est RECALCULÉ, pas remis à zéro : lire jusqu'ici laisse ce
-- qui suit non lu, et la pastille de la liste doit le dire. Écrit seulement
-- s'il change — chaque écriture de `conversations` part en temps réel chez
-- tous les participants.
--
-- Rend le nombre de messages legacy qui me restent à lire.
CREATE OR REPLACE FUNCTION public.marquer_lus_jusqua(
  p_conversation_id TEXT,
  p_message_id      TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid      TEXT := public.firebase_uid();
  v_now      TEXT := NOW()::TEXT;
  v_borne    TIMESTAMPTZ;
  v_bascule  TIMESTAMPTZ;
  v_reste    INTEGER;
  v_data     JSONB;
  v_nouvelle JSONB;
  v_lecteurs JSONB;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'marquer_lus_jusqua: session requise' USING ERRCODE = '42501';
  END IF;

  -- `FOR UPDATE` : le recompte et l'écriture de `data` ci-dessous forment une
  -- lecture-modification-écriture. Le verrou la rend atomique face à un autre
  -- appel du même utilisateur (deux appareils).
  SELECT c.data, c.mls_since INTO v_data, v_bascule
    FROM conversations c
   WHERE c.id = p_conversation_id
     AND v_uid = ANY (c.participant_ids)
     FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'marquer_lus_jusqua: pas participant' USING ERRCODE = '42501';
  END IF;

  SELECT m.created_at INTO v_borne
    FROM messages m
   WHERE m.id = p_message_id
     AND m.conversation_id = p_conversation_id;

  IF v_borne IS NULL THEN
    BEGIN
      SELECT mm.created_at INTO v_borne
        FROM mls_messages mm
       WHERE mm.id = p_message_id::uuid
         AND mm.conversation_id = p_conversation_id;
    EXCEPTION WHEN invalid_text_representation THEN
      v_borne := NULL; -- identifiant legacy non-UUID : pas un message MLS
    END;
  END IF;

  -- Une borne introuvable est une erreur, pas un « rien à faire » : sinon un
  -- identifiant faux passerait pour un succès, et le curseur n'avancerait
  -- jamais sans que personne le sache.
  IF v_borne IS NULL THEN
    RAISE EXCEPTION 'marquer_lus_jusqua: message inconnu dans cette conversation'
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE messages m
     SET data = jsonb_set(
           jsonb_set(
             jsonb_set(
               jsonb_set(
                 COALESCE(m.data, '{}'::jsonb),
                 '{readBy}',
                 CASE WHEN jsonb_typeof(m.data->'readBy') = 'array'
                      THEN m.data->'readBy' ELSE '[]'::jsonb END
                   || to_jsonb(v_uid)
               ),
               '{readAt}',
               -- `||` garde la valeur de DROITE : une heure déjà posée gagne.
               jsonb_build_object(v_uid, v_now)
                 || CASE WHEN jsonb_typeof(m.data->'readAt') = 'object'
                         THEN m.data->'readAt' ELSE '{}'::jsonb END
             ),
             '{deliveredTo}',
             CASE
               WHEN jsonb_typeof(m.data->'deliveredTo') = 'array'
                    AND (m.data->'deliveredTo') ? v_uid
                 THEN m.data->'deliveredTo'
               WHEN jsonb_typeof(m.data->'deliveredTo') = 'array'
                 THEN (m.data->'deliveredTo') || to_jsonb(v_uid)
               ELSE jsonb_build_array(v_uid)
             END
           ),
           '{deliveredAt}',
           jsonb_build_object(v_uid, v_now)
             || CASE WHEN jsonb_typeof(m.data->'deliveredAt') = 'object'
                     THEN m.data->'deliveredAt' ELSE '{}'::jsonb END
         )
   WHERE m.conversation_id = p_conversation_id
     AND m.sender_id <> v_uid
     AND m.created_at <= v_borne
     AND NOT COALESCE((m.data->'readBy') ? v_uid, FALSE);

  -- Même définition que `repere_de_lecture`, sans la borne du curseur : c'est
  -- le compte de la pastille, pas celui du séparateur.
  SELECT count(*)::INTEGER INTO v_reste
    FROM messages m
   WHERE m.conversation_id = p_conversation_id
     AND m.sender_id <> v_uid
     AND m.type IS DISTINCT FROM 'system'
     AND NOT COALESCE(m.is_deleted, FALSE)
     AND NOT COALESCE((m.data->'deletedFor') ? v_uid, FALSE)
     AND NOT COALESCE((m.data->'readBy') ? v_uid, FALSE);

  v_nouvelle := COALESCE(v_data, '{}'::jsonb);
  v_nouvelle := jsonb_set(
    v_nouvelle,
    '{unreadCount}',
    CASE WHEN jsonb_typeof(v_nouvelle->'unreadCount') = 'object'
         THEN v_nouvelle->'unreadCount' ELSE '{}'::jsonb END
      || jsonb_build_object(v_uid, v_reste)
  );

  -- « Le dernier message a été lu par… » alimente les coches de la liste chez
  -- l'expéditeur. On ne s'y ajoute que quand plus rien ne reste à lire — et
  -- jamais sur une conversation basculée, dont le dernier message est MLS :
  -- n'avoir plus de legacy à lire n'y dit rien du dernier message.
  IF v_reste = 0 AND v_bascule IS NULL THEN
    v_lecteurs := CASE WHEN jsonb_typeof(v_nouvelle->'lastMessageReadBy') = 'array'
                       THEN v_nouvelle->'lastMessageReadBy' ELSE '[]'::jsonb END;
    IF NOT v_lecteurs ? v_uid THEN
      v_nouvelle := jsonb_set(v_nouvelle, '{lastMessageReadBy}', v_lecteurs || to_jsonb(v_uid));
    END IF;
  END IF;

  IF v_nouvelle IS DISTINCT FROM COALESCE(v_data, '{}'::jsonb) THEN
    UPDATE conversations SET data = v_nouvelle WHERE id = p_conversation_id;
  END IF;

  -- Les notifications de ce qui vient d'être lu. `mark_messages_as_read` les
  -- marquait toutes ; ici, celles d'un message POSTÉRIEUR à la borne restent :
  -- il n'a pas été vu. Les réactions (`messageReaction`) portent sur mes
  -- propres messages et n'ont pas de place dans le fil d'autrui — elles
  -- partent dès qu'on regarde la discussion, comme avant.
  UPDATE notifications n
     SET is_read = TRUE
   WHERE n.user_id = v_uid
     AND NOT n.is_read
     AND n.type IN ('message', 'messageReaction')
     AND n.data->>'conversationId' = p_conversation_id
     AND NOT (
       n.type = 'message'
       AND (
         EXISTS (SELECT 1 FROM messages m
                  WHERE m.id = n.data->>'messageId'
                    AND m.created_at > v_borne)
         OR EXISTS (SELECT 1 FROM mls_messages mm
                     WHERE mm.id::TEXT = n.data->>'messageId'
                       AND mm.created_at > v_borne)
       )
     );

  RETURN v_reste;
END;
$$;

REVOKE ALL ON FUNCTION public.marquer_lus_jusqua(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.marquer_lus_jusqua(TEXT, TEXT) TO authenticated;
