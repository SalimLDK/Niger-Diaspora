-- Banc : les avis sur les entreprises passent sur Supabase
-- (migrations 20260921083000 puis 20260921090000).
--
--   supabase db query --linked -f tools/rls_tests/avis_entreprises_sur_supabase.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- des DEUX migrations, dans l'ordre, SANS leurs lignes `BEGIN;` / `COMMIT;`
-- (un `COMMIT` au milieu du banc validerait les fiches d'essai). C'est la
-- répétition. APRÈS, lancé tel quel, le banc prouve l'état vivant.
--
-- Mesuré le 2026-09-21 (production portant 20260921080000) :
--   · SANS les deux migrations : 34 ÉCHEC sur 41 ; seuls passent 6, 7, 12,
--     15, 32, 38 et 40 — ceux où « tout refuser » (RLS sans policy) donne
--     par hasard la bonne réponse.
--   · Répétition AVEC : 41 OK sur 41.
--
-- Les comptes sont RÉELS (la policy de dépôt et le déclencheur d'identité
-- lisent `users`) ; le banc ne modifie aucune de leurs lignes. Il crée une
-- fiche d'essai et des avis que le `ROLLBACK` efface, ainsi que les
-- signalements. Aucun déclencheur de `reports`, `business_reviews` ou
-- `businesses` n'envoie de notification.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('patron',  '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('client1', 'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13'),
  ('fiche',   gen_random_uuid()::text);

-- Trois autres comptes réels, ni patron ni client1 ni administrateur : les
-- signalants.
INSERT INTO ctx
SELECT 'client' || (row_number() OVER (ORDER BY id) + 1), id
  FROM (SELECT id FROM public.users
         WHERE id NOT IN ('1X5F6RKlrTgyxZFSTvS6lXBx8C32', 'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13')
           AND NOT coalesce(is_admin, false)
         ORDER BY id LIMIT 3) x;

INSERT INTO ctx SELECT 'admin', id FROM public.users WHERE is_admin ORDER BY id LIMIT 1;

CREATE FUNCTION pg_temp.v(p text) RETURNS text LANGUAGE sql STABLE AS
  $$ SELECT v FROM ctx WHERE k = p $$;

-- Endosse un compte : les claims, puis `SET LOCAL ROLE` à la ligne suivante.
CREATE FUNCTION pg_temp.qui(p text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    jsonb_build_object('role', 'authenticated', 'app_metadata',
      jsonb_build_object('firebase_uid', pg_temp.v(p)))::text, true);
$$;

-- Un essai : exécute `p_sql` sous le rôle courant et note « accepté N » (N =
-- lignes touchées ou lues) ou « refusé <SQLSTATE> ».
CREATE FUNCTION pg_temp.essai(p_n int, p_cas text, p_attendu text, p_sql text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  n bigint;
  o text;
BEGIN
  BEGIN
    EXECUTE p_sql;
    GET DIAGNOSTICS n = ROW_COUNT;
    o := 'accepté ' || n;
  EXCEPTION WHEN OTHERS THEN
    o := 'refusé ' || SQLSTATE;
  END;
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, o,
    CASE WHEN o = p_attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- Note et nombre d'avis de la fiche d'essai, lus depuis `postgres`.
CREATE FUNCTION pg_temp.etat() RETURNS text LANGUAGE sql AS $$
  SELECT coalesce(rating::text, 'NULL') || ' / ' || review_count
    FROM public.businesses WHERE id = pg_temp.v('fiche')::uuid
$$;

CREATE FUNCTION pg_temp.constat(p_n int, p_cas text, p_attendu text, p_obtenu text)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, coalesce(p_obtenu, '(null)'),
    CASE WHEN p_obtenu IS NOT DISTINCT FROM p_attendu THEN 'OK' ELSE 'ÉCHEC' END);
$$;

INSERT INTO public.businesses (id, owner_id, name, description, category, is_active)
VALUES (pg_temp.v('fiche')::uuid, pg_temp.v('patron'),
        'Banc avis — fiche', 'fiche du banc', 'services', true);

-- @@MIGRATION@@

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
SELECT pg_temp.constat(1, 'anon : aucun droit sur business_reviews', '(aucun)',
  coalesce((SELECT string_agg(p, ',') FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE',
            'TRUNCATE','REFERENCES','TRIGGER']) p
            WHERE has_table_privilege('anon', 'public.business_reviews', p)), '(aucun)'));

-- Ce que le client n'écrit JAMAIS lui-même.
SELECT pg_temp.constat(2, 'authenticated : ni statut, ni « utile », ni réponse, ni identité',
  '(aucune colonne)',
  coalesce((SELECT string_agg(c || ':' || p, ',' ORDER BY c, p)
     FROM unnest(ARRAY['status','helpful_count','helpful_by_user_ids','user_display_name',
                       'user_photo_url','owner_reply','owner_reply_at','created_at']) c,
          unnest(ARRAY['INSERT','UPDATE']) p
    WHERE EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'business_reviews' AND column_name = c)
      AND has_column_privilege('authenticated', 'public.business_reviews', c, p)),
     '(aucune colonne)'));

SELECT pg_temp.constat(3, 'authenticated : ni TRUNCATE, ni REFERENCES, ni TRIGGER', '(aucun)',
  coalesce((SELECT string_agg(p, ',') FROM unnest(ARRAY['TRUNCATE','REFERENCES','TRIGGER']) p
            WHERE has_table_privilege('authenticated', 'public.business_reviews', p)), '(aucun)'));

SELECT pg_temp.constat(4, 'les 3 fonctions : authenticated oui, anon non', '3 / 0',
  (SELECT count(*) FILTER (WHERE has_function_privilege('authenticated', p.oid, 'EXECUTE'))
          || ' / ' ||
          count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE'))
     FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace
      AND p.proname IN ('avis_marquer_utile', 'avis_repondre', 'avis_signaler')
   HAVING count(*) = 3));

-- ═══ 2. Déposer ════════════════════════════════════════════════════════════
SELECT pg_temp.qui('client1');
SET LOCAL ROLE authenticated;

SELECT pg_temp.essai(5, 'client1 dépose son avis (4 étoiles)', 'accepté 1', format(
  $q$INSERT INTO public.business_reviews (business_id, user_id, rating, title, content, image_urls)
     VALUES (%L, %L, 4, 'Bien', 'Accueil chaleureux', '{}')$q$,
  pg_temp.v('fiche'), pg_temp.v('client1')));

SELECT pg_temp.essai(6, 'un nom d''affichage fourni par le client : refusé', 'refusé 42501', format(
  $q$INSERT INTO public.business_reviews (business_id, user_id, user_display_name, rating, content)
     VALUES (%L, %L, 'Le Président', 5, 'faux nom')$q$,
  pg_temp.v('fiche'), pg_temp.v('client2')));

SELECT pg_temp.essai(7, 'client1 dépose un avis AU NOM de client2', 'refusé 42501', format(
  $q$INSERT INTO public.business_reviews (business_id, user_id, rating, content)
     VALUES (%L, %L, 1, 'usurpé')$q$,
  pg_temp.v('fiche'), pg_temp.v('client2')));

SELECT pg_temp.essai(8, 'un second avis sur la même fiche', 'refusé 23505', format(
  $q$INSERT INTO public.business_reviews (business_id, user_id, rating, content)
     VALUES (%L, %L, 5, 'encore')$q$,
  pg_temp.v('fiche'), pg_temp.v('client1')));

SELECT pg_temp.essai(9, 'le statut ou le compteur « utile » posés à la main', 'refusé 42501', format(
  $q$UPDATE public.business_reviews SET status = 'published', helpful_count = 99
      WHERE business_id = %L AND user_id = %L$q$,
  pg_temp.v('fiche'), pg_temp.v('client1')));

RESET ROLE;

SELECT pg_temp.constat(10, 'le nom affiché vient de users, pas du client', 'oui',
  (SELECT CASE WHEN r.user_display_name = coalesce(nullif(btrim(u.display_name), ''), '')
               THEN 'oui' ELSE 'non : ' || r.user_display_name END
     FROM public.business_reviews r JOIN public.users u ON u.id = r.user_id
    WHERE r.business_id = pg_temp.v('fiche')::uuid AND r.user_id = pg_temp.v('client1')));

SELECT pg_temp.constat(11, 'la note de la fiche suit (déclencheur d''agrégat)', '4.00 / 1', pg_temp.etat());

SELECT pg_temp.qui('patron');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'le patron note sa propre fiche', 'refusé 42501', format(
  $q$INSERT INTO public.business_reviews (business_id, user_id, rating, content)
     VALUES (%L, %L, 5, 'moi-même')$q$,
  pg_temp.v('fiche'), pg_temp.v('patron')));
RESET ROLE;

-- ═══ 3. Retoucher ══════════════════════════════════════════════════════════
-- `now()` est figé pour toute la transaction : pour voir « modifié le »
-- bouger (ou non), on le recule d'abord à 2020, depuis `postgres`.
INSERT INTO ctx SELECT 'avis', id::text FROM public.business_reviews
 WHERE business_id = pg_temp.v('fiche')::uuid AND user_id = pg_temp.v('client1');
UPDATE public.business_reviews SET updated_at = '2020-01-01Z'
 WHERE id = pg_temp.v('avis')::uuid;

SELECT pg_temp.qui('client1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(13, 'client1 retouche son avis (4 → 2)', 'accepté 1', format(
  $q$UPDATE public.business_reviews SET rating = 2, content = 'Déçu finalement'
      WHERE business_id = %L AND user_id = %L$q$,
  pg_temp.v('fiche'), pg_temp.v('client1')));
RESET ROLE;
SELECT pg_temp.constat(14, 'la note suit la retouche, « modifié le » avance', '2.00 / 1, oui',
  pg_temp.etat() || ', ' ||
  (SELECT CASE WHEN updated_at > '2020-01-01Z' THEN 'oui' ELSE 'non' END
     FROM public.business_reviews WHERE id = pg_temp.v('avis')::uuid));

UPDATE public.business_reviews SET updated_at = '2020-01-01Z'
 WHERE id = pg_temp.v('avis')::uuid;

SELECT pg_temp.qui('client2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(15, 'client2 réécrit l''avis de client1', 'accepté 0', format(
  $q$UPDATE public.business_reviews SET rating = 5 WHERE id = %L$q$, pg_temp.v('avis')));

-- ═══ 4. « Utile » ══════════════════════════════════════════════════════════
SELECT pg_temp.essai(16, 'client2 trouve l''avis utile', 'accepté 1', format(
  $q$SELECT public.avis_marquer_utile(%L, true)$q$, pg_temp.v('avis')));
SELECT pg_temp.essai(17, '… deux fois', 'accepté 1', format(
  $q$SELECT public.avis_marquer_utile(%L, true)$q$, pg_temp.v('avis')));
RESET ROLE;
SELECT pg_temp.constat(18, 'un compte ne compte qu''une fois', '1 / 1',
  (SELECT helpful_count || ' / ' || cardinality(helpful_by_user_ids)
     FROM public.business_reviews WHERE id = pg_temp.v('avis')::uuid));

SELECT pg_temp.qui('client1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(19, 'l''auteur se trouve utile lui-même', 'refusé P0002', format(
  $q$SELECT public.avis_marquer_utile(%L, true)$q$, pg_temp.v('avis')));
RESET ROLE;

SELECT pg_temp.qui('client2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'client2 retire son « utile »', 'accepté 1', format(
  $q$SELECT public.avis_marquer_utile(%L, false)$q$, pg_temp.v('avis')));

-- ═══ 5. Réponse du gérant ══════════════════════════════════════════════════
SELECT pg_temp.essai(21, 'client2 répond à la place du gérant', 'refusé 42501', format(
  $q$SELECT public.avis_repondre(%L, 'je ne suis pas le gérant')$q$, pg_temp.v('avis')));
RESET ROLE;

SELECT pg_temp.qui('patron');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(22, 'le patron répond à l''avis', 'accepté 1', format(
  $q$SELECT public.avis_repondre(%L, '  Merci, nous corrigeons.  ')$q$, pg_temp.v('avis')));
RESET ROLE;

-- Lu par `to_jsonb` : sans la migration, `owner_reply` n'existe pas et une
-- référence directe ferait tomber tout le banc au lieu de ce seul cas.
SELECT pg_temp.constat(23, 'réponse posée, « utile » à 0, « modifié le » intact', 'ok',
  (SELECT CASE WHEN j->>'owner_reply' = 'Merci, nous corrigeons.'
                    AND j->>'owner_reply_at' IS NOT NULL
                    AND (j->>'helpful_count')::int = 0
                    AND (j->>'updated_at')::timestamptz = '2020-01-01Z'
               THEN 'ok'
               ELSE coalesce(j->>'owner_reply', '(null)') || ' / ' || (j->>'helpful_count')
                    || ' / maj ' || (j->>'updated_at') END
     FROM (SELECT to_jsonb(r) j FROM public.business_reviews r
            WHERE r.id = pg_temp.v('avis')::uuid) x));

-- ═══ 6. Signalement ════════════════════════════════════════════════════════
SELECT pg_temp.qui('client1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(24, 'l''auteur signale son propre avis', 'refusé P0002', format(
  $q$SELECT public.avis_signaler(%L, 'moi')$q$, pg_temp.v('avis')));
RESET ROLE;

SELECT pg_temp.qui('client2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(25, 'client2 signale', 'accepté 1', format(
  $q$SELECT public.avis_signaler(%L, 'propos injurieux')$q$, pg_temp.v('avis')));
SELECT pg_temp.essai(26, 'client2 resignale (ne compte pas deux fois)', 'accepté 1', format(
  $q$SELECT public.avis_signaler(%L, 'encore')$q$, pg_temp.v('avis')));
RESET ROLE;

SELECT pg_temp.qui('client3');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(27, 'client3 signale', 'accepté 1', format(
  $q$SELECT public.avis_signaler(%L, 'faux avis')$q$, pg_temp.v('avis')));
RESET ROLE;

SELECT pg_temp.constat(28, 'deux signalants : toujours publié', 'published / 2',
  (SELECT r.status || ' / ' || (SELECT count(*) FROM public.reports
                                 WHERE target_type = 'business_review'
                                   AND target_id = pg_temp.v('avis'))
     FROM public.business_reviews r WHERE r.id = pg_temp.v('avis')::uuid));

SELECT pg_temp.qui('client4');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(29, 'client4 signale (troisième)', 'accepté 1', format(
  $q$SELECT public.avis_signaler(%L, 'spam')$q$, pg_temp.v('avis')));
RESET ROLE;

SELECT pg_temp.constat(30, 'trois signalants : l''avis est retiré de la moyenne', 'flagged, NULL / 0',
  (SELECT status || ', ' || pg_temp.etat()
     FROM public.business_reviews WHERE id = pg_temp.v('avis')::uuid));

SELECT pg_temp.constat(31, 'le signalement arrive au back-office, avec le texte', 'ok',
  (SELECT CASE WHEN count(*) = 3 AND bool_and(content_snapshot->>'text' = 'Déçu finalement')
                    AND bool_and(content_snapshot->'metadata'->>'business_id' = pg_temp.v('fiche'))
               THEN 'ok' ELSE count(*) || ' signalement(s)' END
     FROM public.reports WHERE target_type = 'business_review' AND target_id = pg_temp.v('avis')));

-- ═══ 7. Lecture ════════════════════════════════════════════════════════════
SELECT pg_temp.qui('client3');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(32, 'un avis signalé n''est plus lu par le public', 'accepté 0', format(
  $q$SELECT 1 FROM public.business_reviews WHERE id = %L$q$, pg_temp.v('avis')));
RESET ROLE;

SELECT pg_temp.qui('client1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(33, '… mais par son auteur', 'accepté 1', format(
  $q$SELECT 1 FROM public.business_reviews WHERE id = %L$q$, pg_temp.v('avis')));
RESET ROLE;

SELECT pg_temp.qui('patron');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(34, '… et par le gérant de la fiche', 'accepté 1', format(
  $q$SELECT 1 FROM public.business_reviews WHERE id = %L$q$, pg_temp.v('avis')));
RESET ROLE;

SET LOCAL ROLE anon;
SELECT pg_temp.essai(35, 'anon ne lit rien', 'refusé 42501', format(
  $q$SELECT 1 FROM public.business_reviews WHERE id = %L$q$, pg_temp.v('avis')));
RESET ROLE;

-- ═══ 8. Retrait ════════════════════════════════════════════════════════════
SELECT pg_temp.qui('client2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(36, 'client2 dépose puis retire son propre avis', 'accepté 1', format(
  $q$WITH a AS (INSERT INTO public.business_reviews (business_id, user_id, rating, content)
                VALUES (%L, %L, 5, 'Parfait') RETURNING id)
     SELECT 1 FROM a$q$, pg_temp.v('fiche'), pg_temp.v('client2')));
RESET ROLE;
SELECT pg_temp.constat(37, 'la note compte l''avis de client2', '5.00 / 1', pg_temp.etat());

SELECT pg_temp.qui('client3');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(38, 'client3 supprime l''avis de client2', 'accepté 0', format(
  $q$DELETE FROM public.business_reviews WHERE business_id = %L AND user_id = %L$q$,
  pg_temp.v('fiche'), pg_temp.v('client2')));
RESET ROLE;

SELECT pg_temp.qui('client2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(39, 'client2 retire son avis', 'accepté 1', format(
  $q$DELETE FROM public.business_reviews WHERE business_id = %L AND user_id = %L$q$,
  pg_temp.v('fiche'), pg_temp.v('client2')));
RESET ROLE;
SELECT pg_temp.constat(40, 'plus d''avis publié : plus de note', 'NULL / 0', pg_temp.etat());

-- Le back-office supprime l'avis signalé (`deleteReportedContent`).
SELECT pg_temp.qui('admin');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(41, 'l''administrateur supprime l''avis signalé', 'accepté 1', format(
  $q$DELETE FROM public.business_reviews WHERE id = %L$q$, pg_temp.v('avis')));
RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
