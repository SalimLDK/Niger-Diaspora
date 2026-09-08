-- =============================================================================
-- Annuaire des postes diplomatiques : table Supabase + jeu de depart
--
-- Le module « ambassades » lit aujourd'hui la collection Firestore `embassies`,
-- qui est **vide** : l'ecran affiche une liste vide depuis toujours. Cette
-- migration porte l'annuaire sur Supabase et le remplit avec les 32 postes
-- publies par le ministere des Affaires etrangeres (diplomatie.gouv.ne), releves
-- le 2026-09-07 sur les pages « Les ambassades » et « Les consulats ».
--
-- Trois choses a savoir sur ce jeu de donnees.
--
-- 1. LA SOURCE EST FAUTIVE PAR ENDROITS. 24 defauts ont ete releves : numeros
--    amputes d'un chiffre, codes postaux invalides, fautes dans les noms de
--    pays, et deux cas ou l'adresse e-mail AFFICHEE differe de celle vers
--    laquelle le lien pointe (Ankara, Cotonou). Ce qui pouvait etre corrige
--    avec certitude l'a ete ; le reste est repris tel que publie, avec la
--    reserve consignee dans `data_notes`. Aucune valeur n'a ete inventee : un
--    champ douteux est laisse NULL plutot que devine.
--
-- 2. `is_verified` VAUT `true` POUR LES 32 POSTES. Ce drapeau est la porte de
--    moderation de `embassiesListProvider`, qui masque tout ce qui n'est pas
--    verifie -- le laisser a `false` reviendrait a importer 32 lignes que
--    personne ne verrait. Il atteste ici de l'origine officielle de la fiche,
--    pas de l'exactitude de chaque champ : c'est `data_notes` qui porte cette
--    nuance, et l'ecran doit l'afficher.
--
-- 3. AUCUNE DES 31 ADRESSES E-MAIL N'EST SUR UN DOMAINE DE L'ETAT. 18 sont chez
--    Yahoo, 2 sont des noms de personnes. L'authenticite d'un contact
--    consulaire ne peut donc pas etre etablie par son domaine, et l'interface
--    ne doit pas laisser croire l'inverse.
--
-- Ce que cette migration ne fait PAS : les messages aux ambassades, les
-- employes et les demandes administratives restent sur Firestore. Seul
-- l'annuaire (la liste et la fiche) passe a Supabase.
-- =============================================================================

-- 1. La table ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.embassies (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Cle naturelle stable : permet de rejouer le seed sans creer de doublon,
  -- et de corriger une fiche par une nouvelle migration.
  slug                  text UNIQUE,

  name                  text NOT NULL,
  post_type             text NOT NULL DEFAULT 'embassy'
                          CHECK (post_type IN ('embassy', 'consulate', 'permanent_mission')),
  country               text NOT NULL,
  city                  text NOT NULL,
  address               text,

  phone                 text,
  -- Plusieurs postes publient 2 ou 3 lignes (Le Caire en a trois). Le modele
  -- n'en gardait qu'une, les autres etaient perdues a l'import.
  additional_phones     text[] NOT NULL DEFAULT '{}',
  fax                   text,
  email                 text,
  website               text,

  latitude              double precision,
  longitude             double precision,
  image_url             text,

  services              text[] NOT NULL DEFAULT '{}',
  upcoming_services     text[] NOT NULL DEFAULT '{}',
  opening_hours         jsonb  NOT NULL DEFAULT '{}'::jsonb,
  jurisdiction_countries text[] NOT NULL DEFAULT '{}',

  is_verified           boolean NOT NULL DEFAULT false,
  is_suspended          boolean NOT NULL DEFAULT false,
  verified_at           timestamptz,
  rejection_reason      text,

  is_temporarily_closed boolean NOT NULL DEFAULT false,
  closure_message       text,
  reopen_date           timestamptz,

  -- Tracabilite : d'ou vient la fiche, quand elle a ete confrontee a sa source,
  -- et ce qu'on sait de faux dedans.
  source                text,
  source_url            text,
  source_checked_at     timestamptz,
  data_notes            text,

  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS embassies_country_idx   ON public.embassies (country);
CREATE INDEX IF NOT EXISTS embassies_post_type_idx ON public.embassies (post_type);
-- La liste ne montre que les fiches verifiees et non suspendues : c'est le
-- filtre de tous les appels, il merite son index partiel.
CREATE INDEX IF NOT EXISTS embassies_visible_idx
  ON public.embassies (country, city)
  WHERE is_verified AND NOT is_suspended;

-- `updated_at` entretenu par la base, pas par le client.
CREATE OR REPLACE FUNCTION public.touch_embassies_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS embassies_touch_updated_at ON public.embassies;
CREATE TRIGGER embassies_touch_updated_at
  BEFORE UPDATE ON public.embassies
  FOR EACH ROW EXECUTE FUNCTION public.touch_embassies_updated_at();

-- 2. RLS ---------------------------------------------------------------------
-- L'annuaire est une donnee publique : aucune ligne ne contient de donnee
-- personnelle, et un usager doit pouvoir trouver son consulat avant meme
-- d'ouvrir un compte. La lecture est donc ouverte, y compris a `anon`.
ALTER TABLE public.embassies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "embassies_select_all" ON public.embassies;
CREATE POLICY "embassies_select_all" ON public.embassies
  FOR SELECT USING (TRUE);

-- L'ecriture est reservee au super-admin. Attention : `anon` dispose des
-- privileges INSERT/UPDATE/DELETE au niveau TABLE sur presque tout le schema,
-- et le RLS est la seule barriere -- d'ou le REVOKE explicite en plus des
-- politiques, pour que l'oubli d'une politique ne suffise pas a ouvrir la table.
DROP POLICY IF EXISTS "embassies_insert_admin" ON public.embassies;
CREATE POLICY "embassies_insert_admin" ON public.embassies
  FOR INSERT TO authenticated
  WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS "embassies_update_admin" ON public.embassies;
CREATE POLICY "embassies_update_admin" ON public.embassies
  FOR UPDATE TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS "embassies_delete_admin" ON public.embassies;
CREATE POLICY "embassies_delete_admin" ON public.embassies
  FOR DELETE TO authenticated
  USING (is_super_admin());

REVOKE INSERT, UPDATE, DELETE ON public.embassies FROM anon;
GRANT SELECT ON public.embassies TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.embassies TO authenticated;

-- 3. Le jeu de depart --------------------------------------------------------
-- `ON CONFLICT (slug)` : la migration est rejouable, et une correction future
-- se fait en reinserant la meme ligne.
INSERT INTO public.embassies (
  slug, name, post_type, country, city, address,
  phone, additional_phones, fax, email,
  jurisdiction_countries,
  is_verified, verified_at,
  source, source_url, source_checked_at, data_notes
) VALUES

-- --- Afrique ----------------------------------------------------------------
('abidjan-ambassade', 'Ambassade du Niger en Côte d''Ivoire', 'embassy',
 'Côte d''Ivoire', 'Abidjan', 'Marcory Résidentiel, BP 2743 Abidjan 01',
 '+225 21 26 28 14', '{}', '+225 21 26 41 88', 'ambassadeniger@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Numéros au format antérieur à la réforme ivoirienne de 2021, qui a porté les numéros à dix chiffres et préfixé les fixes d''Abidjan par 27. À reconfirmer auprès du poste.'),

('abuja-ambassade', 'Ambassade du Niger au Nigeria', 'embassy',
 'Nigeria', 'Abuja', 'Plot 933 Pope John Paul II Street, Maitama District',
 '+234 9 234 73 64', '{}', '+234 9 234 73 65', 'embniger@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('accra-ambassade', 'Ambassade du Niger au Ghana', 'embassy',
 'Ghana', 'Accra', 'E 104/3 Independence Avenue, P.O. Box 2685',
 '+233 30 222 4962', '{}', '+233 30 222 9011', 'ambaniggh@yahoo.com',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('addis-abeba-ambassade', 'Ambassade du Niger en Éthiopie', 'embassy',
 'Éthiopie', 'Addis-Abeba', 'Kirkos Sub-city, Kebele 02/03, House No 0547, P.O. Box 5791',
 '+251 11 465 1305', '{"+251 11 465 1175"}', '+251 11 465 1296', 'ambnigeradiss@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('alger-ambassade', 'Ambassade du Niger en Algérie', 'embassy',
 'Algérie', 'Alger', '54 rue du Vercos, Rostomia, Bouzaréah',
 '+213 21 93 71 90', '{}', '+213 21 93 95 89', 'ambassadenigeralger@hotmail.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('le-caire-ambassade', 'Ambassade du Niger en Égypte', 'embassy',
 'Égypte', 'Le Caire', '101 avenue des Pyramides, Guizeh',
 '+20 2 33 38 65 607', '{"+20 2 33 86 56 17","+20 2 386 53 70"}', '+20 2 33 86 56 90', 'ambanigercaire@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Les trois numéros publiés n''ont pas la même longueur : au moins un est mal saisi à la source, sans qu''on puisse dire lequel.'),

('cotonou-ambassade', 'Ambassade du Niger au Bénin', 'embassy',
 'Bénin', 'Cotonou', '01 BP 352 Cotonou',
 '+229 21 31 56 65', '{}', '+229 21 31 40 30', 'nigercotonou@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Adresse e-mail corrigée : le site affiche « amba@nigercotonou@yahoo.fr », avec deux arobases ; le lien pointe bien vers l''adresse retenue ici. Numéros au format antérieur au passage du Bénin à dix chiffres (fin 2022), à reconfirmer.'),

('dakar-ambassade', 'Ambassade du Niger au Sénégal', 'embassy',
 'Sénégal', 'Dakar', '8 avenue Léopold Sédar Senghor, BP 9095 CD',
 '+221 33 824 12 26', '{}', '+221 33 824 12 51', 'niger09@orange.sn',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('lome-ambassade', 'Ambassade du Niger au Togo', 'embassy',
 'Togo', 'Lomé', '13 rue Akati-Tokoin Hôpital, 14 BP 141',
 '+228 22 20 53 44', '{"+228 22 26 47 15"}', '+228 22 20 53 30', 'ambanigertogo@hotmail.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('pretoria-ambassade', 'Ambassade du Niger en Afrique du Sud', 'embassy',
 'Afrique du Sud', 'Pretoria', '648 Jan Shoba (ex-Duncan) Street, Hatfield, Pretoria',
 '+27 12 362 3926', '{}', '+27 12 362 3931', 'ambanigeras@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Adresse corrigée : le site écrit « Hatfiend » pour Hatfield, « Dulcan » pour Duncan, et colle « PretoriaAfriqueSud ».'),

('rabat-ambassade', 'Ambassade du Niger au Maroc', 'embassy',
 'Maroc', 'Rabat', 'Secteur 7, A4, avenue Al Haour, Hay Riad',
 '+212 537 56 68 39', '{}', NULL, 'aambassadeniger@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Fax non repris : le site publie « 00212 537 56 68 », amputé de deux chiffres. L''adresse e-mail commence bien par un double « a » à la source, reprise telle quelle faute de pouvoir trancher.'),

('tripoli-ambassade', 'Ambassade du Niger en Libye', 'embassy',
 'Libye', 'Tripoli', 'P.O. Box 2251 Tripoli',
 '+218 21 360 8990', '{}', '+218 21 478 1639', 'antripoli12@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

-- --- Europe et Turquie ------------------------------------------------------
('ankara-ambassade', 'Ambassade du Niger en Turquie', 'embassy',
 'Turquie', 'Ankara', 'Mahatma Gandhi Caddesi n° 40, Çankaya',
 '+90 312 436 10 13', '{}', NULL, 'ankara@ambaniger-tr.org',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Adresse e-mail corrigée : le site AFFICHE « ankara@ambaniger-tr.org » mais son lien pointe vers « nkara@… », le « a » initial étant du texte posé hors du lien. Fax non repris : « 0090 312 461017 » est trop court d''un chiffre.'),

('berlin-ambassade', 'Ambassade du Niger en Allemagne', 'embassy',
 'Allemagne', 'Berlin', 'Machnower Str. 24, Berlin',
 '+49 30 80 58 96 60', '{"+49 30 80 58 96 61"}', '+49 30 80 58 96 62', 'ambaniger@t-online.de',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Code postal non repris : le site publie « Machnower Str. 24 14 65 », soit quatre chiffres là où un code allemand en compte cinq, et sans mention de la ville. À compléter avant tout géocodage.'),

('bruxelles-ambassade', 'Ambassade du Niger en Belgique', 'embassy',
 'Belgique', 'Bruxelles', '78 avenue Franklin Roosevelt, 1050 Bruxelles',
 '+32 2 648 59 60', '{"+32 2 648 61 40"}', '+32 2 648 27 84', 'ambassadedunigerbelgique@yahoo.be',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('copenhague-ambassade', 'Ambassade du Niger au Danemark', 'embassy',
 'Danemark', 'Copenhague', 'Niels Juels Gade 5, København K',
 '+45 44 22 09 99', '{}', '+45 44 22 09 92', 'ambassade@niger.dk',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Code postal non repris : le site publie « Dk-059 », or les codes danois comptent quatre chiffres.'),

('paris-ambassade', 'Ambassade du Niger en France', 'embassy',
 'France', 'Paris', '154 rue de Longchamp, 75116 Paris',
 '+33 1 45 04 80 60', '{}', '+33 1 45 04 79 73', 'ambassadeniger@wanadoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Arrondissement corrigé : le site écrit « Paris 13ème » alors que le code postal 75116 désigne le 16ᵉ.'),

('rome-ambassade', 'Ambassade du Niger en Italie', 'embassy',
 'Italie', 'Rome', 'Via Antonio Baiamonti, Roma',
 '+39 06 372 0164', '{"+39 06 3751 1947"}', '+39 06 3729 013', 'ambasciatadelniger@virgilio.it',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Numéro de rue et code postal non repris : le site les publie fusionnés en « 1001095 », qui n''est ni l''un ni l''autre — un CAP italien compte cinq chiffres.'),

-- --- Amériques --------------------------------------------------------------
('la-havane-ambassade', 'Ambassade du Niger à Cuba', 'embassy',
 'Cuba', 'La Havane', NULL,
 NULL, '{}', NULL, NULL,
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Aucune coordonnée publiée : le ministère annonce le poste avec « -- » dans les quatre champs. Fiche conservée pour signaler son existence, mais le poste est injoignable en l''état.'),

('washington-ambassade', 'Ambassade du Niger aux États-Unis', 'embassy',
 'États-Unis', 'Washington DC', '2204 R Street, Washington D.C.',
 '+1 202 483 4224', '{}', '+1 202 483 9052', 'communication@embassyofniger.org',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Fax corrigé : le site publie « 00202 483 90 52 », dont l''indicatif pays 202 n''existe pas — le 1 des États-Unis est tombé à la saisie.'),

-- --- Asie et Golfe ----------------------------------------------------------
('doha-ambassade', 'Ambassade du Niger au Qatar', 'embassy',
 'Qatar', 'Doha', NULL,
 NULL, '{}', NULL, 'abdoulbonz@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Aucun téléphone ni adresse publiés — le champ adresse du site ne répète que « DOHA QATAR ». Le seul contact est une boîte au nom d''une personne, qui cessera de servir à sa mutation.'),

('koweit-ambassade', 'Ambassade du Niger au Koweït', 'embassy',
 'Koweït', 'Koweït', 'B.P. 4451 Hawali 32059',
 '+965 2565 2943', '{}', '+965 2564 0478', 'ambanikwt@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('new-delhi-ambassade', 'Ambassade du Niger en Inde', 'embassy',
 'Inde', 'New Delhi', '53 Paschimi Marg, Vasant Vihar',
 '+91 11 2615 0160', '{}', '+91 11 2615 0163', 'ambanigerindia@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 NULL),

('pekin-ambassade', 'Ambassade du Niger en Chine', 'embassy',
 'Chine', 'Pékin', '1-21 San Li Tun Diplomatic Compound, Beijing 100600',
 '+86 10 6532 4274', '{}', '+86 10 6532 7041', 'middahmaimouna@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'L''adresse e-mail publiée est au nom d''une personne, pas du poste : elle cessera de servir à son départ.'),

('riyad-ambassade', 'Ambassade du Niger en Arabie saoudite', 'embassy',
 'Arabie saoudite', 'Riyad', 'P.O. Box 94334, Riyad 11693',
 '+966 146 59 31', '{}', '+966 1205 43 23', 'ambanigerriyadh@gmail.com',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-ambassades', '2026-09-07',
 'Les deux numéros portent un indicatif de zone à un chiffre, format antérieur à la réforme saoudienne de 2013 qui a fait passer Riyad de 1 à 11 : ils sont vraisemblablement périmés. Le pays est par ailleurs orthographié « Arabie Soudite » à la source.'),

-- --- Représentations permanentes --------------------------------------------
-- Ni ambassades bilatérales ni consulats : ces trois postes représentent le
-- Niger auprès d'une organisation. Le site les fait figurer à la fois dans
-- « Les ambassades » et dans une page dédiée -- avec, pour Genève, deux
-- numéros de téléphone différents.
('geneve-mission', 'Mission permanente du Niger à Genève', 'permanent_mission',
 'Suisse', 'Genève', '23 avenue de France, 1202 Genève',
 '+41 22 979 24 52', '{}', '+41 22 979 24 51', 'missionduniger1@gmail.com',
 '{"Suisse","Autriche","Liechtenstein"}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-representations-et-les-delegations-permanentes-aupres-des-organisations-internationales', '2026-09-07',
 'Téléphone repris de la page « représentations permanentes » du ministère (…452). La page des ambassades publie par erreur le numéro de fax (…451) dans les deux champs.'),

('new-york-mission', 'Mission permanente du Niger auprès des Nations unies', 'permanent_mission',
 'États-Unis', 'New York', '417 East 50th Street, New York NY',
 '+1 212 421 3260', '{}', '+1 212 753 6931', 'nigermission@ymail.com',
 '{"Venezuela"}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-representations-et-les-delegations-permanentes-aupres-des-organisations-internationales', '2026-09-07',
 'Accréditée auprès des Nations unies et du Venezuela. Pour les États-Unis, le poste compétent est l''ambassade à Washington.'),

('paris-unesco-mission', 'Délégation permanente du Niger auprès de l''UNESCO', 'permanent_mission',
 'France', 'Paris', '1 rue Miollis, 75015 Paris',
 '+33 1 45 68 25 68', '{}', '+33 1 45 68 25 69', NULL,
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-representations-et-les-delegations-permanentes-aupres-des-organisations-internationales', '2026-09-07',
 'Adresse e-mail non reprise : le ministère publie « dl.niger@unesco_delegations.org », dont le domaine contient un underscore — interdit dans un nom d''hôte, donc non délivrable. Pour les démarches en France, s''adresser à l''ambassade à Paris.'),

-- --- Consulats --------------------------------------------------------------
('djeddah-consulat', 'Consulat général du Niger à Djeddah', 'consulate',
 'Arabie saoudite', 'Djeddah', 'B.P. 1709 Djeddah 21441',
 '+966 2 667 7795', '{"+966 12 673 0068"}', '+966 2 275 6792', 'Djeddah_consulatgnralniger@yahoo.fr',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-consulats', '2026-09-07',
 NULL),

('dubai-consulat', 'Consulat général du Niger à Dubaï', 'consulate',
 'Émirats arabes unis', 'Dubaï', 'Abau Hain Street, Hamdane Area, Villa 130, Deira, P.O. Box 34464',
 '+971 4 266 4642', '{}', '+971 4 266 4645', 'nigerdxb@emirates.net.ae',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-consulats', '2026-09-07',
 NULL),

('kano-consulat', 'Consulat général du Niger à Kano', 'consulate',
 'Nigeria', 'Kano', 'N° 1A Katsina Road, P.O. Box 909',
 '+234 802 529 9396', '{}', NULL, 'consulatgenkano@yahoo.com',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-consulats', '2026-09-07',
 'Pays et adresse corrigés : le site écrit « NIDERIA » pour Nigeria, et « Nà1A » pour « N° 1A » — le degré y est corrompu par un défaut d''encodage.'),

('khartoum-consulat', 'Consulat général du Niger à Khartoum', 'consulate',
 'Soudan', 'Khartoum', 'P.O. Box 8245 Khartoum',
 '+249 18 347 1187', '{}', '+249 18 347 1187', 'dipnigkh@yahoo.com',
 '{}', TRUE, now(),
 'diplomatie.gouv.ne', 'https://diplomatie.gouv.ne/index.php/representations-diplomatiques/les-consulats', '2026-09-07',
 'Le téléphone et le fax publiés sont le même numéro.')

ON CONFLICT (slug) DO UPDATE SET
  name                   = EXCLUDED.name,
  post_type              = EXCLUDED.post_type,
  country                = EXCLUDED.country,
  city                   = EXCLUDED.city,
  address                = EXCLUDED.address,
  phone                  = EXCLUDED.phone,
  additional_phones      = EXCLUDED.additional_phones,
  fax                    = EXCLUDED.fax,
  email                  = EXCLUDED.email,
  jurisdiction_countries = EXCLUDED.jurisdiction_countries,
  source                 = EXCLUDED.source,
  source_url             = EXCLUDED.source_url,
  source_checked_at      = EXCLUDED.source_checked_at,
  data_notes             = EXCLUDED.data_notes;

COMMENT ON TABLE public.embassies IS
  'Annuaire des postes diplomatiques et consulaires du Niger. Jeu de départ relevé le 2026-09-07 sur diplomatie.gouv.ne ; voir data_notes pour les réserves fiche par fiche.';
COMMENT ON COLUMN public.embassies.is_verified IS
  'Porte de modération de la liste : atteste l''origine officielle de la fiche, pas l''exactitude de chaque champ. La réserve est dans data_notes.';
COMMENT ON COLUMN public.embassies.data_notes IS
  'Ce qu''on sait de faux ou d''incertain dans la fiche, en clair, destiné à être affiché à l''usager.';
