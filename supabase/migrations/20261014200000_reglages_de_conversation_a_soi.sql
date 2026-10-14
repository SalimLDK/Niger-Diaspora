-- Ses réglages d'une conversation n'appartiennent qu'à soi.
--
-- Audit des notifications du 2026-10-14, constat n° 7. `conversations.data`
-- porte quatre cartes indexées par participant — `mutedBy`, `pinnedBy`,
-- `archivedBy`, `deletedBy` — et tout participant peut écrire `data` (policy
-- `conversations_update` ; `conversations_guard_admin_fields` laisse passer
-- ces clés, et `fusionner_donnees_conversation` en fait un appel unique).
--
-- N'importe quel participant pouvait donc poser `mutedBy.<autre> = forever` :
-- chaque déclencheur de message, de réaction, d'édition consulte
-- `is_conversation_muted_for` et sautait la victime — plus aucune
-- notification de cette conversation, sans qu'elle ait rien touché. Et
-- `deletedBy.<autre>` lui faisait disparaître la conversation.
--
-- Désormais, depuis le client (`authenticated`, `anon`), seule l'entrée de
-- l'appelant change dans ces quatre cartes ; celles des autres sont remises
-- telles qu'elles étaient. Remises, pas refusées : les versions installées
-- réécrivent encore `data` en entier après l'avoir lu, et un réglage posé par
-- un autre participant entre leur lecture et leur écriture ne doit pas faire
-- échouer leur propre bascule — ni être effacé par elle.
--
-- PAS SECURITY DEFINER : la garde lit `current_user`, qui deviendrait le
-- propriétaire de la fonction. Les fonctions serveur (SECURITY DEFINER) ne
-- sont pas concernées.
--
-- Banc : tools/rls_tests/reglages_de_conversation_a_soi.sql

CREATE OR REPLACE FUNCTION private.reglages_de_conversation_a_soi()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    text;
  v_cle    text;
  v_avant  jsonb;
  v_apres  jsonb;
  v_retenu jsonb;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.data IS NOT DISTINCT FROM OLD.data THEN
    RETURN NEW;
  END IF;

  v_uid := COALESCE((SELECT public.firebase_uid()), '');

  FOREACH v_cle IN ARRAY ARRAY['mutedBy', 'pinnedBy', 'archivedBy', 'deletedBy'] LOOP
    v_avant := CASE WHEN jsonb_typeof(OLD.data -> v_cle) = 'object'
                    THEN OLD.data -> v_cle ELSE '{}'::jsonb END;
    v_apres := CASE WHEN jsonb_typeof(NEW.data -> v_cle) = 'object'
                    THEN NEW.data -> v_cle ELSE '{}'::jsonb END;

    -- Les entrées des autres, telles qu'avant ; la sienne, telle que voulue.
    v_retenu := (v_avant - v_uid)
             || CASE WHEN v_apres ? v_uid
                     THEN jsonb_build_object(v_uid, v_apres -> v_uid)
                     ELSE '{}'::jsonb END;

    IF v_retenu IS DISTINCT FROM v_apres THEN
      NEW.data := jsonb_set(COALESCE(NEW.data, '{}'::jsonb), ARRAY[v_cle], v_retenu);
    END IF;
  END LOOP;

  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION private.reglages_de_conversation_a_soi() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_reglages_de_conversation_a_soi ON public.conversations;
CREATE TRIGGER trg_reglages_de_conversation_a_soi
  BEFORE UPDATE OF data ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION private.reglages_de_conversation_a_soi();
