-- Rectificatif de 20260806130000_guard_group_official.sql.
--
-- Cette migration-là se terminait par :
--     REVOKE UPDATE (is_official) ON public.groups FROM authenticated;
--     REVOKE INSERT (is_official) ON public.groups FROM authenticated;
-- présentés comme une seconde ligne de défense. **Ils n'ont eu aucun effet** :
-- les droits d'`authenticated` sur `groups` viennent d'un GRANT au niveau
-- table, et Postgres ne retire pas une colonne d'un privilège accordé sur la
-- table entière — le REVOKE passe sans erreur et ne change rien. Vérifié
-- après application : `information_schema.column_privileges` liste toujours
-- INSERT et UPDATE sur `is_official` pour `authenticated`.
--
-- La garde réelle est donc **le trigger, et lui seul**. Il a été testé sur la
-- base distante en se faisant passer pour un utilisateur ordinaire :
--     ERROR 42501: Seul un administrateur de la plateforme peut marquer un
--     groupe comme officiel
--
-- Rendre le REVOKE effectif demanderait de retirer l'UPDATE de table puis de
-- le re-accorder colonne par colonne : fragile (toute colonne ajoutée ensuite
-- serait muette) et risqué pour les écritures légitimes. Le trigger suffit et
-- couvre INSERT comme UPDATE.
--
-- On laisse la trace dans le schéma lui-même, pour que la prochaine personne
-- qui lit ces droits ne conclue pas à une faille.

COMMENT ON FUNCTION public.guard_group_official() IS
  'Seule garde du badge « Officiel » : exige is_admin() dès que '
  'groups.is_official change (INSERT ou UPDATE). Les droits de colonne ne '
  'protègent rien — ils viennent d''un GRANT au niveau table, qu''un REVOKE '
  'par colonne ne peut pas entamer. Une session sans firebase_uid (SQL '
  'Editor, service_role, migration) reste le chemin d''adoubement.';

COMMENT ON COLUMN public.groups.is_official IS
  'Badge « Officiel » affiché dans la liste des groupes et sur la carte. '
  'Écriture réservée aux administrateurs plateforme par le trigger '
  'groups_guard_official. Ne pas se fier aux column_privileges : '
  'authenticated y garde INSERT/UPDATE du fait du GRANT de table.';
