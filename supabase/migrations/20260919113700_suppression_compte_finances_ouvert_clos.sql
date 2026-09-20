-- Suppression de compte et historique financier : refuser l'OUVERT, conserver le CLOS.
--
-- CE QUE FAISAIT `20260918224100` (déjà appliquée)
-- `private.suppression_bloquee_pour` refusait dès qu'UNE ligne existait dans
-- `orders`, `escrow_transactions`, `transactions`, `tips`, `room_tickets`,
-- `card_credit_requests` ou `debit_requests`. Défaut prudent tant que ces tables
-- sont vides et la fonctionnalité éteinte — mais une fois la place de marché
-- ouverte, quiconque aurait fait UNE transaction, terminée depuis des années, ne
-- pourrait plus jamais supprimer son compte. Supprimer un compte n'est pas
-- supprimer une obligation comptable : ce sont deux choses à ne pas confondre.
--
-- DÉCISION DE SALIM (2026-09-19)
--   · REFUSER seulement les obligations OUVERTES ;
--   · CONSERVER les dossiers clos avec leurs faits comptables (montants, dates,
--     statuts, identifiants Stripe) et l'uid, devenu une référence
--     pseudonyme — le profil, l'identité Supabase et l'e-mail sont supprimés,
--     et l'identification passe par Stripe ;
--   · EFFACER le texte libre et les coordonnées de la personne ;
--   · LIRE la durée de conservation dans `app_config`, et REFUSER TANT QU'ELLE
--     N'EST PAS POSÉE. Je ne choisis AUCUNE durée légale.
--
-- ⚠️ INERTE TANT QUE `financial_retention_years` N'EST PAS POSÉE
-- Sans elle, tout dossier clos continue de bloquer la suppression, exactement
-- comme avant. Les tables sont vides : l'effet, aujourd'hui, est nul. AVANT de la
-- poser (`INSERT INTO app_config (key, value) VALUES
-- ('financial_retention_years', '7')` — le chiffre est un exemple, pas un
-- conseil), faire relire par un conseil juridique :
--   1. la liste des champs effacés (ci-dessous) ;
--   2. la durée, par juridiction — le Niger, le Canada et l'UE n'ont pas la même ;
--   3. surtout, les dossiers de TRANSFERT (`transactions`, `card_credit_requests`,
--      `debit_requests`) : un envoi d'argent est soumis à des obligations de
--      lutte contre le blanchiment qui exigent parfois de conserver l'identité du
--      bénéficiaire. Cette migration n'y efface donc que le texte libre.
--
-- CE QUI EST OUVERT (refuse la suppression, jamais rien n'est effacé)
--   orders                 status pending, paid, processing, shipped, disputed,
--                          ou escrow_status held/releasing, ou un litige
--                          (`is_in_dispute`, `has_dispute`), ou status NULL
--   escrow_transactions   held, disputed
--   transactions          pending, processing
--   tips, room_tickets    pending
--   card_credit_requests,
--   debit_requests        pending, initiated
--   Un statut NULL vaut « ouvert » : dans le doute on ne supprime pas
--   (aujourd'hui impossible — toutes ces colonnes sont NOT NULL ; la règle
--   protège d'une colonne rendue nullable plus tard). Une commande `delivered`
--   dont le séquestre est libéré est close : l'argent est parti ; un litige
--   éventuel porte ses propres drapeaux.
--
-- CE QUI EST EFFACÉ D'UN DOSSIER CLOS (`private.purge_finances`)
--   orders   côté ACHETEUR : buyer_name, buyer_note, shipping_address
--            côté VENDEUR  : seller_name, seller_note
--   transactions           : notes, quand la personne en est l'expéditrice
--   Le reste — montants, dates, statuts, uid, identifiants Stripe, bénéficiaire
--   et coordonnées de transfert — est conservé jusqu'à l'échéance. `metadata`
--   (jsonb) n'est pas inspectée : la table est vide.
--
-- À L'ÉCHÉANCE (`private.delier_finances_expirees`, chaque nuit)
--   Une ligne dont la personne n'a plus de profil ET qui a dépassé la durée perd
--   son lien : uid remplacé par `compte_supprime`, identifiants Stripe et
--   références du prestataire à NULL, bénéficiaire et téléphone de transfert
--   vidés. Les montants restent (statistiques anonymes). La garde `NOT EXISTS
--   users` protège les comptes vivants : seul un compte supprimé est délié.
--
-- LE JOUR OÙ LA PLACE DE MARCHÉ SERA OUVERTE
-- Relire les statuts ci-dessus contre les vrais flux (le séquestre en
-- particulier) : ils viennent des contraintes CHECK des tables, pas d'un
-- parcours observé — elles sont vides.

-- ── 1. La durée de conservation ─────────────────────────────────────────────
--
-- NULL = non posée. Une valeur qui n'est pas un entier de 1 à 30 est traitée
-- comme non posée : une faute de frappe ne doit pas ouvrir la purge.

CREATE OR REPLACE FUNCTION private.retention_financiere()
RETURNS interval
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  -- CASE, pas des AND : SQL ne garantit pas l'ordre d'évaluation d'un WHERE, et
  -- `::int` sur « sept » ou sur un nombre trop grand LÈVE. Une faute de frappe
  -- doit valoir « non posée », pas faire échouer la demande de suppression.
  SELECT CASE
           WHEN jsonb_typeof(c.value) = 'number' AND (c.value #>> '{}') ~ '^[0-9]{1,2}$'
                AND (c.value #>> '{}')::int BETWEEN 1 AND 30
             THEN make_interval(years => (c.value #>> '{}')::int)
         END
    FROM public.app_config c
   WHERE c.key = 'financial_retention_years'
$function$;

-- ── 2. Ouvert, clos ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION private.obligations_financieres_ouvertes(p_uid text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT EXISTS (
           SELECT 1 FROM public.orders o
            WHERE (o.buyer_id = p_uid OR o.seller_id = p_uid)
              AND (o.status IS NULL
                   OR o.status IN ('pending', 'paid', 'processing', 'shipped', 'disputed')
                   OR o.escrow_status IN ('held', 'releasing')
                   OR COALESCE(o.is_in_dispute, false)
                   OR COALESCE(o.has_dispute, false)))
      OR EXISTS (
           SELECT 1 FROM public.escrow_transactions e
            WHERE (e.buyer_id = p_uid OR e.seller_id = p_uid)
              AND (e.status IS NULL OR e.status IN ('held', 'disputed')))
      OR EXISTS (
           SELECT 1 FROM public.transactions t
            WHERE (t.sender_id = p_uid OR t.recipient_id = p_uid)
              AND (t.status IS NULL OR t.status IN ('pending', 'processing')))
      OR EXISTS (
           SELECT 1 FROM public.tips t
            WHERE (t.sender_id = p_uid OR t.recipient_id = p_uid)
              AND (t.status IS NULL OR t.status = 'pending'))
      OR EXISTS (
           SELECT 1 FROM public.room_tickets r
            WHERE r.user_id = p_uid AND (r.status IS NULL OR r.status = 'pending'))
      OR EXISTS (
           SELECT 1 FROM public.card_credit_requests c
            WHERE c.user_id = p_uid AND (c.status IS NULL OR c.status IN ('pending', 'initiated')))
      OR EXISTS (
           SELECT 1 FROM public.debit_requests d
            WHERE d.user_id = p_uid AND (d.status IS NULL OR d.status IN ('pending', 'initiated')))
$function$;

-- Toute ligne d'historique financier de la personne, ouverte ou close : c'est ce
-- qui, faute de durée de conservation, bloque encore.
CREATE OR REPLACE FUNCTION private.dossiers_financiers(p_uid text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.orders WHERE buyer_id = p_uid OR seller_id = p_uid)
      OR EXISTS (SELECT 1 FROM public.escrow_transactions WHERE buyer_id = p_uid OR seller_id = p_uid)
      OR EXISTS (SELECT 1 FROM public.transactions WHERE sender_id = p_uid OR recipient_id = p_uid)
      OR EXISTS (SELECT 1 FROM public.tips WHERE sender_id = p_uid OR recipient_id = p_uid)
      OR EXISTS (SELECT 1 FROM public.room_tickets WHERE user_id = p_uid)
      OR EXISTS (SELECT 1 FROM public.card_credit_requests WHERE user_id = p_uid)
      OR EXISTS (SELECT 1 FROM public.debit_requests WHERE user_id = p_uid)
$function$;

-- ── 3. Ce qui interdit une suppression (remplace celle de 20260918224100) ───
--
-- Mêmes jetons qu'avant pour le client (`compte_plateforme`,
-- `obligations_financieres`), un jeton de plus pour le cas « clos, durée non
-- posée » : il dit à l'exploitant quoi faire dans `last_error`.

CREATE OR REPLACE FUNCTION private.suppression_bloquee_pour(p_uid text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  -- Le compte plateforme porte les groupes officiels : le supprimer les
  -- orphelinerait tous (un seul compte en a créé 12 sur 15).
  IF EXISTS (SELECT 1 FROM public.groups g WHERE g.creator_id = p_uid AND g.is_official) THEN
    RETURN 'compte_plateforme';
  END IF;

  -- Une obligation ouverte : de l'argent ou une marchandise en route.
  IF private.obligations_financieres_ouvertes(p_uid) THEN
    RETURN 'obligations_financieres';
  END IF;

  -- Des dossiers clos, et personne n'a dit combien de temps les garder : on ne
  -- décide pas seul d'une durée légale.
  IF private.dossiers_financiers(p_uid) AND private.retention_financiere() IS NULL THEN
    RETURN 'conservation_financiere_non_configuree';
  END IF;

  RETURN NULL;
END;
$function$;

-- ── 4. À la purge : conserver le clos, effacer le texte libre ───────────────
--
-- Appelée par `complete_account_deletion`, dans la même transaction que
-- `purge_account`. Elle LÈVE plutôt que de décider quand ce qui l'autorise a
-- changé depuis la réclamation : le bloc entier s'annule, rien n'est effacé à
-- moitié.

CREATE OR REPLACE FUNCTION private.purge_finances(p_uid text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_n_orders_ach integer;
  v_n_orders_ven integer;
  v_n_notes      integer;
BEGIN
  IF private.obligations_financieres_ouvertes(p_uid) THEN
    RAISE EXCEPTION 'obligations_financieres' USING ERRCODE = 'P0001';
  END IF;
  IF private.dossiers_financiers(p_uid) AND private.retention_financiere() IS NULL THEN
    RAISE EXCEPTION 'conservation_financiere_non_configuree' USING ERRCODE = 'P0001';
  END IF;

  -- Côté acheteur : son nom, sa note, son adresse de livraison.
  UPDATE public.orders
     SET buyer_name = NULL, buyer_note = NULL, shipping_address = NULL
   WHERE buyer_id = p_uid
     AND (buyer_name IS NOT NULL OR buyer_note IS NOT NULL OR shipping_address IS NOT NULL);
  GET DIAGNOSTICS v_n_orders_ach = ROW_COUNT;

  -- Côté vendeur : son nom et sa note.
  UPDATE public.orders
     SET seller_name = NULL, seller_note = NULL
   WHERE seller_id = p_uid
     AND (seller_name IS NOT NULL OR seller_note IS NOT NULL);
  GET DIAGNOSTICS v_n_orders_ven = ROW_COUNT;

  -- Texte libre d'un transfert : seulement celui de l'expéditrice. Le
  -- bénéficiaire, les références et `metadata` restent — voir l'en-tête.
  UPDATE public.transactions SET notes = NULL
   WHERE sender_id = p_uid AND notes IS NOT NULL;
  GET DIAGNOSTICS v_n_notes = ROW_COUNT;

  RETURN jsonb_build_object(
    'commandes_acheteur_effacees', v_n_orders_ach,
    'commandes_vendeur_effacees', v_n_orders_ven,
    'notes_de_transfert_effacees', v_n_notes,
    'dossiers_conserves', (
        (SELECT count(*) FROM public.orders WHERE buyer_id = p_uid OR seller_id = p_uid)
      + (SELECT count(*) FROM public.escrow_transactions WHERE buyer_id = p_uid OR seller_id = p_uid)
      + (SELECT count(*) FROM public.transactions WHERE sender_id = p_uid OR recipient_id = p_uid)
      + (SELECT count(*) FROM public.tips WHERE sender_id = p_uid OR recipient_id = p_uid)
      + (SELECT count(*) FROM public.room_tickets WHERE user_id = p_uid)
      + (SELECT count(*) FROM public.card_credit_requests WHERE user_id = p_uid)
      + (SELECT count(*) FROM public.debit_requests WHERE user_id = p_uid)));
END;
$function$;

-- `complete_account_deletion` : mêmes garanties qu'avant (idempotente, rend
-- {ok, …} au lieu de lever), les finances d'abord dans le même bloc.
CREATE OR REPLACE FUNCTION public.complete_account_deletion(p_uid text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_status    text;
  v_summary   jsonb;
  v_finances  jsonb;
BEGIN
  SELECT r.status, r.summary INTO v_status, v_summary
    FROM public.account_deletion_requests r
   WHERE r.user_id = p_uid
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'aucune_demande');
  END IF;
  -- Idempotente : déjà faite, on le redit.
  IF v_status = 'completed' THEN
    RETURN jsonb_build_object('ok', true, 'deja_fait', true, 'summary', v_summary);
  END IF;
  IF v_status <> 'deleting' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'demande_non_reclamee', 'status', v_status);
  END IF;

  BEGIN
    v_finances := private.purge_finances(p_uid);
    v_summary  := private.purge_account(p_uid) || jsonb_build_object('finances', v_finances);
  EXCEPTION WHEN OTHERS THEN
    -- Le bloc entier est annulé : rien n'est resté à moitié effacé.
    UPDATE public.account_deletion_requests
       SET last_error = left(SQLSTATE || ' ' || SQLERRM, 500)
     WHERE user_id = p_uid;
    RETURN jsonb_build_object('ok', false, 'error', left(SQLSTATE || ' ' || SQLERRM, 500));
  END;

  UPDATE public.account_deletion_requests
     SET status = 'completed', completed_at = now(), last_error = NULL,
         summary = v_summary, restore = '{}'::jsonb
   WHERE user_id = p_uid;

  RETURN jsonb_build_object('ok', true, 'summary', v_summary);
END;
$function$;

-- ── 5. À l'échéance : couper le lien ────────────────────────────────────────

CREATE OR REPLACE FUNCTION private.delier_finances_expirees()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_duree interval := private.retention_financiere();
  v_gone  constant text := 'compte_supprime';
  v_n     integer;
  v_total integer := 0;
BEGIN
  -- Durée non posée : rien ne peut être « expiré ».
  IF v_duree IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'duree_non_configuree');
  END IF;

  -- Chaque partie se délie SÉPARÉMENT : l'acheteur peut avoir supprimé son
  -- compte et le vendeur pas. `NOT EXISTS users` protège les comptes vivants.

  UPDATE public.orders
     SET buyer_id = v_gone, stripe_payment_intent_id = NULL, escrow_id = NULL, session_id = NULL
   WHERE buyer_id <> v_gone
     AND COALESCE(updated_at, created_at) < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = orders.buyer_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.orders
     SET seller_id = v_gone, stripe_payment_intent_id = NULL, escrow_id = NULL, session_id = NULL
   WHERE seller_id <> v_gone
     AND COALESCE(updated_at, created_at) < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = orders.seller_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.escrow_transactions
     SET buyer_id = v_gone, stripe_charge_id = NULL, stripe_transfer_id = NULL
   WHERE buyer_id <> v_gone
     AND created_at < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = escrow_transactions.buyer_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.escrow_transactions
     SET seller_id = v_gone, stripe_charge_id = NULL, stripe_transfer_id = NULL
   WHERE seller_id <> v_gone
     AND created_at < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = escrow_transactions.seller_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.transactions
     SET sender_id = v_gone, stripe_payment_intent_id = NULL, provider_reference = NULL
   WHERE sender_id <> v_gone
     AND COALESCE(updated_at, created_at) < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = transactions.sender_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.transactions
     SET recipient_id = v_gone
   WHERE recipient_id IS NOT NULL AND recipient_id <> v_gone
     AND COALESCE(updated_at, created_at) < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = transactions.recipient_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.tips
     SET sender_id = v_gone, stripe_payment_intent_id = NULL
   WHERE sender_id <> v_gone
     AND created_at < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = tips.sender_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.tips
     SET recipient_id = v_gone
   WHERE recipient_id <> v_gone
     AND created_at < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = tips.recipient_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.room_tickets
     SET user_id = v_gone, stripe_payment_intent_id = NULL
   WHERE user_id <> v_gone
     AND created_at < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = room_tickets.user_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  -- Dossiers de transfert : à l'échéance seulement, on vide aussi le bénéficiaire
  -- et le téléphone (NOT NULL : une valeur neutre, pas NULL).
  UPDATE public.card_credit_requests
     SET user_id = v_gone, recipient_name = v_gone, card_last4 = '0000', partner_transaction_id = NULL
   WHERE user_id <> v_gone
     AND COALESCE(updated_at, created_at) < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = card_credit_requests.user_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  UPDATE public.debit_requests
     SET user_id = v_gone, phone = v_gone, phone_country_code = NULL, partner_transaction_id = NULL
   WHERE user_id <> v_gone
     AND COALESCE(updated_at, created_at) < now() - v_duree
     AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = debit_requests.user_id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  RETURN jsonb_build_object('ok', true, 'lignes_deliees', v_total);
END;
$function$;

-- Chaque nuit à 03:20 (UTC). Un upsert par nom : rejouer cette migration ne
-- programme pas deux fois la même tâche. Sans durée posée, elle ne fait rien.
SELECT cron.schedule(
  'delier-finances-expirees',
  '20 3 * * *',
  $cron$SELECT private.delier_finances_expirees()$cron$
);

-- ── 6. Droits ───────────────────────────────────────────────────────────────
--
-- Rien de tout cela ne s'appelle depuis un client. `complete_account_deletion`
-- garde ses droits (service_role seulement) ; on les redit, `CREATE OR REPLACE`
-- ne les réécrit pas mais ne coûte rien.

REVOKE ALL ON FUNCTION private.retention_financiere() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.obligations_financieres_ouvertes(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.dossiers_financiers(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.suppression_bloquee_pour(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.purge_finances(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.delier_finances_expirees() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.complete_account_deletion(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_account_deletion(text) TO service_role;

NOTIFY pgrst, 'reload schema';
