-- Une bannière de message suit ce que devient le message : retirée à la
-- suppression, corrigée à l'édition — même quand sa notification est lue.
--
-- Constaté le 2026-09-21 à deux téléphones (build 1.2.2+26, 1:1 MLS) :
--
-- 1. « Supprimer pour tous » laissait le texte dans la bannière empilée du
--    destinataire (« PA6SECRET » lisible dans le volet Android). La suppression
--    n'est qu'un UPDATE de `mls_messages` : aucun push ne partait, l'appareil
--    n'apprenait jamais qu'il devait retirer la ligne. Même chose à
--    l'expiration d'un message éphémère (ciphertext vidé).
-- 2. Une édition ne corrigeait pas la bannière dès que la notification du
--    message était LUE — alors que la pile de l'appareil, elle, garde ses
--    lignes 24 h (`PileMessagesNotifiees.duree`). Vu : « PA2 » d'avant
--    l'édition resté dans la bannière.
--
-- Les deux signaux sont des lignes `notifications` écrites `is_read = TRUE` :
-- `send-push` les envoie en data-only (aucune alerte), l'appareil corrige sa
-- pile, et l'écran Notifications ne les affiche pas. Le client ne crée
-- JAMAIS de bannière sur ces signaux : un message absent de sa pile est
-- ignoré — c'est ce qui rend l'élargissement du garde sans risque.
--
-- `db push` ne pose pas de transaction autour du fichier : elle est écrite ici.

BEGIN;

-- 24 h, comme la pile de l'appareil. Lue ou non : la lecture sur un autre
-- appareil ne vide pas forcément la pile de celui-ci.
CREATE OR REPLACE FUNCTION private.a_eu_une_banniere_recente(
  p_user_id text,
  p_conversation_id text
)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM notifications n
     WHERE n.user_id = p_user_id
       AND n.type = 'message'
       AND n.data->>'conversationId' = p_conversation_id
       AND n.created_at > now() - interval '24 hours'
  );
$function$;

REVOKE ALL ON FUNCTION private.a_eu_une_banniere_recente(text, text)
  FROM PUBLIC, anon, authenticated;

-- Le retrait : un signal par destinataire qui a reçu CE message en push
-- depuis 24 h. Identifiants seulement — rien de chiffré, rien à lire.
CREATE OR REPLACE FUNCTION private.mls_notifier_suppression(
  p_message_id uuid,
  p_conversation_id text,
  p_sender_id text
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_n RECORD;
BEGIN
  FOR v_n IN
    SELECT DISTINCT ON (n.user_id) n.user_id, n.data
      FROM notifications n
     WHERE n.type = 'message'
       AND n.data->>'messageId' = p_message_id::text
       AND n.created_at > now() - interval '24 hours'
       AND n.user_id IS DISTINCT FROM p_sender_id
     ORDER BY n.user_id, n.created_at DESC
  LOOP
    INSERT INTO notifications (user_id, type, title, body, data, is_read)
    VALUES (
      v_n.user_id, 'messageDeleted', '', '',
      jsonb_build_object(
        'type',              'messageDeleted',
        'protocol',          'mls',
        'conversationId',    p_conversation_id,
        'targetId',          p_conversation_id,
        'target_id',         p_conversation_id,
        'messageId',         p_message_id::text,
        'senderId',          p_sender_id,
        'senderName',        v_n.data->>'senderName',
        'conversationType',  v_n.data->>'conversationType',
        'conversationTitle', v_n.data->>'conversationTitle',
        'isE2EE',            'true',
        'actor_id',          p_sender_id
      ),
      TRUE
    );
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  -- Jamais au prix de la suppression elle-même.
  RAISE WARNING 'mls_notifier_suppression: %', SQLERRM;
END;
$function$;

REVOKE ALL ON FUNCTION private.mls_notifier_suppression(uuid, text, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.trg_mls_notifications_message_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_supprime BOOLEAN;
  v_vide     BOOLEAN;
  v_edite    BOOLEAN;
BEGIN
  v_supprime := COALESCE(NEW.is_deleted, FALSE) AND NOT COALESCE(OLD.is_deleted, FALSE);
  v_vide     := octet_length(NEW.ciphertext) = 0 AND octet_length(OLD.ciphertext) > 0;
  v_edite    := NEW.edited_at IS NOT NULL AND NEW.edited_at IS DISTINCT FROM OLD.edited_at;

  IF v_supprime OR v_vide THEN
    -- AVANT l'oubli : il marque lues les notifications de ce message, et ce
    -- sont elles qui disent à qui une bannière a été posée. Dans son propre
    -- bloc : un échec du signal ne doit JAMAIS empêcher l'oubli de la copie
    -- chiffrée, qui est la garantie d'origine de ce déclencheur.
    BEGIN
      PERFORM private.mls_notifier_suppression(NEW.id, NEW.conversation_id, NEW.sender_id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'trg_mls_notifications_message_change (signal): %', SQLERRM;
    END;
    PERFORM private.mls_notifications_oublier(ARRAY[NEW.id::text]);
  ELSIF v_edite THEN
    -- La copie porte le texte d'avant la correction : elle part. La
    -- notification, elle, reste non lue si elle l'était.
    PERFORM private.mls_notifications_oublier(ARRAY[NEW.id::text], FALSE);
  END IF;

  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_mls_notifications_message_change: %', SQLERRM;
  RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.mls_notifier_controle()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_conv           RECORD;
  v_participant_id TEXT;
  v_muted_by       JSONB;
  v_data           JSONB;
  v_conv_type      TEXT;
  v_conv_titre     TEXT;
  v_nom            TEXT;
BEGIN
  IF NEW.kind <> 'control' THEN
    RETURN NULL;
  END IF;

  -- Au-delà, le ciphertext ne tient pas dans le plafond FCM : l'appareil ne
  -- pourra pas lire la correction, inutile de le réveiller pour rien.
  IF octet_length(NEW.ciphertext) > 2500 THEN
    RETURN NULL;
  END IF;

  SELECT c.id, c.type, c.participant_ids, COALESCE(c.data, '{}'::jsonb) AS data
    INTO v_conv
    FROM conversations c
   WHERE c.id = NEW.conversation_id;
  IF NOT FOUND OR v_conv.participant_ids IS NULL THEN
    RETURN NULL;
  END IF;

  v_muted_by   := COALESCE(v_conv.data->'mutedBy', '{}'::jsonb);
  v_conv_type  := COALESCE(v_conv.type, 'individual');
  v_conv_titre := COALESCE(NULLIF(v_conv.data->>'name', ''),
                           NULLIF(v_conv.data->>'title', ''), 'Groupe');
  v_nom := COALESCE((SELECT display_name FROM users WHERE id = NEW.sender_id),
                    'Un utilisateur');

  v_data := jsonb_build_object(
    'type',              'messageEdited',
    'protocol',          'mls',
    'targetId',          NEW.conversation_id,
    'target_id',         NEW.conversation_id,
    'conversationId',    NEW.conversation_id,
    -- L'identifiant du CONTRÔLE, pas du message corrigé : c'est lui qui entre
    -- dans l'AAD, et le message corrigé est nommé dans la charge chiffrée.
    'messageId',         NEW.id::text,
    'senderId',          NEW.sender_id,
    'senderName',        v_nom,
    'conversationType',  v_conv_type,
    'conversationTitle', CASE WHEN v_conv_type = 'group' THEN v_conv_titre
                              ELSE v_nom END,
    'mlsEpoch',          NEW.epoch::text,
    'mlsSenderDeviceId', NEW.sender_device_id::text,
    'mlsKind',           NEW.kind,
    'mlsCiphertext',     encode(NEW.ciphertext, 'base64'),
    'sentAt',            (extract(epoch from NEW.created_at) * 1000)::bigint::text,
    'isE2EE',            'true',
    'actor_id',          NEW.sender_id
  );

  FOREACH v_participant_id IN ARRAY v_conv.participant_ids
  LOOP
    CONTINUE WHEN v_participant_id IS NULL
               OR v_participant_id = ''
               OR v_participant_id = NEW.sender_id;
    CONTINUE WHEN public.is_conversation_muted_for(v_muted_by, v_participant_id);
    CONTINUE WHEN NOT EXISTS (SELECT 1 FROM users WHERE id = v_participant_id);
    -- Bannière envoyée depuis 24 h, lue ou non : la pile de l'appareil la
    -- garde tout ce temps (voir la tête de ce fichier).
    CONTINUE WHEN NOT private.a_eu_une_banniere_recente(
                    v_participant_id, NEW.conversation_id);

    INSERT INTO notifications (user_id, type, title, body, data, is_read)
    VALUES (v_participant_id, 'messageEdited', '', '', v_data, TRUE);
  END LOOP;

  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'mls_notifier_controle: %', SQLERRM;
  RETURN NULL;
END;
$function$;

COMMIT;
