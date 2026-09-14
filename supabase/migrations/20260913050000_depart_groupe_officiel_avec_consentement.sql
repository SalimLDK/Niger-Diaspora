-- Changer de pays : proposer de quitter le groupe officiel de l'ancien pays,
-- six mois plus tard, et seulement avec l'accord de l'utilisateur.
--
-- Constat du 2026-09-13 : changer de pays ajoute au groupe officiel du
-- nouveau pays sans jamais sortir de l'ancien. Le compte `0D3P…` était membre
-- de « Diaspora Niger — Cap-Vert » et de « — Angola ».
--
-- Consigne de Salim : quitter l'ancien groupe « après 6 mois, avec
-- avertissement et consentement ». Donc :
--   1. au changement de pays, RIEN ne bouge : on note l'ancien groupe ;
--   2. six mois plus tard, s'il n'est pas revenu dans ce pays et qu'il est
--      toujours membre, l'utilisateur est averti (notification) ;
--   3. il choisit, sur la fiche du groupe : « Quitter » ou « Rester ».
--      Sans réponse, il reste. « Rester » est définitif pour ce départ-là.
--
-- Cycle d'une ligne :
--   en_attente ──(6 mois, tâche quotidienne)──▶ a_confirmer ──▶ quitte | reste
--        └───────(retour au pays, plus membre, groupe plus officiel)──▶ annule

-- ─────────────────────────────────────────────────────────────────────────
-- 1. Les départs proposés.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.departs_groupe_officiel (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        text NOT NULL,
  group_id       uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  ancien_pays    text NOT NULL,
  change_le      timestamptz NOT NULL DEFAULT now(),
  proposer_apres timestamptz NOT NULL,
  statut         text NOT NULL DEFAULT 'en_attente'
                 CHECK (statut IN ('en_attente', 'a_confirmer', 'quitte', 'reste', 'annule')),
  propose_le     timestamptz,
  repondu_le     timestamptz
);

COMMENT ON TABLE public.departs_groupe_officiel IS
  'Départ du groupe officiel de l''ancien pays, proposé 6 mois après un changement de pays. Jamais exécuté sans réponse de l''utilisateur (repondre_depart_groupe_officiel).';

-- Un seul départ ouvert par personne et par groupe : changer deux fois de
-- pays ne repousse pas l'échéance du premier départ.
CREATE UNIQUE INDEX IF NOT EXISTS departs_groupe_officiel_ouvert
  ON public.departs_groupe_officiel (user_id, group_id)
  WHERE statut IN ('en_attente', 'a_confirmer');

CREATE INDEX IF NOT EXISTS departs_groupe_officiel_echeance
  ON public.departs_groupe_officiel (proposer_apres)
  WHERE statut = 'en_attente';

-- Lecture de ses propres lignes seulement (la fiche du groupe demande « ai-je
-- un départ à confirmer ici ? »). Aucune écriture directe : tout passe par
-- les fonctions ci-dessous.
ALTER TABLE public.departs_groupe_officiel ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS departs_groupe_officiel_lecture ON public.departs_groupe_officiel;
CREATE POLICY departs_groupe_officiel_lecture ON public.departs_groupe_officiel
  FOR SELECT TO authenticated
  USING (user_id = (SELECT public.firebase_uid()));

-- ─────────────────────────────────────────────────────────────────────────
-- 2. Au changement de pays : noter, sans rien retirer.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.planifier_depart_groupe_officiel()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Revenu dans un pays : plus rien à proposer pour le groupe de ce pays.
  IF NEW.country_code IS NOT NULL THEN
    UPDATE public.departs_groupe_officiel d
       SET statut = 'annule', repondu_le = now()
      FROM public.groups g
     WHERE g.id = d.group_id
       AND d.user_id = NEW.id
       AND d.statut IN ('en_attente', 'a_confirmer')
       AND g.country_code = NEW.country_code;
  END IF;

  -- Un pays effacé n'est pas un changement de pays : on ne propose rien.
  -- L'owner (le compte plateforme) n'est jamais concerné.
  IF OLD.country_code IS NOT NULL AND NEW.country_code IS NOT NULL THEN
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

  RETURN NULL;
EXCEPTION
  WHEN OTHERS THEN
    -- Accessoire : ne doit jamais faire échouer l'enregistrement du profil.
    RAISE WARNING 'planifier_depart_groupe_officiel: %', SQLERRM;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_planifier_depart_groupe_officiel ON public.users;
CREATE TRIGGER trg_planifier_depart_groupe_officiel
  AFTER UPDATE OF country_code ON public.users
  FOR EACH ROW
  WHEN (OLD.country_code IS DISTINCT FROM NEW.country_code)
  EXECUTE FUNCTION public.planifier_depart_groupe_officiel();

-- ─────────────────────────────────────────────────────────────────────────
-- 3. Chaque jour : avertir ceux dont les six mois sont écoulés.
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
BEGIN
  FOR r IN
    SELECT d.id, d.user_id, d.group_id, g.name, g.is_official,
           g.country_code AS pays_groupe,
           u.country_code AS pays_profil,
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
    IF NOT r.membre
       OR NOT r.is_official
       OR r.pays_profil IS NULL
       OR r.pays_profil = r.pays_groupe THEN
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
      'Vous avez changé de pays il y a 6 mois. Vous pouvez quitter ce groupe ou y rester : rien ne change sans votre accord.',
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

-- Déclenchable par la tâche planifiée seulement : exposée, elle permettrait
-- d'avancer des notifications.
REVOKE ALL ON FUNCTION public.proposer_departs_groupes_officiels() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.proposer_departs_groupes_officiels() FROM anon, authenticated;

SELECT cron.schedule(
  'proposer-departs-groupes-officiels',
  '0 9 * * *',
  $cron$SELECT public.proposer_departs_groupes_officiels()$cron$
);

-- ─────────────────────────────────────────────────────────────────────────
-- 4. La réponse de l'utilisateur — la seule voie vers un départ.
--    N'agit que sur l'appelant (firebase_uid), jamais sur un id fourni.
--    Rend 'quitte', 'reste', ou NULL s'il n'y avait rien à décider.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.repondre_depart_groupe_officiel(p_group_id uuid, p_quitter boolean)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid text := public.firebase_uid();
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Utilisateur non authentifié' USING ERRCODE = '42501';
  END IF;
  IF p_quitter IS NULL THEN
    RAISE EXCEPTION 'Réponse requise' USING ERRCODE = 'P0001';
  END IF;

  SELECT id INTO v_id
    FROM public.departs_groupe_officiel
   WHERE user_id = v_uid
     AND group_id = p_group_id
     AND statut = 'a_confirmer'
   FOR UPDATE;

  IF v_id IS NULL THEN
    RETURN NULL;
  END IF;

  IF p_quitter THEN
    -- Même départ que « Quitter le groupe » dans l'app (`leaveGroup`) :
    -- la ligne d'appartenance, puis la participation à la discussion.
    DELETE FROM public.group_members
     WHERE group_id = p_group_id
       AND user_id = v_uid
       AND role <> 'owner';
    PERFORM public.leave_group_conversation(p_group_id::text);
  END IF;

  UPDATE public.departs_groupe_officiel
     SET statut = CASE WHEN p_quitter THEN 'quitte' ELSE 'reste' END,
         repondu_le = now()
   WHERE id = v_id;

  RETURN CASE WHEN p_quitter THEN 'quitte' ELSE 'reste' END;
END;
$$;

-- `REVOKE ... FROM PUBLIC` ne suffit pas : Supabase accorde EXECUTE à `anon`
-- nommément sur toute nouvelle fonction de `public` (voir 20260910070000).
REVOKE ALL ON FUNCTION public.repondre_depart_groupe_officiel(uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.repondre_depart_groupe_officiel(uuid, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.repondre_depart_groupe_officiel(uuid, boolean) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 5. L'existant : ceux qui ont déjà changé de pays avant cette migration.
--    Date du changement inconnue : on prend leur entrée dans le groupe
--    officiel de leur pays actuel, qui la suit de près (adhésion automatique
--    au premier chargement du profil). Relevé le 2026-09-13 : une seule ligne,
--    `0D3P…` dans « — Cap-Vert », entré dans « — Angola » le 2026-09-11.
-- ─────────────────────────────────────────────────────────────────────────
INSERT INTO public.departs_groupe_officiel (user_id, group_id, ancien_pays, change_le, proposer_apres)
SELECT m.user_id, g.id, g.country_code, mc.joined_at, mc.joined_at + interval '6 months'
  FROM public.group_members m
  JOIN public.groups g ON g.id = m.group_id AND g.is_official
  JOIN public.users u ON u.id = m.user_id
                     AND u.country_code IS NOT NULL
                     AND u.country_code <> g.country_code
  JOIN public.groups gc ON gc.is_official AND gc.country_code = u.country_code
  JOIN public.group_members mc ON mc.group_id = gc.id AND mc.user_id = m.user_id
 WHERE m.role <> 'owner'
ON CONFLICT (user_id, group_id) WHERE statut IN ('en_attente', 'a_confirmer')
DO NOTHING;
