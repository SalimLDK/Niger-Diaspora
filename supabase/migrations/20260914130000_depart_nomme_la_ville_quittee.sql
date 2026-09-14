-- Ce que la fiche du groupe annonce doit être vrai.
--
-- La carte de départ dit « Vous avez changé de pays » et « votre profil
-- n'indique plus {pays} », avec `ancien_pays`. Pour un départ d'un groupe de
-- VILLE, les deux sont faux : quelqu'un qui déménage de Montréal à Toronto
-- est toujours au Canada, et son profil l'indique toujours.
--
-- D'où `ancienne_ville`, le NOM de la ville quittée, écrit au moment où le
-- départ est planifié. Un nom et pas une clé étrangère : c'est un message sur
-- le passé, il doit rester ce qu'il était même si le référentiel change.
-- `NULL` = départ d'un groupe de pays, et la carte garde ses textes actuels.

ALTER TABLE public.departs_groupe_officiel
  ADD COLUMN IF NOT EXISTS ancienne_ville text;

COMMENT ON COLUMN public.departs_groupe_officiel.ancienne_ville IS
  'Nom de la ville quittée, figé à la planification. NULL pour le départ d''un groupe de pays — c''est alors ancien_pays qui nomme ce qui est quitté.';

CREATE OR REPLACE FUNCTION public.planifier_depart_groupe_officiel()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ancienne bigint := public.ville_de_groupe(OLD.ville_id);
  v_nouvelle bigint := public.ville_de_groupe(NEW.ville_id);
BEGIN
  -- Revenu dans un pays : plus rien à proposer pour le groupe DE CE PAYS.
  -- `ville_id IS NULL` est essentiel : sans lui, un départ du groupe de
  -- Montréal s'annulerait tout seul, l'usager étant toujours au Canada.
  IF NEW.country_code IS NOT NULL THEN
    UPDATE public.departs_groupe_officiel d
       SET statut = 'annule', repondu_le = now()
      FROM public.groups g
     WHERE g.id = d.group_id
       AND d.user_id = NEW.id
       AND d.statut IN ('en_attente', 'a_confirmer')
       AND g.ville_id IS NULL
       AND g.country_code = NEW.country_code;
  END IF;

  -- Revenu dans une ville : même règle, au niveau de la ville.
  IF v_nouvelle IS NOT NULL THEN
    UPDATE public.departs_groupe_officiel d
       SET statut = 'annule', repondu_le = now()
      FROM public.groups g
     WHERE g.id = d.group_id
       AND d.user_id = NEW.id
       AND d.statut IN ('en_attente', 'a_confirmer')
       AND g.ville_id = v_nouvelle;
  END IF;

  -- Changement de PAYS : tous les groupes officiels de l'ancien pays, celui
  -- du pays comme ceux de ses villes. Un pays effacé n'est pas un changement
  -- de pays. L'owner (le compte plateforme) n'est jamais concerné.
  IF OLD.country_code IS NOT NULL AND NEW.country_code IS NOT NULL
     AND OLD.country_code IS DISTINCT FROM NEW.country_code THEN
    INSERT INTO public.departs_groupe_officiel
      (user_id, group_id, ancien_pays, ancienne_ville, proposer_apres)
    SELECT NEW.id, g.id, g.country_code, w.nom, now() + interval '6 months'
      FROM public.groups g
      JOIN public.group_members m ON m.group_id = g.id AND m.user_id = NEW.id
      LEFT JOIN public.villes w ON w.id = g.ville_id
     WHERE g.is_official
       AND g.country_code = OLD.country_code
       AND m.role <> 'owner'
    ON CONFLICT (user_id, group_id) WHERE statut IN ('en_attente', 'a_confirmer')
    DO NOTHING;
  END IF;

  -- Changement de VILLE : le groupe de l'ancienne ville. Comparées par leur
  -- pôle — Laval et Longueuil mènent au même groupe, en changer n'est pas un
  -- déménagement pour lui.
  IF v_ancienne IS NOT NULL AND v_ancienne IS DISTINCT FROM v_nouvelle THEN
    INSERT INTO public.departs_groupe_officiel
      (user_id, group_id, ancien_pays, ancienne_ville, proposer_apres)
    SELECT NEW.id, g.id, g.country_code, w.nom, now() + interval '6 months'
      FROM public.groups g
      JOIN public.group_members m ON m.group_id = g.id AND m.user_id = NEW.id
      JOIN public.villes w ON w.id = g.ville_id
     WHERE g.is_official
       AND g.ville_id = v_ancienne
       AND m.role <> 'owner'
    ON CONFLICT (user_id, group_id) WHERE statut IN ('en_attente', 'a_confirmer')
    DO NOTHING;
  END IF;

  RETURN NULL;
EXCEPTION
  WHEN OTHERS THEN
    -- Accessoire : ne doit jamais faire échouer l'enregistrement du profil.
    RAISE WARNING 'planifier_depart_groupe_officiel: %', SQLERRM;
    RETURN NULL;
END;
$$;

-- Les lignes déjà posées concernent toutes un groupe de pays (les groupes de
-- ville n'existaient pas avant aujourd'hui) : `ancienne_ville` y reste nul,
-- ce qui est exact.
