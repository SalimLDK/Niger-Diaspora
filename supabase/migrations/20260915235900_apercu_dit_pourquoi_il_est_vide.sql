-- L'aperçu de la liste des discussions doit dire POURQUOI il est vide.
--
-- CE QUI MANQUAIT
-- `conversations.data->>'lastMessage'` porte le texte du dernier message **en
-- clair**. Depuis 20260915234500, la purge des messages éphémères le vide en
-- même temps qu'elle pose la pierre tombale. « Supprimer pour tout le monde »,
-- lui, ne le vidait pas : la bulle affichait « Message supprimé » et le texte
-- restait parfaitement lisible une ligne plus haut, dans la liste. Le client
-- referme ce trou (`_viderApercuSiDernier`) ; il reste à dire au client
-- LEQUEL des deux libellés afficher.
--
-- Jusqu'ici il devinait. Un aperçu vide avec un `lastMessageAt` derrière lui
-- ne pouvait venir que de la purge, donc « Message expiré » — et la seconde
-- cause l'aurait fait mentir sans que rien ne le dise. Deux marques, deux
-- libellés :
--
--   data->>'lastMessageDeleted'  → « Message supprimé »  (le client la pose)
--   data->>'lastMessageExpired'  → « Message expiré »    (la purge la pose)
--
-- ELLES S'EXCLUENT, ET TOUT ÉCRIVAIN D'APERÇU LES EFFACE
-- Poser l'une retire l'autre ; un message qui arrive ensuite retire les deux.
-- Trois écrivains d'aperçu existent, et les trois doivent le faire :
-- `_updateConversationLastMessage` (envoi legacy, côté client),
-- `mls_messages_apercu_conversation()` (trigger, ci-dessous) et
-- `purger_messages_expires()` (ci-dessous). Une marque oubliée sous un aperçu
-- neuf ferait dire « Message supprimé » à une conversation vivante, pour
-- toujours — et le cas n'a rien de théorique : une conversation legacy dont
-- le dernier message est supprimé, puis qui bascule vers MLS, passe
-- exactement par là.
--
-- AUCUNE COLONNE, AUCUN BACKFILL
-- Les deux marques vivent dans le JSONB. Leur absence vaut `false` des deux
-- côtés (`json['lastMessageDeleted'] as bool? ?? false`), donc les
-- conversations existantes se lisent inchangées : un aperçu vide sans marque
-- retombe sur le libellé neutre, ce qu'il faut pour les conversations
-- chiffrées — leur aperçu est vide par conception, le serveur n'en voyant
-- jamais le clair.

-- ── 1. Le trigger d'aperçu MLS efface les deux marques ─────────────────────
-- Seule la clause `data` change ; le reste est repris tel quel de
-- 20260915200000 (`CREATE OR REPLACE` remplace le corps entier).

CREATE OR REPLACE FUNCTION public.mls_messages_apercu_conversation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  -- Un contrôle (réaction, édition, suppression) ne remonte pas la
  -- conversation dans la liste : seul un message de contenu le fait.
  IF NEW.kind <> 'content' THEN
    RETURN NEW;
  END IF;

  UPDATE conversations c
     SET last_message_at        = NEW.created_at,
         last_message_id        = NEW.id,
         last_message_kind      = NEW.content_type,
         last_message_sender_id = NEW.sender_id,
         updated_at             = now(),
         -- `lastMessage` est RETIRÉ, pas laissé : sans ça, une conversation
         -- qui bascule garderait pour toujours l'aperçu en clair de son
         -- dernier message legacy, figé sous des messages chiffrés récents.
         --
         -- Et avec lui les deux marques qui disaient pourquoi il était vide :
         -- ce message-ci est neuf, il n'a été ni supprimé ni expiré. Une
         -- conversation dont le dernier message legacy avait été supprimé
         -- afficherait sinon « Message supprimé » sous chacun de ses messages
         -- chiffrés suivants.
         data = (COALESCE(c.data, '{}'::jsonb)
                   - 'lastMessage'
                   - 'lastMessageDeleted'
                   - 'lastMessageExpired')
                || jsonb_build_object(
                     'lastMessageSenderId', NEW.sender_id,
                     -- `content_type` est grossier par conception : le
                     -- serveur ne distingue pas une photo d'une vidéo ni
                     -- d'un document. `file` (« 📎 Document ») est le libellé
                     -- neutre ; écrire `media` tel quel tomberait en silence
                     -- sur `MessageType.text` dans le parseur Dart, et une
                     -- photo s'afficherait comme un message vide.
                     'lastMessageType', CASE NEW.content_type
                                          WHEN 'media'    THEN 'file'
                                          WHEN 'voice'    THEN 'voiceNote'
                                          WHEN 'location' THEN 'location'
                                          WHEN 'poll'     THEN 'poll'
                                          WHEN 'sticker'  THEN 'sticker'
                                          WHEN 'system'   THEN 'system'
                                          ELSE 'text'
                                        END,
                     -- Remise à zéro des reçus de l'aperçu : personne n'a
                     -- encore vu CE message. Sans elle, les deux coches
                     -- bleues du message précédent resteraient affichées.
                     'lastMessageStatus', 'sent',
                     'lastMessageReadBy', jsonb_build_array(NEW.sender_id),
                     'lastMessageDeliveredTo', jsonb_build_array(NEW.sender_id)
                   )
   WHERE c.id = NEW.conversation_id;

  RETURN NEW;
END;
$function$;

-- ── 2. La purge pose `lastMessageExpired` ──────────────────────────────────
-- Seul le CTE `apercu` change ; le reste est repris tel quel de
-- 20260915234500.

CREATE OR REPLACE FUNCTION public.purger_messages_expires()
RETURNS TABLE (legacy integer, mls integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_maintenant timestamptz := now();
  v_legacy integer := 0;
  v_mls    integer := 0;
BEGIN
  -- 1. Legacy. L'échéance est du texte dans un JSONB : le garde `~` écarte
  --    toute valeur qui n'a pas la forme ISO-8601 écrite par le client. Sans
  --    lui, une seule valeur mal formée ferait échouer le cast — donc toute
  --    la purge, pour tout le monde, en silence côté application.
  WITH expires AS (
    SELECT m.id, m.data
      FROM public.messages m
     WHERE NOT m.is_deleted
       AND m.data ? 'expiresAt'
       AND m.data->>'expiresAt' ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
       AND (m.data->>'expiresAt')::timestamptz <= v_maintenant
  ), pose AS (
    UPDATE public.messages m
       SET is_deleted = true,
           -- Mêmes champs que `deleteMessageForEveryone` côté client : le
           -- contenu, mais aussi l'aperçu de partage et la clé du média
           -- chiffré. Laisser la clé rendrait le blob Storage encore
           -- ouvrable ; laisser l'aperçu laisserait titre, extrait et URL
           -- cible en base, ce qui a déjà survécu à une suppression une fois.
           data = (e.data
                     - 'content'
                     - 'fileUrl'
                     - 'thumbnailUrl'
                     - 'encAnnexes'
                     - 'encMedia'
                     - 'postData'
                     - 'eventData'
                     - 'productData'
                     - 'linkPreviewData'
                     - 'replyToMessageData'
                     - 'audioWaveform')
                  || jsonb_build_object(
                       'content', '',
                       'deletedForEveryone', true,
                       'deletedAt', to_char(v_maintenant AT TIME ZONE 'UTC',
                                            'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
                       -- Ce qui distingue « a expiré » de « a été supprimé ».
                       'expiredAt', to_char(v_maintenant AT TIME ZONE 'UTC',
                                            'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))
      FROM expires e
     WHERE m.id = e.id
    RETURNING m.id, m.conversation_id, m.created_at
  ),
  -- L'aperçu de la liste de discussions, dans la MÊME instruction : un CTE
  -- n'existe pas au-delà d'elle.
  --
  -- `conversations.data->>'lastMessage'` porte le texte du dernier message
  -- **en clair** (c'est `_updateConversationLastMessage` qui l'y écrit).
  -- Vider la bulle sans le vider laisserait le message expiré parfaitement
  -- lisible une ligne plus haut, dans la liste des discussions — la fonction
  -- se dirait accomplie pendant que son contenu reste à l'écran.
  --
  -- `lastMessageExpired` dit POURQUOI il est vide. Sans elle, le client
  -- devinait : un aperçu vide ne pouvait venir que d'ici, donc « Message
  -- expiré » — et « supprimer pour tout le monde », qui le vide désormais
  -- aussi, l'aurait fait mentir. `lastMessageDeleted` part dans le même
  -- geste : les deux marques s'excluent.
  --
  -- `last_message_at` vient du `created_at` du message : leur égalité
  -- identifie le dernier message sans dépendre de `last_message_id`, que ce
  -- chemin d'écriture ne renseigne pas.
  derniers AS (
    SELECT conversation_id, max(created_at) AS quand
      FROM pose GROUP BY conversation_id
  ), apercu AS (
    UPDATE public.conversations c
       SET data = (c.data - 'lastMessageDeleted')
                  || jsonb_build_object('lastMessage', '',
                                        'lastMessageExpired', true)
      FROM derniers d
     WHERE c.id = d.conversation_id
       AND c.last_message_at = d.quand
    RETURNING c.id
  )
  SELECT count(*) INTO v_legacy FROM pose;

  -- 2. MLS. Le ciphertext est `NOT NULL` : on le vide plutôt que de
  --    l'annuler. Le client ne tente plus de le déchiffrer dès que
  --    `is_deleted` est vrai (cf. le garde « pierre tombale » du rattrapage),
  --    sans quoi chaque rattrapage écrirait un `decrypt_failed` de plus.
  --
  --    L'aperçu n'a rien à vider ici : le trigger d'insertion lui a déjà
  --    retiré `lastMessage`, le serveur n'ayant jamais vu le clair d'un
  --    message chiffré. C'est le cache local de l'appareil qui le porte, et
  --    c'est lui qui s'efface — `apercuDepuisCache` refuse le texte d'un
  --    message marqué supprimé.
  WITH pose AS (
    UPDATE public.mls_messages
       SET is_deleted = true,
           deleted_at = v_maintenant,
           ciphertext = '\x'::bytea
     WHERE NOT is_deleted
       AND expires_at IS NOT NULL
       AND expires_at <= v_maintenant
    RETURNING id
  )
  SELECT count(*) INTO v_mls FROM pose;

  RETURN QUERY SELECT v_legacy, v_mls;
END;
$function$;

-- Les droits ne sont pas hérités par `CREATE OR REPLACE` d'une fonction déjà
-- existante, mais les reposer ne coûte rien et vaut pour le jour où cette
-- migration sera rejouée sur une base neuve, où la fonction naîtrait ici.
REVOKE ALL ON FUNCTION public.purger_messages_expires() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purger_messages_expires() FROM anon, authenticated;
