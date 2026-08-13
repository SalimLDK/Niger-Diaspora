-- Groupe prive : un membre ne voyait que sa propre ligne d'appartenance.
--
-- `group_members_select` valait :
--
--   USING (firebase_uid() = user_id OR is_group_public(group_id))
--
-- Dans un groupe **prive**, aucune des deux branches ne couvre les autres
-- membres. `_membershipFor` (group_supabase_datasource.dart:41) reconstruit
-- `member_ids` et `admin_ids` a partir de cette table, et `GroupEntity`
-- derive `memberCount` de `memberIds.length` : un groupe prive de cinq
-- personnes s'affichait donc « 1 membre » pour chacune d'elles, et la liste
-- des membres ne montrait que soi-meme.
--
-- Le defaut etait invisible jusqu'ici parce que les deux groupes prives de la
-- base n'ont qu'un membre chacun. Il devient observable des qu'un second
-- membre arrive -- c'est-a-dire des que l'approbation des demandes d'adhesion
-- fonctionne (20260806180000). Les deux se corrigent donc ensemble.
--
-- `is_group_member` est deja l'idiome retenu sur la table `groups`
-- (`groups_select_public` : NOT is_private OR creator OR is_group_member(id)).
-- Pas de recursion : la fonction est SECURITY DEFINER, appartient au
-- proprietaire de la table, et `group_members` n'a pas FORCE ROW LEVEL
-- SECURITY -- la lecture qu'elle fait n'est donc pas re-filtree par la policy
-- qui l'appelle. C'est le meme montage que celui deja en place sur `groups`
-- depuis 20260804120000.

-- `ALTER` plutot que `DROP` + `CREATE` : la policy est remplacee d'un bloc,
-- sans la fenetre ou la table n'a plus de policy de lecture.
ALTER POLICY group_members_select ON public.group_members
  USING (
    (SELECT public.firebase_uid()) = user_id
    OR public.is_group_public(group_id)
    OR public.is_group_member(group_id)
  );
