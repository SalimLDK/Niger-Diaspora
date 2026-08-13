-- get_or_create_official_group() insérait `creator_id = 'system_official'`,
-- mais `enforce_group_creator_trigger` (BEFORE INSERT, alphabétiquement
-- avant les autres triggers de `groups`) écrase TOUJOURS `creator_id` par
-- l'identité de l'appelant, quoi que l'INSERT tente de poser. Découvert en
-- corrigeant le seul groupe officiel existant (« Diaspora Niger — Canada »,
-- créé le 2026-07-16, avant que les gardes ci-dessous n'existent) : son
-- `creator_id` pointait vers le compte perso du premier utilisateur dont le
-- profil avait déclenché sa création, avec `creator_name` seul à dire
-- « Diaspo Niger » -- voir docs/ops/GROUPES_OFFICIELS.md.
--
-- Depuis le 2026-08-06, `groups_guard_official` (20260806130000) aggrave le
-- symptôme pour tout NOUVEAU pays : `creator_id` posé sur l'appelant n'étant
-- pas admin plateforme (`is_admin()` = false), l'INSERT entier échoue en
-- 42501. `ProfileNotifier._joinOfficialCountryGroup` avale cette erreur en
-- silence (best-effort) -- constat : plus aucun groupe officiel ne peut être
-- créé pour un nouveau pays depuis cette date, sans qu'aucune erreur ne
-- remonte nulle part.
--
-- Corrigé en faisant porter l'INSERT par le compte plateforme réel (créé le
-- 2026-08-13, czk5UoUclLOFmbRtUIZ5XYLYKo52 / support@diasponiger.com) et en
-- désactivant les deux triggers concernés le temps de cet unique INSERT --
-- même technique que la migration des groupes hérités du 2026-08-06 (voir
-- CLAUDE.md) : transactionnel, aucune fenêtre sans garde-fou côté requêtes
-- utilisateur normales (PostgREST), un échec du bloc annule tout par
-- ROLLBACK.
--
-- Ajoute aussi la ligne group_members manquante : is_group_admin() (RLS des
-- policies d'édition) ne lit jamais creator_id, seulement group_members.role
-- -- sans elle, un groupe officiel fraîchement créé n'aurait toujours aucun
-- administrateur fonctionnel, même avec le bon creator_id.

CREATE OR REPLACE FUNCTION public.get_or_create_official_group(p_country_code text, p_country_name text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_row public.groups%ROWTYPE;
  v_platform_uid CONSTANT text := 'czk5UoUclLOFmbRtUIZ5XYLYKo52';
BEGIN
  IF p_country_code IS NULL OR length(trim(p_country_code)) = 0 THEN
    RAISE EXCEPTION 'p_country_code requis' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_row FROM public.groups
    WHERE country_code = p_country_code AND is_official
    LIMIT 1;

  IF FOUND THEN
    RETURN row_to_json(v_row);
  END IF;

  ALTER TABLE public.groups DISABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups DISABLE TRIGGER groups_guard_official;

  INSERT INTO public.groups (
    name, description, creator_id, creator_name,
    category, is_private, country_code, is_official, member_count
  ) VALUES (
    format('Diaspora Niger — %s', p_country_name),
    format('Groupe officiel de la communauté nigérienne en %s.', p_country_name),
    v_platform_uid, 'Diaspo Niger',
    'regional', false, p_country_code, true, 0
  )
  ON CONFLICT (country_code) WHERE is_official DO NOTHING
  RETURNING * INTO v_row;

  ALTER TABLE public.groups ENABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups ENABLE TRIGGER groups_guard_official;

  -- Course possible entre deux appels concurrents : si le nôtre a été ignoré
  -- par le conflit, on relit la ligne créée par l'autre appel -- son
  -- group_members a déjà été posé par cet autre appel, rien à ajouter.
  IF NOT FOUND THEN
    SELECT * INTO v_row FROM public.groups
      WHERE country_code = p_country_code AND is_official
      LIMIT 1;
    RETURN row_to_json(v_row);
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (v_row.id, v_platform_uid, 'owner')
  ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner';

  -- Relire : le trigger group_members_count_trigger vient d'incrémenter
  -- member_count (0 -> 1) sur la ligne qu'on a capturée avant son passage.
  SELECT * INTO v_row FROM public.groups WHERE id = v_row.id;

  RETURN row_to_json(v_row);
END;
$function$;
