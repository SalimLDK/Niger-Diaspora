-- Enveloppe d'écriture du journal pour le panneau Flutter. NON APPLIQUÉE.
--
-- Prépare la fermeture de `write_admin_audit` (20261029130000). Le panneau l'appelle aujourd'hui en direct
-- (admin_provider.dart, `_ecrireAudit`). Une fois l'accès direct retiré à `authenticated`, il lui faut une
-- autre porte : cette enveloppe, qui refuse les rôles limités et délègue à `write_admin_audit`.
--
-- ORDRE IMPÉRATIF (le premier pas n'a aucun effet visible, le troisième peut casser un panneau périmé) :
--   1. appliquer CETTE migration ;
--   2. déployer le panneau Flutter qui appelle `admin_audit_client` (lib/.../admin_provider.dart) ;
--   3. SEULEMENT ALORS appliquer 20261029130000.
-- Sauter l'étape 2 coupe l'écriture d'audit du panneau en production.

SET lock_timeout = '5s';

DROP FUNCTION IF EXISTS public.admin_audit_client(text, text, text, jsonb);

CREATE FUNCTION public.admin_audit_client(
  p_action        text,
  p_resource_type text,
  p_resource_id   text,
  p_metadata      jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Un rôle limité (dont l'auditeur, garant du journal) n'écrit jamais une ligne « à la main ».
  IF (SELECT public.firebase_uid()) IS NULL OR NOT public.is_admin() OR public.is_limited_admin() THEN
    RAISE EXCEPTION 'journal : écriture directe réservée aux administrateurs' USING ERRCODE = '42501';
  END IF;
  RETURN public.write_admin_audit(p_action, p_resource_type, p_resource_id, 'success', NULL, NULL, p_metadata);
END $$;

REVOKE ALL ON FUNCTION public.admin_audit_client(text, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_audit_client(text, text, text, jsonb) TO authenticated;

NOTIFY pgrst, 'reload schema';
