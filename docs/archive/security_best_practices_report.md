# Rapport d'Audit de Securite - Diaspo Niger

**Date:** 2026-04-06 (audit) | 2026-04-07 (remediation)  
**Projet:** Diaspo Niger - Plateforme mobile de la diaspora nigerienne  
**Stack:** Flutter/Dart (frontend mobile) + Firebase (Firestore, RTDB, Storage, Cloud Functions) + Stripe (paiements)  
**Fichiers analyses:** ~500+ fichiers Dart, 5 fichiers Cloud Functions JS, Firestore rules, Storage rules, RTDB rules  
**Statut:** REMEDIATION APPLIQUEE - 64 vulnerabilites corrigees le 2026-04-07

---

## Resume Executif

L'audit de securite complet du projet Diaspo Niger a revele **12 vulnerabilites CRITIQUES**, **26 vulnerabilites HAUTES**, **17 vulnerabilites MOYENNES** et **9 vulnerabilites BASSES**. Les problemes les plus graves concernent :

1. **Cle de chiffrement AES codee en dur** dans le code source (extractible par reverse-engineering)
2. **Implementation E2EE fondamentalement cassee** (signatures HMAC au lieu d'Ed25519, X3DH incorrect)
3. **Regles Firestore permissives** permettant la manipulation de montants financiers et l'escalade de privileges
4. **Cloud Functions avec controles d'acces defaillants** (verification de webhook toujours en echec, admin checks incorrects)
5. **Donnees sensibles stockees en clair** (cles privees dans Hive, coordonnees GPS non chiffrees)

**Le projet necessite des corrections immediates avant toute mise en production, particulierement sur les flux financiers et le chiffrement.**

---

## Vulnerabilites CRITIQUES (12)

### CRIT-01 : Cle de chiffrement AES codee en dur dans le code source
**Fichier:** `lib/core/services/encryption_service.dart`, ligne 19  
**Impact:** Compromission totale de toutes les donnees chiffrees

```
static const String _sharedKeyString = 'DiaspoNigerSecureKey2025ForApps!';
```

La cle AES-CBC 256 bits est codee en dur comme constante. Elle est extractible par reverse-engineering de l'APK/IPA. Tout attaquant peut dechiffrer l'ensemble des messages et donnees chiffrees avec cette cle. La cle etant partagee avec les Cloud Functions, elle ne peut pas etre changee sans impacter tout le systeme.

---

### CRIT-02 : Implementation E2EE - Signature HMAC au lieu d'Ed25519
**Fichier:** `lib/core/services/e2ee/key_manager_service.dart`, lignes 68-76  
**Impact:** Usurpation d'identite possible, attaque MITM

La methode `_sign()` utilise HMAC-SHA256 (algorithme symetrique) au lieu d'une signature asymetrique Ed25519 comme requis par le protocole Signal. Cela signifie que les Signed Pre-Keys n'offrent aucune garantie d'authenticite.

---

### CRIT-03 : X3DH receiver-side casse - Cle ephemere non utilisee
**Fichier:** `lib/core/services/e2ee/messaging_e2ee_service.dart`, lignes 411-476  
**Impact:** Forward secrecy compromise, sessions deterministes

L'implementation receiver-side de X3DH reutilise la cle d'identite de l'expediteur au lieu de la cle ephemere (EKa) pour DH2 et DH3. Le secret de session est donc deterministe a partir des cles d'identite long-terme.

---

### CRIT-04 : Cle publique Sender Key derivee par hash avec secret code en dur
**Fichier:** `lib/core/services/e2ee/sender_key_service.dart`, lignes 104-113  
**Impact:** Signatures de messages de groupe contournables

La cle publique est derivee par HMAC de la cle privee avec le secret code en dur `'DiaspoNiger_SenderKey_PK'`. Toute personne connaissant cette chaine peut calculer la "cle publique".

---

### CRIT-05 : Contenu dechiffre stocke en clair sur le serveur (moderation)
**Fichier:** `lib/core/services/e2ee/content_moderation_service.dart`, lignes 181-213  
**Impact:** Rupture totale de la garantie E2EE

La fonction `reportMessage()` envoie le contenu dechiffre en clair dans la collection Firestore `moderation_reports`. Tout message signale est stocke de facon permanente sur le serveur.

---

### CRIT-06 : Cles privees de session E2EE stockees en clair dans Hive
**Fichier:** `lib/core/services/e2ee/secure_key_storage.dart`, lignes 302-312, 372-379  
**Impact:** Recuperation de toutes les cles de session sur appareil compromis

Les `localRatchetPrivateKey`, `sendingChainKey`, `receivingChainKey` et `rootKey` sont stockes en JSON dans des boites Hive non chiffrees au lieu de `flutter_secure_storage`.

---

### CRIT-07 : Client controle le montant du paiement Stripe via document Firestore non valide
**Fichier:** `firestore.rules`, lignes 284-295  
**Impact:** Fraude financiere - manipulation des montants

La collection `payment_intents` autorise la creation par tout utilisateur authentifie sans aucune validation de champ. Un client malveillant peut ecrire `amount: 0.01` avant que la Cloud Function ne traite le document.

---

### CRIT-08 : UID "admin" code en dur comme backdoor dans les regles Firestore
**Fichier:** `firestore.rules`, ligne 333  
**Impact:** Acces admin permanent non autorise

```
request.auth.uid == "admin"
```

Tout compte Firebase dont l'UID serait la chaine `"admin"` obtiendrait un acces illimite aux commerces.

---

### CRIT-09 : Collections financieres `debit_requests` sans regles Firestore
**Fichier:** `firestore.rules` / `lib/core/services/partner_payment_service.dart`, lignes 28-44  
**Impact:** Debit non autorise sur numeros de telephone arbitraires

Les collections `debit_requests` et `card_credit_requests` n'ont aucune regle Firestore. De plus, aucun champ `userId` n'est ecrit, empechant toute verification d'appartenance.

---

### CRIT-10 : Nonce Play Integrity genere cote client (contournable)
**Fichier:** `lib/core/services/play_integrity_service.dart`, lignes 423-428  
**Impact:** Contournement de toutes les protections d'integrite de l'appareil

Le nonce est genere a partir d'un timestamp et d'un prefixe code en dur. Le Play Integrity API exige un nonce genere cote serveur.

---

### CRIT-11 : Admin check `seedLegalContent` laisse passer tous les utilisateurs
**Fichier:** `functions/index.js`, lignes 2748-2763  
**Impact:** Tout utilisateur peut modifier les contenus legaux (CGU, politique de confidentialite)

La condition `adminRole === "none"` ne bloque jamais car les utilisateurs normaux ont `adminRole: undefined`, pas `"none"`.

---

### CRIT-12 : Verification de signature webhook toujours `false` en production
**Fichier:** `functions/partners/mynita.js`, lignes 83-96; `functions/partners/wave.js`, lignes 84-91  
**Impact:** Tous les webhooks de paiement mobile money sont rejetes en production

`verifySignature()` retourne toujours `false` en mode non-mock, bloquant definitivement tous les callbacks de paiement.

---

## Vulnerabilites HAUTES (26)

| ID | Fichier | Ligne(s) | Description |
|----|---------|----------|-------------|
| HIGH-01 | `pin_service.dart` | 106-109 | PIN hashe avec SHA-256 sans sel ni key-stretching (4 chiffres = crackable en ms) |
| HIGH-02 | `play_integrity_service.dart` | 291-323 | `checkIntegrity()` retourne un verdict "tout vert" code en dur |
| HIGH-03 | `encryption_service.dart` | 56-60 | Chiffrement retombe silencieusement en texte clair si non initialise |
| HIGH-04 | `auth_provider.dart` | 33-45 | Donnees utilisateur dans SharedPreferences non chiffrees |
| HIGH-05 | `e2ee_service.dart` | 39 | ID de cle E2EE = timestamp (predictible, collisions possibles) |
| HIGH-06 | `e2ee_service.dart` | 220-225 | PBKDF2 avec sel statique `'diasponiger-key-wrap'` et seulement 10000 iterations |
| HIGH-07 | `auth_remote_datasource.dart` | 257-374 | Suppression de compte : donnees supprimees avant revocation auth |
| HIGH-08 | `firestore.rules` | 353-371 | Participants peuvent modifier tous les champs d'une transaction financiere |
| HIGH-09 | `firestore.rules` | 386-389 | Liste des commandes sans filtre obligatoire - enumeration possible |
| HIGH-10 | `firestore.rules` | 541-543 | Journaux d'audit modifiables par tout admin |
| HIGH-11 | `firestore.rules` | 164-176 | Tout utilisateur peut creer des notifications pour n'importe qui |
| HIGH-12 | `firestore.rules` | 24-30 | Escalade de privileges via champ `isAdmin` modifiable par l'utilisateur |
| HIGH-13 | `storage.rules` | 62-83 | Upload d'images groups/events/produits sans verification de propriete |
| HIGH-14 | `transfer_repository_impl.dart` | 66-103 | Frais, taux de change et montants calcules cote client et ecrits directement |
| HIGH-15 | `marketplace_remote_datasource.dart` | 270-279 | Client definit `escrowStatus: released` directement sans backend |
| HIGH-16 | `monetization_remote_datasource.dart` | 742-774 | Race condition dans `cancelPayout` (operations non atomiques) |
| HIGH-17 | `payment_account_datasource.dart` | 56-74 | `userId` fourni par l'appelant non verifie contre l'utilisateur authentifie |
| HIGH-18 | `messaging_e2ee_service.dart` | 169-173 | Sel zero pour HKDF dans la derivation de Root Key X3DH |
| HIGH-19 | `messaging_e2ee_service.dart` | 480-498 | Root Key et Chain Key derives avec parametres HKDF identiques |
| HIGH-20 | `key_backup_service.dart` | 112-133 | Fichier de backup unique sans versioning, chemin previsible |
| HIGH-21 | `cache_service.dart` | 257-302 | Messages dechiffres caches en clair dans Hive |
| HIGH-22 | `message_remote_datasource.dart` | 401-412 | Double systeme de chiffrement (legacy + E2EE) non integre |
| HIGH-23 | `message_remote_datasource.dart` | 1917-1928 | Coordonnees GPS stockees en clair dans RTDB |
| HIGH-24 | `functions/index.js` | 3365-3450 | `processDebitRequest` fait confiance aux donnees ecrites par le client |
| HIGH-25 | `functions/index.js` | 3739-3795 | `bankWebhook` appelle une fonction inexistante - crash permanent |
| HIGH-26 | `functions/index.js` | 2830-2843 | `seedLegalContentHttp` sans protection brute-force sur cle API statique |

---

## Vulnerabilites MOYENNES (17)

| ID | Fichier | Ligne(s) | Description |
|----|---------|----------|-------------|
| MED-01 | `auth_remote_datasource.dart` | 93-182 | `dev.log` expose email et UID dans les builds release |
| MED-02 | `auth_remote_datasource.dart` | 464-485 | Messages d'erreur differents pour "user-not-found" et "wrong-password" (enumeration) |
| MED-03 | `security_gate_service.dart` | 80-82 | Toutes les verifications de securite contournees sur iOS |
| MED-04 | `security_gate_service.dart` | 68-70 | Cache de verdict Play Integrity pendant 5 minutes |
| MED-05 | `auth_provider.dart` | 299-308 | Pas de rate limiting sur la reinitialisation de mot de passe |
| MED-06 | `token_refresh_service.dart` | 207-213 | Token ID Firebase stocke en double dans le secure storage |
| MED-07 | `tax_service.dart` | 240-288 | Taxes et frais de plateforme calcules uniquement cote client |
| MED-08 | `stripe_service.dart` | 253-267 | `clientSecret` Stripe potentiellement expose dans les logs |
| MED-09 | `firestore.rules` | 566-568 | Messages d'ambassade lisibles par tous (condition toujours vraie) |
| MED-10 | `firestore.rules` | 145-146 | Demandes d'amis lisibles par tous les utilisateurs authentifies |
| MED-11 | `firestore.rules` | 450-453 | Acheteur peut marquer commande comme "payee" sans validation backend |
| MED-12 | `storage.rules` | 51-59 | Upload media dans conversations sans verification de participation |
| MED-13 | `messaging_e2ee_service.dart` | - | Signature Signed Pre-Key jamais verifiee lors de l'etablissement de session |
| MED-14 | `content_moderation_service.dart` | 496-501 | SHA-256 utilise comme "hash perceptuel" - detection CSAM non fonctionnelle |
| MED-15 | `message_e2ee_helper.dart` | 61-75 | Downgrade silencieux vers non-E2EE sans avertissement |
| MED-16 | `functions/index.js` | 3226-3299 | Token LiveKit accorde sans verification de participation au groupe |
| MED-17 | `functions/index.js` | 661-720 | Index de recherche stocke les messages dechiffres en clair |

---

## Vulnerabilites BASSES (9)

| ID | Fichier | Ligne(s) | Description |
|----|---------|----------|-------------|
| LOW-01 | `app_config.dart` | 42 | Client ID OAuth Google code en dur par defaut |
| LOW-02 | `secure_preferences_service.dart` | partout | Toutes les erreurs du secure storage avalees silencieusement |
| LOW-03 | `pin_service.dart` | 83-85 | Flag biometrie stocke comme string fragile |
| LOW-04 | `session_service.dart` | 48, 88, 95 | Session ID dans SharedPreferences non chiffrees |
| LOW-05 | `device_sync_service.dart` | 352-379 | Filtre de notifications multi-device avec polarite inversee |
| LOW-06 | `message_remote_datasource.dart` | 1000-1041 | Miniatures video uploadees sans chiffrement |
| LOW-07 | `key_backup_service.dart` | 406-423 | Vocabulaire de passphrase de seulement 30 mots (entropie faible) |
| LOW-08 | `functions/index.js` | 4079-4082 | `processRoomTicket` ecoute la mauvaise collection (`room_tickets` vs `roomTickets`) |
| LOW-09 | `storage.rules` | 17-18 | Validation taille fichier off-by-one (`<` au lieu de `<=`) |

---

## Clefs API et Secrets exposes dans le code source

| Secret | Fichier | Ligne(s) | Statut |
|--------|---------|----------|--------|
| Cle AES `DiaspoNigerSecureKey2025ForApps!` | `encryption_service.dart` | 19 | **CRITIQUE - Code en dur** |
| Firebase API Key (Android) | `firebase_options.dart` | 50 | Expose dans le repo git |
| Firebase API Key (iOS) | `firebase_options.dart` | 60 | Expose dans le repo git |
| Firebase API Key (Web) | `firebase_options.dart` | 40 | Expose dans le repo git |
| Google Web Client ID | `app_config.dart` | 42 | Code en dur par defaut |
| Salt PBKDF2 `diasponiger-key-wrap` | `e2ee_service.dart` | 225 | Code en dur statique |
| Secret derivation `DiaspoNiger_SenderKey_PK` | `sender_key_service.dart` | 108 | Code en dur |

---

## Plan de Remediation Prioritaire

### Immediat (avant mise en production)

1. **Retirer la cle AES codee en dur** - Utiliser une derivation de cle par utilisateur ou un echange de cles avec le serveur
2. **Corriger l'implementation E2EE** - Remplacer HMAC par Ed25519, corriger X3DH, stocker les cles dans flutter_secure_storage
3. **Ajouter la validation des champs financiers dans les regles Firestore** - amount, status, userId pour payment_intents, debit_requests, transactions
4. **Supprimer le backdoor `"admin"` code en dur** dans les regles Firestore
5. **Corriger les admin checks dans les Cloud Functions** (`seedLegalContent`, `manualCallCleanup`)
6. **Implementer la verification de signature webhook** pour Mynita et Wave
7. **Deplacer les calculs financiers (frais, taux) cote serveur** via Cloud Functions

### Court terme (1-2 semaines)

8. Utiliser PBKDF2/Argon2 avec sel aleatoire pour le hash du PIN
9. Corriger `checkIntegrity()` pour ne jamais retourner de verdict code en dur
10. Ajouter des regles Firestore pour `debit_requests`, `card_credit_requests`
11. Supprimer le champ `isAdmin` modifiable par l'utilisateur ou le proteger dans les regles
12. Chiffrer les coordonnees GPS dans les messages RTDB
13. Supprimer le stockage de `decryptedContent` dans les rapports de moderation
14. Deplacer les sessions E2EE de Hive vers flutter_secure_storage

### Moyen terme (1 mois)

15. Implementer App Attest / DeviceCheck pour iOS
16. Ajouter un rate limiting cote client et serveur
17. Unifier les messages d'erreur d'authentification (anti-enumeration)
18. Restreindre les regles Storage avec verification de propriete
19. Implementer le nonce Play Integrity cote serveur
20. Chiffrer le cache de messages dans Hive

---

## Notes sur la Stack

- **Dart/Flutter** : Pas de guide de securite specifique disponible dans les references du skill. Les recommandations sont basees sur les bonnes pratiques generales de securite mobile et cryptographique.
- **Firebase** : Les regles de securite sont le point critique principal. Plusieurs collections sensibles manquent de validation.
- **Cloud Functions (Node.js)** : Plusieurs fonctions ont des controles d'acces defaillants ou des bugs critiques empechant leur fonctionnement en production.
- **Chiffrement E2EE** : L'implementation actuelle ne fournit pas les garanties de securite attendues d'un protocole Signal. Elle necessite une refonte significative.

---

*Rapport genere automatiquement par l'outil Security Best Practices*
