-- `messages.created_at` est posé par le serveur pour toute écriture client.
--
-- LE DÉFAUT
-- Le client envoie `created_at` = `DateTime.now()` de SON téléphone
-- (message_supabase_datasource : `'created_at': now`). Une horloge en retard
-- ou en avance de quelques minutes — fréquent, un téléphone sans heure réseau
-- ou réglé à la main — datait le message de travers pour tout le monde :
--   · en direct, le destinataire jetait l'INSERT : son flux ne gardait que
--     les messages postérieurs au dernier message chargé, et celui-ci
--     « datait » d'avant ;
--   · il réapparaissait au rechargement, rangé dans le passé, au milieu de
--     messages qu'il suivait en réalité ;
--   · la pagination par curseur `(created_at, id)` et le push (« l'heure du
--     message », 20260916140000) héritaient de la même date fausse.
--
-- LE CORRECTIF
-- Un déclencheur BEFORE INSERT remplace `created_at` par `now()` pour les
-- écritures DIRECTES (`authenticated`, `anon`) — sur le modèle de
-- `guard_group_members_role` (20260917010000) et des colonnes figées des
-- conversations (20261003120000). Les fonctions SECURITY DEFINER (notices de
-- groupe…) s'exécutent sous leur propriétaire et gardent la date qu'elles
-- posent.
--
-- Le client n'a rien à changer pour que ça tienne : la colonne qu'il envoie
-- est simplement remplacée. Il cesse en parallèle de comparer cette date à
-- sa propre horloge (flux temps réel, rapprochement de l'écho).
--
-- `UPDATE` n'est pas concerné : `created_at` n'est pas dans les colonnes que
-- `authenticated` peut modifier (`GRANT UPDATE (data, is_deleted)`,
-- 20260916210000).
--
-- Banc : tools/rls_tests/messages_dates_par_le_serveur.sql

CREATE OR REPLACE FUNCTION public.messages_date_du_serveur()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    NEW.created_at := now();
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.messages_date_du_serveur() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS messages_date_du_serveur ON public.messages;
CREATE TRIGGER messages_date_du_serveur
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.messages_date_du_serveur();
