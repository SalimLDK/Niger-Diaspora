-- Organisation de la gestion des groupes officiels (suite du correctif
-- creator_id/get_or_create_official_group) : Salim est déjà superAdmin de la
-- plateforme (`users.is_admin = true`), mais `groups_update_admin` ne
-- regarde que `is_group_admin(id)` -- qui ne lit que `group_members.role`.
-- Sans ligne `owner`/`admin` sur SON compte perso pour un groupe officiel
-- donné, un superAdmin n'a aujourd'hui AUCUN droit de gestion dessus : la
-- seule voie serait de se reconnecter comme le compte plateforme
-- (`support@diasponiger.com`) à chaque action, ce qui n'est pas praticable
-- au quotidien.
--
-- Décision (voir docs/ops/GROUPES_OFFICIELS.md) : un superAdmin peut gérer
-- tout groupe OFFICIEL sans devenir le compte plateforme, mais ne gagne
-- aucun droit sur les groupes privés des utilisateurs -- portée délibérément
-- plus étroite qu'un accès superAdmin global à `groups`.
--
-- La suppression (`groups_delete`, `firebase_uid() = creator_id`) reste
-- inchangée : action plus lourde que la gestion courante, volontairement
-- réservée au compte plateforme qui reste le point d'ancrage réel du
-- groupe.

ALTER POLICY groups_update_admin ON public.groups
  USING (is_group_admin(id) OR (is_official AND is_admin()));
