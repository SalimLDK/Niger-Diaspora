-- Conversations : `group_id`, `created_by`, `type` et `id` ne se réécrivent
-- plus depuis le client, et les participants d'une conversation hors groupe ne
-- changent plus par écriture directe.
--
-- LE DÉFAUT
-- `conversations_guard_admin_fields` (dernière version : 20260909234500)
-- protège `participant_ids` et `data.adminIds` des conversations de groupe.
-- Sa première ligne est :
--
--     IF NEW.group_id IS NULL THEN RETURN NEW; END IF;
--
-- et `group_id` est lui-même une colonne que la policy `conversations_update`
-- (« être participant », 20260715120000) laisse réécrire. Un simple membre
-- d'un groupe passait donc la garde en deux UPDATE :
--
--   1. SET group_id = NULL, participant_ids = <ce qu'il veut>,
--          data = jsonb_set(data, '{adminIds}', '["moi"]')   -- garde sautée
--   2. SET group_id = '<l'ancien>'                           -- rien ne change
--                                                            -- dans les champs
--                                                            -- gardés : passe
--
-- et il était administrateur de la discussion, libre d'exclure n'importe qui.
--
-- Deux autres portes, sans même passer par `group_id` :
--   · `created_by` n'est gardé par rien, et c'est lui que lit la policy
--     `conversations_delete`. `SET created_by = moi` puis `DELETE` : la
--     conversation et, par la cascade de 20260806220000, TOUT son historique
--     disparaissent pour tous les participants ;
--   · hors groupe (1:1, demande, « Mes notes »), `group_id` est NULL pour de
--     bon : la garde sort dès sa première ligne, et n'importe quel participant
--     peut AJOUTER un tiers à `participant_ids`. Le tiers lit alors tout
--     l'historique (`messages_select` ne regarde que `participant_ids`) et
--     obtient la clé AES de la conversation par `crypto-keys`.
--
-- LE CORRECTIF
-- Un déclencheur distinct, SECURITY INVOKER, sur le modèle exact de
-- `guard_group_members_role` (20260917010000) : il ne s'applique qu'aux
-- écritures directes, `current_user IN ('authenticated', 'anon')`. Les RPC
-- SECURITY DEFINER (join_group_conversation, retrait de groupe, suppression
-- de compte par phases, notices de groupe…) s'exécutent sous leur
-- propriétaire et ne sont pas concernées — elles portent leurs propres gardes.
--
-- Pourquoi pas dans `conversations_guard_admin_fields` : elle est SECURITY
-- DEFINER, `current_user` y vaut toujours son propriétaire ; elle ne peut pas
-- distinguer le client d'une RPC.
--
-- CE QUE LE CLIENT ÉCRIT RÉELLEMENT (relevé dans lib/ le 2026-10-03) :
-- `data`, `last_message_at`, `participant_ids` (exclusion dans un groupe —
-- gardée par conversations_guard_admin_fields, inchangée), `mls_since`,
-- `mls_group_info`. Jamais `id`, `type`, `group_id` ni `created_by` : aucune
-- fonctionnalité ne perd rien. Une demande de message acceptée garde
-- `type = 'request'` (message_supabase_datasource, recherche
-- `inFilter('type', ['individual', 'request'])`), elle ne le réécrit pas.
--
-- Banc : tools/rls_tests/conversations_colonnes_figees.sql

CREATE OR REPLACE FUNCTION public.guard_conversations_colonnes_figees()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Une RPC SECURITY DEFINER écrit sous son propriétaire : pas concernée.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.type IS DISTINCT FROM OLD.type
     OR NEW.group_id IS DISTINCT FROM OLD.group_id
     OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION
      'id, type, group_id et created_by d''une conversation ne se réécrivent pas'
      USING ERRCODE = '42501';
  END IF;

  -- Conversation de groupe : `participant_ids` est l'affaire de
  -- conversations_guard_admin_fields (exclusion par un admin, départ,
  -- rattachement d'un membre). `group_id` étant désormais figé, elle ne peut
  -- plus être sautée.
  IF NEW.group_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Hors groupe : `participant_ids` ne bouge plus par écriture directe.
  -- Pas d'exception « se retirer soi-même » : `conversations_update` n'a pas
  -- de WITH CHECK, son USING (« être participant ») s'applique donc aussi à
  -- la NOUVELLE ligne, et la RLS refuse déjà qu'on s'en retire. La
  -- suppression de compte passe par le serveur (20260918224100).
  IF NEW.participant_ids IS DISTINCT FROM OLD.participant_ids THEN
    RAISE EXCEPTION
      'Hors groupe, les participants d''une conversation ne changent pas par écriture directe'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_conversations_colonnes_figees() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS conversations_colonnes_figees ON public.conversations;
CREATE TRIGGER conversations_colonnes_figees
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_conversations_colonnes_figees();
