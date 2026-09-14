-- Deux trous du déclencheur de cohérence (20260913110000), trouvés au banc
-- sur la base réelle avant d'écrire la moindre ligne d'app.
--
-- 1. `UPDATE users SET city = 'Niamey bis'` passait sans rien déclencher.
--    `BEFORE ... UPDATE OF ville_id, country_code` se déclenche sur les
--    colonnes CITÉES dans le SET : `city` n'y était pas. Le profil pouvait
--    donc afficher « Niamey bis » tout en désignant Niamey — précisément la
--    divergence que « une seule source pour le libellé » devait interdire, et
--    le seul cas où elle comptait (un écrivain qui n'est pas l'éditeur de
--    profil, ou une version installée qui envoie un texte périmé).
--
-- 2. Changer de pays effaçait bien `ville_id`, mais laissait « Montréal »
--    dans `city`. Le profil restait « Niger · Montréal ». Quand la base
--    retire la ville, elle sait POURQUOI : cette ville est dans un autre
--    pays. Le libellé qui en vient est faux avec elle ; il part avec elle.
--
--    Une ville en texte libre (`ville_id` nul), elle, n'est pas touchée : on
--    ne sait pas à quel pays elle appartient, donc on ne sait pas qu'elle est
--    devenue fausse. N'agir que là où l'on sait.
CREATE OR REPLACE FUNCTION public.ville_coherente_avec_pays()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ville   public.villes%ROWTYPE;
  v_pays    text;
  v_change  boolean;
BEGIN
  IF NEW.ville_id IS NULL THEN
    RETURN NEW;  -- « Autre ville » : `city` reste ce que l'usager a écrit.
  END IF;

  SELECT * INTO v_ville FROM public.villes WHERE id = NEW.ville_id;
  IF NOT FOUND THEN
    -- La clé étrangère l'interdit ; si elle tombait, mieux vaut un profil
    -- sans ville qu'un profil qui en désigne une inexistante.
    NEW.ville_id := NULL;
    RETURN NEW;
  END IF;

  -- Un pays hors référentiel (saisie libre) est gardé tel quel, comme le fait
  -- `normaliser_pays` : il n'a pas de ville, donc il n'a pas à en perdre une.
  v_pays := COALESCE(public.pays_canonique(NEW.country_code), NEW.country_code);
  v_change := TG_OP = 'UPDATE' AND OLD.country_code IS DISTINCT FROM NEW.country_code;

  IF v_pays IS NULL THEN
    NEW.country_code := v_ville.pays;
  ELSIF v_pays <> v_ville.pays THEN
    IF v_change THEN
      NEW.ville_id := NULL;
      NEW.city := NULL;
      RETURN NEW;
    END IF;
    NEW.country_code := v_ville.pays;
  END IF;

  NEW.city := v_ville.nom;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ville_coherente_avec_pays ON public.users;
CREATE TRIGGER trg_ville_coherente_avec_pays
  BEFORE INSERT OR UPDATE OF ville_id, country_code, city ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.ville_coherente_avec_pays();
