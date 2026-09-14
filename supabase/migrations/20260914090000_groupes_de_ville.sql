-- Les groupes officiels de ville : « Diaspora Niger — Montréal ».
--
-- LE VERROU À LEVER D'ABORD
-- En production tourne, depuis un temps qu'aucune migration du dépôt ne
-- raconte :
--
--   CREATE UNIQUE INDEX uniq_official_group_per_country
--     ON public.groups (country_code) WHERE is_official
--
-- Il porte sur le PAYS SEUL. Un groupe de ville garde le `country_code` de sa
-- ville — c'est ce qui fait marcher le filtre par pays — donc « — Montréal »
-- (Canada, officiel) serait entré en collision avec « — Canada » : le tout
-- premier groupe de ville aurait été refusé, et l'erreur serait remontée
-- depuis `get_or_create_official_group`, loin de sa cause.
--
-- Deux index partiels le remplacent : un groupe officiel par pays SANS ville,
-- un par ville. Et comme l'index d'origine n'existe que sur le serveur, le
-- `DROP` doit être `IF EXISTS` — sur une base repartie des migrations, il n'y
-- a rien à supprimer.
--
-- LE SECOND PIÈGE, MOINS VISIBLE
-- `get_or_create_official_group` cherche `WHERE country_code = v_pays AND
-- is_official LIMIT 1`. Sans précaution, ce `LIMIT 1` aurait pu rendre le
-- groupe de MONTRÉAL à qui demandait celui du CANADA — et son `ON CONFLICT
-- (country_code) WHERE is_official` désigne nommément l'index qu'on remplace,
-- donc aurait échoué à l'exécution (« no unique or exclusion constraint
-- matching the ON CONFLICT specification ») au premier profil canadien. La
-- fonction est donc recréée ici, avec `ville_id IS NULL` partout.
--
-- CE QUI N'A PAS BESOIN D'UNE COLONNE
-- Le groupe parent d'un groupe de ville est le groupe officiel de même
-- `country_code` sans `ville_id`. Déduit à la lecture, il ne peut pas
-- diverger. D'où `groupe_pays_du_groupe_ville` et `villes_du_groupe_pays`,
-- qui n'ajoutent aucune donnée.
--
-- LES DÉCISIONS DE SALIM (2026-09-13), ET OÙ ELLES VIVENT
--   * seuil de 3 profils → `seuil_groupe_de_ville()`, lue par le déclencheur
--     comme par le balayage quotidien ;
--   * invitation, jamais d'ajout d'office, et jamais pour un profil
--     invisible → notification `cityGroupInvite`, et `is_visible` filtre
--     aussi bien le COMPTE que les invités : un groupe ouvert pour trois
--     personnes que personne ne peut inviter resterait vide ;
--   * banlieues rattachées à leur pôle → `ville_de_groupe`, qui rend le pôle
--     quand il existe. Laval et Longueuil mènent au groupe de Montréal.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. La colonne, et l'unicité refaite.
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS ville_id bigint REFERENCES public.villes(id);

COMMENT ON COLUMN public.groups.ville_id IS
  'Ville dont ce groupe est le groupe officiel. NULL = groupe de pays. country_code vaut toujours le pays (de la ville, le cas échéant) : le filtre par pays vaut pour les deux.';

DROP INDEX IF EXISTS public.uniq_official_group_per_country;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_groupe_officiel_par_pays
  ON public.groups (country_code) WHERE is_official AND ville_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_groupe_officiel_par_ville
  ON public.groups (ville_id) WHERE is_official AND ville_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. La ville qui porte le groupe : la sienne, ou son pôle.
--    Laval (440 000) est à 12 km de Montréal (1,7 M) : `pole_id` la rattache,
--    et son groupe est celui de Montréal. Un pôle n'a jamais de pôle
--    (l'import résout les chaînes), mais `ville_de_groupe` ne s'appuie pas
--    là-dessus : une donnée retouchée à la main pourrait en créer une.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ville_de_groupe(p_ville_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(v.pole_id, v.id) FROM public.villes v WHERE v.id = p_ville_id;
$$;

COMMENT ON FUNCTION public.ville_de_groupe(bigint) IS
  'Ville dont le groupe accueille les habitants de p_ville_id : son pôle quand elle en a un (Laval → Montréal), elle-même sinon.';

-- ─────────────────────────────────────────────────────────────────────────
-- 3. Le groupe officiel d'un PAYS. Repris de 20260913030000, avec
--    `ville_id IS NULL` aux trois endroits qui en dépendent.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_or_create_official_group(p_country_code text, p_country_name text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_row public.groups%ROWTYPE;
  v_platform_uid CONSTANT text := 'czk5UoUclLOFmbRtUIZ5XYLYKo52';
  v_pays text;
BEGIN
  v_pays := public.pays_canonique(p_country_code);
  IF v_pays IS NULL THEN
    RAISE EXCEPTION 'Pays inconnu : %', p_country_code USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_row FROM public.groups
    WHERE country_code = v_pays AND is_official AND ville_id IS NULL
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
    format('Diaspora Niger — %s', v_pays),
    format('Groupe officiel de la communauté nigérienne — %s.', v_pays),
    v_platform_uid, 'Diaspo Niger',
    'regional', false, v_pays, true, 0
  )
  ON CONFLICT (country_code) WHERE is_official AND ville_id IS NULL DO NOTHING
  RETURNING * INTO v_row;

  ALTER TABLE public.groups ENABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups ENABLE TRIGGER groups_guard_official;

  -- Course possible entre deux appels concurrents : si le nôtre a été ignoré
  -- par le conflit, on relit la ligne créée par l'autre appel -- son
  -- group_members a déjà été posé par cet autre appel, rien à ajouter.
  IF NOT FOUND THEN
    SELECT * INTO v_row FROM public.groups
      WHERE country_code = v_pays AND is_official AND ville_id IS NULL
      LIMIT 1;
    RETURN row_to_json(v_row);
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (v_row.id, v_platform_uid, 'owner')
  ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner';

  SELECT * INTO v_row FROM public.groups WHERE id = v_row.id;
  RETURN row_to_json(v_row);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4. Le groupe officiel d'une VILLE.
--
--    Le nom ne porte le pays qu'en cas d'homonyme — « — London (Canada) »
--    face à « — London (Royaume-Uni) ». Quand le second arrive, le premier
--    est renommé aussi, mais SEULEMENT si son nom est encore celui que cette
--    fonction lui avait donné : un nom retouché à la main appartient à qui
--    l'a écrit. L'unicité, elle, ne repose jamais sur le nom — c'est
--    `uniq_groupe_officiel_par_ville` qui la tient.
-- ─────────────────────────────────────────────────────────────────────────
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
  v_homonyme boolean;
  v_nom text;
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

  SELECT EXISTS (
    SELECT 1 FROM public.groups g
      JOIN public.villes w ON w.id = g.ville_id
     WHERE g.is_official AND w.nom_plie = v_ville.nom_plie AND w.id <> v_ville.id
  ) INTO v_homonyme;

  IF v_homonyme THEN
    v_nom := format('Diaspora Niger — %s (%s)', v_ville.nom, v_ville.pays);
    UPDATE public.groups g
       SET name = format('Diaspora Niger — %s (%s)', w.nom, w.pays)
      FROM public.villes w
     WHERE w.id = g.ville_id
       AND g.is_official
       AND w.nom_plie = v_ville.nom_plie
       AND w.id <> v_ville.id
       AND g.name = format('Diaspora Niger — %s', w.nom);
  ELSE
    v_nom := format('Diaspora Niger — %s', v_ville.nom);
  END IF;

  ALTER TABLE public.groups DISABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups DISABLE TRIGGER groups_guard_official;

  INSERT INTO public.groups (
    name, description, creator_id, creator_name,
    category, is_private, country_code, ville_id, is_official, member_count
  ) VALUES (
    v_nom,
    format('Groupe officiel de la communauté nigérienne de %s.', v_ville.nom),
    v_platform_uid, 'Diaspo Niger',
    'regional', false, v_ville.pays, v_ville.id, true, 0
  )
  ON CONFLICT (ville_id) WHERE is_official AND ville_id IS NOT NULL DO NOTHING
  RETURNING * INTO v_row;

  ALTER TABLE public.groups ENABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups ENABLE TRIGGER groups_guard_official;

  IF NOT FOUND THEN
    SELECT * INTO v_row FROM public.groups
      WHERE ville_id = v_ville.id AND is_official LIMIT 1;
    RETURN row_to_json(v_row);
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role)
  VALUES (v_row.id, v_platform_uid, 'owner')
  ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner';

  SELECT * INTO v_row FROM public.groups WHERE id = v_row.id;
  RETURN row_to_json(v_row);
END;
$$;

-- Ni l'une ni l'autre ne s'appelle depuis l'app : c'est le déclencheur du
-- profil qui ouvre un groupe de ville, au seuil, et jamais sur demande.
REVOKE ALL ON FUNCTION public.get_or_create_ville_group(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_or_create_ville_group(bigint) FROM anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 5. Le seuil, et l'invitation.
--
--    Trois profils VISIBLES dans la ville (pôle compris) ouvrent le groupe.
--    Les profils invisibles ne comptent pas et ne sont pas invités : compter
--    quelqu'un qu'on ne peut pas inviter ouvrirait des groupes vides.
--
--    Rien n'est ajouté d'office. Chaque profil concerné reçoit une
--    notification `cityGroupInvite` — une fois, jamais deux, d'où le
--    `NOT EXISTS` sur les notifications déjà posées pour ce groupe.
-- ─────────────────────────────────────────────────────────────────────────
-- Le seuil vit ici et nulle part ailleurs : le déclencheur et le balayage
-- quotidien le lisent tous les deux, et deux copies d'un nombre finissent
-- toujours par diverger. Décision de Salim du 2026-09-13 : trois profils.
-- Le changer est un `CREATE OR REPLACE` d'une ligne, sans redéploiement.
CREATE OR REPLACE FUNCTION public.seuil_groupe_de_ville()
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$ SELECT 3 $$;

CREATE OR REPLACE FUNCTION public.ouvrir_groupe_de_ville(p_ville_id bigint)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ville bigint;
  v_nom   text;
  v_n     integer;
  v_group uuid;
BEGIN
  v_ville := public.ville_de_groupe(p_ville_id);
  IF v_ville IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT count(*) INTO v_n
    FROM public.users u
    JOIN public.villes w ON w.id = u.ville_id
   WHERE COALESCE(w.pole_id, w.id) = v_ville
     AND u.is_visible;

  IF v_n < public.seuil_groupe_de_ville() THEN
    RETURN NULL;
  END IF;

  v_group := ((public.get_or_create_ville_group(v_ville))->>'id')::uuid;
  IF v_group IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT name INTO v_nom FROM public.groups WHERE id = v_group;

  INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
  SELECT u.id,
         'cityGroupInvite',
         format('Rejoindre « %s » ?', v_nom),
         'Des membres de votre ville s''y retrouvent. Vous n''y êtes ajouté que si vous le demandez.',
         jsonb_build_object('groupId', v_group, 'targetId', v_group, 'target_id', v_group),
         FALSE
    FROM public.users u
    JOIN public.villes w ON w.id = u.ville_id
   WHERE COALESCE(w.pole_id, w.id) = v_ville
     AND u.is_visible
     AND NOT EXISTS (
       SELECT 1 FROM public.group_members m
        WHERE m.group_id = v_group AND m.user_id = u.id
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.notifications n
        WHERE n.user_id = u.id
          AND n.type = 'cityGroupInvite'
          AND n.data->>'groupId' = v_group::text
     );

  RETURN v_group;
END;
$$;

REVOKE ALL ON FUNCTION public.ouvrir_groupe_de_ville(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ouvrir_groupe_de_ville(bigint) FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.ouvrir_groupe_de_ville_si_seuil()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.ville_id IS NOT NULL THEN
    PERFORM public.ouvrir_groupe_de_ville(NEW.ville_id);
  END IF;
  RETURN NULL;
EXCEPTION
  WHEN OTHERS THEN
    -- Accessoire : ne doit jamais faire échouer l'enregistrement du profil.
    -- Ce qui est avalé ici est rattrapé le lendemain par le balayage.
    RAISE WARNING 'ouvrir_groupe_de_ville_si_seuil: %', SQLERRM;
    RETURN NULL;
END;
$$;

-- `is_visible` est dans la liste : devenir visible peut être le troisième
-- profil qui ouvre le groupe.
DROP TRIGGER IF EXISTS trg_ouvrir_groupe_de_ville ON public.users;
CREATE TRIGGER trg_ouvrir_groupe_de_ville
  AFTER INSERT OR UPDATE OF ville_id, is_visible ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.ouvrir_groupe_de_ville_si_seuil();

-- Le filet. Le déclencheur ouvre le groupe au moment même où le troisième
-- profil arrive — mais il avale ses erreurs (il ne doit jamais faire échouer
-- un enregistrement de profil), et la création prend un verrou exclusif sur
-- `groups` le temps de neutraliser les deux déclencheurs de garde. Un échec,
-- et plus rien ne se passerait pour cette ville tant qu'un quatrième profil
-- n'y arrive pas — ce qui, avec un seuil de trois, peut vouloir dire jamais.
--
-- Ce balayage quotidien reprend ce qui est resté en arrière. Il ne double
-- jamais un groupe (`get_or_create_ville_group` relit avant d'insérer) ni une
-- invitation (le `NOT EXISTS` sur les notifications).
CREATE OR REPLACE FUNCTION public.ouvrir_groupes_de_ville_en_retard()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_ouverts integer := 0;
BEGIN
  FOR r IN
    SELECT COALESCE(w.pole_id, w.id) AS ville, count(*) AS n
      FROM public.users u
      JOIN public.villes w ON w.id = u.ville_id
     WHERE u.is_visible
     GROUP BY 1
    HAVING count(*) >= public.seuil_groupe_de_ville()
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.groups g
       WHERE g.is_official AND g.ville_id = r.ville
    ) THEN
      v_ouverts := v_ouverts + 1;
    END IF;
    PERFORM public.ouvrir_groupe_de_ville(r.ville);
  END LOOP;
  RETURN v_ouverts;
END;
$$;

REVOKE ALL ON FUNCTION public.ouvrir_groupes_de_ville_en_retard() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ouvrir_groupes_de_ville_en_retard() FROM anon, authenticated;

SELECT cron.schedule(
  'ouvrir-groupes-de-ville',
  '30 9 * * *',
  $cron$SELECT public.ouvrir_groupes_de_ville_en_retard()$cron$
);

-- ─────────────────────────────────────────────────────────────────────────
-- 6. Lire la hiérarchie sans la stocker.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.groupe_pays_du_groupe_ville(p_group_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT p.id
    FROM public.groups g
    JOIN public.groups p
      ON p.country_code = g.country_code AND p.is_official AND p.ville_id IS NULL
   WHERE g.id = p_group_id AND g.ville_id IS NOT NULL
   LIMIT 1;
$$;

COMMENT ON FUNCTION public.groupe_pays_du_groupe_ville(uuid) IS
  'Groupe officiel du pays auquel appartient un groupe de ville. Déduit, jamais stocké : il ne peut pas diverger.';

/** Les villes d'un groupe de pays : « Montréal · 12, Toronto · 5 ». */
CREATE OR REPLACE FUNCTION public.villes_du_groupe_pays(p_group_id uuid)
RETURNS TABLE (group_id uuid, nom text, member_count integer, latitude double precision, longitude double precision)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT g.id, v.nom, g.member_count, v.latitude, v.longitude
    FROM public.groups parent
    JOIN public.groups g
      ON g.country_code = parent.country_code AND g.is_official AND g.ville_id IS NOT NULL
    JOIN public.villes v ON v.id = g.ville_id
   WHERE parent.id = p_group_id AND parent.ville_id IS NULL
   ORDER BY g.member_count DESC, v.nom;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 7. La carte.
--
--    `groups_map_screen.dart` place chaque groupe sur une table de 32
--    centroïdes de pays écrite en dur, et SAUTE le groupe dont le pays n'y
--    est pas (`if (centroid == null) continue;`) — 165 des 197 pays du
--    référentiel sont dans ce cas.
--
--    Ici, une coordonnée pour chaque groupe demandé : celle de sa ville, ou
--    à défaut celle de la plus grande ville de son pays. `source` dit laquelle,
--    pour que l'app garde ses centroïdes là où elle en a un — même carte
--    qu'aujourd'hui pour les 32, une épingle au lieu de rien pour les autres.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.coordonnees_des_groupes(p_group_ids uuid[])
RETURNS TABLE (group_id uuid, latitude double precision, longitude double precision, source text)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT g.id,
         COALESCE(v.latitude, p.latitude),
         COALESCE(v.longitude, p.longitude),
         CASE WHEN v.id IS NOT NULL THEN 'ville' ELSE 'pays' END
    FROM public.groups g
    LEFT JOIN public.villes v ON v.id = g.ville_id
    LEFT JOIN LATERAL (
      SELECT w.latitude, w.longitude
        FROM public.villes w
       WHERE g.ville_id IS NULL AND w.pays = g.country_code
       ORDER BY w.population DESC, w.nom
       LIMIT 1
    ) p ON TRUE
   WHERE g.id = ANY (p_group_ids)
     AND COALESCE(v.latitude, p.latitude) IS NOT NULL;
$$;

COMMENT ON FUNCTION public.coordonnees_des_groupes(uuid[]) IS
  'Où poser chaque groupe sur la carte : coordonnées de sa ville (source « ville ») ou, pour un groupe de pays, celles de la plus grande ville du pays (source « pays »). Un groupe dont le pays n''a aucune ville connue n''est pas rendu.';

REVOKE ALL ON FUNCTION public.villes_du_groupe_pays(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.villes_du_groupe_pays(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.villes_du_groupe_pays(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.groupe_pays_du_groupe_ville(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.groupe_pays_du_groupe_ville(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.groupe_pays_du_groupe_ville(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.coordonnees_des_groupes(uuid[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.coordonnees_des_groupes(uuid[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.coordonnees_des_groupes(uuid[]) TO authenticated;

REVOKE ALL ON FUNCTION public.ville_de_groupe(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ville_de_groupe(bigint) FROM anon;
GRANT EXECUTE ON FUNCTION public.ville_de_groupe(bigint) TO authenticated;
