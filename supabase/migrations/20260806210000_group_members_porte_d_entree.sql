-- Adhesion : n'importe qui pouvait s'inscrire dans n'importe quel groupe.
--
-- `group_members_own` est une policy FOR ALL dont le USING vaut
-- `firebase_uid() = user_id`, sans WITH CHECK explicite -- la meme expression
-- sert donc au controle d'insertion. Elle verifie qu'on s'inscrit *soi-meme*,
-- et rien d'autre : ni le groupe, ni une invitation, ni une approbation.
--
-- Consequence, mesuree le 2026-08-06 sous une vraie identite : l'insertion
-- d'une ligne d'appartenance est acceptee pour un groupe **inexistant**
-- (`group_members.group_id` n'a d'ailleurs aucune cle etrangere -- 7 lignes
-- orphelines dorment deja dans la table). A fortiori pour un groupe prive dont
-- on n'a jamais recu d'invitation : il suffit d'en connaitre l'uuid et
-- d'appeler l'API directement. Les uuid des groupes prives ne sont pas listes,
-- mais c'est de l'obscurite, pas un controle.
--
-- On ferme l'INSERT sans toucher au reste. Une policy RESTRICTIVE s'ajoute en
-- ET aux permissives, et `FOR INSERT` la limite a la seule creation de ligne :
--
--   * SELECT / UPDATE / DELETE gardent `group_members_own` tel quel -- quitter
--     un groupe prive reste possible, ce qu'une condition sur l'invitation
--     aurait casse ;
--   * les chemins legitimes d'insertion restent ouverts :
--       - rejoindre un groupe **public** (`joinGroup`) -> is_group_public ;
--       - accepter une **invitation** (`acceptGroupInvite`) -> has_group_invite ;
--       - creation de groupe (`insert_group`) et approbation d'une demande
--         (`approve_group_request`) sont SECURITY DEFINER, donc hors RLS.
--
-- Le test d'invitation passe par une fonction SECURITY DEFINER plutot que par
-- un EXISTS inline : lire `group_invites` depuis une policy de `group_members`
-- ferait evaluer les policies de `group_invites`, dont l'une appelle
-- `is_group_admin`, qui relit `group_members`. C'est exactement la recursion
-- que 20260804120000 a deja du defaire sur `groups`. Une fonction definer
-- coupe la chaine, comme `is_group_member` et `is_group_public` le font deja.

CREATE OR REPLACE FUNCTION public.has_group_invite(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_invites i
     WHERE i.group_id = p_group_id
       AND i.invitee_id = (SELECT firebase_uid())
  )
$$;

REVOKE ALL ON FUNCTION public.has_group_invite(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_group_invite(uuid) TO authenticated;

DROP POLICY IF EXISTS group_members_insert_gate ON public.group_members;
CREATE POLICY group_members_insert_gate ON public.group_members
  AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (
    public.is_group_public(group_members.group_id)
    OR public.has_group_invite(group_members.group_id)
  );
