-- Invitations : la porte d'entree de `group_members` avait une porte laterale.
--
-- 20260806210000 a ferme l'inscription directe dans un groupe prive avec une
-- policy RESTRICTIVE : on n'insere une ligne `group_members` que si le groupe
-- est public, ou si `has_group_invite()` trouve une invitation a son nom.
--
-- Mais rien n'encadrait la creation de cette invitation. `group_invites_own`
-- est une policy FOR ALL dont le WITH CHECK vaut
-- `firebase_uid() = inviter_id OR firebase_uid() = invitee_id` : le second
-- terme autorise n'importe qui a INSERER une invitation **dont il est
-- lui-meme le destinataire**, pour n'importe quel groupe. Le controle
-- d'adhesion se contourne donc en deux appels d'API :
--
--   1. INSERT group_invites (group_id = <groupe prive>, invitee_id = moi)
--   2. INSERT group_members (group_id = <groupe prive>, user_id = moi)
--
-- Verifie le 2026-09-09 sous une identite reelle non membre, dans une
-- transaction annulee (`SET LOCAL ROLE authenticated` + `request.jwt.claims`,
-- sinon la connexion `postgres` de `db query --linked` contourne RLS et rend
-- un faux negatif) : les deux insertions passent. Il suffit de connaitre
-- l'uuid du groupe.
--
-- Le WITH CHECK ne peut pas etre resserre sur le seul `inviter_id` : c'est le
-- meme qui sert a l'UPDATE, et l'invite doit pouvoir ecrire sa reponse --
-- exactement ce que 20260806200000 avait du reparer. On ajoute donc une
-- policy RESTRICTIVE limitee a l'INSERT, comme pour `group_members`, qui
-- s'ajoute en ET sans toucher aux permissives existantes.
--
-- Qui peut inviter : les administrateurs du groupe, et eux seuls. Meme regle
-- que l'interface (`peutInviterDansGroupe`), et meme fonction que partout
-- ailleurs dans ce module -- une policy plus large que le bouton donnerait un
-- droit invisible, une policy plus etroite un refus muet.

DROP POLICY IF EXISTS group_invites_insert_gate ON public.group_invites;
CREATE POLICY group_invites_insert_gate ON public.group_invites
  AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (
    (SELECT public.firebase_uid()) = inviter_id
    -- Le coeur du correctif : on ne s'invite pas soi-meme.
    AND inviter_id <> invitee_id
    AND public.is_group_admin(group_id)
  );

-- Deuxieme chemin vers le meme resultat : garder une invitation legitime
-- recue pour le groupe A et lui reecrire `group_id` vers le groupe prive B.
-- L'UPDATE est couvert par `group_invites_own` (je suis l'invite de la
-- ligne), et une policy RLS ne sait pas comparer OLD et NEW sans self-join
-- fragile a l'interieur d'une meme ligne -- c'est le raisonnement deja retenu
-- pour `20260814000500_guard_conversation_admin_fields.sql`. Un trigger
-- BEFORE UPDATE le fait sans ambiguite.
--
-- `inviter_id` reste modifiable vers l'appelant : reinviter quelqu'un passe
-- par un `upsert` (INSERT ... ON CONFLICT DO UPDATE) qui, fait par un second
-- administrateur, remplace legitimement l'auteur de l'invitation.
CREATE OR REPLACE FUNCTION public.group_invites_guard_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.group_id IS DISTINCT FROM OLD.group_id
     OR NEW.invitee_id IS DISTINCT FROM OLD.invitee_id THEN
    RAISE EXCEPTION 'Invitation : le groupe et le destinataire sont figes'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.inviter_id IS DISTINCT FROM OLD.inviter_id
     AND NEW.inviter_id IS DISTINCT FROM (SELECT public.firebase_uid()) THEN
    RAISE EXCEPTION 'Invitation : on ne reattribue pas une invitation a autrui'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS group_invites_guard_update_trigger
  ON public.group_invites;
CREATE TRIGGER group_invites_guard_update_trigger
  BEFORE UPDATE ON public.group_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.group_invites_guard_update();

-- Enfin, `has_group_invite()` acceptait n'importe quelle invitation, y compris
-- une invitation REFUSEE : decliner puis s'inscrire quand meme restait
-- possible. La reponse de l'invite doit compter.
--
-- 'accepted' est indispensable dans la liste : `acceptGroupInvite` passe le
-- statut a 'accepted' AVANT d'inserer la ligne `group_members`.
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
       AND i.inviter_id <> i.invitee_id
       AND i.status IN ('pending', 'accepted')
  )
$$;

REVOKE ALL ON FUNCTION public.has_group_invite(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_group_invite(uuid) TO authenticated;

-- Dernier point, de nature inverse : `groups_select_public` vaut
-- `NOT is_private OR creator_id = moi OR is_group_member(id)`. Un invite a un
-- groupe PRIVE n'est ni l'un ni l'autre : il voit bien son invitation (le nom
-- et l'image sont recopies dans `group_invites`), mais « Voir les details »
-- rend « Details indisponibles », et une notification qui l'enverrait sur
-- `/groups/<id>` tomberait sur l'etat d'erreur de la fiche.
--
-- On lui ouvre la lecture du groupe auquel il est invite -- description, lieu,
-- categorie : exactement ce qu'il faut pour decider. Cela ne s'ajoute qu'apres
-- les gardes ci-dessus : avant elles, `has_group_invite()` se fabriquait soi-
-- meme, et cette ligne aurait rendu tout groupe prive lisible par n'importe
-- qui. L'ordre des deux dans ce fichier n'est donc pas indifferent.
ALTER POLICY groups_select_public ON public.groups
  USING (
    NOT is_private
    OR (SELECT public.firebase_uid()) = creator_id
    OR public.is_group_member(id)
    OR public.has_group_invite(id)
  );
