-- =============================================================================
-- RPC create_user_notification : créer une notification POUR UN AUTRE utilisateur.
--
-- Problème corrigé : la policy `notifications_own` est
--   FOR ALL USING (firebase_uid() = user_id)
-- Sans WITH CHECK distinct, Postgres applique cette condition à l'INSERT. Donc
-- quand A like/commente/ajoute B, le client de A tente d'insérer une notif
-- user_id = B → firebase_uid() = A ≠ B → RLS bloque (42501), l'erreur est avalée
-- par le catch client → AUCUNE notif (ni in-app ni push) pour B.
-- Résultat : seules les notifs « pour soi-même » passaient, i.e. quasi aucune.
--
-- Fix : un RPC SECURITY DEFINER (contourne la RLS) qui
--   1) exige un appelant authentifié,
--   2) vérifie que le destinataire existe,
--   3) estampille l'ACTEUR RÉEL (firebase_uid()) dans data.actor_id pour qu'un
--      client ne puisse pas se faire passer pour un autre expéditeur,
--   4) insère la ligne → le trigger notify_push_on_notification prend le relais
--      (→ send-push → FCM).
--
-- Note de durcissement (hors périmètre) : l'idéal à terme est de créer ces
-- notifications via des triggers DB sur post_likes / post_comments /
-- friend_requests / orders … (impossible à spoofer, pas de dépendance client).
-- Ce RPC débloque le fonctionnement sans cette refonte.
-- Idempotent : CREATE OR REPLACE.
-- =============================================================================

CREATE OR REPLACE FUNCTION create_user_notification(
  p_user_id TEXT,
  p_type    TEXT,
  p_title   TEXT,
  p_body    TEXT,
  p_data    JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor TEXT := firebase_uid();
  v_id    UUID;
BEGIN
  IF v_actor IS NULL OR v_actor = '' THEN
    RAISE EXCEPTION 'create_user_notification: not authenticated';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'create_user_notification: recipient % not found', p_user_id;
  END IF;

  INSERT INTO notifications (user_id, type, title, body, data, is_read)
  VALUES (
    p_user_id,
    p_type,
    p_title,
    p_body,
    COALESCE(p_data, '{}'::jsonb) || jsonb_build_object('actor_id', v_actor),
    FALSE
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION create_user_notification(TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_user_notification(TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
