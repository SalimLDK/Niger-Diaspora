-- write_admin_audit accepte les noms d'action HISTORIQUES (`ban_user`,
-- `refund_transaction`…), en plus des MAJUSCULES du référentiel.
--
-- 20261016090000 n'admettait que MAJUSCULES_ET_TIRETS_BAS. Or le panneau écrit
-- des noms en minuscules (une vingtaine d'appels à AdminAuditHelper.log), ses
-- écrans les affichent par un `switch` sur ces noms (admin_audit_screen.dart),
-- et functions/supabase.js en écrit d'autres : les passer en majuscules
-- scinderait l'historique en deux orthographes et casserait les libellés. La
-- règle devient : lettres, chiffres, tiret bas, 3 à 64 caractères, sans
-- espace ni ponctuation. Les nouveaux événements suivent le référentiel
-- (MAJUSCULES) ; les anciens restent lisibles.
--
-- Même signature, même ACL : CREATE OR REPLACE ne les touche pas. Banc :
-- tools/rls_tests/admin_catalogue_permissions_et_audit.sql (cas 51 : une
-- action avec espace reste refusée).

CREATE OR REPLACE FUNCTION public.write_admin_audit(
  p_action         text,
  p_resource_type  text,
  p_resource_id    text,
  p_result         text  DEFAULT 'success',
  p_reason_code    text  DEFAULT NULL,
  p_correlation_id text  DEFAULT NULL,
  p_metadata       jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor text := (SELECT public.firebase_uid());
  v_name  text;
  v_id    uuid;
BEGIN
  IF v_actor IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'write_admin_audit : réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  IF p_action IS NULL OR p_action !~ '^[A-Za-z][A-Za-z0-9_]{2,63}$' THEN
    RAISE EXCEPTION 'write_admin_audit : action invalide (lettres, chiffres, tiret bas)'
      USING ERRCODE = '22023';
  END IF;
  IF p_result NOT IN ('success', 'denied', 'failed', 'partial') THEN
    RAISE EXCEPTION 'write_admin_audit : result invalide' USING ERRCODE = '22023';
  END IF;

  p_metadata := COALESCE(p_metadata, '{}'::jsonb);
  IF jsonb_typeof(p_metadata) <> 'object' OR length(p_metadata::text) > 4096 THEN
    RAISE EXCEPTION 'write_admin_audit : metadata doit être un objet de 4 Ko au plus'
      USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_metadata) k
              WHERE lower(k) ~ '(pass|token|secret|api_?key|private_?key|authorization)') THEN
    RAISE EXCEPTION 'write_admin_audit : metadata ne doit porter aucun secret'
      USING ERRCODE = '22023';
  END IF;

  SELECT display_name INTO v_name FROM public.users WHERE id = v_actor;

  INSERT INTO public.admin_audit_logs
    (admin_id, admin_name, action, target_type, target_id, details,
     result, reason_code, correlation_id)
  VALUES
    (v_actor, v_name, p_action, p_resource_type, p_resource_id, p_metadata,
     p_result, p_reason_code, p_correlation_id)
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;
