-- CIBLE (non appliquée) : `reports` ne change plus de statut que par
-- `signalement_transition`.
--
-- À APPLIQUER seulement quand le panneau appelle la RPC (tranche 2) et que ce
-- build est déployé : sinon « Résoudre » / « Classer » font un UPDATE qui ne
-- touche plus aucune ligne, et l'écran affiche un succès à vide.
-- Banc : tools/rls_tests/moderation_signalements_update_ferme_cible.sql.

SET lock_timeout = '5s';

DROP POLICY IF EXISTS "reports_update_admin" ON public.reports;
REVOKE UPDATE ON public.reports FROM authenticated;
