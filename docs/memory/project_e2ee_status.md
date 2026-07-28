---
name: project_e2ee_status
description: "Statut E2EE : Signal câblé (1:1 + groupes), clé AES globale = fallback + aperçus/localisation/background ; per-conversation keys écarté"
metadata: 
  node_type: memory
  type: project
  originSessionId: 33a17c23-b0bb-4143-9bba-895a4bfe1d75
  modified: 2026-07-28T08:39:48.330Z
---

## État vérifié (2026-07-17)

Signal Protocol **est câblé** dans le flux de messages (pas code mort). Dispatch dans `_encryptContent` — [message_remote_datasource.dart:710] :
- **1:1** → `encrypt1to1()` → `e2eePayloads`, `encryptionLevel: 'e2ee'` (serveur ne peut pas déchiffrer)
- **Groupes** → `encryptGroup()` → Sender Keys Signal
- **AES clé globale (`ENCRYPTION_KEY`)** → seulement le **fallback** quand pas de session Signal

## Où `ENCRYPTION_KEY` (clé AES globale) reste load-bearing
- Fallback sans session Signal — message_crypto_service.dart:98,127
- `lastMessage` aperçu conversation — message_remote_datasource.dart:1694
- Localisation lat/lng/adresse — :2072-2083
- Réponse depuis notification (isolate background) — background_reply_service.dart:116
- Legacy en base
- **Cloud Functions notifications** — functions/index.js:114 `decryptText` construit l'aperçu push côté serveur. Messages E2EE → déjà aperçu générique (`getE2EEMessagePreview`).

## Régression corrigée le 2026-07-17 : envoi DM bloqué si destinataire sans clés
`_encryptContent` (message_supabase_datasource.dart) avait deux gardes qui **court-circuitaient le repli AES** et faisaient échouer TOUT envoi (triangle rouge, message non persisté) vers un destinataire n'ayant jamais publié ses clés Signal :
1. `throw` si `!recipientHasKeys(recipientId)` — avant même d'essayer.
2. `throw` si `result.encryptionLevel != 'e2ee'` — rejetait le résultat AES pourtant valide (groupes inclus).
Or `encrypt1to1()`/`encryptGroup()` retombent déjà proprement sur AES (message_crypto_service.dart:98,127) sans jamais throw. **Correctif** : les deux gardes retirées ; on garde `recipientHasKeys` seulement pour décider s'il vaut la peine de tenter X3DH (sinon on va direct au repli AES, pas d'attente 10 s). Ne jamais réintroduire de throw qui bloque l'envoi sur absence d'E2EE. Symptôme typique : conversation « Aucun message » alors qu'on a tenté d'envoyer ; logs `KeyManagerService: No keys found` / `no bundle for <uid>`.

## Fiabilisation publication des clés Signal — 2026-07-17 (baisse le taux de repli AES)
Cause du « recipient sans clés » : `_publishKeysToSupabase` (key_manager_service.dart) écrivait dans `e2ee_devices` / RPC `e2ee_add_active_device` / OTP **sans `ensureAuthenticated()`**. Lancée en arrière-plan par `_bootE2EE` (auth_provider.dart) dès la résolution Firebase — donc **avant** que le pont de session Supabase soit prêt (fenêtre des 401 au démarrage) → écritures bloquées RLS, erreur avalée, **aucun retry**, clés jamais publiées à vie.
Correctifs :
1. Garde `SupabaseAuthBridge.ensureAuthenticated()` en tête de `_publishKeysToSupabase` et `_publishOneTimePreKeysToSupabase` (throw si session pas prête → déclenche le retry). `ensureAuthenticated()` établit proactivement la session.
2. `_publishWithRetry` : 4 tentatives, backoff 3/6/9 s, couvre la fenêtre de démarrage.
3. `_ensurePublishedToSupabase` vérifie désormais `e2ee_user_keys.active_devices` **non vide** (table qui fait autorité, cf. `fetchPreKeyBundle`), pas juste l'existence de la ligne.
4. **Clé du self-healing** : `MessagingE2EEService.initialize` appelle désormais `initializeKeys` **à chaque lancement** (avant : seulement si `!hasKeys`) → le filet `_ensurePublishedToSupabase` re-publie tout compte dont la publication initiale avait échoué. Ne pas remettre le `if (!hasKeys)`.
Vérif end-to-end complète = les DEUX appareils sur le nouveau build (le destinataire publie depuis SON device). Sur un seul device on ne valide que la (re)publication de ses propres clés.

## Instrumentation continue du taux de fallback AES (2026-07-17)
- Mesure one-shot (stock) : `scripts/measure_aes_fallback.sql` — SQL Editor Supabase (ref zyrfkcjjrhddpfxcgezo). Ne compte QUE le texte 1:1 (`conversations.type='individual'`, `messages.type='text'`) ; `data->>'encryptionLevel'` = aes/e2ee/null.
- Mesure continue (flux) : event Firebase Analytics **`message_encryption`** émis dans `MessageSupabaseDataSource._encryptContent` (fire-and-forget, `unawaited`). Params : `level` (aes|e2ee), `scope` (direct|group), `is_fallback`, `fallback_reason` (recipient_no_keys | session_failed | sender_key_failed). Méthode `AnalyticsService.logMessageEncryption`. Taux = count(level=aes)/count(*) par scope.

## Flux sauvegarde/restauration des clés câblé — 2026-07-28
Avant : les clés étaient générées silencieusement au login (`auth_provider._initializeE2EE` → `MessagingE2EEService.initialize`) et **rien** n'invitait à sauvegarder ; `SecurityBackupScreen` (`/settings/security/backup`, gère create ET restore selon `hasBackup`) n'était atteignable qu'à la main.
Nouveau : `E2EEBackupCoordinator` (`lib/core/services/e2ee/e2ee_backup_coordinator.dart`, `StateNotifierProvider<…, E2EEBackupPrompt>`), appelé par `auth_provider._initializeE2EE` à la place de `initialize` :
- clés locales présentes → `initialize` (self-healing re-publication conservé), prompt `none` ;
- pas de clés + `keyBackupService.hasBackup` vrai → `needsRestore`, **ne génère PAS** (générer écraserait l'identité, backup irrécupérable) ;
- pas de clés + pas de backup → `initialize` (génère) → `needsBackup`.
`MainShell` observe le provider (`ref.listen` + lecture initiale post-frame car listen ne rejoue pas l'état courant) et affiche un `MaterialBanner` non bloquant → route vers l'écran backup. Passphrases = liste EFF large (7776 mots) depuis `eff_wordlist.dart`, PBKDF2 200k + AES-256-GCM.
**Durci** : `KeyBackupService.checkBackupPresence` renvoie `BackupPresence.{present,absent,unknown}` — `absent` uniquement si `object-not-found` confirmé, toute autre erreur (réseau/permission/quota) = `unknown`. Le coordinateur ne génère de clés que sur `absent` ; sur `unknown` il ne génère RIEN et ne propose rien (repli AES, réévalué au login suivant) → plus de risque d'écraser une identité restaurable sur panne réseau. `hasBackup()` conservé (== present) car `SecurityBackupScreen` en dépend.

## Décision sur les clés per-conversation : ÉCARTÉ
Le contenu réel des messages est déjà en Signal (1:1 + groupes). Dériver des clés per-conversation que le serveur ignore = rendre tout le trafic « E2EE » côté serveur → **perte des aperçus de notification riches** (compromis fondamental E2EE). Gain de sécurité quasi nul (le message est déjà en Signal). **Ne pas investir.**

**Why:** Question user "mettre ENCRYPTION_KEY dans Supabase au lieu de .env" → analyse a révélé que la clé n'est plus le cœur du chiffrement.
**How to apply:** Garder `ENCRYPTION_KEY` en `.env` (asset Flutter, embarqué en clair — ce n'est pas un vrai secret côté client). Côté serveur elle est déjà secret Supabase (push-supabase-secrets.ps1:41) + `process.env` Functions. Vrai gain restant = baisser le **taux de fallback AES** (bonne établissement des sessions Signal), pas réécrire la crypto. Voir [[project_audit_remediation]].
