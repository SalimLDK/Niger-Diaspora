-- =============================================================================
-- Ferme le trou anon sur 4 RPC repérées par l'audit du 2026-08-13
-- (voir [[project_supabase_echecs_muets]] pour la cause structurelle :
-- ALTER DEFAULT PRIVILEGES accorde EXECUTE à anon sur toute nouvelle fonction,
-- REVOKE ALL ... FROM PUBLIC ne suffit pas à le retirer).
--
-- 1) lock_escrow_for_release(uuid, text) — libère l'escrow d'une commande
--    marketplace (déclenche le virement Stripe au vendeur). Deux défauts :
--    a) bug de logique : `IF p_caller_id IS NOT NULL AND buyer_id != p_caller_id`
--       — passer p_caller_id = NULL contournait entièrement le contrôle
--       d'appartenance.
--    b) p_caller_id est un paramètre fourni par l'appelant, jamais vérifié
--       contre une session — usurper n'importe quel buyer_id suffisait.
--    Le seul appelant légitime (supabase/functions/process-escrow-release)
--    valide déjà le JWT lui-même AVANT d'appeler cette RPC, et le fait avec
--    la clé service_role (pas de JWT utilisateur à transmettre côté SQL — la
--    dériver ici via auth.jwt() casserait ce flux). Le bon correctif n'est
--    donc pas de re-dériver l'identité en SQL, mais de fermer l'accès direct :
--    seul service_role peut désormais l'appeler, et le contrôle NULL est
--    devenu strict en défense en profondeur.
--
-- 2) e2ee_add_active_device / e2ee_remove_active_device(text, text) — aucune
--    vérification : n'importe qui pouvait ajouter un appareil à la liste des
--    appareils actifs E2EE de N'IMPORTE QUEL utilisateur (risque d'écoute si
--    cette liste sert au fan-out des messages chiffrés), ou en retirer un
--    (déni de service — la victime ne reçoit plus ses messages chiffrés).
--    Le code Dart (key_manager_service.dart, device_sync_service.dart) les
--    appelle toujours avec le propre userId de l'appelant : contrôle
--    « soi-même uniquement » ajouté en conséquence, via le helper firebase_uid()
--    déjà utilisé par accept_friend_request/delete_group/insert_group.
--
-- 3) consume_one_time_prekey(text, text) — cross-utilisateur PAR CONCEPTION
--    (Alice consomme une clé de Bob pour démarrer une session Signal) : pas de
--    contrôle « soi-même ». Mais accessible sans compte du tout, ce qui rend
--    l'épuisement du stock de clés à usage unique de n'importe qui gratuit et
--    anonyme. Relevé au minimum à « authentifié ».
--
-- 4) increment_column(text, text, text, int) — allowlist déjà en place
--    (compteurs Heritage uniquement), mais aucune vérification d'appelant.
--    Relevé à « authentifié », comme le fait déjà l'app côté Dart
--    (heritage_provider.dart n'appelle qu'après vérification de currentUser).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.lock_escrow_for_release(
  p_order_id uuid,
  p_caller_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order orders%ROWTYPE;
BEGIN
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  -- Strict : absent ou différent, dans les deux cas refusé (l'ancienne version
  -- laissait passer un p_caller_id NULL).
  IF p_caller_id IS NULL OR v_order.buyer_id != p_caller_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Caller is not the order buyer');
  END IF;

  IF v_order.status != 'delivered' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Order status is %s, expected delivered', v_order.status)
    );
  END IF;

  IF v_order.escrow_status != 'held' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Escrow status is %s, expected held', v_order.escrow_status)
    );
  END IF;

  UPDATE orders
  SET escrow_status = 'releasing', updated_at = NOW()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'order', jsonb_build_object(
      'id',                        v_order.id,
      'seller_id',                 v_order.seller_id,
      'total_amount',              v_order.total_amount,
      'currency',                  v_order.currency,
      'stripe_payment_intent_id',  v_order.stripe_payment_intent_id
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.lock_escrow_for_release(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lock_escrow_for_release(uuid, text) TO service_role;

COMMENT ON FUNCTION public.lock_escrow_for_release(uuid, text) IS
  'Verrouille l''escrow d''une commande avant virement Stripe. Réservée à service_role : l''unique appelant légitime (Edge Function process-escrow-release) a déjà validé le JWT avant d''appeler ici. Ne jamais rouvrir à anon/authenticated sans re-dériver p_caller_id depuis une session vérifiée.';

CREATE OR REPLACE FUNCTION public.e2ee_add_active_device(
  p_user_id text,
  p_device_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_max_devices constant int := 5;
BEGIN
  IF p_user_id IS DISTINCT FROM firebase_uid() THEN
    RAISE EXCEPTION 'e2ee_add_active_device: not authorized' USING ERRCODE = '42501';
  END IF;

  INSERT INTO e2ee_user_keys (user_id, e2ee_enabled, e2ee_version, active_devices, updated_at)
  VALUES (p_user_id, TRUE, 1, ARRAY[p_device_id], NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET active_devices = (
          SELECT ARRAY(
            SELECT DISTINCT unnest(e2ee_user_keys.active_devices || ARRAY[p_device_id])
          )
        ),
        e2ee_enabled = TRUE,
        updated_at   = NOW();

  -- Élagage : on garde les v_max_devices plus récemment actifs.
  -- `dev = p_device_id` en tête du tri garantit que l'appareil qui vient de
  -- s'enregistrer n'est jamais celui qu'on retire, même sans `last_active`.
  UPDATE e2ee_user_keys u
  SET active_devices = (
        SELECT ARRAY(
          SELECT dev
          FROM unnest(u.active_devices) AS dev
          LEFT JOIN e2ee_devices d
            ON d.user_id = u.user_id AND d.device_id = dev
          ORDER BY (dev = p_device_id) DESC, d.last_active DESC NULLS LAST
          LIMIT v_max_devices
        )
      ),
      updated_at = NOW()
  WHERE u.user_id = p_user_id
    AND array_length(u.active_devices, 1) > v_max_devices;
END;
$$;

REVOKE ALL ON FUNCTION public.e2ee_add_active_device(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.e2ee_add_active_device(text, text) TO authenticated;

COMMENT ON FUNCTION public.e2ee_add_active_device(text, text) IS
  'Enregistre un appareil E2EE actif pour l''utilisateur authentifié courant (soi-même uniquement — p_user_id doit matcher firebase_uid()).';

CREATE OR REPLACE FUNCTION public.e2ee_remove_active_device(
  p_user_id text,
  p_device_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
BEGIN
  IF p_user_id IS DISTINCT FROM firebase_uid() THEN
    RAISE EXCEPTION 'e2ee_remove_active_device: not authorized' USING ERRCODE = '42501';
  END IF;

  UPDATE e2ee_user_keys
  SET    active_devices = array_remove(active_devices, p_device_id),
         updated_at     = NOW()
  WHERE  user_id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.e2ee_remove_active_device(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.e2ee_remove_active_device(text, text) TO authenticated;

COMMENT ON FUNCTION public.e2ee_remove_active_device(text, text) IS
  'Retire un appareil E2EE actif pour l''utilisateur authentifié courant (soi-même uniquement — p_user_id doit matcher firebase_uid()).';

CREATE OR REPLACE FUNCTION public.consume_one_time_prekey(
  p_user_id text,
  p_device_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_row e2ee_one_time_prekeys;
BEGIN
  -- Cross-utilisateur par conception (Alice consomme une clé de Bob) : pas de
  -- contrôle « soi-même », seulement une exigence d'authentification pour
  -- retirer la gratuité/l'anonymat d'un épuisement de stock de clés.
  IF firebase_uid() IS NULL THEN
    RAISE EXCEPTION 'consume_one_time_prekey: not authenticated' USING ERRCODE = '42501';
  END IF;

  DELETE FROM e2ee_one_time_prekeys
  WHERE id = (
    SELECT id
    FROM   e2ee_one_time_prekeys
    WHERE  user_id   = p_user_id
      AND  device_id = p_device_id
    LIMIT  1
    FOR UPDATE SKIP LOCKED
  )
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'keyId',     v_row.key_id,
    'publicKey', v_row.public_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.consume_one_time_prekey(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consume_one_time_prekey(text, text) TO authenticated;

COMMENT ON FUNCTION public.consume_one_time_prekey(text, text) IS
  'Consomme une clé pré-partagée à usage unique (X3DH). Cross-utilisateur par conception ; exige seulement une session authentifiée, pas p_user_id = soi-même.';

CREATE OR REPLACE FUNCTION public.increment_column(
  p_table text,
  p_id text,
  p_column text,
  p_delta integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
BEGIN
  IF firebase_uid() IS NULL THEN
    RAISE EXCEPTION 'increment_column: not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT (
       (p_table = 'heritage_collections' AND p_column IN ('followerCount','playCount'))
    OR (p_table = 'heritage_recordings'  AND p_column IN ('playCount','likeCount','shareCount','downloadCount'))
  ) THEN
    RAISE EXCEPTION 'increment_column: not allowed for %.%', p_table, p_column;
  END IF;

  EXECUTE format(
    'UPDATE %I SET %I = GREATEST(COALESCE(%I, 0) + $1, 0) WHERE id = $2',
    p_table, p_column, p_column
  ) USING p_delta, p_id;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_column(text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_column(text, text, text, integer) TO authenticated;

COMMENT ON FUNCTION public.increment_column(text, text, text, integer) IS
  'Incrémente un compteur Heritage allowlisté. Exige une session authentifiée (l''app ne l''appelle déjà que dans ce cas).';
