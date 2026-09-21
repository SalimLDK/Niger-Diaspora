-- ════════════════════════════════════════════════════════════════════════════
-- CIBLE — NE PAS APPLIQUER EN L'ÉTAT. Fermeture 1.1b de l'audit pré-prod.
-- ════════════════════════════════════════════════════════════════════════════
--
-- Ce fichier est HORS de `supabase/migrations/` : `db push` ne le voit pas,
-- et c'est voulu. Il décrit l'état final de `users`, écrit et répété, en
-- attendant que les conditions ci-dessous soient TOUTES remplies. Même
-- convention que `gel-messages-cible.sql` et `database.rules.strict-cible.json`.
--
-- Banc de préparation : tools/rls_tests/users_colonnes_privees_cible.sql —
-- il répète ce fichier en `BEGIN … ROLLBACK` et dit ce qui tiendrait et ce
-- qui casserait.
--
-- ═══ CE QUE ÇA FERME ═════════════════════════════════════════════════════
--
-- Mesuré le 2026-09-21 sous l'identité d'un compte ordinaire : 127 profils
-- lisibles, 89 e-mails, 65 positions, 64 jeux de jetons push, 35
-- identifiants de session. Dont deux consentements que le serveur n'applique
-- pas : 6 personnes ont coupé `share_location` et restent localisables,
-- 1 téléphone réglé sur `private` reste lisible.
--
-- ═══ POURQUOI ON NE PEUT PAS L'APPLIQUER AUJOURD'HUI ═════════════════════
--
-- Sous droits par colonnes, PostgREST refuse la requête ENTIÈRE dès qu'elle
-- touche une colonne non accordée — `SELECT *`, un filtre `WHERE`, ou le
-- `RETURNING *` d'un upsert. Tout build installé perdrait profil, carte,
-- recherche, liste des discussions et enregistrement du jeton push.
--
-- ═══ CONDITIONS, TOUTES REQUISES, DANS CET ORDRE ═════════════════════════
--
-- 1. UNE VERSION CLIENTE qui ne touche plus aucune colonne révoquée par
--    PostgREST. 16 sites au 2026-09-21 :
--
--    a) 11 lectures de `*` — elles cassent en 42501 :
--       profile_supabase_datasource.dart  :121 :141(.stream) :164 :183 :233
--                                         :260 :289 :366(upsert RETURNING *)
--       auth_remote_datasource.dart       :736
--       admin_provider.dart               :372 :1512  → `profils_admin()`
--       Pour soi : `mon_profil_prive()`. Pour autrui : colonnes nommées,
--       prises dans la liste du GRANT ci-dessous. La carte :
--       `positions_partagees()`, puis l'identité par identifiants.
--
--    b) 3 lectures NOMMÉES de colonnes révoquées, sur SA propre ligne —
--       elles cassent aussi en 42501, et la liste explicite ne protège de
--       rien :
--       notification_service.dart :1749 :1797 (`fcm_tokens`) — c'est
--         l'enregistrement du jeton push. Le laisser casser, c'est plus
--         AUCUNE notification sur un nouvel appareil. À remplacer par une
--         RPC qui ajoute le jeton côté serveur, pas par une relecture ;
--       session_service.dart :300 (`session_id`).
--
--    c) 2 abonnements temps réel — ils NE cassent PAS, et c'est le piège :
--       le temps réel RETIRE une colonne révoquée au lieu d'échouer (mesuré :
--       tools/rls_tests/temps_reel_droits_colonnes.sql). Donc :
--       profile_supabase_datasource.dart :333 — la carte en direct perd
--         `latitude`/`longitude`, le rappel sort tôt, plus personne ne bouge
--         à l'écran. Sans erreur ;
--       session_service.dart :281 — `session_id` n'arrive plus, et la
--         révocation de session par un administrateur cesse de marcher.
--         Sans erreur. (`is_banned` reste accordé : l'éjection des bannis,
--         elle, continue.)
--
--    Et un test qui balaie `lib/` pour interdire `from('users')` suivi d'un
--    `select()` nu, d'un `.stream(`, ou d'un `onPostgresChanges` sur
--    `users` — sur le modèle du garde de `RustLib.init()`.
--
-- 2. CETTE VERSION PUBLIÉE sur les deux stores, et sa version inscrite dans
--    `DERNIERE_VERSION_APP`.
--
-- 3. LE VERROU POSÉ : `supabase secrets set VERSION_MINIMALE_APP=<elle>`.
--    `app-config` sert cette clé depuis le 2026-09-21 (v5) ; le verrou était
--    inerte avant. Il refuse de bloquer si la version exigée n'est pas encore
--    sur le store — une valeur posée trop tôt reste sans effet.
--
-- 4. Laisser passer un délai pour que les appareils se mettent à jour, puis
--    seulement : répéter ce fichier par son banc, l'appliquer.
--
-- ═══ CE QUI RESTE HORS DE CETTE CIBLE ════════════════════════════════════
--
-- · `phone_visibility` : révoquer `phone_number` le retire à TOUT LE MONDE,
--   y compris aux 8 comptes qui l'ont réglé sur `everyone`. Il faudra une
--   RPC qui applique `everyone` / `friends` / `none` — et trancher d'abord le
--   vocabulaire : la base écrit `private`, le client connaît `everyone`,
--   `friends`, `none`.
-- · `show_online_status` : même forme que `share_location`, consentement
--   appliqué par le seul client. `is_online` et `last_seen_at` restent
--   accordés ici, faute de quoi toute présence disparaîtrait.
--
-- ═══ CONTRAINTE À NE JAMAIS OUBLIER ══════════════════════════════════════
--
-- `id` et `is_admin` doivent rester dans le GRANT. Deux policies d'AUTRES
-- tables les lisent sous le rôle de l'appelant — `content_reports` (« Admins
-- can manage all reports ») et `mls_diagnostics` (« lire les siens ou
-- admin »). Les retirer ferait tomber ces deux tables en 42501, loin d'ici.
-- Relevé le 2026-09-21 : aucune autre policy, aucune fonction INVOKER ne lit
-- une colonne révoquée par ce fichier.
--
-- ⚠️ PAS DE `BEGIN` / `COMMIT` ICI, ET C'EST UNE SÉCURITÉ. Le banc injecte ce
-- fichier dans une répétition en `BEGIN … ROLLBACK` : un `COMMIT` au milieu
-- VALIDERAIT le REVOKE en production, et le `ROLLBACK` final n'annulerait
-- plus rien. Le banc refuse d'ailleurs d'injecter un texte qui en contient.
-- Le jour de l'application, ce fichier devient une migration : l'encadrer
-- alors de `BEGIN … COMMIT` (voir la note « db push sans transaction »).

REVOKE SELECT ON public.users FROM authenticated;

-- Tout sauf : email, phone_number, latitude, longitude, location_updated_at,
-- fcm_tokens, voip_token, last_token_update, session_id, cart_data,
-- ban_reason, banned_at, banned_by, admin_role.
--
-- Accordés délibérément malgré une sensibilité faible : `is_banned` (le
-- guetteur de session en a besoin pour éjecter un banni), les préférences de
-- notification et les drapeaux d'onboarding (lus par leur seul propriétaire,
-- sans enjeu pour un tiers — les garder retire l'onboarding de la liste des
-- sites à reprendre).
GRANT SELECT (
  id, firebase_uid, display_name, display_name_lower, handle, avatar_url,
  bio, profession, country_code, city, ville_id, current_region,
  origin_region, origin_city,
  is_private, is_visible, is_verified, is_admin, is_banned,
  follower_count, following_count, post_count,
  connections_count, groups_count, events_count,
  interests, skills, languages,
  is_online, last_seen_at, last_active_at, show_online_status,
  share_location, phone_visibility, is_phone_verified,
  notifications_enabled, notify_local_events, show_message_preview,
  notification_prefs,
  has_seen_onboarding, has_seen_coach_marks, has_given_consent,
  consent_date, profile_config_complete,
  created_at, updated_at
) ON public.users TO authenticated;
