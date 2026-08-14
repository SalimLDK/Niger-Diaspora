-- Trouvé en testant le trigger précédent : leaveGroup() (group_supabase_datasource.dart:343)
-- ne supprime que la ligne group_members -- ne touche jamais
-- conversations.participant_ids. Un membre qui quitte un groupe restait donc
-- participant de sa conversation indéfiniment, avec accès en lecture aux
-- messages envoyés après son départ (conversations_select se fie à
-- participant_ids).
--
-- Un simple UPDATE côté client échoue de toute façon : conversations_update
-- n'a pas de WITH CHECK explicite, donc Postgres réutilise USING
-- (participant_ids @> [firebase_uid()]) comme WITH CHECK -- qui exige que
-- l'appelant reste dans participant_ids APRÈS l'update. Un départ volontaire
-- (qui retire justement l'appelant) est donc rejeté par la policy elle-même,
-- avant même d'atteindre conversations_guard_admin_fields_trigger.
--
-- Plutôt que d'assouplir conversations_update (risque d'ouvrir une case plus
-- large, ex. ajouter n'importe qui à participant_ids), une RPC SECURITY
-- DEFINER dédiée : elle s'exécute avec les privilèges de son propriétaire et
-- n'est donc pas soumise à conversations_update, mais reste soumise à
-- conversations_guard_admin_fields_trigger (attaché à la TABLE, pas à la
-- policy) -- qui autorise déjà explicitement ce cas précis (un participant
-- qui ne retire que lui-même de participant_ids et d'adminIds).
--
-- N'agit que sur firebase_uid() (l'appelant authentifié), jamais sur un
-- userId fourni par le client : leaveGroup() n'est appelé qu'avec
-- currentUser.id à tous ses points d'entrée actuels (groups_screen.dart,
-- group_detail_screen.dart) -- ce choix empêche par construction qu'elle
-- serve un jour à retirer quelqu'un d'autre.

CREATE OR REPLACE FUNCTION public.leave_group_conversation(p_group_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := firebase_uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE = '42501';
  END IF;

  UPDATE conversations
  SET participant_ids = array_remove(participant_ids, v_caller),
      data = jsonb_set(
        COALESCE(data, '{}'::jsonb),
        '{adminIds}',
        COALESCE(
          (
            SELECT jsonb_agg(v)
            FROM jsonb_array_elements_text(COALESCE(data->'adminIds', '[]'::jsonb)) v
            WHERE v <> v_caller
          ),
          '[]'::jsonb
        )
      )
  WHERE group_id = p_group_id
    AND participant_ids @> ARRAY[v_caller];
END;
$$;

REVOKE ALL ON FUNCTION public.leave_group_conversation(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.leave_group_conversation(text) TO authenticated;
