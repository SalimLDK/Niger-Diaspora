-- =============================================================================
-- Ajoute `users` à la publication supabase_realtime.
--
-- Raison : profile_supabase_datasource.getUserStream() utilise .stream() (donc
-- Supabase Realtime) sur la table users. Sans la table dans la publication, le
-- flux est incomplet / peut échouer → le profil est vu comme introuvable →
-- l'écran affiche à tort « Profil supprimé ».
--
-- Les RLS de users continuent de s'appliquer au realtime (users_select), donc
-- aucun élargissement d'accès : un abonné ne reçoit que les lignes qu'il a le
-- droit de lire.
--
-- REPLICA IDENTITY FULL : nécessaire pour que les événements UPDATE/DELETE
-- realtime portent l'ancienne ligne et passent correctement le filtre RLS.
-- Idempotent : sûr à rejouer.
-- =============================================================================

ALTER TABLE public.users REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
