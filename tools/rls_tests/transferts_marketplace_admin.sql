-- Banc : transferts et marketplace côté administration (migration 20261019160000).
--
--   supabase db query --linked -f tools/rls_tests/transferts_marketplace_admin.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Les dangers sont : qu'un administrateur ne VOIE rien (la
-- liste vide qui ressemble à un calme plat) ou voie ce qui ne le regarde pas ;
-- qu'un remboursement soit décidé par celui qui l'a demandé ; que des statuts
-- changent sans preuve ni motif, ou hors du cycle ; qu'un vendeur rétablisse
-- un produit que la modération a masqué ; et qu'un litige se « résolve »
-- sans que personne n'ait le droit de l'écrire.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

CREATE FUNCTION pg_temp.essai(n int, cas text, attendu text, q text) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE obtenu text;
BEGIN
  EXECUTE q;
  obtenu := 'OK';
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN obtenu = attendu THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (n, cas, attendu, SQLSTATE,
    CASE WHEN SQLSTATE = attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $f$;

CREATE FUNCTION pg_temp.moi(uid text) RETURNS void
LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', uid))::text, true)
$f$;

CREATE FUNCTION pg_temp.verifie(n int, cas text, attendu text, obtenu text) RETURNS void
LANGUAGE sql AS $f$
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN attendu = obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$f$;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-trf-super',   'Super',   'trf-super@banc.test',   true,  'superAdmin'),
  ('banc-trf-fin',     'Fin 1',   'trf-fin@banc.test',     true,  'financeMod'),
  ('banc-trf-fin2',    'Fin 2',   'trf-fin2@banc.test',    true,  'financeMod'),
  ('banc-trf-biz',     'Biz',     'trf-biz@banc.test',     true,  'businessMod'),
  ('banc-trf-content', 'Content', 'trf-content@banc.test', true,  'contentMod'),
  ('banc-trf-vendeur', 'Vendeur', 'trf-vendeur@banc.test', false, NULL),
  ('banc-trf-acheteur','Acheteur','trf-acheteur@banc.test',false, NULL);

INSERT INTO public.transactions (id, sender_id, recipient_id, amount, currency, status) VALUES
  ('00000000-0000-0000-0000-0000000000f1', 'banc-trf-acheteur', 'banc-trf-vendeur', 5000, 'XOF', 'pending'),
  ('00000000-0000-0000-0000-0000000000f2', 'banc-trf-acheteur', 'banc-trf-vendeur', 6000, 'XOF', 'pending'),
  ('00000000-0000-0000-0000-0000000000f3', 'banc-trf-acheteur', 'banc-trf-vendeur', 7000, 'XOF', 'completed');

INSERT INTO public.products (id, seller_id, title, price, currency, is_available) VALUES
  ('00000000-0000-0000-0000-0000000000c1', 'banc-trf-vendeur', 'p1 à masquer', 1000, 'XOF', true),
  ('00000000-0000-0000-0000-0000000000c2', 'banc-trf-vendeur', 'p2 à supprimer', 1000, 'XOF', true),
  ('00000000-0000-0000-0000-0000000000c3', 'banc-trf-vendeur', 'p3 avec commande', 1000, 'XOF', true);

INSERT INTO public.orders (id, buyer_id, seller_id, product_id, quantity, unit_price, total_amount, currency, status, is_in_dispute, has_dispute) VALUES
  ('00000000-0000-0000-0000-0000000000d1', 'banc-trf-acheteur', 'banc-trf-vendeur', '00000000-0000-0000-0000-0000000000c3', 1, 1000, 1000, 'XOF', 'disputed', true, true),
  ('00000000-0000-0000-0000-0000000000d2', 'banc-trf-acheteur', 'banc-trf-vendeur', '00000000-0000-0000-0000-0000000000c3', 1, 1000, 1000, 'XOF', 'paid', false, false);

-- ═══ 1. Droits et visibilité ═══════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'anon n''exécute aucune des sept fonctions', 'false',
  (has_function_privilege('anon', 'public.transaction_admin_complete(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.transaction_admin_fail(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.transaction_admin_request_refund(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.transaction_admin_decide_refund(uuid,boolean,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.product_admin_set_availability(uuid,boolean,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.product_admin_delete(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.order_admin_resolve_dispute(uuid,text,text)', 'EXECUTE'))::text);
SELECT pg_temp.verifie(2, 'plus d''écriture directe sur transactions et orders', 'false',
  (has_table_privilege('authenticated', 'public.transactions', 'UPDATE')
   OR has_table_privilege('authenticated', 'public.transactions', 'DELETE')
   OR has_table_privilege('authenticated', 'public.orders', 'UPDATE')
   OR has_table_privilege('anon', 'public.transactions', 'TRUNCATE'))::text);

SELECT pg_temp.moi('banc-trf-fin');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(3, 'financeMod VOIT les transferts (la liste n''est plus vide)', '3',
  (SELECT count(*)::text FROM public.transactions WHERE id::text LIKE '00000000-0000-0000-0000-0000000000f%'));
RESET ROLE;
SELECT pg_temp.moi('banc-trf-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(4, 'businessMod ne voit aucun transfert', '0',
  (SELECT count(*)::text FROM public.transactions WHERE id::text LIKE '00000000-0000-0000-0000-0000000000f%'));
SELECT pg_temp.verifie(5, 'businessMod voit les produits masqués ET les commandes', '3/2',
  (SELECT count(*)::text FROM public.products WHERE seller_id = 'banc-trf-vendeur') || '/' ||
  (SELECT count(*)::text FROM public.orders WHERE seller_id = 'banc-trf-vendeur'));
RESET ROLE;
SELECT pg_temp.moi('banc-trf-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(6, 'contentMod ne voit ni transferts ni commandes', '0/0',
  (SELECT count(*)::text FROM public.transactions WHERE id::text LIKE '00000000-0000-0000-0000-0000000000f%') || '/' ||
  (SELECT count(*)::text FROM public.orders WHERE seller_id = 'banc-trf-vendeur'));
RESET ROLE;
SELECT pg_temp.moi('banc-trf-acheteur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(7, 'l''acheteur ne voit que SON transfert', '3',
  (SELECT count(*)::text FROM public.transactions WHERE sender_id = 'banc-trf-acheteur'));
RESET ROLE;

-- ═══ 2. Compléter, échouer ═════════════════════════════════════════════════
SELECT pg_temp.moi('banc-trf-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'businessMod : compléter REFUSÉ', '42501',
  $q$SELECT public.transaction_admin_complete('00000000-0000-0000-0000-0000000000f1', 'Reçu bancaire n° 1234')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-trf-fin');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : compléter sans preuve → 22023', '22023',
  $q$SELECT public.transaction_admin_complete('00000000-0000-0000-0000-0000000000f1', '  ')$q$);
SELECT pg_temp.essai(12, 'financeMod : transfert introuvable → P0002', 'P0002',
  $q$SELECT public.transaction_admin_complete('00000000-0000-0000-0000-0000000000ff', 'Reçu bancaire n° 1234')$q$);
SELECT pg_temp.essai(13, 'financeMod : compléter f1 avec la preuve', 'OK',
  $q$SELECT public.transaction_admin_complete('00000000-0000-0000-0000-0000000000f1', 'Reçu bancaire n° 1234')$q$);
SELECT pg_temp.essai(14, 'financeMod : compléter f1 de nouveau → 55000', '55000',
  $q$SELECT public.transaction_admin_complete('00000000-0000-0000-0000-0000000000f1', 'Reçu bancaire n° 1234')$q$);
SELECT pg_temp.essai(15, 'financeMod : échouer sans motif → 22023', '22023',
  $q$SELECT public.transaction_admin_fail('00000000-0000-0000-0000-0000000000f2', '')$q$);
SELECT pg_temp.essai(16, 'financeMod : échoue f2 avec motif', 'OK',
  $q$SELECT public.transaction_admin_fail('00000000-0000-0000-0000-0000000000f2', 'Rejeté par la banque du destinataire')$q$);
SELECT pg_temp.essai(17, 'financeMod : échouer un transfert terminé → 55000', '55000',
  $q$SELECT public.transaction_admin_fail('00000000-0000-0000-0000-0000000000f3', 'Erreur de ma part')$q$);
RESET ROLE;
SELECT pg_temp.verifie(18, 'f1 terminé par fin (text), preuve conservée ; f2 échoué par fin', 'completed/banc-trf-fin/Reçu bancaire n° 1234/failed/banc-trf-fin',
  (SELECT a.status || '/' || a.completed_by || '/' || a.completion_proof || '/' || b.status || '/' || b.failed_by
     FROM public.transactions a, public.transactions b
    WHERE a.id = '00000000-0000-0000-0000-0000000000f1' AND b.id = '00000000-0000-0000-0000-0000000000f2'));

-- ═══ 3. Remboursement en deux temps ════════════════════════════════════════
SELECT pg_temp.moi('banc-trf-fin');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'demander le remboursement d''un transfert non terminé → 55000', '55000',
  $q$SELECT public.transaction_admin_request_refund('00000000-0000-0000-0000-0000000000f2', 'Erreur du client')$q$);
SELECT pg_temp.essai(21, 'demander sans motif → 22023', '22023',
  $q$SELECT public.transaction_admin_request_refund('00000000-0000-0000-0000-0000000000f3', '')$q$);
SELECT pg_temp.essai(22, 'fin demande le remboursement de f3', 'OK',
  $q$SELECT public.transaction_admin_request_refund('00000000-0000-0000-0000-0000000000f3', 'Colis jamais reçu, litige tranché')$q$);
SELECT pg_temp.essai(23, 'demander deux fois → 55000', '55000',
  $q$SELECT public.transaction_admin_request_refund('00000000-0000-0000-0000-0000000000f3', 'Colis jamais reçu, litige tranché')$q$);
SELECT pg_temp.essai(24, 'fin approuve SA propre demande REFUSÉ', '42501',
  $q$SELECT public.transaction_admin_decide_refund('00000000-0000-0000-0000-0000000000f3', true)$q$);
RESET ROLE;
SELECT pg_temp.verifie(25, 'f3 toujours « completed » après la demande', 'completed',
  (SELECT status FROM public.transactions WHERE id = '00000000-0000-0000-0000-0000000000f3'));

SELECT pg_temp.moi('banc-trf-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(26, 'superAdmin (pas le demandeur) : décision sans valeur → 22023', '22023',
  $q$SELECT public.transaction_admin_decide_refund('00000000-0000-0000-0000-0000000000f3', NULL)$q$);
SELECT pg_temp.essai(27, 'superAdmin : refuser sans motif → 22023', '22023',
  $q$SELECT public.transaction_admin_decide_refund('00000000-0000-0000-0000-0000000000f3', false, '')$q$);
SELECT pg_temp.essai(28, 'superAdmin : refuse avec motif', 'OK',
  $q$SELECT public.transaction_admin_decide_refund('00000000-0000-0000-0000-0000000000f3', false, 'Le litige ne porte que sur 20 %')$q$);
SELECT pg_temp.essai(29, 'décider sans demande en attente → 55000', '55000',
  $q$SELECT public.transaction_admin_decide_refund('00000000-0000-0000-0000-0000000000f3', true)$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-trf-fin2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'fin2 : redemande après le refus', 'OK',
  $q$SELECT public.transaction_admin_request_refund('00000000-0000-0000-0000-0000000000f3', 'Remboursement partiel convenu avec le vendeur')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-trf-fin');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(31, 'fin (pas le demandeur) approuve', 'OK',
  $q$SELECT public.transaction_admin_decide_refund('00000000-0000-0000-0000-0000000000f3', true)$q$);
RESET ROLE;
SELECT pg_temp.verifie(32, 'f3 remboursé : par fin, motif de la demande conservé', 'refunded/banc-trf-fin/Remboursement partiel convenu avec le vendeur',
  (SELECT status || '/' || refunded_by || '/' || refund_reason FROM public.transactions WHERE id = '00000000-0000-0000-0000-0000000000f3'));

-- ═══ 4. Écriture directe ═══════════════════════════════════════════════════
SELECT pg_temp.moi('banc-trf-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(35, 'superAdmin : UPDATE direct d''un transfert REFUSÉ (plus de droit UPDATE)', '42501',
  $q$UPDATE public.transactions SET status = 'refunded' WHERE id = '00000000-0000-0000-0000-0000000000f1'$q$);
SELECT pg_temp.essai(36, 'superAdmin : UPDATE direct d''une commande REFUSÉ', '42501',
  $q$UPDATE public.orders SET is_in_dispute = false WHERE id = '00000000-0000-0000-0000-0000000000d1'$q$);
RESET ROLE;

-- ═══ 5. Produits ═══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-trf-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'contentMod : masquer un produit REFUSÉ', '42501',
  $q$SELECT public.product_admin_set_availability('00000000-0000-0000-0000-0000000000c1', false, 'Contenu douteux')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-trf-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(41, 'businessMod : masquer sans motif → 22023', '22023',
  $q$SELECT public.product_admin_set_availability('00000000-0000-0000-0000-0000000000c1', false, '')$q$);
SELECT pg_temp.essai(42, 'businessMod : masquer p1 avec motif', 'OK',
  $q$SELECT public.product_admin_set_availability('00000000-0000-0000-0000-0000000000c1', false, 'Photos trompeuses signalées')$q$);
SELECT pg_temp.essai(43, 'businessMod : masquer de nouveau → 55000', '55000',
  $q$SELECT public.product_admin_set_availability('00000000-0000-0000-0000-0000000000c1', false, 'Photos trompeuses signalées')$q$);
SELECT pg_temp.essai(44, 'businessMod : supprimer REFUSÉ (superAdmin seul)', '42501',
  $q$SELECT public.product_admin_delete('00000000-0000-0000-0000-0000000000c2', 'Produit illicite')$q$);
RESET ROLE;
SELECT pg_temp.verifie(45, 'p1 masqué : motif et auteur conservés', 'false/Photos trompeuses signalées/banc-trf-biz',
  (SELECT is_available::text || '/' || moderation_reason || '/' || moderated_by FROM public.products WHERE id = '00000000-0000-0000-0000-0000000000c1'));

SELECT pg_temp.moi('banc-trf-vendeur');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(46, 'vendeur : rétablir lui-même un produit masqué REFUSÉ', '42501',
  $q$UPDATE public.products SET is_available = true WHERE id = '00000000-0000-0000-0000-0000000000c1'$q$);
SELECT pg_temp.essai(47, 'vendeur : effacer la trace de modération REFUSÉ', '42501',
  $q$UPDATE public.products SET moderation_reason = NULL, moderated_at = NULL WHERE id = '00000000-0000-0000-0000-0000000000c1'$q$);
SELECT pg_temp.essai(48, 'vendeur : modifier le titre de son produit (comme avant)', 'OK',
  $q$UPDATE public.products SET title = 'p2 renommé' WHERE id = '00000000-0000-0000-0000-0000000000c2'$q$);
SELECT pg_temp.essai(49, 'vendeur : masquer lui-même son produit (comme avant)', 'OK',
  $q$UPDATE public.products SET is_available = false WHERE id = '00000000-0000-0000-0000-0000000000c2'$q$);
SELECT pg_temp.essai(50, 'vendeur : le rétablir lui-même (non modéré, comme avant)', 'OK',
  $q$UPDATE public.products SET is_available = true WHERE id = '00000000-0000-0000-0000-0000000000c2'$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-trf-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(51, 'businessMod : rétablit p1 avec motif', 'OK',
  $q$SELECT public.product_admin_set_availability('00000000-0000-0000-0000-0000000000c1', true, 'Photos corrigées par le vendeur')$q$);
RESET ROLE;
SELECT pg_temp.verifie(52, 'p1 rétabli : plus de trace de modération sur la ligne', 'true/vide',
  (SELECT is_available::text || '/' || coalesce(moderation_reason, 'vide') FROM public.products WHERE id = '00000000-0000-0000-0000-0000000000c1'));

SELECT pg_temp.moi('banc-trf-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(53, 'superAdmin : supprimer sans motif → 22023', '22023',
  $q$SELECT public.product_admin_delete('00000000-0000-0000-0000-0000000000c2', '')$q$);
SELECT pg_temp.essai(54, 'superAdmin : supprimer un produit qui a des commandes → 55000', '55000',
  $q$SELECT public.product_admin_delete('00000000-0000-0000-0000-0000000000c3', 'Produit illicite')$q$);
SELECT pg_temp.essai(55, 'superAdmin : supprime p2 (sans commande)', 'OK',
  $q$SELECT public.product_admin_delete('00000000-0000-0000-0000-0000000000c2', 'Produit illicite confirmé')$q$);
RESET ROLE;

-- ═══ 6. Litiges ════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-trf-biz');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(60, 'businessMod : résoudre un litige REFUSÉ (marketplace.disputes.resolve : financeMod)', '42501',
  $q$SELECT public.order_admin_resolve_dispute('00000000-0000-0000-0000-0000000000d1', 'buyer_favor', 'Preuve de non-livraison fournie')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-trf-fin');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(61, 'financeMod : décision hors liste → 22023', '22023',
  $q$SELECT public.order_admin_resolve_dispute('00000000-0000-0000-0000-0000000000d1', 'au_hasard', 'Preuve de non-livraison fournie')$q$);
SELECT pg_temp.essai(62, 'financeMod : motif trop court → 22023', '22023',
  $q$SELECT public.order_admin_resolve_dispute('00000000-0000-0000-0000-0000000000d1', 'buyer_favor', 'ok')$q$);
SELECT pg_temp.essai(63, 'financeMod : litige sur une commande qui n''en a pas → 55000', '55000',
  $q$SELECT public.order_admin_resolve_dispute('00000000-0000-0000-0000-0000000000d2', 'buyer_favor', 'Preuve de non-livraison fournie')$q$);
SELECT pg_temp.essai(64, 'financeMod : tranche d1 en faveur de l''acheteur', 'OK',
  $q$SELECT public.order_admin_resolve_dispute('00000000-0000-0000-0000-0000000000d1', 'buyer_favor', 'Preuve de non-livraison fournie')$q$);
SELECT pg_temp.essai(65, 'financeMod : trancher deux fois → 55000', '55000',
  $q$SELECT public.order_admin_resolve_dispute('00000000-0000-0000-0000-0000000000d1', 'seller_favor', 'Revirement sans nouvelle preuve')$q$);
RESET ROLE;
SELECT pg_temp.verifie(66, 'd1 : décision, motif et auteur conservés, litige fermé', 'buyer_favor/banc-trf-fin/false',
  (SELECT dispute_resolution || '/' || dispute_resolved_by || '/' || is_in_dispute::text FROM public.orders WHERE id = '00000000-0000-0000-0000-0000000000d1'));

-- ═══ 7. Audit ══════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(70, 'audit : complété, échoué, demandé x2, refusé, approuvé', '1/1/2/1/1',
  (SELECT count(*) FILTER (WHERE action = 'TRANSACTION_MARKED_COMPLETED') || '/' ||
          count(*) FILTER (WHERE action = 'TRANSACTION_MARKED_FAILED') || '/' ||
          count(*) FILTER (WHERE action = 'REFUND_REQUESTED') || '/' ||
          count(*) FILTER (WHERE action = 'REFUND_REJECTED') || '/' ||
          count(*) FILTER (WHERE action = 'REFUND_APPROVED')
     FROM public.admin_audit_logs WHERE target_id LIKE '00000000-0000-0000-0000-0000000000f%'));
SELECT pg_temp.verifie(71, 'audit produits et litige', '1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'PRODUCT_HIDDEN') || '/' ||
          count(*) FILTER (WHERE action = 'PRODUCT_RESTORED') || '/' ||
          count(*) FILTER (WHERE action = 'PRODUCT_DELETED') || '/' ||
          count(*) FILTER (WHERE action = 'DISPUTE_RESOLVED')
     FROM public.admin_audit_logs
    WHERE target_id LIKE '00000000-0000-0000-0000-0000000000c%' OR target_id LIKE '00000000-0000-0000-0000-0000000000d%'));
SELECT pg_temp.verifie(72, 'l''audit ne contient ni preuve de règlement ni numéro de reçu', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE details::text LIKE '%1234%' OR details::text LIKE '%Reçu bancaire%'));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
