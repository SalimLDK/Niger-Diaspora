-- =============================================================================
-- `users.notification_prefs` — les préférences par type, côté serveur.
--
-- Jusqu'ici elles n'existaient que dans les SharedPreferences de l'appareil, et
-- `_shouldShowNotification` ne les consultait que depuis
-- `_handleForegroundMessage`. App en arrière-plan ou tuée, c'est le système qui
-- affiche le bloc `notification` du push : la préférence n'était jamais lue.
-- Couper « Messages » dans les réglages ne coupait donc rien dès que l'app était
-- fermée — précisément le moment où ça compte.
--
-- Une colonne JSONB plutôt que douze booléens : l'ensemble des types bouge avec
-- les fonctionnalités, et `send-push` n'a besoin que d'une lecture par clé.
--
-- Convention : **clé absente = notification autorisée**. Seul un `false`
-- explicite coupe. Les comptes existants ({} par défaut) gardent donc le
-- comportement actuel, et un type ajouté plus tard est actif par défaut.
--
-- Les clés sont celles des SharedPreferences, sans le préfixe `notify_` :
--   messages, friend_requests, groups, events, event_reminders, local_events,
--   audio_room_reminders, podcast_episodes, transfer_reminders, calls, orders,
--   system_messages
--
-- `notifications_enabled` (interrupteur maître) et `show_message_preview`
-- restent des colonnes à part : elles préexistent et `send-push` les lit déjà.
-- =============================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS notification_prefs JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.users.notification_prefs IS
  'Préférences de notification par type, écrites par l''app et lues par '
  'l''Edge Function send-push. Clé absente = autorisé ; seul false coupe.';

-- PostgREST doit revoir son cache de schéma pour exposer la colonne.
NOTIFY pgrst, 'reload schema';
