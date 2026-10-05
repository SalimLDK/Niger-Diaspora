-- Message en clair supprimé pour tous, ou expiré : sa notification ne garde
-- plus son texte, et la bannière de l'appareil se retire.
--
-- LE DÉFAUT (audit du 2026-10-03, P2 notifications)
-- `trg_notifications_message_masque` (20260912200000) se contentait de
-- marquer LUES les notifications du message. Leur `body` — « Alice: le texte
-- du message », en clair — restait en base et dans l'écran Notifications, qui
-- affiche aussi les notifications lues ; leurs charges chiffrées
-- (`e2eePayloads`…) aussi. Et l'appareil n'apprenait jamais qu'il devait
-- retirer la ligne de sa bannière : le texte supprimé restait lisible dans le
-- volet Android. Le transport MLS a reçu ces deux garanties le 2026-09-21
-- (20260921230000) ; le transport en clair, non.
--
-- LE CORRECTIF
-- À la suppression (transition de `is_deleted`, que posent aussi bien
-- « supprimer pour tout le monde » que `purger_messages_expires`) :
--   1. un signal `messageDeleted` à chaque destinataire qui a reçu CE message
--      en push depuis 24 h — même forme que le signal MLS, identifiants
--      seulement, `is_read = TRUE` donc data-only ; le client le traite
--      quel que soit le transport (`_retirerDeLaBanniereApresSuppression`) ;
--   2. les notifications du message perdent leur texte (« Message supprimé »)
--      et leurs charges chiffrées, et sont marquées lues.
-- Le signal part AVANT l'effacement : ce sont les notifications d'origine
-- qui disent à qui une bannière a été posée.
--
-- Banc : tools/rls_tests/notification_suit_le_message_clair_supprime.sql

CREATE OR REPLACE FUNCTION private.trg_notifications_message_masque()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_n RECORD;
BEGIN
  IF NOT (COALESCE(NEW.is_deleted, FALSE) AND NOT COALESCE(OLD.is_deleted, FALSE)) THEN
    RETURN NULL;
  END IF;

  -- 1. Le signal de retrait. Dans son propre bloc : un échec ne doit jamais
  --    empêcher l'effacement du texte, qui est la garantie de fond.
  BEGIN
    FOR v_n IN
      SELECT DISTINCT ON (n.user_id) n.user_id, n.data
        FROM notifications n
       WHERE n.type = 'message'
         AND n.data->>'messageId' = NEW.id
         AND n.created_at > now() - interval '24 hours'
         AND n.user_id IS DISTINCT FROM NEW.sender_id
       ORDER BY n.user_id, n.created_at DESC
    LOOP
      INSERT INTO notifications (user_id, type, title, body, data, is_read)
      VALUES (
        v_n.user_id, 'messageDeleted', '', '',
        jsonb_build_object(
          'type',              'messageDeleted',
          'conversationId',    NEW.conversation_id,
          'targetId',          NEW.conversation_id,
          'target_id',         NEW.conversation_id,
          'messageId',         NEW.id,
          'senderId',          NEW.sender_id,
          'senderName',        v_n.data->>'senderName',
          'conversationType',  v_n.data->>'conversationType',
          'conversationTitle', v_n.data->>'conversationTitle',
          'actor_id',          NEW.sender_id
        ),
        TRUE
      );
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'trg_notifications_message_masque (signal): %', SQLERRM;
  END;

  -- 2. Plus de texte ni de charge chiffrée, et lues.
  UPDATE notifications n
     SET is_read = TRUE,
         body = CASE WHEN n.type = 'message' THEN 'Message supprimé' ELSE n.body END,
         data = n.data - ARRAY['e2eePayloads', 'e2eePayload', 'senderKeyPayload']
   WHERE n.data->>'messageId' = NEW.id
     AND n.type IN ('message', 'messageMention');

  -- Les autres notifications qui désignent ce message (réactions…) : lues,
  -- comme avant. Elles ne portent pas de contenu (`libelle_message_reagi`).
  PERFORM private.lire_notifications_de_cible(NEW.id, ARRAY['messageId']);

  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_notifications_message_masque: %', SQLERRM;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_notifications_message_masque()
  FROM PUBLIC, anon, authenticated;

-- Le déclencheur existe (20260912200000) ; le reposer rend la migration
-- complète à elle seule.
DROP TRIGGER IF EXISTS trg_notifications_message_masque ON public.messages;
CREATE TRIGGER trg_notifications_message_masque
  AFTER UPDATE OF is_deleted ON public.messages
  FOR EACH ROW EXECUTE FUNCTION private.trg_notifications_message_masque();
