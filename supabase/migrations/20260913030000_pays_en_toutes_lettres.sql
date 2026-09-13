-- Le pays s'écrit en toutes lettres (« Canada », « Algérie »), plus jamais en
-- code ISO — sur `users`, `groups` et `posts`, malgré le nom `country_code`
-- des colonnes, conservé pour ne pas casser les versions installées.
--
-- POURQUOI
-- La normalisation vers l'ISO-2 (tools/normalize_country_codes.sql, août)
-- n'a pas tenu : sa conversion côté app (`Country.toIsoCode`) ne connaissait
-- que 28 pays, alors que le sélecteur du profil en propose 197. Un pays hors
-- des 28 repartait en toutes lettres. Relevé en base le 2026-09-13 :
--   groups : NE ×3, CA, DZ, « Cap-Vert », « Angola »
--   users  : NE ×3, CA ×2, BF, DZ, « Angola »
-- Deux conséquences :
--   * l'unicité du groupe officiel (`uniq_official_group_per_country`) porte
--     sur ce texte exact : `AO` et `Angola` auraient fait deux groupes
--     officiels pour un même pays ;
--   * `get_or_create_official_group` nommait le groupe d'après le pays relu
--     en base, soit le code : « Diaspora Niger — NE », « — DZ ».
--
-- Décision (Salim, 2026-09-13) : plus de code ISO ; noms accentués ; le
-- groupe du Niger est gardé et renommé « Diaspora Niger — Niger ».
--
-- ET LE COMPTEUR DE MEMBRES
-- `update_group_member_count` tournait avec les droits de l'appelant. Quand un
-- membre ordinaire rejoint ou quitte un groupe, son `UPDATE groups` passe par
-- la policy `groups_update_admin`, qui le réduit à zéro ligne, sans erreur.
-- Seuls les ajouts faits dans une fonction SECURITY DEFINER (le créateur,
-- l'owner d'un groupe officiel) étaient comptés : 4 groupes officiels
-- affichaient 1 pour 2 membres, « Testeurs » 4 pour 2.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. Référentiel : la liste du sélecteur de l'app (ProfileOptions.countries),
--    générée depuis lib/core/constants/profile_options.dart.
--    `code_iso_herite` ne sert qu'à RECONNAÎTRE les anciennes valeurs.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pays (
  nom             text PRIMARY KEY,
  code_iso_herite text NOT NULL UNIQUE
);

COMMENT ON TABLE public.pays IS
  'Pays reconnus, sous leur nom affiché. Même liste que ProfileOptions.countries (app). code_iso_herite : lecture des anciennes valeurs uniquement, jamais écrit ailleurs.';

ALTER TABLE public.pays ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pays_lecture ON public.pays;
CREATE POLICY pays_lecture ON public.pays
  FOR SELECT TO anon, authenticated USING (true);

INSERT INTO public.pays (nom, code_iso_herite) VALUES
  ('Niger', 'NE'),
  ('France', 'FR'),
  ('États-Unis', 'US'),
  ('Canada', 'CA'),
  ('Belgique', 'BE'),
  ('Allemagne', 'DE'),
  ('Royaume-Uni', 'GB'),
  ('Italie', 'IT'),
  ('Espagne', 'ES'),
  ('Suisse', 'CH'),
  ('Maroc', 'MA'),
  ('Sénégal', 'SN'),
  ('Côte d''Ivoire', 'CI'),
  ('Bénin', 'BJ'),
  ('Togo', 'TG'),
  ('Burkina Faso', 'BF'),
  ('Mali', 'ML'),
  ('Cameroun', 'CM'),
  ('Gabon', 'GA'),
  ('Nigeria', 'NG'),
  ('Afrique du Sud', 'ZA'),
  ('Algérie', 'DZ'),
  ('Angola', 'AO'),
  ('Botswana', 'BW'),
  ('Burundi', 'BI'),
  ('Cap-Vert', 'CV'),
  ('Centrafrique', 'CF'),
  ('Comores', 'KM'),
  ('Congo', 'CG'),
  ('RD Congo', 'CD'),
  ('Djibouti', 'DJ'),
  ('Égypte', 'EG'),
  ('Érythrée', 'ER'),
  ('Eswatini', 'SZ'),
  ('Éthiopie', 'ET'),
  ('Gambie', 'GM'),
  ('Ghana', 'GH'),
  ('Guinée', 'GN'),
  ('Guinée-Bissau', 'GW'),
  ('Guinée équatoriale', 'GQ'),
  ('Kenya', 'KE'),
  ('Lesotho', 'LS'),
  ('Liberia', 'LR'),
  ('Libye', 'LY'),
  ('Madagascar', 'MG'),
  ('Malawi', 'MW'),
  ('Maurice', 'MU'),
  ('Mauritanie', 'MR'),
  ('Mozambique', 'MZ'),
  ('Namibie', 'NA'),
  ('Ouganda', 'UG'),
  ('Rwanda', 'RW'),
  ('Sao Tomé-et-Principe', 'ST'),
  ('Seychelles', 'SC'),
  ('Sierra Leone', 'SL'),
  ('Somalie', 'SO'),
  ('Soudan', 'SD'),
  ('Soudan du Sud', 'SS'),
  ('Tanzanie', 'TZ'),
  ('Tchad', 'TD'),
  ('Tunisie', 'TN'),
  ('Zambie', 'ZM'),
  ('Zimbabwe', 'ZW'),
  ('Albanie', 'AL'),
  ('Andorre', 'AD'),
  ('Autriche', 'AT'),
  ('Biélorussie', 'BY'),
  ('Bosnie-Herzégovine', 'BA'),
  ('Bulgarie', 'BG'),
  ('Chypre', 'CY'),
  ('Croatie', 'HR'),
  ('Danemark', 'DK'),
  ('Estonie', 'EE'),
  ('Finlande', 'FI'),
  ('Grèce', 'GR'),
  ('Hongrie', 'HU'),
  ('Irlande', 'IE'),
  ('Islande', 'IS'),
  ('Kosovo', 'XK'),
  ('Lettonie', 'LV'),
  ('Liechtenstein', 'LI'),
  ('Lituanie', 'LT'),
  ('Luxembourg', 'LU'),
  ('Macédoine du Nord', 'MK'),
  ('Malte', 'MT'),
  ('Moldavie', 'MD'),
  ('Monaco', 'MC'),
  ('Monténégro', 'ME'),
  ('Norvège', 'NO'),
  ('Pays-Bas', 'NL'),
  ('Pologne', 'PL'),
  ('Portugal', 'PT'),
  ('République tchèque', 'CZ'),
  ('Roumanie', 'RO'),
  ('Russie', 'RU'),
  ('Saint-Marin', 'SM'),
  ('Serbie', 'RS'),
  ('Slovaquie', 'SK'),
  ('Slovénie', 'SI'),
  ('Suède', 'SE'),
  ('Ukraine', 'UA'),
  ('Vatican', 'VA'),
  ('Mexique', 'MX'),
  ('Antigua-et-Barbuda', 'AG'),
  ('Bahamas', 'BS'),
  ('Barbade', 'BB'),
  ('Belize', 'BZ'),
  ('Costa Rica', 'CR'),
  ('Cuba', 'CU'),
  ('Dominique', 'DM'),
  ('El Salvador', 'SV'),
  ('Grenade', 'GD'),
  ('Guatemala', 'GT'),
  ('Haïti', 'HT'),
  ('Honduras', 'HN'),
  ('Jamaïque', 'JM'),
  ('Nicaragua', 'NI'),
  ('Panama', 'PA'),
  ('République dominicaine', 'DO'),
  ('Saint-Kitts-et-Nevis', 'KN'),
  ('Sainte-Lucie', 'LC'),
  ('Saint-Vincent-et-les-Grenadines', 'VC'),
  ('Trinité-et-Tobago', 'TT'),
  ('Argentine', 'AR'),
  ('Bolivie', 'BO'),
  ('Brésil', 'BR'),
  ('Chili', 'CL'),
  ('Colombie', 'CO'),
  ('Équateur', 'EC'),
  ('Guyana', 'GY'),
  ('Paraguay', 'PY'),
  ('Pérou', 'PE'),
  ('Suriname', 'SR'),
  ('Uruguay', 'UY'),
  ('Venezuela', 'VE'),
  ('Afghanistan', 'AF'),
  ('Arabie saoudite', 'SA'),
  ('Arménie', 'AM'),
  ('Azerbaïdjan', 'AZ'),
  ('Bahreïn', 'BH'),
  ('Bangladesh', 'BD'),
  ('Bhoutan', 'BT'),
  ('Brunei', 'BN'),
  ('Cambodge', 'KH'),
  ('Chine', 'CN'),
  ('Corée du Nord', 'KP'),
  ('Corée du Sud', 'KR'),
  ('Émirats arabes unis', 'AE'),
  ('Géorgie', 'GE'),
  ('Inde', 'IN'),
  ('Indonésie', 'ID'),
  ('Irak', 'IQ'),
  ('Iran', 'IR'),
  ('Israël', 'IL'),
  ('Japon', 'JP'),
  ('Jordanie', 'JO'),
  ('Kazakhstan', 'KZ'),
  ('Kirghizistan', 'KG'),
  ('Koweït', 'KW'),
  ('Laos', 'LA'),
  ('Liban', 'LB'),
  ('Malaisie', 'MY'),
  ('Maldives', 'MV'),
  ('Mongolie', 'MN'),
  ('Myanmar', 'MM'),
  ('Népal', 'NP'),
  ('Oman', 'OM'),
  ('Ouzbékistan', 'UZ'),
  ('Pakistan', 'PK'),
  ('Palestine', 'PS'),
  ('Philippines', 'PH'),
  ('Qatar', 'QA'),
  ('Singapour', 'SG'),
  ('Sri Lanka', 'LK'),
  ('Syrie', 'SY'),
  ('Tadjikistan', 'TJ'),
  ('Taïwan', 'TW'),
  ('Thaïlande', 'TH'),
  ('Timor oriental', 'TL'),
  ('Turkménistan', 'TM'),
  ('Turquie', 'TR'),
  ('Vietnam', 'VN'),
  ('Yémen', 'YE'),
  ('Australie', 'AU'),
  ('Fidji', 'FJ'),
  ('Kiribati', 'KI'),
  ('Îles Marshall', 'MH'),
  ('Micronésie', 'FM'),
  ('Nauru', 'NR'),
  ('Nouvelle-Zélande', 'NZ'),
  ('Palaos', 'PW'),
  ('Papouasie-Nouvelle-Guinée', 'PG'),
  ('Îles Salomon', 'SB'),
  ('Samoa', 'WS'),
  ('Tonga', 'TO'),
  ('Tuvalu', 'TV'),
  ('Vanuatu', 'VU')
ON CONFLICT (nom) DO UPDATE SET code_iso_herite = EXCLUDED.code_iso_herite;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. Reconnaître un pays écrit n'importe comment.
--    Même règle de pliage que `foldCountryName` côté app : si l'une change,
--    l'autre doit suivre.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.plier_nom_de_pays(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT btrim(regexp_replace(
           regexp_replace(
             lower(translate(p,
               'ÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇàáâãäåèéêëìíîïòóôõöùúûüç',
               'AAAAAAEEEEIIIIOOOOOUUUUCaaaaaaeeeeiiiiooooouuuuc')),
             '[’''`-]', ' ', 'g'),
           '\s+', ' ', 'g'))
$$;

-- SECURITY DEFINER : appelée depuis des déclencheurs qui tournent avec les
-- droits de l'utilisateur. Sans elle, une RLS mal réglée sur `pays` rendrait
-- `NULL` partout — la valeur brute repartirait en base sans un mot.
CREATE OR REPLACE FUNCTION public.pays_canonique(p text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT nom FROM public.pays
      WHERE public.plier_nom_de_pays(nom) = public.plier_nom_de_pays(p)
      LIMIT 1),
    (SELECT nom FROM public.pays
      WHERE code_iso_herite = upper(btrim(p))
      LIMIT 1)
  )
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3. Garde-fou à l'écriture. Les versions de l'app déjà installées écrivent
--    encore des codes (« CA ») : la base les ramène au nom. Un pays inconnu
--    (saisie libre) est gardé tel quel, une chaîne vide devient NULL.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.normaliser_pays()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.country_code := COALESCE(
    public.pays_canonique(NEW.country_code),
    NULLIF(btrim(NEW.country_code), '')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_normaliser_pays ON public.users;
CREATE TRIGGER trg_normaliser_pays
  BEFORE INSERT OR UPDATE OF country_code ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.normaliser_pays();

DROP TRIGGER IF EXISTS trg_normaliser_pays ON public.posts;
CREATE TRIGGER trg_normaliser_pays
  BEFORE INSERT OR UPDATE OF country_code ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.normaliser_pays();

-- `groups` a déjà son déclencheur de défaut (20260806170000) : il normalise
-- désormais aussi, et son défaut passe de 'NE' à 'Niger'.
CREATE OR REPLACE FUNCTION public.groups_country_code_defaut()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.country_code := COALESCE(
    public.pays_canonique(NEW.country_code),
    NULLIF(btrim(NEW.country_code), ''),
    'Niger'
  );
  RETURN NEW;
END;
$$;

ALTER TABLE public.groups ALTER COLUMN country_code SET DEFAULT 'Niger';

COMMENT ON COLUMN public.groups.country_code IS
  'Nom du pays en toutes lettres (public.pays.nom), jamais un code ISO malgré le nom de la colonne. Jamais nul : défaut Niger, sinon le groupe disparaît de « Découvrir » dès qu''un filtre pays est actif.';
COMMENT ON COLUMN public.users.country_code IS
  'Nom du pays en toutes lettres (public.pays.nom), jamais un code ISO malgré le nom de la colonne.';
COMMENT ON COLUMN public.posts.country_code IS
  'Pays de l''auteur à la publication, en toutes lettres (public.pays.nom).';

-- ─────────────────────────────────────────────────────────────────────────
-- 4. Reprise de l'existant.
-- ─────────────────────────────────────────────────────────────────────────

-- 4a. Refuser plutôt que deviner : si deux groupes officiels désignent le
--     même pays une fois convertis, l'index unique ferait échouer la
--     conversion — mieux vaut un message qui dit lequel.
DO $$
DECLARE
  v_doublons text;
BEGIN
  SELECT string_agg(pays, ', ') INTO v_doublons
    FROM (SELECT COALESCE(public.pays_canonique(country_code), country_code) AS pays
            FROM public.groups
           WHERE is_official
           GROUP BY 1
          HAVING count(*) > 1) d;
  IF v_doublons IS NOT NULL THEN
    RAISE EXCEPTION
      'Plusieurs groupes officiels pour : %. À trancher à la main avant cette migration.',
      v_doublons;
  END IF;
END;
$$;

-- 4b. Groupes officiels encore sous leur nom automatique : nom et
--     description suivent le pays en toutes lettres. Un nom ou une
--     description retouchés à la main ne sont pas écrasés.
--     Le gabarit peut porter l'ancienne valeur (« — NE ») ou déjà le nom :
--     « Diaspora Niger — Canada » date d'avant la normalisation ISO, sa
--     colonne valait `CA` mais son nom et sa description disaient « Canada ».
--     (Dans un SET, `g.country_code` est l'ancienne valeur.)
UPDATE public.groups g
   SET name = CASE
         WHEN g.name IN (format('Diaspora Niger — %s', g.country_code),
                         format('Diaspora Niger — %s', c.pays))
         THEN format('Diaspora Niger — %s', c.pays)
         ELSE g.name
       END,
       description = CASE
         WHEN g.description IN (
                format('Groupe officiel de la communauté nigérienne en %s.', g.country_code),
                format('Groupe officiel de la communauté nigérienne en %s.', c.pays))
         THEN format('Groupe officiel de la communauté nigérienne — %s.', c.pays)
         ELSE g.description
       END,
       country_code = c.pays
  FROM (SELECT id, public.pays_canonique(country_code) AS pays FROM public.groups) c
 WHERE c.id = g.id
   AND g.is_official
   AND c.pays IS NOT NULL;

-- 4c. Toutes les autres lignes. Un pays non reconnu reste tel quel.
UPDATE public.groups
   SET country_code = public.pays_canonique(country_code)
 WHERE public.pays_canonique(country_code) IS NOT NULL
   AND public.pays_canonique(country_code) IS DISTINCT FROM country_code;

UPDATE public.users
   SET country_code = public.pays_canonique(country_code)
 WHERE public.pays_canonique(country_code) IS NOT NULL
   AND public.pays_canonique(country_code) IS DISTINCT FROM country_code;
UPDATE public.users SET country_code = NULL WHERE btrim(country_code) = '';

UPDATE public.posts
   SET country_code = public.pays_canonique(country_code)
 WHERE public.pays_canonique(country_code) IS NOT NULL
   AND public.pays_canonique(country_code) IS DISTINCT FROM country_code;
UPDATE public.posts SET country_code = NULL WHERE btrim(country_code) = '';

-- ─────────────────────────────────────────────────────────────────────────
-- 5. Le groupe officiel d'un pays : cherché et créé sous le nom du pays.
--    Même signature qu'avant (les versions installées l'appellent avec un
--    code) ; `p_country_name` n'est plus lu, le nom vient du référentiel.
--    Un pays inconnu (saisie libre) n'ouvre plus de groupe officiel.
--    Le reste est repris tel quel de 20260813233000.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_or_create_official_group(p_country_code text, p_country_name text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
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
    WHERE country_code = v_pays AND is_official
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
  ON CONFLICT (country_code) WHERE is_official DO NOTHING
  RETURNING * INTO v_row;

  ALTER TABLE public.groups ENABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups ENABLE TRIGGER groups_guard_official;

  -- Course possible entre deux appels concurrents : si le nôtre a été ignoré
  -- par le conflit, on relit la ligne créée par l'autre appel -- son
  -- group_members a déjà été posé par cet autre appel, rien à ajouter.
  IF NOT FOUND THEN
    SELECT * INTO v_row FROM public.groups
      WHERE country_code = v_pays AND is_official
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

-- ─────────────────────────────────────────────────────────────────────────
-- 6. Compteur de membres : droits du propriétaire, puis recomptage.
--    Sans risque d'abus : une fonction `RETURNS trigger` ne s'appelle pas
--    directement, et elle ne touche que `member_count` du groupe de la ligne
--    `group_members` insérée ou supprimée — lignes que la RLS de
--    `group_members` gouverne déjà.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_group_member_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE groups SET member_count = GREATEST(member_count + 1, 0) WHERE id = NEW.group_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE groups SET member_count = GREATEST(member_count - 1, 0) WHERE id = OLD.group_id;
  END IF;
  RETURN NULL;
END;
$$;

UPDATE public.groups g
   SET member_count = c.n
  FROM (SELECT g2.id, count(m.user_id)::int AS n
          FROM public.groups g2
          LEFT JOIN public.group_members m ON m.group_id = g2.id
         GROUP BY g2.id) c
 WHERE c.id = g.id
   AND g.member_count IS DISTINCT FROM c.n;
