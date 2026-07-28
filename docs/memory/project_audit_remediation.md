---
name: Audit sécurité messagerie — état des corrections
description: Findings confirmés, faux positifs, et statut de chaque correctif appliqué sur la branche wip-jules
type: project
originSessionId: 37133e6b-8348-480f-b102-836e4bbbf777
---
## Corrections appliquées (session 2026-05-08)

| ID | Fichier | Statut |
|----|---------|--------|
| SEC-3 | `database.rules.json` | ✅ Corrigé — 5 validations tautologiques remplacées par règles `$uid === auth.uid` |
| SEC-5 | `firestore.rules:778` | ✅ Corrigé — `calls` list filtrée par callerId/calleeId |
| SEC-6 | `firestore.rules:533` | ✅ Corrigé — `business_reviews` list requiert isAuthenticated() |
| SEC-7 | `firestore.rules:498` | ✅ Corrigé — `group_invites` list filtrée par inviteeId/inviterId |
| SEC-8 | `firestore.rules:800` | ✅ Corrigé — `group_calls` list filtrée par hostId/participantIds |
| SEC-2 | `message_export_service.dart` | ✅ Corrigé — HtmlEscape sur senderName, content, displayName, fileUrl validé |
| BUG-2 | `message_provider.dart:321` | ✅ Corrigé — fenêtre optimiste 30s → 5s |
| BUG-4 | `message_repository_impl.dart` | ✅ Corrigé — fetch limit+1, `hasMore = messages.length > limit`, trim sublist(1) |
| PERF-1 | `message_repository_impl.dart:73-78` | ✅ Corrigé — sort null-safe (nulls en fin de liste) |
| PERF-2 | `message_provider.dart:593` | ✅ Corrigé — early return dans markAllAsReadLocally si rien à faire |

## Faux positifs confirmés (ne pas re-signaler)

- BUG-1 : `Transaction.success(value)` — API correcte (new value, pas boolean)
- BUG-3 : fuite mémoire `_optimisticTimeouts` — nettoyage explicite OK
- PERF : Blurhash bloque main thread — compute() déjà utilisé
- Voice/Video calls "absent" — implémentation complète dans webrtc_service.dart
- Typing indicator "stub" — widget complet 290 lignes
- Offline queue "absent" — implémenté 274 lignes (texte uniquement)

## Corrections P3 appliquées (session 2026-05-08, suite)

| ID | Fichier | Statut |
|----|---------|--------|
| BUG-2 UUID | `MessageEntity`, `MessageModel`, `message_repository.dart`, `message_repository_impl.dart`, `message_remote_datasource.dart`, `message_provider.dart` | ✅ `clientMessageId` UUID v4 généré avant envoi, propagé jusqu'au payload RTDB, matching optimiste priorise UUID sur temporal |
| E2EE AES-GCM | `encryption_service.dart` | ✅ AES-256-GCM pour les nouveaux messages (`gcm:nonce:ct`), AES-256-CBC backward-compat pour déchiffrer les anciens |

## Corrections P3 suite (session 2026-05-08, troisième partie)

| ID | Fichier | Statut |
|----|---------|--------|
| E2EE Signal bootstrap | `auth_provider.dart` | ✅ `MessagingE2EEService.initialize(userId)` appelé en fire-and-forget dans `_loadUserData`, `signInWithEmail`, `signInWithGoogle`, `signUp` |
| Tests Firebase Emulator | `test/rules/firestore.rules.test.js`, `test/rules/database.rules.test.js` | ✅ Écrits, setup dans `test/rules/package.json`, emulators configurés dans `firebase.json` |

## Phase 4B appliquée (2026-05-08, quatrième partie)

| ID | Fichier | Statut |
|----|---------|--------|
| MessageCryptoService | `lib/core/services/e2ee/message_crypto_service.dart` | ✅ Bridge encrypt1to1 (Signal) / encryptGroup (AES-GCM) / decrypt (auto-détection) |
| Datasource encrypt | `message_remote_datasource.dart` : `sendTextMessage` | ✅ Détecte 1:1 vs groupe, appelle `_crypto.encrypt1to1` ou `encryptGroup` |
| Datasource decrypt | `message_remote_datasource.dart` : `_decryptE2EEContent` | ✅ Async post-process après le AES-GCM sync ; déchiffre `e2eePayload` via Signal |
| Provider | `message_provider.dart` : `messageRemoteDataSourceProvider` | ✅ Injecte `messageCryptoServiceProvider` dans le datasource |
| Firebase Rules tests | `test/rules/*.js` | ✅ Fixé : `demo-` prefix + `--project demo-diaspo-niger` flag |

## Restant (vraiment long terme)

- **Libérer le disque** : 76MB libres — `flutter test` ne peut pas tourner.
- **Tests rules** : `firebase emulators:start --only firestore,database --project demo-diaspo-niger` puis `cd test/rules && npm install && npm test`
- **Signal pour autres types** : `sendFileMessage`, `sendLocationMessage`, `editMessage` utilisent encore AES-GCM direct — à migrer après stabilisation

**Why:** Audit multi-modèle (Opus/GPT-5/Gemini) commandé pour sécuriser avant la mise en production.
**How to apply:** Les corrections sont dans les fichiers listés. Avant tout déploiement Firebase, vérifier les rules avec l'émulateur.
