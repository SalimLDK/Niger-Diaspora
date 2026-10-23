-- `reports.status` (et les colonnes de décision) ne change plus que par
-- `signalement_transition` (SECURITY DEFINER, migration 20261017100000).
--
-- Le panneau en ligne appelle la RPC (vérifié sur le bundle déployé le
-- 2026-10-23) ; l'UPDATE direct restait ouvert à tout admin, hors table des
-- transitions et sans audit.
--
-- Reste un seul UPDATE légitime : `reported_user_notified`, posé par le
-- panneau et par la source de données après l'envoi de la notification à la
-- personne signalée. Un REVOKE complet le ferait échouer en silence (l'appel
-- est enveloppé dans un catch) : on garde ce droit-là, colonne par colonne,
-- sous la même condition `is_admin()`.
--
-- Un GRANT n'enlève rien : Supabase accorde ALL par défaut, d'où le REVOKE
-- d'abord (anon autant qu'authenticated).

SET lock_timeout = '5s';

REVOKE UPDATE ON public.reports FROM anon, authenticated;
GRANT UPDATE (reported_user_notified) ON public.reports TO authenticated;

NOTIFY pgrst, 'reload schema';
