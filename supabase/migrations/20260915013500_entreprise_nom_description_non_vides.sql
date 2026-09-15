-- Entreprises (`public.businesses`) : `name` et `description` sont NOT
-- NULL depuis 20260915012000_entreprise_nom_description_requis.sql, mais
-- NOT NULL laisse passer la chaîne vide -- et c'est exactement ce qui
-- s'est produit (fiche « Autre »/Goudoumaria, `name`/`description` à ''
-- depuis avant la validation du formulaire, capture SM A515F du
-- 2026-09-14).
--
-- Cette contrainte ferme aussi ce trou-là, pour toute NOUVELLE ligne.
--
-- Posée en NOT VALID à dessein : la fiche Goudoumaria
-- (id 6a9a3a65-f74c-4a39-8279-141633d097f2) viole déjà les deux
-- contraintes aujourd'hui, et sa correction (nom/description réels, ou
-- suppression) reste une décision produit, pas une décision de schéma --
-- NOT VALID applique la règle à tout INSERT/UPDATE à partir de
-- maintenant sans toucher aux lignes déjà en place ni faire échouer cette
-- migration dessus. Une fois la fiche corrigée :
--   ALTER TABLE public.businesses VALIDATE CONSTRAINT businesses_name_non_vide;
--   ALTER TABLE public.businesses VALIDATE CONSTRAINT businesses_description_non_vide;

ALTER TABLE public.businesses
  ADD CONSTRAINT businesses_name_non_vide
  CHECK (length(btrim(name)) > 0) NOT VALID;

ALTER TABLE public.businesses
  ADD CONSTRAINT businesses_description_non_vide
  CHECK (length(btrim(description)) > 0) NOT VALID;
