-- =============================================================================
-- Aperçu minimal d'un groupe, pour qui en détient le lien.
--
-- Décision de Salim le 2026-09-10 : « pour les groupes privés, celui qui
-- reçoit le lien fait une demande d'adhésion au groupe ». Jusqu'ici le lien
-- menait à une impasse — `groups_select_public` ne rend aucune ligne à un
-- non-membre, donc PGRST116, donc « Ce groupe est privé ou n'existe plus. »
--
-- `group_requests.group_name` est **dénormalisé** : `requestToJoinGroup`
-- l'exige. Sans un moyen de lire le nom, aucune demande ne peut être créée
-- depuis un lien. C'est cette fonction, et rien d'autre, qui débloque le
-- parcours.
--
-- ── Ce que ça expose, et ce que ça n'expose pas ────────────────────────────
--
-- Exposé à qui détient l'uuid : le nom, l'avatar, le nombre de membres, et le
-- fait que le groupe soit privé. Rien d'autre.
--
-- PAS exposé : la description, la liste des membres, le créateur, les tags,
-- la localisation, les épingles, les messages. Le reste de la fiche continue
-- de passer par `groups_select_public`, qui n'a pas bougé.
--
-- ⚠️ C'est un **choix de produit assumé**, pas un oubli : un uuid connu révèle
-- désormais le nom d'un groupe privé. C'est le modèle du lien d'invitation
-- (WhatsApp, Telegram), et c'est ce qui rend un lien partagé utile.
--
-- Ce que ça ne rouvre PAS, et c'est ce qui distingue ce choix de la porte
-- fermée par `20260909201500` : cette fonction ne donne **aucun accès**. Elle
-- ne permet pas de s'auto-inviter, ni de lire quoi que ce soit du contenu.
-- La seule suite possible est une ligne dans `group_requests`, qu'un
-- administrateur doit approuver. Le groupe reste fermé tant que personne
-- n'ouvre.
--
-- Réservée à `authenticated` : demander à rejoindre suppose un compte, et un
-- anonyme n'a rien à faire de ce nom.
-- =============================================================================

CREATE OR REPLACE FUNCTION group_link_preview(p_group_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  avatar_url TEXT,
  member_count INTEGER,
  is_private BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT g.id, g.name, g.avatar_url, g.member_count, g.is_private
    FROM groups g
   WHERE g.id = p_group_id
$$;

REVOKE ALL ON FUNCTION group_link_preview(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION group_link_preview(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
