-- Un groupe sans `country_code` est invisible dans « Découvrir ».
--
-- `_applyFilters` (groups_screen.dart) filtre sur `g.country == _selectedCountry`,
-- et `_loadDefaultCountryFilter` pose un filtre pays **tout seul** au premier
-- affichage — pays du profil, ou `NE` à défaut. Un groupe à `country_code` nul
-- n'est donc pas « non filtré » : il est écarté sans que l'utilisateur ait rien
-- demandé, et rien à l'écran ne le signale. Un groupe était dans ce cas au
-- 2026-08-06 (`2b24986f-08b5-4840-9931-dbe046ffb394`, « Groupe de test prive »).
--
-- Décision : le pays par défaut est le Niger (`NE`). Trois verrous, du plus
-- large au plus étroit — le côté app pose déjà le même défaut dans
-- `GroupSupabaseDataSource.createGroup` et `create_group_screen.dart`
-- (`kDefaultCountryCode`).

-- 1. Reprise de l'existant.
UPDATE public.groups
   SET country_code = 'NE'
 WHERE country_code IS NULL
    OR length(trim(country_code)) = 0;

-- 2. Colonne omise à l'insertion.
ALTER TABLE public.groups
  ALTER COLUMN country_code SET DEFAULT 'NE';

-- 3. Colonne fournie mais nulle ou vide — le cas que ni le `DEFAULT` ni le
--    code applicatif ne couvrent, puisque `insert_group` passe explicitement
--    `p_country_code`, fût-il nul. Un déclencheur plutôt qu'une réécriture de
--    la fonction : elle est `SECURITY DEFINER`, et la reproduire depuis
--    `pg_proc` pour n'y changer qu'un `COALESCE` fait courir un risque de
--    dérive sans rapport avec le sujet.
CREATE OR REPLACE FUNCTION public.groups_country_code_defaut()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.country_code IS NULL OR length(trim(NEW.country_code)) = 0 THEN
    NEW.country_code := 'NE';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_groups_country_code_defaut ON public.groups;
CREATE TRIGGER trg_groups_country_code_defaut
  BEFORE INSERT OR UPDATE OF country_code ON public.groups
  FOR EACH ROW
  EXECUTE FUNCTION public.groups_country_code_defaut();

COMMENT ON COLUMN public.groups.country_code IS
  'Code ISO-2. Jamais nul : défaut NE (Niger), sinon le groupe disparaît de « Découvrir » dès qu''un filtre pays est actif.';
