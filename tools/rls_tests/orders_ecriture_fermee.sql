-- Banc : `public.orders` fermée à l'écriture cliente
-- (migration 20260921034600).
--
--   supabase db query --linked -f tools/rls_tests/orders_ecriture_fermee.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@MIGRATION@@` par le contenu
-- de la migration — c'est la répétition. APRÈS, lancé tel quel, le banc prouve
-- l'état vivant.
--
-- Un banc qui ne sait pas échouer ne prouve rien : sans la migration, **neuf
-- cas tombent** — 1 à 7 (droits et policies grandes ouvertes, l'acheteur
-- fabrique sa commande, la passe en « livrée », en réécrit le montant), 10 et
-- 11 (le back-office). Mesuré le 2026-09-21.
--
-- Le cas 10 mérite un mot : il échoue AVANT comme après, tant qu'aucune
-- policy d'administration n'existe. Un administrateur n'est ni acheteur ni
-- vendeur, donc `orders_select_parties` ne lui montre rien — et Postgres
-- applique les policies de SELECT aux lignes qu'un `UPDATE … WHERE` doit
-- d'abord retrouver. La résolution de litige touchait donc 0 ligne, en
-- silence. La migration ajoute `orders_select_admin` pour cela.
--
-- La table est VIDE en production, et le banc la laisse vide : sa commande
-- d'essai est créée sous le rôle propriétaire, puis annulée par le `ROLLBACK`.
-- Aucun déclencheur de `orders` n'envoie de notification (seul
-- `orders_updated_at` existe).

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO anon, authenticated;

INSERT INTO ctx VALUES
  ('acheteur', '1X5F6RKlrTgyxZFSTvS6lXBx8C32'),
  ('vendeur',  'hMGnFMEpKfhvmsm8Y1wL5Iuh4X13'),
  ('cmd',      gen_random_uuid()::text);   -- `orders.id` est un uuid

-- Un administrateur RÉEL : on ne peut pas en fabriquer un, le déclencheur
-- `users_guard_admin_flags` refuse toute écriture de `is_admin` hors
-- super-admin — y compris au propriétaire de la table. C'est voulu, et c'est
-- vérifié ailleurs (« Auto-promotion group_members » du suivi).
INSERT INTO ctx SELECT 'admin', id FROM public.users WHERE is_admin LIMIT 1;

-- @@MIGRATION@@

-- Une commande d'essai, posée par le propriétaire (hors RLS).
INSERT INTO public.orders
       (id, buyer_id, seller_id, product_id, status, total_amount, unit_price)
SELECT (SELECT v FROM ctx WHERE k = 'cmd')::uuid,
       (SELECT v FROM ctx WHERE k = 'acheteur'),
       (SELECT v FROM ctx WHERE k = 'vendeur'),
       gen_random_uuid(), 'pending', 1000, 1000;

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'anon : aucun droit de table sur orders', '(aucun)',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucun)'),
       CASE WHEN count(p) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('anon', 'public.orders', p);

INSERT INTO resultat
SELECT 2, 'authenticated : ni INSERT, ni DELETE, ni TRUNCATE', '(aucun)',
       coalesce(string_agg(p, ',' ORDER BY p), '(aucun)'),
       CASE WHEN count(p) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM unnest(ARRAY['INSERT','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
 WHERE has_table_privilege('authenticated', 'public.orders', p);

INSERT INTO resultat
SELECT 3, 'authenticated : UPDATE limité aux 6 colonnes de litige', '6 colonnes',
       count(*)::text || ' colonne(s)',
       CASE WHEN count(*) = 6 THEN 'OK' ELSE 'ÉCHEC' END
  FROM information_schema.column_privileges
 WHERE table_schema = 'public' AND table_name = 'orders'
   AND grantee = 'authenticated' AND privilege_type = 'UPDATE';

INSERT INTO resultat
SELECT 4, 'plus de policy d''insertion ni de mise à jour par les parties', '(aucune)',
       coalesce(string_agg(policyname, ',' ORDER BY policyname), '(aucune)'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'orders'
   AND policyname IN ('orders_insert_buyer', 'orders_update_parties');

-- ═══ 2. L'acheteur ═════════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', (SELECT v FROM ctx WHERE k = 'acheteur')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  INSERT INTO public.orders
         (id, buyer_id, seller_id, product_id, status, total_amount, unit_price)
  VALUES (gen_random_uuid(), (SELECT v FROM ctx WHERE k = 'acheteur'),
          (SELECT v FROM ctx WHERE k = 'vendeur'), gen_random_uuid(),
          'delivered', 1, 1);
  INSERT INTO resultat VALUES (5, 'LA FAILLE — l''acheteur fabrique une commande « livrée » à 1',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (5, 'LA FAILLE — l''acheteur fabrique une commande « livrée » à 1',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
BEGIN
  UPDATE public.orders SET status = 'delivered', escrow_status = 'held'
   WHERE id = (SELECT v FROM ctx WHERE k = 'cmd')::uuid;
  INSERT INTO resultat VALUES (6, 'LA FAILLE — l''acheteur passe sa commande en « livrée »',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (6, 'LA FAILLE — l''acheteur passe sa commande en « livrée »',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

DO $$
BEGIN
  UPDATE public.orders SET total_amount = 999999
   WHERE id = (SELECT v FROM ctx WHERE k = 'cmd')::uuid;
  INSERT INTO resultat VALUES (7, 'LA FAILLE — l''acheteur réécrit le montant',
    'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (7, 'LA FAILLE — l''acheteur réécrit le montant',
    'refusé 42501', 'refusé 42501', 'OK');
END $$;

-- Non-régression : la partie lit toujours sa commande.
DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.orders WHERE id = (SELECT v FROM ctx WHERE k = 'cmd')::uuid;
  INSERT INTO resultat VALUES (8, 'l''acheteur lit toujours sa commande', '1',
    n::text, CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'l''acheteur lit toujours sa commande', '1',
    'REFUSÉ ' || SQLSTATE, 'ÉCHEC');
END $$;

-- Un non-participant ne voit rien : non-régression de `orders_select_parties`.
RESET ROLE;
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid', 'banc-tiers-sans-rapport'))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM public.orders WHERE id = (SELECT v FROM ctx WHERE k = 'cmd')::uuid;
  INSERT INTO resultat VALUES (9, 'un tiers ne voit pas la commande', '0',
    n::text, CASE WHEN n = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;

-- ═══ 3. Le back-office ═════════════════════════════════════════════════════
-- L'administrateur résout un litige : les six colonnes, et elles seules.
SELECT set_config('request.jwt.claims',
  jsonb_build_object('role', 'authenticated', 'app_metadata',
    jsonb_build_object('firebase_uid',
      coalesce((SELECT v FROM ctx WHERE k = 'admin'), 'aucun-admin')))::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE n bigint;
BEGIN
  UPDATE public.orders
     SET dispute_resolution = 'banc', dispute_note = 'banc',
         dispute_resolved_by = 'banc', dispute_resolved_at = now(),
         is_in_dispute = false, has_dispute = false
   WHERE id = (SELECT v FROM ctx WHERE k = 'cmd')::uuid;
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO resultat VALUES (10, 'admin : résout un litige (6 colonnes)', '1 ligne',
    n::text || ' ligne(s)', CASE WHEN n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (10, 'admin : résout un litige (6 colonnes)', '1 ligne',
    'REFUSÉ ' || SQLSTATE || ' ' || SQLERRM, 'ÉCHEC');
END $$;

DO $$
BEGIN
  UPDATE public.orders SET total_amount = 1
   WHERE id = (SELECT v FROM ctx WHERE k = 'cmd')::uuid;
  INSERT INTO resultat VALUES (11, 'admin : ne touche PAS au montant', 'refusé 42501',
    'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO resultat VALUES (11, 'admin : ne touche PAS au montant', 'refusé 42501',
    'refusé 42501', 'OK');
END $$;

RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
