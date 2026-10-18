-- Transferts et marketplace : un panneau qui lit enfin ce qu'il affiche, et
-- des écritures qui passent par des fonctions motivées et auditées.
--
-- Référentiel d'administration § 3, § 4 et § 18 (séparation des tâches,
-- double validation des opérations à risque).
--
-- ═══ CE QUI ÉTAIT CASSÉ ════════════════════════════════════════════════════
--
-- Mesuré le 2026-10-19 sur la base liée (tables toutes vides, paiements
-- éteints — c'est ce qui a masqué le défaut) :
--
-- • `transactions` n'avait AUCUNE policy de lecture pour un administrateur
--   (`transactions_select_own` seule) : l'écran Transferts montrait une liste
--   vide quoi qu'il arrive, et ses trois gestes — compléter, échouer,
--   « rembourser » — mettaient à jour zéro ligne. Quand la fonction se
--   rallumera, elle sera vide pour tout le monde.
-- • Même si une policy avait existé, `completed_by` et `failed_by` sont des
--   `uuid` alors que l'identifiant d'un administrateur est un uid Firebase :
--   l'écriture aurait échoué sur la conversion.
-- • `products` : l'administrateur ne lisait que les produits disponibles ou
--   les siens ; masquer un produit le faisait donc disparaître du panneau.
-- • `orders` : `orders_update_litige_admin` existe, mais l'ordre `UPDATE`
--   n'est accordé à personne (le GRANT est SELECT seul, depuis
--   `20260921…orders_ecriture_fermee`) : « résoudre un litige » ne pouvait
--   pas aboutir. Et la lecture passait par `is_admin()` : un contentMod voyait
--   les commandes.
-- • Aucun de ces gestes n'écrivait une ligne d'audit utile (le journal client
--   avalait l'erreur).
--
-- ═══ CE QUE CETTE MIGRATION POSE ═══════════════════════════════════════════
--
-- • Lecture par permission : `finance.transactions.view`, `marketplace.view`,
--   `marketplace.orders.view` — celles que financeMod et businessMod portent
--   déjà, plus le droit du superAdmin.
-- • `completed_by` et `failed_by` passent en `text`.
-- • Transferts : `transaction_admin_complete` (preuve du règlement
--   obligatoire), `transaction_admin_fail` (motif), et un remboursement en
--   DEUX temps — `transaction_admin_request_refund` puis
--   `transaction_admin_decide_refund`, où l'approbateur ne peut pas être le
--   demandeur, super-administrateur compris. Ces gestes ne touchent QUE le
--   registre : aucun fonds ne bouge (aucun appel prestataire n'existe dans le
--   dépôt) ; l'écran le dit.
-- • Marketplace : `product_admin_set_availability` (masquer ou rétablir, motif
--   obligatoire, conservé), `product_admin_delete` (réservée au
--   super-administrateur, motif), `order_admin_resolve_dispute` (décision et
--   motif consignés ; ne déplace aucun séquestre non plus).
-- • Un produit masqué par la modération ne se rétablit pas par le vendeur
--   (déclencheur de garde).
-- • Lecture / écriture directe : `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`,
--   `TRIGGER` retirés à `anon` et `authenticated` sur `transactions` et
--   `orders` ; `TRUNCATE`, `REFERENCES`, `TRIGGER` sur `products`.
--
-- ═══ CE QU'ELLE NE FAIT PAS ═════════════════════════════════════════════════
--
-- • Aucun mouvement d'argent : ni remboursement, ni libération de séquestre.
--   Marquer « remboursée » n'est pas rembourser ; c'est écrit sur l'écran et
--   dans le commentaire de chaque fonction.
-- • Pas de notification de l'acheteur ou du vendeur.
--
-- Banc : tools/rls_tests/transferts_marketplace_admin.sql.

SET lock_timeout = '5s';

-- ── 1. Colonnes ─────────────────────────────────────────────────────────────
ALTER TABLE public.transactions
  ALTER COLUMN completed_by TYPE text USING completed_by::text,
  ALTER COLUMN failed_by    TYPE text USING failed_by::text;
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS refund_requested_by     text,
  ADD COLUMN IF NOT EXISTS refund_requested_at     timestamptz,
  ADD COLUMN IF NOT EXISTS refund_request_reason   text,
  ADD COLUMN IF NOT EXISTS completion_proof        text;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS moderated_by      text,
  ADD COLUMN IF NOT EXISTS moderated_at      timestamptz,
  ADD COLUMN IF NOT EXISTS moderation_reason text;

-- ── 2. Permission nouvelle (suppression exceptionnelle) ─────────────────────
INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('marketplace.products.delete', 'marketplace', 'Supprimer un produit (exceptionnel, motif obligatoire)', NULL)
ON CONFLICT (key) DO NOTHING;
-- Aucun rôle : seul le superAdmin la porte.

-- ── 3. Lecture par permission ───────────────────────────────────────────────
DROP POLICY IF EXISTS transactions_select_admin ON public.transactions;
CREATE POLICY transactions_select_admin ON public.transactions
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('finance.transactions.view'));

DROP POLICY IF EXISTS products_select_admin ON public.products;
CREATE POLICY products_select_admin ON public.products
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('marketplace.view'));

DROP POLICY IF EXISTS orders_select_admin ON public.orders;
CREATE POLICY orders_select_admin ON public.orders
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('marketplace.orders.view'));
DROP POLICY IF EXISTS orders_update_litige_admin ON public.orders;

-- ── 4. Droits de table ──────────────────────────────────────────────────────
REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.transactions FROM PUBLIC, anon, authenticated;
REVOKE UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.orders       FROM PUBLIC, anon, authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.products FROM PUBLIC, anon, authenticated;

-- ── 5. Un produit masqué par la modération reste masqué ─────────────────────
CREATE OR REPLACE FUNCTION public.products_garde_moderation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Chemins de confiance : migrations, fonctions SECURITY DEFINER, service_role.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.moderated_by      IS DISTINCT FROM OLD.moderated_by
     OR NEW.moderated_at      IS DISTINCT FROM OLD.moderated_at
     OR NEW.moderation_reason IS DISTINCT FROM OLD.moderation_reason THEN
    RAISE EXCEPTION 'products : la modération se pose par les fonctions d''administration'
      USING ERRCODE = '42501';
  END IF;
  IF OLD.moderated_at IS NOT NULL AND NOT OLD.is_available AND NEW.is_available THEN
    RAISE EXCEPTION 'products : produit masqué par la modération, seule l''administration le rétablit'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS products_garde_moderation ON public.products;
CREATE TRIGGER products_garde_moderation
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.products_garde_moderation();

-- ═══ Transferts ════════════════════════════════════════════════════════════
-- Toutes ces fonctions écrivent le REGISTRE. Aucun fonds ne bouge.

DROP FUNCTION IF EXISTS public.transaction_admin_complete(uuid, text);

CREATE FUNCTION public.transaction_admin_complete(p_id uuid, p_proof text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  t        public.transactions%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'transfert : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('finance.transactions.complete');

  IF p_proof IS NULL OR length(btrim(p_proof)) < 5 OR length(p_proof) > 1000 THEN
    RAISE EXCEPTION 'transfert : preuve du règlement requise (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO t FROM public.transactions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'transfert : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF t.status NOT IN ('pending', 'processing') THEN
    RAISE EXCEPTION 'transfert : passage % → completed impossible', t.status USING ERRCODE = '55000';
  END IF;

  UPDATE public.transactions SET
    status = 'completed', completed_by = v_caller, completed_at = now(),
    completion_proof = btrim(p_proof), updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'TRANSACTION_MARKED_COMPLETED', 'transaction', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('from', t.status, 'amount', t.amount, 'currency', t.currency));
  RETURN 'completed';
END $$;

DROP FUNCTION IF EXISTS public.transaction_admin_fail(uuid, text);

CREATE FUNCTION public.transaction_admin_fail(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  t        public.transactions%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'transfert : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('finance.transactions.complete');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'transfert : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO t FROM public.transactions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'transfert : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF t.status NOT IN ('pending', 'processing') THEN
    RAISE EXCEPTION 'transfert : passage % → failed impossible', t.status USING ERRCODE = '55000';
  END IF;

  UPDATE public.transactions SET
    status = 'failed', failure_reason = btrim(p_reason), failed_by = v_caller, updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'TRANSACTION_MARKED_FAILED', 'transaction', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('from', t.status));
  RETURN 'failed';
END $$;

DROP FUNCTION IF EXISTS public.transaction_admin_request_refund(uuid, text);

CREATE FUNCTION public.transaction_admin_request_refund(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  t        public.transactions%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'transfert : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('finance.transactions.refund');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'transfert : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO t FROM public.transactions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'transfert : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF t.status <> 'completed' THEN
    RAISE EXCEPTION 'transfert : seul un transfert terminé se rembourse (statut %)', t.status
      USING ERRCODE = '55000';
  END IF;
  IF t.refund_requested_at IS NOT NULL THEN
    RAISE EXCEPTION 'transfert : une demande de remboursement attend déjà une décision' USING ERRCODE = '55000';
  END IF;

  UPDATE public.transactions SET
    refund_requested_by = v_caller, refund_requested_at = now(),
    refund_request_reason = btrim(p_reason), updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'REFUND_REQUESTED', 'transaction', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('amount', t.amount, 'currency', t.currency));
  RETURN 'requested';
END $$;

DROP FUNCTION IF EXISTS public.transaction_admin_decide_refund(uuid, boolean, text);

CREATE FUNCTION public.transaction_admin_decide_refund(
  p_id      uuid,
  p_approve boolean,
  p_note    text DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  t        public.transactions%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'transfert : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('finance.transactions.refund');

  IF p_approve IS NULL THEN
    RAISE EXCEPTION 'transfert : décision requise' USING ERRCODE = '22023';
  END IF;
  IF NOT p_approve AND (p_note IS NULL OR length(btrim(p_note)) < 5) THEN
    RAISE EXCEPTION 'transfert : un refus doit être motivé' USING ERRCODE = '22023';
  END IF;
  IF length(coalesce(p_note, '')) > 1000 THEN
    RAISE EXCEPTION 'transfert : note trop longue (1000 max)' USING ERRCODE = '22001';
  END IF;

  SELECT * INTO t FROM public.transactions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'transfert : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF t.status <> 'completed' OR t.refund_requested_at IS NULL THEN
    RAISE EXCEPTION 'transfert : aucune demande de remboursement en attente' USING ERRCODE = '55000';
  END IF;
  -- Double validation : le demandeur ne décide pas, superAdmin compris.
  IF t.refund_requested_by = v_caller THEN
    RAISE EXCEPTION 'transfert : vous avez demandé ce remboursement, un autre administrateur doit le décider'
      USING ERRCODE = '42501';
  END IF;

  IF p_approve THEN
    UPDATE public.transactions SET
      status = 'refunded', refund_reason = refund_request_reason,
      refunded_by = v_caller, refunded_at = now(), updated_at = now()
     WHERE id = p_id;
  ELSE
    UPDATE public.transactions SET
      refund_requested_by = NULL, refund_requested_at = NULL, refund_request_reason = NULL,
      updated_at = now()
     WHERE id = p_id;
  END IF;

  PERFORM public.write_admin_audit(
    CASE WHEN p_approve THEN 'REFUND_APPROVED' ELSE 'REFUND_REJECTED' END,
    'transaction', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('requested_by', t.refund_requested_by));
  RETURN CASE WHEN p_approve THEN 'refunded' ELSE 'rejected' END;
END $$;

-- ═══ Marketplace ═══════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.product_admin_set_availability(uuid, boolean, text);

CREATE FUNCTION public.product_admin_set_availability(
  p_id        uuid,
  p_available boolean,
  p_reason    text
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  p        public.products%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'produit : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('marketplace.products.moderate');

  IF p_available IS NULL THEN
    RAISE EXCEPTION 'produit : état requis' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'produit : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO p FROM public.products WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'produit : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF p.is_available = p_available THEN
    RAISE EXCEPTION 'produit : déjà %', CASE WHEN p_available THEN 'disponible' ELSE 'masqué' END
      USING ERRCODE = '55000';
  END IF;

  UPDATE public.products SET
    is_available = p_available,
    moderated_by = CASE WHEN p_available THEN NULL ELSE v_caller END,
    moderated_at = CASE WHEN p_available THEN NULL ELSE now() END,
    moderation_reason = CASE WHEN p_available THEN NULL ELSE btrim(p_reason) END,
    updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    CASE WHEN p_available THEN 'PRODUCT_RESTORED' ELSE 'PRODUCT_HIDDEN' END,
    'product', p_id::text, 'success', NULL, p_id::text, '{}'::jsonb);
  RETURN CASE WHEN p_available THEN 'available' ELSE 'hidden' END;
END $$;

DROP FUNCTION IF EXISTS public.product_admin_delete(uuid, text);

CREATE FUNCTION public.product_admin_delete(p_id uuid, p_reason text) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  p        public.products%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'produit : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('marketplace.products.delete');

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 OR length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'produit : motif requis (5 à 1000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO p FROM public.products WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'produit : introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF EXISTS (SELECT 1 FROM public.orders WHERE product_id = p_id) THEN
    RAISE EXCEPTION 'produit : des commandes y sont rattachées, on le masque, on ne l''efface pas'
      USING ERRCODE = '55000';
  END IF;

  DELETE FROM public.products WHERE id = p_id;
  PERFORM public.write_admin_audit(
    'PRODUCT_DELETED', 'product', p_id::text, 'success', NULL, p_id::text,
    jsonb_build_object('was_available', p.is_available));
  RETURN 'deleted';
END $$;

DROP FUNCTION IF EXISTS public.order_admin_resolve_dispute(uuid, text, text);

CREATE FUNCTION public.order_admin_resolve_dispute(
  p_id         uuid,
  p_resolution text,
  p_note       text
) RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller text := (SELECT public.firebase_uid());
  o        public.orders%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'litige : réservé aux administrateurs' USING ERRCODE = '42501';
  END IF;
  PERFORM public.admin_require_permission('marketplace.disputes.resolve');

  IF p_resolution IS NULL OR p_resolution NOT IN ('buyer_favor', 'seller_favor', 'refund') THEN
    RAISE EXCEPTION 'litige : décision invalide (buyer_favor, seller_favor, refund)' USING ERRCODE = '22023';
  END IF;
  IF p_note IS NULL OR length(btrim(p_note)) < 5 OR length(p_note) > 2000 THEN
    RAISE EXCEPTION 'litige : motif requis (5 à 2000 caractères)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO o FROM public.orders WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'litige : commande introuvable' USING ERRCODE = 'P0002';
  END IF;
  IF NOT (coalesce(o.is_in_dispute, false) OR coalesce(o.has_dispute, false)) THEN
    RAISE EXCEPTION 'litige : cette commande n''est pas en litige' USING ERRCODE = '55000';
  END IF;

  -- Décision consignée. Le séquestre n'est PAS libéré ni remboursé ici :
  -- aucun appel prestataire n'existe dans le dépôt.
  UPDATE public.orders SET
    dispute_resolution = p_resolution, dispute_note = btrim(p_note),
    dispute_resolved_by = v_caller, dispute_resolved_at = now(),
    is_in_dispute = false, has_dispute = false, updated_at = now()
   WHERE id = p_id;

  PERFORM public.write_admin_audit(
    'DISPUTE_RESOLVED', 'order', p_id::text, 'success', p_resolution, p_id::text,
    jsonb_build_object('resolution', p_resolution));
  RETURN p_resolution;
END $$;

-- ── Droits d'exécution ──────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.transaction_admin_complete(uuid, text)               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.transaction_admin_fail(uuid, text)                   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.transaction_admin_request_refund(uuid, text)         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.transaction_admin_decide_refund(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.product_admin_set_availability(uuid, boolean, text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.product_admin_delete(uuid, text)                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.order_admin_resolve_dispute(uuid, text, text)        FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transaction_admin_complete(uuid, text)               TO authenticated;
GRANT EXECUTE ON FUNCTION public.transaction_admin_fail(uuid, text)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.transaction_admin_request_refund(uuid, text)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.transaction_admin_decide_refund(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.product_admin_set_availability(uuid, boolean, text)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.product_admin_delete(uuid, text)                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.order_admin_resolve_dispute(uuid, text, text)        TO authenticated;

NOTIFY pgrst, 'reload schema';
