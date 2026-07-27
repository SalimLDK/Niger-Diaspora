-- ============================================================================
-- Correctif : un membre qui rejoint un groupe APRÈS la création de sa
-- conversation n'était jamais ajouté à conversations.participant_ids (joinGroup
-- n'écrit que dans group_members). Résultat : le groupe restait absent de son
-- onglet Messages, et findGroupConversationByGroupId (qui filtrait par
-- participant_ids) ne retrouvait jamais la conversation existante — recréant
-- parfois un doublon via createGroupConversation.
--
-- conversations_update exige déjà d'être participant
-- (participant_ids @> ARRAY[...]) : un nouveau membre ne peut donc pas
-- s'auto-ajouter par une UPDATE normale (RLS bloque la ligne avant même
-- d'atteindre la condition). D'où ce RPC SECURITY DEFINER, qui vérifie
-- l'appartenance réelle au groupe (group_members) avant d'agir.
--
-- NB : au moment de cette migration, les groupes (Firestore) ne sont pas
-- encore migrés vers Supabase — group_members n'est donc pas encore alimenté
-- par joinGroup. Cette fonction est écrite pour l'architecture cible (déjà
-- utilisée par messages/conversations) : tant que la migration groupes n'est
-- pas terminée, elle se dégrade proprement en no-op (retourne NULL) plutôt
-- que d'échouer.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.join_group_conversation(p_group_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid TEXT := current_user_id();
  v_conv_id TEXT;
  v_participants TEXT[];
  v_data JSONB;
  v_unread JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  -- Le bypass RLS de SECURITY DEFINER n'accorde rien sans cette vérification :
  -- seul un membre réel du groupe peut être ajouté à sa conversation.
  -- group_members.group_id est UUID alors que conversations.group_id (et donc
  -- p_group_id) est TEXT : cast explicite requis, sinon erreur de type.
  IF NOT EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = p_group_id::uuid AND gm.user_id = v_uid
  ) THEN
    RETURN NULL;
  END IF;

  SELECT id, participant_ids, data INTO v_conv_id, v_participants, v_data
  FROM public.conversations
  WHERE type = 'group' AND group_id = p_group_id
  LIMIT 1;

  IF v_conv_id IS NULL THEN
    RETURN NULL;
  END IF;

  IF NOT (v_uid = ANY(v_participants)) THEN
    v_unread := COALESCE(v_data->'unreadCount', '{}'::jsonb)
      || jsonb_build_object(v_uid, 0);
    v_data := COALESCE(v_data, '{}'::jsonb) || jsonb_build_object('unreadCount', v_unread);

    UPDATE public.conversations
    SET participant_ids = array_append(participant_ids, v_uid),
        data = v_data
    WHERE id = v_conv_id;
  END IF;

  RETURN v_conv_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_group_conversation(TEXT) TO authenticated;
