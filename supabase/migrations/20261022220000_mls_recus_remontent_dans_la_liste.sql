-- La liste des discussions (/messages) n'affichait jamais « livré » pour une
-- conversation MLS tant que le destinataire n'avait pas ouvert la discussion.
--
-- La tuile lit `conversations.data.lastMessageDeliveredTo` / `lastMessageReadBy`.
-- Pour MLS, le déclencheur d'aperçu (`mls_messages_apercu_conversation`) les
-- remet à `[expéditeur]` à chaque message, mais rien ne les alimentait ensuite
-- hormis l'ouverture de la discussion côté destinataire (écriture client de
-- toute la ligne `data`). Le reçu posé à l'arrivée du push, lui, ne va que dans
-- `mls_message_receipts` : la tuile restait sur une coche simple.
--
-- Le déclencheur ci-dessous fait remonter chaque reçu dans la conversation, en
-- base et dans la même transaction que le reçu — pas de lecture-puis-écriture
-- depuis le client, donc pas de course avec le déclencheur d'aperçu. Seul le
-- DERNIER message de la conversation compte : un reçu sur un message plus
-- ancien ne doit pas faire passer la tuile à « livré ».

CREATE OR REPLACE FUNCTION public.mls_recus_apercu_conversation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_conv text;
BEGIN
  SELECT m.conversation_id INTO v_conv
    FROM mls_messages m
   WHERE m.id = NEW.message_id;

  IF v_conv IS NULL THEN
    RETURN NEW;
  END IF;

  -- `||` garde la valeur de droite : l'union est faite ici, en ne touchant que
  -- les clés concernées, et une valeur déjà présente n'est pas dupliquée.
  UPDATE conversations c
     SET data = COALESCE(c.data, '{}'::jsonb)
       || CASE
            WHEN NEW.delivered_at IS NOT NULL
             AND NOT (COALESCE(c.data->'lastMessageDeliveredTo', '[]'::jsonb) ? NEW.user_id)
            THEN jsonb_build_object(
                   'lastMessageDeliveredTo',
                   COALESCE(c.data->'lastMessageDeliveredTo', '[]'::jsonb) || to_jsonb(NEW.user_id))
            ELSE '{}'::jsonb
          END
       || CASE
            WHEN NEW.read_at IS NOT NULL
             AND NOT (COALESCE(c.data->'lastMessageReadBy', '[]'::jsonb) ? NEW.user_id)
            THEN jsonb_build_object(
                   'lastMessageReadBy',
                   COALESCE(c.data->'lastMessageReadBy', '[]'::jsonb) || to_jsonb(NEW.user_id))
            ELSE '{}'::jsonb
          END
   WHERE c.id = v_conv
     AND c.last_message_id = NEW.message_id
     -- Rien à écrire : pas de réécriture ni d'événement temps réel pour rien.
     AND (
          (NEW.delivered_at IS NOT NULL
             AND NOT (COALESCE(c.data->'lastMessageDeliveredTo', '[]'::jsonb) ? NEW.user_id))
       OR (NEW.read_at IS NOT NULL
             AND NOT (COALESCE(c.data->'lastMessageReadBy', '[]'::jsonb) ? NEW.user_id))
     );

  RETURN NEW;
END;
$function$;

-- Une fonction de déclencheur n'a pas à être appelable : ni par l'API, ni par
-- personne. (Le `GRANT ALL` par défaut de Supabase ne s'applique pas aux
-- fonctions, mais EXECUTE est accordé à PUBLIC à la création.)
REVOKE ALL ON FUNCTION public.mls_recus_apercu_conversation() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS mls_message_receipts_apercu_conversation_trg ON public.mls_message_receipts;
CREATE TRIGGER mls_message_receipts_apercu_conversation_trg
  AFTER INSERT OR UPDATE OF delivered_at, read_at ON public.mls_message_receipts
  FOR EACH ROW
  EXECUTE FUNCTION public.mls_recus_apercu_conversation();
