-- Le départ consenti s'étend aux groupes de ville.
--
-- Déménager de Montréal à Toronto doit proposer de quitter « — Montréal » six
-- mois plus tard, sans toucher au groupe « — Canada ». Le mécanisme livré le
-- 2026-09-13 fait déjà tout le travail : il ne regardait que le pays.
--
-- TROIS DÉFAUTS, QUE L'ARRIVÉE DES GROUPES DE VILLE RÉVÈLE
--
-- 1. **La garde « revenu dans le pays » annulait tout.** Elle annule les
--    départs en cours dont le groupe a le `country_code` du profil — et un
--    groupe de ville porte le pays de sa ville. Un départ de Montréal aurait
--    donc été annulé au tout premier enregistrement de profil qui suit, sans
--    trace : l'usager reste au Canada, donc la condition est vraie à chaque
--    fois. La proposition n'aurait jamais eu lieu, et rien n'aurait signalé
--    qu'elle manquait.
--
-- 2. **Rien n'était planifié à ville constante de pays.** Le déclencheur ne se
--    déclenchait que sur `country_code`. Montréal → Toronto ne produisait
--    aucune ligne.
--
-- 3. **La tâche quotidienne annulait pour la même raison que 1.** Son test
--    « `pays_profil = pays_groupe` ⇒ il est revenu » vaut pour un groupe de
--    pays ; pour un groupe de ville, c'est la VILLE qu'il faut comparer.
--
-- Ce qui marchait déjà, et qu'on garde : changer de PAYS planifie le départ
-- de tous les groupes officiels de l'ancien pays — celui du pays comme ceux
-- de ses villes. Quitter le Canada pour la France propose bien de quitter
-- « — Canada » ET « — Montréal », chacun avec son échéance de six mois.
--
-- Les banlieues se comparent par leur PÔLE : Laval → Longueuil ne propose
-- rien, les deux mènent au même groupe.

COMMENT ON COLUMN public.departs_groupe_officiel.ancien_pays IS
  'country_code du groupe qu''il est proposé de quitter. Pour un groupe de ville, c''est le pays de cette ville — pas un pays que l''usager aurait quitté.';

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
  -- `ville_id IS NULL` est la correction du premier défaut : sans lui, un
  -- départ du groupe de Montréal s'annulait tout seul, l'usager étant
  -- toujours au Canada.
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
    INSERT INTO public.departs_groupe_officiel (user_id, group_id, ancien_pays, proposer_apres)
    SELECT NEW.id, g.id, g.country_code, now() + interval '6 months'
      FROM public.groups g
      JOIN public.group_members m ON m.group_id = g.id AND m.user_id = NEW.id
     WHERE g.is_official
       AND g.country_code = OLD.country_code
       AND m.role <> 'owner'
    ON CONFLICT (user_id, group_id) WHERE statut IN ('en_attente', 'a_confirmer')
    DO NOTHING;
  END IF;

  -- Changement de VILLE, pays constant ou non : le groupe de l'ancienne
  -- ville. Comparées par leur pôle — Laval et Longueuil mènent au même
  -- groupe, en changer n'est pas un déménagement pour lui.
  IF v_ancienne IS NOT NULL AND v_ancienne IS DISTINCT FROM v_nouvelle THEN
    INSERT INTO public.departs_groupe_officiel (user_id, group_id, ancien_pays, proposer_apres)
    SELECT NEW.id, g.id, g.country_code, now() + interval '6 months'
      FROM public.groups g
      JOIN public.group_members m ON m.group_id = g.id AND m.user_id = NEW.id
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

-- `UPDATE OF` se déclenche sur les colonnes CITÉES dans le SET : `ville_id`
-- doit y être, sinon un déménagement de ville ne réveille rien.
DROP TRIGGER IF EXISTS trg_planifier_depart_groupe_officiel ON public.users;
CREATE TRIGGER trg_planifier_depart_groupe_officiel
  AFTER UPDATE OF country_code, ville_id ON public.users
  FOR EACH ROW
  WHEN (OLD.country_code IS DISTINCT FROM NEW.country_code
     OR OLD.ville_id IS DISTINCT FROM NEW.ville_id)
  EXECUTE FUNCTION public.planifier_depart_groupe_officiel();

-- ─────────────────────────────────────────────────────────────────────────
-- La tâche quotidienne : « est-il revenu ? » se pose au bon niveau.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.proposer_departs_groupes_officiels()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_proposes integer := 0;
  v_revenu boolean;
BEGIN
  FOR r IN
    SELECT d.id, d.user_id, d.group_id, g.name, g.is_official,
           g.country_code AS pays_groupe,
           g.ville_id     AS ville_groupe,
           u.country_code AS pays_profil,
           public.ville_de_groupe(u.ville_id) AS ville_profil,
           EXISTS (
             SELECT 1 FROM public.group_members m
              WHERE m.group_id = d.group_id
                AND m.user_id = d.user_id
                AND m.role <> 'owner'
           ) AS membre
      FROM public.departs_groupe_officiel d
      JOIN public.groups g ON g.id = d.group_id
      LEFT JOIN public.users u ON u.id = d.user_id
     WHERE d.statut = 'en_attente'
       AND d.proposer_apres <= now()
     FOR UPDATE OF d SKIP LOCKED
  LOOP
    -- Un groupe de ville se juge sur la ville, un groupe de pays sur le pays.
    -- Dans les deux cas, une valeur effacée vaut « on ne sait pas » : on
    -- annule plutôt que de proposer un départ sur une supposition.
    v_revenu := CASE
      WHEN r.ville_groupe IS NOT NULL
        THEN r.ville_profil IS NULL OR r.ville_profil = r.ville_groupe
      ELSE r.pays_profil IS NULL OR r.pays_profil = r.pays_groupe
    END;

    IF NOT r.membre OR NOT r.is_official OR v_revenu THEN
      UPDATE public.departs_groupe_officiel
         SET statut = 'annule', repondu_le = now()
       WHERE id = r.id;
      CONTINUE;
    END IF;

    UPDATE public.departs_groupe_officiel
       SET statut = 'a_confirmer', propose_le = now()
     WHERE id = r.id;

    -- `trg_notify_push` envoie le push. Le type ouvre la fiche du groupe,
    -- où se trouve le choix.
    INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
    VALUES (
      r.user_id,
      'officialGroupLeave',
      format('Rester dans « %s » ?', r.name),
      CASE WHEN r.ville_groupe IS NOT NULL
        THEN 'Vous avez changé de ville il y a 6 mois. Vous pouvez quitter ce groupe ou y rester : rien ne change sans votre accord.'
        ELSE 'Vous avez changé de pays il y a 6 mois. Vous pouvez quitter ce groupe ou y rester : rien ne change sans votre accord.'
      END,
      jsonb_build_object(
        'groupId', r.group_id,
        'targetId', r.group_id,
        'target_id', r.group_id
      ),
      FALSE
    );

    v_proposes := v_proposes + 1;
  END LOOP;

  RETURN v_proposes;
END;
$$;

REVOKE ALL ON FUNCTION public.proposer_departs_groupes_officiels() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.proposer_departs_groupes_officiels() FROM anon, authenticated;
