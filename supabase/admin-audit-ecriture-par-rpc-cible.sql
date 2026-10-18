-- CIBLE (non appliquée) : le journal d'audit ne s'écrit plus que par
-- `write_admin_audit` (ou la clé de service).
--
-- À APPLIQUER seulement quand le build du panneau qui appelle la RPC
-- (admin_provider.dart, `_ecrireAudit`) est DÉPLOYÉ : un panneau plus ancien
-- ferait un INSERT refusé (42501), et son `catch` avale l'erreur — l'audit
-- redeviendrait muet sans qu'aucun écran le montre. Ordre : déployer le web,
-- vérifier qu'une action de test laisse une ligne, puis copier ce fichier en
-- supabase/migrations/<horodatage>_….sql.
--
-- Banc : tools/rls_tests/admin_audit_ecriture_par_rpc_cible.sql.

SET lock_timeout = '5s';

DROP POLICY IF EXISTS admin_audit_logs_insert_admin ON public.admin_audit_logs;
REVOKE INSERT ON public.admin_audit_logs FROM authenticated;
