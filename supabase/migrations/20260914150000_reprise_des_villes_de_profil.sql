-- Reprise de l'existant : les profils dont la ville écrite à la main
-- correspond, sans ambiguïté, à une ville du référentiel.
--
-- CE QUI A ÉTÉ MESURÉ, LE 2026-09-14
-- Treize profils portent une ville. Rapprochés par `plier_nom_de_pays`
-- (minuscules, sans accent) DANS LEUR PAYS :
--
--   Niamey ×3 + « niamey » ×1 → Niamey (Niger)     ← la casse cesse de compter
--   Bouza, Dosso, Magaria     → leurs villes (Niger)
--   Kaduna                    → Kaduna (Nigeria)
--   Djelfa                    → Djelfa (Algérie)
--
-- Neuf profils. Les quatre autres restent du texte, et c'est exact :
--
--   « Almoustapha » — un prénom, aucune ville de ce nom nulle part ;
--   « Arewa »       — un DÉPARTEMENT du Niger, pas une ville ;
--   « test.diaspo@example.com » — l'adresse du compte de test ;
--   « Montréal »    — la ville existe, mais le profil N'A PAS DE PAYS. La
--                     relier poserait aussi le Canada, ce qui déplacerait
--                     quelqu'un d'un groupe officiel à un autre sans qu'il
--                     l'ait demandé. Décision de Salim : à proposer, pas à
--                     imposer. Le champ ville du profil s'en charge, la
--                     prochaine fois qu'il l'ouvrira.
--
-- POURQUOI « DANS LEUR PAYS », ET POURQUOI UNE SEULE CORRESPONDANCE
-- Le pays du profil est la seule chose qui lève l'ambiguïté : « Victoria »
-- existe dans sept pays. Et deux villes homonymes d'un même pays (les quatre
-- Springfield des États-Unis) ne permettent pas de choisir : ces profils-là
-- sont laissés tels quels plutôt que reliés au hasard.
--
-- DEUX EFFETS À CONNAÎTRE
-- `trg_ville_coherente_avec_pays` recopie le nom officiel dans `city` : la
-- ligne « niamey » devient « Niamey ». C'est voulu — c'est le doublon
-- d'écriture qui a motivé tout ce travail.
--
-- Et quatre profils visibles à Niamey, c'est plus que le seuil de trois :
-- `trg_ouvrir_groupe_de_ville` ouvrirait le groupe et enverrait quatre
-- invitations PENDANT le `db push`. On le neutralise le temps de la reprise.
-- Non pas pour éviter ces invitations — elles sont justes, et le balayage
-- quotidien (9 h 30) les enverra — mais pour que les données puissent être
-- relues avant que quiconque reçoive quoi que ce soit. Pour ne pas attendre :
--
--   SELECT public.ouvrir_groupes_de_ville_en_retard();

ALTER TABLE public.users DISABLE TRIGGER trg_ouvrir_groupe_de_ville;

UPDATE public.users u
   SET ville_id = c.ville_id
  FROM (
    SELECT u2.id AS user_id, min(v.id) AS ville_id
      FROM public.users u2
      JOIN public.villes v
        ON v.pays = u2.country_code
       AND v.nom_plie = public.plier_nom_de_pays(u2.city)
     WHERE u2.ville_id IS NULL
       AND u2.city IS NOT NULL
       AND btrim(u2.city) <> ''
     GROUP BY u2.id
    -- Une seule ville possible, sinon on ne choisit pas à la place des gens.
    HAVING count(*) = 1
  ) c
 WHERE u.id = c.user_id;

ALTER TABLE public.users ENABLE TRIGGER trg_ouvrir_groupe_de_ville;

-- Ce que la reprise a fait, et ce qu'elle a laissé : lisible dans la sortie
-- de `db push`, pas seulement dans l'intention de ce fichier.
DO $$
DECLARE
  v_relies integer;
  v_restants text;
  v_villes text;
BEGIN
  SELECT count(*) INTO v_relies FROM public.users WHERE ville_id IS NOT NULL;

  SELECT string_agg(format('%s (%s)', city, COALESCE(country_code, 'sans pays')), ', ' ORDER BY city)
    INTO v_restants
    FROM public.users
   WHERE ville_id IS NULL AND city IS NOT NULL AND btrim(city) <> '';

  SELECT string_agg(format('%s ×%s', nom, n), ', ' ORDER BY n DESC, nom)
    INTO v_villes
    FROM (
      SELECT v.nom, count(*) AS n
        FROM public.users u JOIN public.villes v ON v.id = u.ville_id
       GROUP BY v.nom
    ) t;

  RAISE NOTICE 'Reprise des villes : % profils reliés (%)', v_relies, COALESCE(v_villes, 'aucun');
  RAISE NOTICE 'Restent en texte libre : %', COALESCE(v_restants, 'aucun');
END;
$$;
