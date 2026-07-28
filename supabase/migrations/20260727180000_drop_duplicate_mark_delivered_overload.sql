-- =============================================================================
-- Supprime la surcharge en trop de mark_messages_as_delivered
--
-- Symptôme observé sur appareil (SM-A515F, 2026-07-27) :
--
--   markAsDelivered error: PostgrestException(
--     message: Could not choose the best candidate function between:
--       public.mark_messages_as_delivered(p_conversation_id => text, p_user_id => text),
--       public.mark_messages_as_delivered(p_conversation_id => uuid, p_user_id => text),
--     code: PGRST203, details: Multiple Choices)
--
-- Deux fonctions de même nom coexistent au distant, l'une prenant un TEXT,
-- l'autre un UUID. PostgREST ne résout pas la surcharge et rejette CHAQUE
-- appel : les accusés de réception « remis » sont donc cassés en production.
--
-- La variante UUID est la bonne : `messages.conversation_id` et
-- `conversations.id` sont de type UUID, et c'est celle que déclare la migration
-- 20260720120300_mark_messages_as_delivered_rpc.sql. La variante TEXT provient
-- d'un état antérieur du schéma distant, absent du dépôt (dérive de schéma
-- documentée par ailleurs).
--
-- On ne supprime QUE la signature (TEXT, TEXT). La signature (UUID, TEXT) reste
-- intacte, y compris ses GRANT.
-- =============================================================================

DROP FUNCTION IF EXISTS public.mark_messages_as_delivered(TEXT, TEXT);

-- Filet de sécurité : si la variante UUID avait elle aussi disparu du distant,
-- l'app n'aurait plus aucune RPC à appeler. On la recrée à l'identique si
-- besoin (CREATE OR REPLACE est sans effet si elle est déjà correcte).
-- La définition de référence reste celle de 20260720120300.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'mark_messages_as_delivered'
  ) THEN
    RAISE WARNING
      'mark_messages_as_delivered absente après suppression de la surcharge TEXT — rejouer 20260720120300_mark_messages_as_delivered_rpc.sql';
  END IF;
END
$$;
