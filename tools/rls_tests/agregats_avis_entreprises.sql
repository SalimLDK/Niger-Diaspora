-- Banc : `businesses.rating` et `review_count` calculés par la base
-- (migration 20260921083000).
--
--   supabase db query --linked -f tools/rls_tests/agregats_avis_entreprises.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration, SANS ses lignes `BEGIN;` et `COMMIT;` — un `COMMIT` au
-- milieu du banc validerait tout ce qui précède, fiches d'essai comprises.
-- C'est la répétition. APRÈS, lancé tel quel, le banc prouve l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien. Mesuré le 2026-09-21 :
--   · SANS la migration (production telle quelle) : 13 ÉCHEC sur 19 ; seuls
--     passent 3, 6, 10, 11, 15 et 16 — ceux qui ne dépendent pas d'un calcul
--     (droits, écritures acceptées, fiche qui n'a jamais eu de note).
--   · Répétition AVEC : 19 OK sur 19. Rien resté en base ensuite (fiches,
--     avis, policies, déclencheur, fonctions : relu).
--
-- Le banc pose ses propres policies d'essai (`banc_avis_*`, effacées par le
-- `ROLLBACK`). Écrites avant la bascule (20260921090000), elles restent
-- nécessaires : le cas 17 fait noter sa propre fiche par le PATRON — le seul
-- chemin où la garde de `businesses` est réellement atteinte — et la vraie
-- policy de dépôt le lui refuse. Rejoué avec les deux migrations : 19/19.
--
-- La production porte 2 entreprises et 0 avis. Le banc ne touche aucune ligne
-- existante, sauf par le rattrapage de la migration pendant la répétition
-- (annulé). Aucun déclencheur de `businesses` ni de `business_reviews`
-- n'envoie de notification.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('patron',  '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('client1', 'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13'),
  ('client2', 'banc-avis-client-2'),
  ('fiche',   gen_random_uuid()::text),
  ('autre',   gen_random_uuid()::text),
  ('perimee', gen_random_uuid()::text);

-- Trois fiches d'essai, posées par le propriétaire de la table (hors RLS et
-- hors garde). `rating` au défaut (NULL) sauf la périmée.
INSERT INTO public.businesses (id, owner_id, name, description, category, is_active)
SELECT (SELECT v FROM ctx WHERE k = x)::uuid, (SELECT v FROM ctx WHERE k = 'patron'),
       'Banc avis — ' || x, 'fiche du banc', 'services', true
  FROM unnest(ARRAY['fiche', 'autre', 'perimee']) x;

-- La fiche PÉRIMÉE : deux avis publiés (4 et 2) et un signalé (5), mais des
-- compteurs à 0 — l'état exact de la production si un avis y était posé
-- aujourd'hui. Sans déclencheur, rien ne les corrige ; le rattrapage si.
-- (Sur l'état vivant, le déclencheur les calcule dès l'insertion : même
-- attendu, le cas vaut dans les deux modes.)
UPDATE public.businesses SET rating = 0, review_count = 0
 WHERE id = (SELECT v FROM ctx WHERE k = 'perimee')::uuid;

INSERT INTO public.business_reviews (business_id, user_id, rating, content, status)
SELECT (SELECT v FROM ctx WHERE k = 'perimee')::uuid, u, r, 'avis du banc', s
  FROM (VALUES ('banc-avis-p1', 4, 'published'),
               ('banc-avis-p2', 2, 'published'),
               ('banc-avis-p3', 5, 'flagged')) v(u, r, s);

-- @@MIGRATION@@

-- Policies d'ESSAI (voir l'en-tête) : un compte écrit ses propres avis.
CREATE POLICY banc_avis_select ON public.business_reviews
  FOR SELECT TO authenticated USING (true);
CREATE POLICY banc_avis_insert ON public.business_reviews
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.firebase_uid()) = user_id);
CREATE POLICY banc_avis_update ON public.business_reviews
  FOR UPDATE TO authenticated USING ((SELECT public.firebase_uid()) = user_id)
  WITH CHECK ((SELECT public.firebase_uid()) = user_id);
CREATE POLICY banc_avis_delete ON public.business_reviews
  FOR DELETE TO authenticated USING ((SELECT public.firebase_uid()) = user_id);

-- Lecture des compteurs d'une fiche, toujours depuis `postgres`.
CREATE FUNCTION pg_temp.etat(k text) RETURNS text LANGUAGE sql AS $$
  SELECT coalesce(rating::text, 'NULL') || ' / ' || review_count
    FROM public.businesses WHERE id = (SELECT v FROM ctx WHERE ctx.k = $1)::uuid
$$;

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'le déclencheur d''agrégat est posé sur business_reviews', 'présent',
       coalesce(string_agg(t.tgname, ','), '(absent)'),
       CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_trigger t
 WHERE NOT t.tgisinternal AND t.tgrelid = 'public.business_reviews'::regclass
   AND t.tgname = 'business_reviews_agreger';

-- LE POINT QUI FAIT TRAVERSER LA GARDE. En INVOKER, ou possédées par un autre
-- rôle que `postgres`, ces fonctions s'exécuteraient sous `authenticated`.
INSERT INTO resultat
SELECT 2, 'fonctions d''agrégat SECURITY DEFINER, à postgres',
       '2 × definer/postgres',
       coalesce(string_agg(p.proname || ':' || CASE WHEN p.prosecdef THEN 'definer' ELSE 'INVOKER' END
                           || '/' || pg_get_userbyid(p.proowner), ', ' ORDER BY p.proname), '(absentes)'),
       CASE WHEN count(*) = 2 AND bool_and(p.prosecdef)
                 AND bool_and(pg_get_userbyid(p.proowner) = 'postgres') THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_proc p
 WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('business_reviews_agreger', 'businesses_recalculer_avis');

INSERT INTO resultat
SELECT 3, 'le recalcul n''est pas un rpc ouvert', 'ni anon ni authenticated',
       coalesce(string_agg(r, ','), 'ni anon ni authenticated'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['anon', 'authenticated']) r
 WHERE EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'businesses_recalculer_avis'
                AND pronamespace = 'public'::regnamespace)
   AND has_function_privilege(r, 'public.businesses_recalculer_avis(uuid)', 'EXECUTE');

-- ═══ 2. Le rattrapage ══════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 4, 'fiche périmée : (4+2)/2, le signalé exclu', '3.00 / 2',
       pg_temp.etat('perimee'),
       CASE WHEN pg_temp.etat('perimee') = '3.00 / 2' THEN 'OK' ELSE 'ÉCHEC' END;

-- Toutes les fiches de la base, les 2 réelles comprises : chacune porte
-- l'agrégat de ses avis publiés. Sans avis, NULL / 0 — la fiche réelle à
-- `0.00` sans avis compte parmi les incohérences avant la migration.
INSERT INTO resultat
SELECT 5, 'toutes les fiches = agrégat de leurs avis publiés', '0 incohérente',
       count(*) || ' incohérente(s)' || coalesce(' : ' || string_agg(b.name, ', '), ''),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.businesses b
  LEFT JOIN (SELECT business_id, round(avg(rating), 2) m, count(*)::int c
               FROM public.business_reviews WHERE status = 'published'
              GROUP BY business_id) a ON a.business_id = b.id
 WHERE b.rating IS DISTINCT FROM a.m
    OR b.review_count IS DISTINCT FROM coalesce(a.c, 0);

-- ═══ 3. Des comptes déposent des avis, par PostgREST ═══════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'client1')))::text, true);
SET LOCAL ROLE authenticated;

-- Un client qui n'est PAS le propriétaire : sous `authenticated`, la policy
-- de `businesses` réduirait l'UPDATE de la fiche à 0 ligne, en silence. Seul
-- le chemin DEFINER (hors RLS) fait monter la note — cas 7 à 9. Le chemin où
-- la garde elle-même est atteinte est celui du propriétaire : cas 17.
DO $$
BEGIN
  INSERT INTO public.business_reviews (business_id, user_id, rating, content)
  VALUES ((SELECT v FROM ctx WHERE k = 'fiche')::uuid,
          (SELECT v FROM ctx WHERE k = 'client1'), 4, 'bien');
  INSERT INTO resultat VALUES (6, 'un client dépose un avis : accepté',
    'accepté', 'accepté', 'OK');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'un client dépose un avis : accepté',
    'accepté', 'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;
INSERT INTO resultat SELECT 7, 'après un avis à 4', '4.00 / 1', pg_temp.etat('fiche'),
  CASE WHEN pg_temp.etat('fiche') = '4.00 / 1' THEN 'OK' ELSE 'ÉCHEC' END;

SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'client2')))::text, true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  INSERT INTO public.business_reviews (business_id, user_id, rating, content)
  VALUES ((SELECT v FROM ctx WHERE k = 'fiche')::uuid,
          (SELECT v FROM ctx WHERE k = 'client2'), 5, 'parfait');
EXCEPTION WHEN OTHERS THEN NULL;  -- l'état ci-dessous le dira
END $$;
RESET ROLE;
INSERT INTO resultat SELECT 8, 'second avis à 5', '4.50 / 2', pg_temp.etat('fiche'),
  CASE WHEN pg_temp.etat('fiche') = '4.50 / 2' THEN 'OK' ELSE 'ÉCHEC' END;

-- Le premier client révise sa note.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'client1')))::text, true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  UPDATE public.business_reviews SET rating = 2
   WHERE business_id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid
     AND user_id = (SELECT v FROM ctx WHERE k = 'client1');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
RESET ROLE;
INSERT INTO resultat SELECT 9, 'client 1 révise 4 → 2', '3.50 / 2', pg_temp.etat('fiche'),
  CASE WHEN pg_temp.etat('fiche') = '3.50 / 2' THEN 'OK' ELSE 'ÉCHEC' END;

-- Une retouche qui ne touche pas la note : acceptée, compteurs inchangés.
SET LOCAL ROLE authenticated;
DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.business_reviews SET content = 'finalement moyen'
   WHERE business_id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid
     AND user_id = (SELECT v FROM ctx WHERE k = 'client1');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (10, 'retouche du texte : acceptée', '1 ligne',
    n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'retouche du texte : acceptée', '1 ligne',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

RESET ROLE;

-- Non-régression de la garde : même le PROPRIÉTAIRE de la fiche (le seul que
-- la policy laisse écrire) ne pose pas la note à la main.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'patron')))::text, true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  UPDATE public.businesses SET rating = 5, review_count = 999
   WHERE id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid;
  INSERT INTO resultat VALUES (11, 'le patron ne se met toujours pas 5 étoiles',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (11, 'le patron ne se met toujours pas 5 étoiles',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;
RESET ROLE;
INSERT INTO resultat SELECT 12, 'après retouche et PATCH refusé : inchangé', '3.50 / 2',
  pg_temp.etat('fiche'),
  CASE WHEN pg_temp.etat('fiche') = '3.50 / 2' THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 4. Modération, déplacement, suppression ═══════════════════════════════
-- Le serveur signale l'avis à 5 : il sort de la moyenne.
UPDATE public.business_reviews SET status = 'flagged'
 WHERE business_id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid
   AND user_id = (SELECT v FROM ctx WHERE k = 'client2');
INSERT INTO resultat SELECT 13, 'avis à 5 signalé : sort de la moyenne', '2.00 / 1',
  pg_temp.etat('fiche'),
  CASE WHEN pg_temp.etat('fiche') = '2.00 / 1' THEN 'OK' ELSE 'ÉCHEC' END;

-- Un avis rattaché à une autre fiche recalcule les deux.
UPDATE public.business_reviews SET business_id = (SELECT v FROM ctx WHERE k = 'autre')::uuid,
                                   status = 'published'
 WHERE business_id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid
   AND user_id = (SELECT v FROM ctx WHERE k = 'client2');
INSERT INTO resultat
SELECT 14, 'avis déplacé : les deux fiches recalculées', '2.00 / 1 | 5.00 / 1',
       pg_temp.etat('fiche') || ' | ' || pg_temp.etat('autre'),
       CASE WHEN pg_temp.etat('fiche') || ' | ' || pg_temp.etat('autre')
                 = '2.00 / 1 | 5.00 / 1' THEN 'OK' ELSE 'ÉCHEC' END;

-- Le client retire son avis, par PostgREST : la fiche retombe à « pas noté ».
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'client1')))::text, true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE n bigint;
BEGIN
  DELETE FROM public.business_reviews
   WHERE business_id = (SELECT v FROM ctx WHERE k = 'fiche')::uuid
     AND user_id = (SELECT v FROM ctx WHERE k = 'client1');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (15, 'le client retire son avis', '1 ligne',
    n || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (15, 'le client retire son avis', '1 ligne',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;
RESET ROLE;
INSERT INTO resultat SELECT 16, 'dernier avis retiré : plus de note', 'NULL / 0',
  pg_temp.etat('fiche'),
  CASE WHEN pg_temp.etat('fiche') = 'NULL / 0' THEN 'OK' ELSE 'ÉCHEC' END;

-- LA GARDE, VRAIMENT ATTEINTE. Pour un client quelconque, la policy de
-- `businesses` écarterait l'UPDATE avant la garde (voir la contre-épreuve) :
-- seul le PROPRIÉTAIRE de la fiche amène la garde sur le chemin. Rien
-- n'empêche un patron de noter sa propre fiche — c'est une question de
-- modération, pas de ce déclencheur ; ici il sert de sonde.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'patron')))::text, true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  INSERT INTO public.business_reviews (business_id, user_id, rating, content)
  VALUES ((SELECT v FROM ctx WHERE k = 'perimee')::uuid,
          (SELECT v FROM ctx WHERE k = 'patron'), 3, 'sonde');
  INSERT INTO ctx VALUES ('ce17', 'accepté');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO ctx VALUES ('ce17', 'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60));
END $$;
RESET ROLE;
INSERT INTO resultat
SELECT 17, 'le PATRON dépose un avis : la garde le laisse passer, note juste',
       'accepté, 3.00 / 3',
       (SELECT v FROM ctx WHERE k = 'ce17') || ', ' || pg_temp.etat('perimee'),
       CASE WHEN (SELECT v FROM ctx WHERE k = 'ce17') = 'accepté'
                 AND pg_temp.etat('perimee') = '3.00 / 3' THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 5. Contre-épreuve : ce que DEFINER évite ══════════════════════════════
-- Les mêmes fonctions repassées en INVOKER, pour montrer que les cas 6 à 16
-- ne passent pas par hasard. Mesuré, INVOKER casse de DEUX façons selon qui
-- dépose l'avis :
--   · un client quelconque : la policy `businesses_update_owner` réduit
--     l'UPDATE de la fiche à 0 ligne, EN SILENCE — l'avis est accepté, la
--     note reste figée. La garde n'est même pas atteinte.
--   · le propriétaire de la fiche : la policy le laisse passer, la garde lève
--     42501 « agrégats » — et c'est l'AVIS entier qui est refusé.
DO $$
BEGIN
  ALTER FUNCTION public.business_reviews_agreger() SECURITY INVOKER;
  ALTER FUNCTION public.businesses_recalculer_avis(uuid) SECURITY INVOKER;
  GRANT EXECUTE ON FUNCTION public.businesses_recalculer_avis(uuid) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'client1')))::text, true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  INSERT INTO public.business_reviews (business_id, user_id, rating, content)
  VALUES ((SELECT v FROM ctx WHERE k = 'autre')::uuid,
          (SELECT v FROM ctx WHERE k = 'client1'), 1, 'contre-épreuve');
  INSERT INTO ctx VALUES ('ce18', 'accepté');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO ctx VALUES ('ce18', 'REFUSÉ ' || SQLSTATE || ' ' || left(SQLERRM, 60));
END $$;
RESET ROLE;
INSERT INTO resultat
SELECT 18, 'contre-épreuve INVOKER, client : avis accepté, note FIGÉE',
       'accepté, 5.00 / 1',
       (SELECT v FROM ctx WHERE k = 'ce18') || ', ' || pg_temp.etat('autre'),
       CASE WHEN (SELECT v FROM ctx WHERE k = 'ce18') = 'accepté'
                 AND pg_temp.etat('autre') = '5.00 / 1' THEN 'OK' ELSE 'ÉCHEC' END;

SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'patron')))::text, true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  INSERT INTO public.business_reviews (business_id, user_id, rating, content)
  VALUES ((SELECT v FROM ctx WHERE k = 'autre')::uuid,
          (SELECT v FROM ctx WHERE k = 'patron'), 5, 'contre-épreuve');
  INSERT INTO resultat VALUES (19, 'contre-épreuve INVOKER, patron : la garde refuse l''avis',
    'refusé 42501 (agrégats)', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (19, 'contre-épreuve INVOKER, patron : la garde refuse l''avis',
    'refusé 42501 (agrégats)', 'refusé 42501 : ' || left(SQLERRM, 50),
    CASE WHEN SQLERRM LIKE '%agrégats%' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;
RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
