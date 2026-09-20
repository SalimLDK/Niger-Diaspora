-- Banc de « refuser l'OUVERT, conserver le CLOS » (suppression de compte et finances).
--
-- Suppose `20260918224100` APPLIQUÉE et joue `20260919113700` dans la même
-- transaction :
--
--   { echo "BEGIN;"; \
--     cat supabase/migrations/20260919113700_suppression_compte_finances_ouvert_clos.sql; \
--     cat tools/rls_tests/suppression_compte_finances.sql; \
--     echo "ROLLBACK;"; } > /tmp/finances_banc.sql
--   supabase db query --linked -o csv -f /tmp/finances_banc.sql
--
-- Une fois cette migration appliquée, ce fichier se joue seul entre `BEGIN;` et
-- `ROLLBACK;`. Condition : 0 cas en ÉCHEC — la dernière ligne le dit.
--
-- CE QUE LE BANC ÉTABLIT
-- Les sept tables financières sont VIDES en production et la fonctionnalité est
-- éteinte : rien de ceci ne peut se voir sur des données réelles. Le banc
-- fabrique donc des dossiers fictifs (`zz_fin_*`) et mesure :
--   · l'interrupteur : sans `financial_retention_years`, un dossier CLOS bloque
--     encore (comportement d'avant), et une valeur invalide vaut « non posée » ;
--   · la frontière ouvert/clos, table par table, dont les cas limites (commande
--     terminée dont le séquestre est retenu, litige, statut NULL) ;
--   · ce que la purge EFFACE d'un dossier clos et ce qu'elle CONSERVE ;
--   · qu'une purge sans durée posée ne fait RIEN (atomique) ;
--   · l'échéance : seul un compte SUPPRIMÉ et assez ancien est délié ;
--   · les refus, à la demande comme à la réclamation, et les droits.
--
-- Tout est dans la transaction annulée.

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO authenticated, anon;

CREATE FUNCTION pg_temp.verifie(p_n int, p_cas text, p_attendu text, p_obtenu text)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO resultat VALUES (p_n, p_cas, p_attendu, p_obtenu,
    CASE WHEN p_attendu IS NOT DISTINCT FROM p_obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$$;

CREATE FUNCTION pg_temp.moi(p_uid text, p_sub uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    jsonb_build_object('sub', p_sub, 'role', 'authenticated',
                       'app_metadata', jsonb_build_object('firebase_uid', p_uid))::text, true)
$$;

-- Pose ou retire la durée de conservation.
CREATE FUNCTION pg_temp.duree(p_valeur jsonb) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.app_config WHERE key = 'financial_retention_years';
  IF p_valeur IS NOT NULL THEN
    INSERT INTO public.app_config (key, value) VALUES ('financial_retention_years', p_valeur);
  END IF;
END $$;

-- Une commande fictive ; les paramètres sont ceux que la logique lit.
-- Les identifiants Stripe sont UNIQUES (`orders_stripe_payment_intent_id_key`) : un par commande.
CREATE FUNCTION pg_temp.commande(
  p_acheteur text, p_vendeur text, p_statut text, p_sequestre text,
  p_age interval DEFAULT interval '0', p_litige boolean DEFAULT false
) RETURNS void LANGUAGE sql AS $$
  INSERT INTO public.orders
    (buyer_id, seller_id, product_id, unit_price, total_amount, status, escrow_status,
     buyer_name, seller_name, buyer_note, seller_note, shipping_address,
     stripe_payment_intent_id, escrow_id, session_id, is_in_dispute, created_at, updated_at)
  VALUES
    (p_acheteur, p_vendeur, gen_random_uuid(), 5000, 5000, p_statut, p_sequestre,
     'Acheteur ' || p_acheteur, 'Vendeur ' || p_vendeur, 'note acheteur', 'note vendeur',
     '{"rue": "1 rue du Test", "ville": "Niamey"}'::jsonb,
     'pi_' || gen_random_uuid()::text, 'esc_' || gen_random_uuid()::text, 'cs_' || gen_random_uuid()::text, p_litige,
     now() - p_age, now() - p_age)
$$;

-- ═══ Comptes fictifs ════════════════════════════════════════════════════════
INSERT INTO public.users (id, email, display_name) VALUES
  ('zz_fin_a', 'zz_fin_a@example.invalid', 'Acheteuse Test'),
  ('zz_fin_b', 'zz_fin_b@example.invalid', 'Vendeur Test'),
  ('zz_fin_c', 'zz_fin_c@example.invalid', 'Sans finances'),
  ('zz_fin_d', 'zz_fin_d@example.invalid', 'Commande ouverte'),
  ('zz_fin_e', 'zz_fin_e@example.invalid', 'Transfert clos'),
  ('zz_fin_f', 'zz_fin_f@example.invalid', 'Demande via le client');

-- ═══ Droits ═════════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'droits : aucune de ces fonctions ne s''appelle depuis un client',
  'retention=false/false ouvertes=false/false dossiers=false/false bloquee=false/false purge=false/false delier=false/false complete=false/false/true',
  'retention=' || has_function_privilege('authenticated','private.retention_financiere()','EXECUTE')::text
      || '/' || has_function_privilege('anon','private.retention_financiere()','EXECUTE')::text
  || ' ouvertes=' || has_function_privilege('authenticated','private.obligations_financieres_ouvertes(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','private.obligations_financieres_ouvertes(text)','EXECUTE')::text
  || ' dossiers=' || has_function_privilege('authenticated','private.dossiers_financiers(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','private.dossiers_financiers(text)','EXECUTE')::text
  || ' bloquee=' || has_function_privilege('authenticated','private.suppression_bloquee_pour(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','private.suppression_bloquee_pour(text)','EXECUTE')::text
  || ' purge=' || has_function_privilege('authenticated','private.purge_finances(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','private.purge_finances(text)','EXECUTE')::text
  || ' delier=' || has_function_privilege('authenticated','private.delier_finances_expirees()','EXECUTE')::text
      || '/' || has_function_privilege('anon','private.delier_finances_expirees()','EXECUTE')::text
  || ' complete=' || has_function_privilege('authenticated','public.complete_account_deletion(text)','EXECUTE')::text
      || '/' || has_function_privilege('anon','public.complete_account_deletion(text)','EXECUTE')::text
      || '/' || has_function_privilege('service_role','public.complete_account_deletion(text)','EXECUTE')::text);

-- ═══ L'interrupteur : la durée de conservation ══════════════════════════════
SELECT pg_temp.duree(NULL);
SELECT pg_temp.verifie(2, 'durée non posée : NULL', 'NULL',
  COALESCE(private.retention_financiere()::text, 'NULL'));

SELECT pg_temp.duree('7'::jsonb);
SELECT pg_temp.verifie(3, 'durée posée à 7 : 7 ans', '7 years', COALESCE(private.retention_financiere()::text, 'NULL'));
SELECT pg_temp.duree('30'::jsonb);
SELECT pg_temp.verifie(4, 'durée posée à 30 : 30 ans (la borne haute)', '30 years', COALESCE(private.retention_financiere()::text, 'NULL'));

-- Une faute de frappe ne doit pas ouvrir la purge : tout ce qui n'est pas un
-- entier de 1 à 30 vaut « non posée ».
SELECT pg_temp.duree('"sept"'::jsonb);
INSERT INTO ctx SELECT 'chaine', COALESCE(private.retention_financiere()::text, 'NULL');
SELECT pg_temp.duree('0'::jsonb);
INSERT INTO ctx SELECT 'zero', COALESCE(private.retention_financiere()::text, 'NULL');
SELECT pg_temp.duree('31'::jsonb);
INSERT INTO ctx SELECT 'trente_et_un', COALESCE(private.retention_financiere()::text, 'NULL');
SELECT pg_temp.duree('3.5'::jsonb);
INSERT INTO ctx SELECT 'decimal', COALESCE(private.retention_financiere()::text, 'NULL');
SELECT pg_temp.duree('-2'::jsonb);
INSERT INTO ctx SELECT 'negatif', COALESCE(private.retention_financiere()::text, 'NULL');
SELECT pg_temp.duree('true'::jsonb);
INSERT INTO ctx SELECT 'booleen', COALESCE(private.retention_financiere()::text, 'NULL');
SELECT pg_temp.verifie(5, 'valeurs invalides (chaîne, 0, 31, décimal, négatif, booléen) : toutes « non posée »',
  'NULL/NULL/NULL/NULL/NULL/NULL',
  (SELECT string_agg(v, '/' ORDER BY k) FROM ctx WHERE k IN ('chaine','zero','trente_et_un','decimal','negatif','booleen')));
SELECT pg_temp.duree(NULL);

-- ═══ La frontière ouvert / clos, table par table ════════════════════════════
-- Un compte fictif par cas, pour qu'aucun ne masque un autre.
INSERT INTO public.users (id, email) SELECT 'zz_fin_v' || i, 'zz_fin_v' || i || '@example.invalid' FROM generate_series(1, 22) i;

-- OUVERTS (v1..v13)
SELECT pg_temp.commande('zz_fin_v1', 'zz_fin_x', 'shipped', 'none');                 -- expédiée
SELECT pg_temp.commande('zz_fin_v2', 'zz_fin_x', 'completed', 'held');               -- terminée mais séquestre retenu
SELECT pg_temp.commande('zz_fin_v3', 'zz_fin_x', 'completed', 'released', interval '0', true); -- litige
SELECT pg_temp.commande('zz_fin_x', 'zz_fin_v4', 'pending', 'none');                 -- en attente, côté VENDEUR
SELECT pg_temp.commande('zz_fin_v5', 'zz_fin_x', 'processing', 'none');              -- en traitement
INSERT INTO public.escrow_transactions (order_id, buyer_id, seller_id, amount, status)
  VALUES (gen_random_uuid(), 'zz_fin_v6', 'zz_fin_x', 5000, 'held');
INSERT INTO public.escrow_transactions (order_id, buyer_id, seller_id, amount, status)
  VALUES (gen_random_uuid(), 'zz_fin_x', 'zz_fin_v7', 5000, 'disputed');
INSERT INTO public.transactions (sender_id, recipient_id, amount, amount_in_xof, status)
  VALUES ('zz_fin_v8', 'zz_fin_x', 1000, 1000, 'processing');
INSERT INTO public.transactions (sender_id, recipient_id, amount, amount_in_xof, status)
  VALUES ('zz_fin_x', 'zz_fin_v9', 1000, 1000, 'pending');                           -- en attente, côté DESTINATAIRE
INSERT INTO public.tips (room_id, sender_id, recipient_id, amount, status)
  VALUES ('r1', 'zz_fin_v10', 'zz_fin_x', 500, 'pending');
INSERT INTO public.room_tickets (room_id, user_id, amount, status) VALUES ('r1', 'zz_fin_v11', 500, 'pending');
INSERT INTO public.card_credit_requests (user_id, card_last4, card_network, recipient_name, amount, currency, transaction_id, status)
  VALUES ('zz_fin_v12', '4242', 'visa', 'Bénéficiaire', 100, 'XOF', gen_random_uuid(), 'initiated');
INSERT INTO public.debit_requests (user_id, provider, phone, amount, currency, transaction_id, status)
  VALUES ('zz_fin_v13', 'wave', '+22700000000', 100, 'XOF', gen_random_uuid(), 'pending');

-- CLOS (v14..v22) : aucune de ces lignes ne doit compter comme ouverte.
SELECT pg_temp.commande('zz_fin_v14', 'zz_fin_x', 'completed', 'released');
SELECT pg_temp.commande('zz_fin_v15', 'zz_fin_x', 'cancelled', 'none');
SELECT pg_temp.commande('zz_fin_v16', 'zz_fin_x', 'refunded', 'refunded');
SELECT pg_temp.commande('zz_fin_v17', 'zz_fin_x', 'delivered', 'released');           -- livrée, argent parti : close
INSERT INTO public.escrow_transactions (order_id, buyer_id, seller_id, amount, status)
  VALUES (gen_random_uuid(), 'zz_fin_v18', 'zz_fin_x', 5000, 'released');
INSERT INTO public.transactions (sender_id, recipient_id, amount, amount_in_xof, status)
  VALUES ('zz_fin_v19', 'zz_fin_x', 1000, 1000, 'completed');
INSERT INTO public.tips (room_id, sender_id, recipient_id, amount, status)
  VALUES ('r1', 'zz_fin_v20', 'zz_fin_x', 500, 'completed');
INSERT INTO public.room_tickets (room_id, user_id, amount, status) VALUES ('r1', 'zz_fin_v21', 500, 'refunded');
INSERT INTO public.card_credit_requests (user_id, card_last4, card_network, recipient_name, amount, currency, transaction_id, status)
  VALUES ('zz_fin_v22', '4242', 'visa', 'Bénéficiaire', 100, 'XOF', gen_random_uuid(), 'confirmed');

SELECT pg_temp.verifie(6, 'ouvert : 13 cas, tous ouverts (dont le vendeur et le destinataire)',
  '13/13',
  (SELECT count(*) FILTER (WHERE private.obligations_financieres_ouvertes('zz_fin_v' || i))::text || '/13'
     FROM generate_series(1, 13) i));
SELECT pg_temp.verifie(7, 'clos : 9 cas, AUCUN ouvert — l''argent est parti, la marchandise aussi',
  '0/9',
  (SELECT count(*) FILTER (WHERE private.obligations_financieres_ouvertes('zz_fin_v' || i))::text || '/9'
     FROM generate_series(14, 22) i));
SELECT pg_temp.verifie(8, 'clos : mais ce sont bien des DOSSIERS (ce qui bloque sans durée posée)',
  '9/9',
  (SELECT count(*) FILTER (WHERE private.dossiers_financiers('zz_fin_v' || i))::text || '/9'
     FROM generate_series(14, 22) i));
SELECT pg_temp.verifie(9, 'un compte sans aucun dossier : ni ouvert ni dossier',
  'ouvert=false dossiers=false',
  'ouvert=' || private.obligations_financieres_ouvertes('zz_fin_c')::text
  || ' dossiers=' || private.dossiers_financiers('zz_fin_c')::text);

-- ═══ Les refus, selon la durée ══════════════════════════════════════════════
-- A : acheteuse d'une commande CLOSE. B : sa vendeuse. D : commande OUVERTE.
SELECT pg_temp.commande('zz_fin_a', 'zz_fin_b', 'completed', 'released');
SELECT pg_temp.commande('zz_fin_d', 'zz_fin_b', 'shipped', 'held');
INSERT INTO public.transactions (sender_id, recipient_id, amount, amount_in_xof, status, notes)
  VALUES ('zz_fin_e', 'zz_fin_b', 2000, 2000, 'completed', 'pour ma mère');

SELECT pg_temp.duree(NULL);
SELECT pg_temp.verifie(10, 'durée NON posée : le clos bloque comme avant, l''ouvert garde son jeton, un compte propre passe',
  'clos=conservation_financiere_non_configuree ouvert=obligations_financieres propre=NULL',
  'clos=' || COALESCE(private.suppression_bloquee_pour('zz_fin_a'), 'NULL')
  || ' ouvert=' || COALESCE(private.suppression_bloquee_pour('zz_fin_d'), 'NULL')
  || ' propre=' || COALESCE(private.suppression_bloquee_pour('zz_fin_c'), 'NULL'));

SELECT pg_temp.duree('7'::jsonb);
SELECT pg_temp.verifie(11, 'durée POSÉE : le clos ne bloque plus, l''ouvert bloque toujours',
  'clos=NULL ouvert=obligations_financieres propre=NULL',
  'clos=' || COALESCE(private.suppression_bloquee_pour('zz_fin_a'), 'NULL')
  || ' ouvert=' || COALESCE(private.suppression_bloquee_pour('zz_fin_d'), 'NULL')
  || ' propre=' || COALESCE(private.suppression_bloquee_pour('zz_fin_c'), 'NULL'));

-- ═══ À la demande, par le client ════════════════════════════════════════════
SELECT pg_temp.commande('zz_fin_f', 'zz_fin_b', 'completed', 'released');
SELECT pg_temp.duree(NULL);
SET LOCAL ROLE authenticated;
SELECT pg_temp.moi('zz_fin_f', 'f0000000-0000-4000-8000-0000000000f6');
DO $$
DECLARE v text := 'aucune erreur';
BEGIN
  BEGIN PERFORM public.request_account_deletion();
  EXCEPTION WHEN OTHERS THEN v := SQLERRM; END;
  PERFORM pg_temp.verifie(12, 'demande d''un compte à dossier clos, durée non posée : refusée avec le jeton qui dit quoi faire',
    'conservation_financiere_non_configuree', v);
END $$;
SELECT pg_temp.moi('zz_fin_d', 'f0000000-0000-4000-8000-0000000000d4');
DO $$
DECLARE v text := 'aucune erreur';
BEGIN
  BEGIN PERFORM public.request_account_deletion();
  EXCEPTION WHEN OTHERS THEN v := SQLERRM; END;
  PERFORM pg_temp.verifie(13, 'demande d''un compte à commande ouverte : refusée, durée posée ou non',
    'obligations_financieres', v);
END $$;
RESET ROLE;

SELECT pg_temp.duree('7'::jsonb);
SET LOCAL ROLE authenticated;
SELECT pg_temp.moi('zz_fin_f', 'f0000000-0000-4000-8000-0000000000f6');
INSERT INTO ctx SELECT 'demande_f', public.request_account_deletion()::text;
RESET ROLE;
SELECT pg_temp.verifie(14, 'demande d''un compte à dossier clos, durée POSÉE : acceptée (échéance rendue)',
  'pending', (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_fin_f'));

-- ═══ À la réclamation : un compte devenu bloquant n'est pas réclamé ═════════
INSERT INTO public.account_deletion_requests (user_id, status, execute_at)
VALUES ('zz_fin_d', 'pending', now() - interval '1 minute');
INSERT INTO ctx SELECT 'reclames', count(*)::text FROM public.claim_due_account_deletions(10) WHERE uid = 'zz_fin_d';
SELECT pg_temp.verifie(15, 'réclamation : la commande ouverte empêche de supprimer le compte Firebase (bloqué, pas réclamé)',
  'reclames=0 statut=blocked motif=obligations_financieres',
  'reclames=' || (SELECT v FROM ctx WHERE k = 'reclames')
  || ' statut=' || (SELECT status FROM public.account_deletion_requests WHERE user_id = 'zz_fin_d')
  || ' motif=' || (SELECT last_error FROM public.account_deletion_requests WHERE user_id = 'zz_fin_d'));

-- ═══ La purge SANS durée posée ne fait rien (atomique) ══════════════════════
SELECT pg_temp.duree(NULL);
INSERT INTO public.account_deletion_requests (user_id, status, execute_at, started_at, attempts)
VALUES ('zz_fin_a', 'deleting', now(), now(), 1);
INSERT INTO ctx SELECT 'purge_sans_duree', public.complete_account_deletion('zz_fin_a')::text;
SELECT pg_temp.verifie(16, 'purge sans durée posée : ok=false, et RIEN n''est effacé (profil, noms, adresse intacts)',
  'ok=false profil=1 nom=Acheteur zz_fin_a adresse=oui',
  'ok=' || ((SELECT v FROM ctx WHERE k = 'purge_sans_duree')::jsonb->>'ok')
  || ' profil=' || (SELECT count(*) FROM public.users WHERE id = 'zz_fin_a')::text
  || ' nom=' || (SELECT buyer_name FROM public.orders WHERE buyer_id = 'zz_fin_a')
  || ' adresse=' || (SELECT CASE WHEN shipping_address IS NOT NULL THEN 'oui' ELSE 'non' END FROM public.orders WHERE buyer_id = 'zz_fin_a'));
SELECT pg_temp.verifie(17, 'purge refusée : l''erreur est consignée pour l''exploitant',
  'true',
  (SELECT (last_error LIKE '%conservation_financiere_non_configuree%')::text
     FROM public.account_deletion_requests WHERE user_id = 'zz_fin_a'));

-- ═══ La purge AVEC durée : le clos est conservé, le texte libre effacé ══════
SELECT pg_temp.duree('7'::jsonb);
INSERT INTO ctx SELECT 'purge_a', public.complete_account_deletion('zz_fin_a')::text;
SELECT pg_temp.verifie(18, 'purge de l''acheteuse : ok, profil supprimé',
  'ok=true profil=0', 'ok=' || ((SELECT v FROM ctx WHERE k = 'purge_a')::jsonb->>'ok')
  || ' profil=' || (SELECT count(*) FROM public.users WHERE id = 'zz_fin_a')::text);
SELECT pg_temp.verifie(19, 'commande close conservée : nom, note et adresse de l''acheteuse EFFACÉS ; le vendeur, lui, garde les siens',
  'ligne=1 nom=NULL note=NULL adresse=NULL vendeur=Vendeur zz_fin_b note_vendeur=note vendeur',
  'ligne=' || (SELECT count(*) FROM public.orders WHERE buyer_id = 'zz_fin_a')::text
  || ' nom=' || COALESCE((SELECT buyer_name FROM public.orders WHERE buyer_id = 'zz_fin_a'), 'NULL')
  || ' note=' || COALESCE((SELECT buyer_note FROM public.orders WHERE buyer_id = 'zz_fin_a'), 'NULL')
  || ' adresse=' || COALESCE((SELECT shipping_address::text FROM public.orders WHERE buyer_id = 'zz_fin_a'), 'NULL')
  || ' vendeur=' || (SELECT seller_name FROM public.orders WHERE buyer_id = 'zz_fin_a')
  || ' note_vendeur=' || (SELECT seller_note FROM public.orders WHERE buyer_id = 'zz_fin_a'));
SELECT pg_temp.verifie(20, 'faits comptables conservés : montant, statut, uid (référence pseudonyme), identifiant Stripe',
  'montant=5000 statut=completed uid=zz_fin_a stripe=true',
  'montant=' || (SELECT total_amount::text FROM public.orders WHERE buyer_id = 'zz_fin_a')
  || ' statut=' || (SELECT status FROM public.orders WHERE buyer_id = 'zz_fin_a')
  || ' uid=' || (SELECT buyer_id FROM public.orders WHERE buyer_id = 'zz_fin_a')
  || ' stripe=' || (SELECT (stripe_payment_intent_id LIKE 'pi_%')::text FROM public.orders WHERE buyer_id = 'zz_fin_a'));
SELECT pg_temp.verifie(21, 'le résumé de la purge dit ce qui a été conservé',
  'commandes_acheteur_effacees=1 dossiers_conserves=1',
  'commandes_acheteur_effacees=' || ((SELECT v FROM ctx WHERE k = 'purge_a')::jsonb->'summary'->'finances'->>'commandes_acheteur_effacees')
  || ' dossiers_conserves=' || ((SELECT v FROM ctx WHERE k = 'purge_a')::jsonb->'summary'->'finances'->>'dossiers_conserves'));

-- Côté vendeur, et texte libre d'un transfert.
INSERT INTO public.account_deletion_requests (user_id, status, execute_at, started_at, attempts)
VALUES ('zz_fin_b', 'deleting', now(), now(), 1), ('zz_fin_e', 'deleting', now(), now(), 1);
INSERT INTO ctx SELECT 'purge_b', public.complete_account_deletion('zz_fin_b')::text;
INSERT INTO ctx SELECT 'purge_e', public.complete_account_deletion('zz_fin_e')::text;
-- (B est aussi le vendeur d'une commande OUVERTE, celle de D : sa purge doit être refusée.)
SELECT pg_temp.verifie(22, 'la vendeuse a une commande OUVERTE (celle de D) : sa purge est refusée, rien n''est effacé',
  'ok=false profil=1 nom_vendeur=Vendeur zz_fin_b',
  'ok=' || ((SELECT v FROM ctx WHERE k = 'purge_b')::jsonb->>'ok')
  || ' profil=' || (SELECT count(*) FROM public.users WHERE id = 'zz_fin_b')::text
  || ' nom_vendeur=' || (SELECT seller_name FROM public.orders WHERE buyer_id = 'zz_fin_a'));
SELECT pg_temp.verifie(23, 'texte libre d''un transfert effacé chez l''expéditeur ; le bénéficiaire et le montant restent',
  'ok=true notes=NULL destinataire=zz_fin_b montant=2000',
  'ok=' || ((SELECT v FROM ctx WHERE k = 'purge_e')::jsonb->>'ok')
  || ' notes=' || COALESCE((SELECT notes FROM public.transactions WHERE sender_id = 'zz_fin_e'), 'NULL')
  || ' destinataire=' || (SELECT recipient_id FROM public.transactions WHERE sender_id = 'zz_fin_e')
  || ' montant=' || (SELECT amount::text FROM public.transactions WHERE sender_id = 'zz_fin_e'));

-- ═══ L'échéance : couper le lien, jamais sur un compte vivant ═══════════════
-- A est supprimée (plus de profil). On insère à la main des lignes anciennes et
-- récentes : les colonnes de date d'une ligne touchée par la purge ne sont pas
-- fiables si un déclencheur `updated_at` les réécrit.
SELECT pg_temp.commande('zz_fin_a', 'zz_fin_c', 'completed', 'released', interval '8 years');   -- ancienne, compte SUPPRIMÉ
SELECT pg_temp.commande('zz_fin_a', 'zz_fin_c', 'completed', 'released', interval '1 year');    -- récente, compte SUPPRIMÉ
SELECT pg_temp.commande('zz_fin_c', 'zz_fin_v14', 'completed', 'released', interval '9 years'); -- ancienne, comptes VIVANTS

SELECT pg_temp.duree(NULL);
INSERT INTO ctx SELECT 'delier_sans_duree', private.delier_finances_expirees()::text;
SELECT pg_temp.verifie(24, 'échéance sans durée posée : rien ne peut être « expiré »',
  '{"ok": true, "raison": "duree_non_configuree"}', (SELECT v FROM ctx WHERE k = 'delier_sans_duree'));

SELECT pg_temp.duree('7'::jsonb);
INSERT INTO ctx SELECT 'delier_1', private.delier_finances_expirees()::text;
SELECT pg_temp.verifie(25, 'échéance : la ligne ANCIENNE d''un compte supprimé est déliée (uid, Stripe, séquestre vidés) ; les montants restent',
  'uid=compte_supprime stripe=NULL escrow=NULL montant=5000',
  'uid=' || (SELECT buyer_id FROM public.orders WHERE seller_id = 'zz_fin_c' AND buyer_id = 'compte_supprime')
  || ' stripe=' || COALESCE((SELECT stripe_payment_intent_id FROM public.orders WHERE seller_id = 'zz_fin_c' AND buyer_id = 'compte_supprime'), 'NULL')
  || ' escrow=' || COALESCE((SELECT escrow_id FROM public.orders WHERE seller_id = 'zz_fin_c' AND buyer_id = 'compte_supprime'), 'NULL')
  || ' montant=' || (SELECT total_amount::text FROM public.orders WHERE seller_id = 'zz_fin_c' AND buyer_id = 'compte_supprime'));
SELECT pg_temp.verifie(26, 'échéance : la ligne RÉCENTE du même compte supprimé garde son lien',
  '1', (SELECT count(*)::text FROM public.orders WHERE buyer_id = 'zz_fin_a' AND seller_id = 'zz_fin_c' AND updated_at > now() - interval '2 years'));
SELECT pg_temp.verifie(27, 'échéance : une ligne ANCIENNE dont les deux comptes sont VIVANTS n''est jamais déliée',
  'acheteur=zz_fin_c vendeur=zz_fin_v14',
  'acheteur=' || (SELECT buyer_id FROM public.orders WHERE seller_id = 'zz_fin_v14')
  || ' vendeur=' || (SELECT seller_id FROM public.orders WHERE seller_id = 'zz_fin_v14'));

INSERT INTO ctx SELECT 'delier_2', private.delier_finances_expirees()::text;
SELECT pg_temp.verifie(28, 'échéance idempotente : la seconde passe ne délie plus rien',
  '0', ((SELECT v FROM ctx WHERE k = 'delier_2')::jsonb->>'lignes_deliees'));

SELECT pg_temp.verifie(29, 'la tâche nocturne est programmée, une seule fois',
  '1 20 3 * * *',
  (SELECT count(*)::text || ' ' || min(schedule) FROM cron.job WHERE jobname = 'delier-finances-expirees'));

-- ═══ Verdict ════════════════════════════════════════════════════════════════
SELECT n, cas, attendu, obtenu, verdict FROM resultat
UNION ALL
SELECT 9999, 'BILAN', '0 échec',
       count(*) FILTER (WHERE verdict <> 'OK')::text || ' échec(s) sur ' || count(*)::text,
       CASE WHEN count(*) FILTER (WHERE verdict <> 'OK') = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM resultat
ORDER BY 1;
