-- Entreprises (`public.businesses`) : `name` ET `description` ne doivent
-- jamais être NULL.
--
-- `name` l'était déjà (NOT NULL posé à la création de la table).
-- `description` ne l'était pas -- et une fiche vide (catégorie « Autre »,
-- ville Goudoumaria, capture SM A515F le 2026-09-14 : aucun nom, aucune
-- description affichés) l'a montré. En réalité cette fiche porte `name` et
-- `description` à `''` (chaîne vide), pas `NULL` -- `create_business_screen`
-- valide déjà les deux côté client (lignes 498-516) et empêche une chaîne
-- vide de passer par le formulaire ; cette fiche est antérieure à cette
-- validation, ou vient d'un import qui l'a contournée.
--
-- Cette migration ferme le trou NULL côté `description`, au niveau base --
-- demandé indépendamment de la chaîne vide déjà en place, qu'elle ne
-- retire pas (voir la note dans le compte-rendu de session).

-- Défensif : aucune ligne NULL au moment d'écrire cette migration (3 lignes
-- en tout, 0 description NULL), mais l'ALTER suivant échouerait s'il y en
-- avait une par la suite.
UPDATE public.businesses
SET description = ''
WHERE description IS NULL;

ALTER TABLE public.businesses
  ALTER COLUMN description SET DEFAULT '',
  ALTER COLUMN description SET NOT NULL;
