-- Invitations : l'invite ne pouvait pas repondre a sa propre invitation.
--
-- `group_invites_own` avait un USING et un WITH CHECK asymetriques :
--
--   USING       (firebase_uid() = inviter_id OR firebase_uid() = invitee_id)
--   WITH CHECK  (firebase_uid() = inviter_id)
--
-- L'invite pouvait donc **lire** son invitation -- elle s'affiche bien dans
-- « Invitations recues » -- mais toute ecriture de sa reponse etait refusee :
--
--   42501 / new row violates row-level security policy for table "group_invites"
--
-- `acceptGroupInvite` et `declineGroupInvite` sont tous deux des UPDATE faits
-- par le destinataire. Aucun des deux n'a donc jamais pu aboutir. A l'ecran,
-- cela se lit « Action impossible pour le moment, reessayez. » -- le message
-- generique de `_showError`, qui ne dit pas laquelle des quatre etapes a
-- echoue.
--
-- Constate sur appareil le 2026-08-06 en acceptant une vraie invitation, puis
-- localise en rejouant la sequence sous l'identite de l'invite dans une
-- transaction annulee : la lecture passe, l'insertion dans `group_members`
-- passe, seul l'UPDATE de `group_invites` est refuse.
--
-- La policy admin ajoutee en 20260806180000 n'est pas en cause : elle est
-- permissive, donc elle ne peut qu'elargir -- mais `is_group_admin` est faux
-- pour quelqu'un qui rejoint, elle ne pouvait pas rattraper le cas.
--
-- On aligne donc le WITH CHECK sur le USING. Les deux parties de l'invitation
-- peuvent ecrire sur la ligne qui les concerne, ce que le USING affirmait
-- deja. `ALTER POLICY` : la policy est remplacee d'un bloc, sans fenetre.

ALTER POLICY group_invites_own ON public.group_invites
  WITH CHECK (
    (SELECT public.firebase_uid()) = inviter_id
    OR (SELECT public.firebase_uid()) = invitee_id
  );
