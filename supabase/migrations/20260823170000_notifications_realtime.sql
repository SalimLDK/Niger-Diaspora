-- La page Notifications s'abonne au flux temps réel de `public.notifications`
-- (`.stream(primaryKey: ['id'])` dans NotificationSupabaseDataSource).
-- La table n'a jamais été ajoutée à la publication `supabase_realtime`, alors
-- que `messages` et `conversations` y sont. L'abonnement échouait donc à
-- chaque ouverture de l'écran :
--
--   RealtimeSubscribeException(status: channelError, details: Unable to
--   subscribe to changes with given parameters. Please check Realtime is
--   enabled ... table: notifications ...)
--
-- Le flux réessaie quatre fois puis laisse remonter l'erreur : l'écran
-- affichait « Erreur de chargement » alors que les lignes existaient bien en
-- base (badge de la cloche à 19). Vérifié sur SM A515F le 2026-08-23, le
-- message d'erreur ci-dessus vient de son logcat.
--
-- RLS reste la seule barrière, et elle est déjà en place : la policy
-- `notifications_own` (`firebase_uid() = user_id`, cmd ALL) est du même modèle
-- que `messages_select`, qui fonctionne déjà en temps réel — Realtime évalue
-- les policies avec le JWT du client.
--
-- REPLICA IDENTITY reste à `default`, comme `messages`. Conséquence assumée :
-- les événements DELETE ne portent que la clé primaire, donc le filtre
-- `user_id=eq.…` ne peut pas être évalué dessus et un DELETE n'est pas diffusé.
-- Sans effet ici : une notification n'est supprimée que par son propriétaire,
-- depuis l'app, qui met sa liste à jour localement. Passer à `full` coûterait
-- du WAL pour un cas qui ne se produit pas.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END
$$;
