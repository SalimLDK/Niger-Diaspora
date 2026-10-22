-- Journal d'audit : plus aucune écriture directe, seulement `write_admin_audit`
-- (ou la clé de service).
--
-- Le panneau déployé le 2026-10-18 n'écrit plus l'audit que par la fonction
-- (admin_provider.dart, `_ecrireAudit`) : la source ne contient plus aucun
-- INSERT sur la table, et le bundle servi appelle `write_admin_audit`. Avant
-- cette migration, tout administrateur pouvait écrire une ligne d'audit à
-- n'importe quel nom d'acteur par la policy d'INSERT.
--
-- Banc : tools/rls_tests/admin_audit_ecriture_par_rpc_cible.sql (2/2).
-- Retour arrière : recréer la policy `admin_audit_logs_insert_admin` et
-- `GRANT INSERT … TO authenticated`.

SET lock_timeout = '5s';

DROP POLICY IF EXISTS admin_audit_logs_insert_admin ON public.admin_audit_logs;
REVOKE INSERT ON public.admin_audit_logs FROM authenticated;
