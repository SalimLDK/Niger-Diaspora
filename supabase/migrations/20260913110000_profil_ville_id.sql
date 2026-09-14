-- Le profil désigne une ville du référentiel : `users.ville_id`.
--
-- `city` reste, et reste du texte libre : c'est « Autre ville », le cas où
-- l'usager habite quelque part que la liste ignore. Ce cas-là n'ouvrira
-- simplement pas de groupe de ville. Ce qui ouvrira un groupe, c'est
-- `ville_id`, qui pointe une ligne — jamais une chaîne.
--
-- LA COHÉRENCE VILLE ↔ PAYS EST TENUE PAR LA BASE, PAS PAR L'APP
-- Même raison que pour les pays (20260913030000) : les versions déjà
-- installées continuent d'écrire, et une seule d'entre elles suffit à poser
-- « Montréal » dans un profil réglé sur le Niger. Le couple serait alors
-- incohérent pour toujours, et le groupe de ville du Canada compterait un
-- membre qui n'y est pas.
--
-- Trois règles, dans cet ordre :
--
--   1. pays absent → la ville le pose (« Montréal » ⇒ Canada) ;
--   2. le pays vient de changer et la ville n'y est pas → la VILLE s'en va.
--      C'est le sens prudent : perdre une ville se voit et se refait, alors
--      qu'un changement de pays silencieux déplacerait l'usager de groupe
--      officiel sans un mot ;
--   3. sinon, la ville pose son pays — ce qui répare aussi un couple
--      incohérent hérité, au premier enregistrement du profil.
--
-- Et `city` suit `villes.nom` dès que `ville_id` est posé : sans ça, le profil
-- pourrait afficher « Montreu » tout en étant membre du groupe de Montréal.
-- Une seule source pour le libellé.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS
-- `trg_planifier_depart_groupe_officiel` ne surveille que `country_code`
-- (`AFTER UPDATE OF country_code`, qui se déclenche sur la présence de la
-- colonne dans le SET, pas sur un changement de valeur). L'enregistrement du
-- profil envoie toujours `country_code`, donc un déménagement passe bien par
-- lui aujourd'hui. Mais un changement de ville à pays constant ne propose
-- rien : c'est l'objet de l'étape « extension du départ consenti », qui fera
-- surveiller `ville_id` aussi.
--
-- La reprise des profils existants (« Montréal » sans pays, « Arewa »,
-- « Almoustapha ») est une étape à part : elle se propose à l'usager, elle ne
-- s'impose pas.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS ville_id bigint REFERENCES public.villes(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.users.ville_id IS
  'Ville du référentiel où vit l''usager. NULL = « Autre ville » (voir la colonne city, texte libre) : pas de groupe de ville. Cohérence avec country_code tenue par trg_ville_coherente_avec_pays.';

-- Compter les profils d'une ville — ce que le seuil de création d'un groupe
-- de ville (3 profils) interrogera à chaque nouvelle arrivée.
CREATE INDEX IF NOT EXISTS users_ville_id ON public.users (ville_id)
  WHERE ville_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- SECURITY DEFINER : `villes` n'est lisible que par `authenticated`. Un
-- déclencheur qui tourne avec les droits de l'appelant n'y verrait rien dès
-- que la RLS bouge — et « rien » voudrait dire « cette ville n'existe pas »,
-- donc `ville_id` effacé, en silence, pour tout le monde.
-- ─────────────────────────────────────────────────────────────────────────
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
      RETURN NEW;
    END IF;
    NEW.country_code := v_ville.pays;
  END IF;

  NEW.city := v_ville.nom;
  RETURN NEW;
END;
$$;

-- Le nom compte : les déclencheurs BEFORE d'une même table s'exécutent dans
-- l'ordre alphabétique, et celui-ci doit passer APRÈS `trg_normaliser_pays`,
-- qui ramène « CA » à « Canada » — sinon la comparaison de pays se ferait sur
-- l'ancienne forme et effacerait la ville à tort.
DROP TRIGGER IF EXISTS trg_ville_coherente_avec_pays ON public.users;
CREATE TRIGGER trg_ville_coherente_avec_pays
  BEFORE INSERT OR UPDATE OF ville_id, country_code ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.ville_coherente_avec_pays();
