-- Diagnostic : l'aperçu chiffré de la liste dépend de deux réglages serveur.
--
-- `MlsNotificationPreview` ne déchiffre que si le push porte
-- `showMessagePreview != 'false'` — `send-push` le transmet depuis
-- `users.show_message_preview`. Et sans push du tout
-- (`notifications_enabled = false`, ou aucun jeton FCM), l'isolate n'est jamais
-- réveillé : il n'y a rien à relire, et la liste garde son libellé générique.
--
-- À lire AVANT de conclure qu'un aperçu manquant est un défaut de code.
-- Lecture seule, encadrée par BEGIN/ROLLBACK.

BEGIN;

SELECT u.id,
       u.notifications_enabled,
       u.show_message_preview,
       -- `fcm_tokens` est un JSONB, pas un tableau Postgres.
       jsonb_array_length(coalesce(u.fcm_tokens, '[]'::jsonb)) AS jetons_fcm
  FROM public.users u
 WHERE u.id IN (
         'U64HKfrjM5NwR6HO00XPKo6168z2',  -- Salim (destinataire observé)
         'vQZE49dTdyRtLwSG6lMIbhAqoFG2'   -- Sim A (expéditeur)
       );

ROLLBACK;
