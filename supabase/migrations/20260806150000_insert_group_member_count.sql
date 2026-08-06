-- `insert_group` : ne plus compter le créateur deux fois, et rendre à l'appelant
-- le compteur réel.
--
-- CONSTAT (2026-08-06, sur appareil)
-- Un groupe créé depuis « Créer un groupe » sortait avec `member_count = 2`
-- alors qu'il n'avait qu'une seule ligne dans `group_members` — son créateur.
--
-- DEUX DÉFAUTS DANS LA MÊME FONCTION
--
-- 1. Double comptage. La fonction posait `member_count = 1` à l'INSERT dans
--    `groups`, PUIS insérait le créateur dans `group_members` ; or le trigger
--    `group_members_count_trigger` fait `member_count + 1` à chaque INSERT.
--    Le créateur était donc compté une fois à la main et une fois par le
--    trigger. On pose désormais 0 et on laisse le trigger seul maître du
--    compteur — une seule autorité, plus de dérive possible.
--
-- 2. Valeur retournée fausse, et fausse AUTREMENT. `RETURNING * INTO v_row`
--    capture la ligne AVANT l'insertion du membre, donc avant que le trigger
--    n'ait agi : la fonction renvoyait `1` pendant que la base contenait `2`.
--    L'écran de création affichait donc un troisième chiffre, différent des
--    deux autres. La ligne est maintenant relue après l'insertion du membre.
--
-- Le reste de la fonction est inchangé : même signature, même SECURITY
-- DEFINER, même garde `firebase_uid` (c'est elle qui empêche de créer un
-- groupe au nom d'autrui).
--
-- Les compteurs déjà dérivés se recalent avec `tools/recount_group_members.sql`.

-- ⚠️ Les valeurs par défaut doivent être reproduites À L'IDENTIQUE.
-- PostgreSQL refuse un `CREATE OR REPLACE` qui les retirerait
-- (`cannot remove parameter defaults from existing function`, SQLSTATE 42P13),
-- et il a raison : tout appelant qui omet un paramètre cesserait de résoudre
-- la fonction. Relevées sur la fonction en place avant écriture, via
-- `pg_get_function_arguments`.
CREATE OR REPLACE FUNCTION public.insert_group(
  p_name           text,
  p_description    text     DEFAULT NULL::text,
  p_avatar_url     text     DEFAULT NULL::text,
  p_creator_name   text     DEFAULT NULL::text,
  p_category       text     DEFAULT 'general'::text,
  p_is_private     boolean  DEFAULT false,
  p_group_location text     DEFAULT NULL::text,
  p_tags           text[]   DEFAULT '{}'::text[],
  p_country_code   text     DEFAULT NULL::text,
  p_origin_region  text     DEFAULT NULL::text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_firebase_uid TEXT;
  v_row          public.groups%ROWTYPE;
BEGIN
  v_firebase_uid := COALESCE(
    auth.jwt()->'app_metadata'->>'firebase_uid',
    (SELECT am.firebase_uid
       FROM public.auth_mappings am
      WHERE am.supabase_id = auth.uid()
      LIMIT 1)
  );

  IF v_firebase_uid IS NULL THEN
    RAISE EXCEPTION
      'firebase_uid introuvable — déconnectez-vous et reconnectez-vous.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.groups (
    name, description, avatar_url,
    creator_id, creator_name,
    category, is_private, group_location,
    tags, country_code, origin_region,
    member_count
  ) VALUES (
    p_name, p_description, p_avatar_url,
    v_firebase_uid, p_creator_name,
    p_category, p_is_private, p_group_location,
    to_jsonb(p_tags), p_country_code, p_origin_region,
    -- 0 et non 1 : le trigger compte le créateur juste en dessous.
    0
  )
  RETURNING * INTO v_row;

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (v_row.id, v_firebase_uid, 'owner');

  -- Relire APRÈS l'insertion du membre : `v_row` date d'avant le trigger et
  -- porterait encore 0.
  SELECT * INTO v_row FROM public.groups WHERE id = v_row.id;

  RETURN row_to_json(v_row);
END;
$$;
