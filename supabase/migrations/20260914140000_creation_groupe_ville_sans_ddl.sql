-- Créer un groupe de ville ne fait plus de DDL.
--
-- CE QUE LA RÉPÉTITION DE LA REPRISE A TROUVÉ
-- `get_or_create_ville_group` neutralise deux déclencheurs de garde le temps
-- de son insertion — `enforce_group_creator_trigger`, qui écraserait le
-- compte plateforme par l'appelant, et `groups_guard_official`, qui refuse
-- `is_official` à un non-administrateur. Elle le faisait par
-- `ALTER TABLE public.groups DISABLE TRIGGER`, recopié de
-- `get_or_create_official_group`.
--
-- Rejouée dans une transaction, la fonction a échoué :
--
--   55006: cannot ALTER TABLE "groups" because it is being used by active
--   queries in this session
--
-- `ALTER TABLE` est refusé dès que la REQUÊTE DE L'APPELANT a `groups`
-- ouvert. La création dépendait donc de ce que faisait l'appelant, pas d'elle-
-- même — et elle est appelée depuis un déclencheur sur `users` et depuis une
-- boucle de balayage. Le jour où l'une de ces requêtes lirait `groups`, la
-- création s'arrêterait, sans que rien ne change dans cette fonction.
--
-- Accessoirement, `ALTER TABLE` prend un verrou ACCESS EXCLUSIVE sur `groups`,
-- tenu jusqu'à la fin de la transaction — celle d'un enregistrement de profil.
--
-- LA VOIE SANS DDL, ET SON UNIQUE PIÈGE
-- `SET LOCAL session_replication_role = 'replica'` neutralise les
-- déclencheurs sans DDL, sans verrou, et sans rien devoir à l'appelant.
--
-- Son piège, mesuré ici : `SET LOCAL` dans une fonction NE REVIENT PAS en
-- sortant de la fonction — il tient jusqu'à la fin de la TRANSACTION. Or
-- `ouvrir_groupe_de_ville_si_seuil` avale ses erreurs (il ne doit jamais
-- faire échouer un enregistrement de profil) : une insertion en échec aurait
-- laissé TOUS les déclencheurs de la base neutralisés pour le reste de
-- l'enregistrement.
--
-- D'où le sous-bloc `BEGIN … EXCEPTION` : c'est une sous-transaction, et son
-- annulation rétablit le réglage d'elle-même. Vérifié avant d'écrire ceci —
-- après un échec provoqué, `session_replication_role` valait bien « origin »,
-- dans le gestionnaire comme après.
--
-- `get_or_create_official_group` garde son `ALTER TABLE`. Elle porte la
-- création des groupes de PAYS depuis un an, elle n'est appelée que comme RPC
-- autonome — aucune requête de l'appelant n'a `groups` ouvert — et la
-- convertir au même moment mêlerait à ce correctif un changement sur le
-- chemin le plus fréquenté de la fonctionnalité. À faire à part, si la voie
-- ci-dessous tient.
CREATE OR REPLACE FUNCTION public.get_or_create_ville_group(p_ville_id bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_row public.groups%ROWTYPE;
  v_ville public.villes%ROWTYPE;
  v_platform_uid CONSTANT text := 'czk5UoUclLOFmbRtUIZ5XYLYKo52';
  v_insere boolean;
BEGIN
  SELECT * INTO v_ville FROM public.villes
   WHERE id = public.ville_de_groupe(p_ville_id);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ville inconnue : %', p_ville_id USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_row FROM public.groups
    WHERE ville_id = v_ville.id AND is_official
    LIMIT 1;
  IF FOUND THEN
    RETURN row_to_json(v_row);
  END IF;

  -- Sous-transaction : si l'insertion échoue, son annulation remet
  -- `session_replication_role` à « origin » toute seule.
  BEGIN
    SET LOCAL session_replication_role = 'replica';

    INSERT INTO public.groups (
      name, description, creator_id, creator_name,
      category, is_private, country_code, ville_id, is_official, member_count
    ) VALUES (
      public.nom_du_groupe_de_ville(v_ville.id),
      format('Groupe officiel de la communauté nigérienne de %s.', v_ville.nom),
      v_platform_uid, 'Diaspo Niger',
      'regional', false, v_ville.pays, v_ville.id, true, 0
    )
    ON CONFLICT (ville_id) WHERE is_official AND ville_id IS NOT NULL DO NOTHING
    RETURNING * INTO v_row;
    v_insere := FOUND;

    SET LOCAL session_replication_role = 'origin';
  EXCEPTION
    WHEN OTHERS THEN
      -- Surtout pas avalée : c'est `ouvrir_groupe_de_ville_si_seuil` qui
      -- décide d'ignorer un échec, et le balayage quotidien qui rattrape.
      RAISE;
  END;

  IF NOT v_insere THEN
    SELECT * INTO v_row FROM public.groups
      WHERE ville_id = v_ville.id AND is_official LIMIT 1;
    RETURN row_to_json(v_row);
  END IF;

  -- Les homonymes déjà en place gagnent leur qualificatif, s'ils portent
  -- encore un nom posé par la plateforme. Après l'insertion : avant, le
  -- nouveau groupe ne compte pas parmi leurs homonymes.
  UPDATE public.groups g
     SET name = public.nom_du_groupe_de_ville(g.ville_id)
    FROM public.villes w
   WHERE w.id = g.ville_id
     AND g.is_official
     AND w.id <> v_ville.id
     AND w.nom_plie = v_ville.nom_plie
     AND public.est_nom_automatique_de_ville(g.ville_id, g.name)
     AND g.name IS DISTINCT FROM public.nom_du_groupe_de_ville(g.ville_id);

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (v_row.id, v_platform_uid, 'owner')
  ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner';

  SELECT * INTO v_row FROM public.groups WHERE id = v_row.id;
  RETURN row_to_json(v_row);
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_ville_group(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_or_create_ville_group(bigint) FROM anon, authenticated;
