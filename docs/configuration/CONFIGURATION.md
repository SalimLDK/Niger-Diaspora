# Configuration — Diaspo Niger

Guide unique de configuration de l'application (fusion des anciens `CONFIGURATION.md` et `CONFIGURATION_COMPLETE.md`).

## Table des matières

1. [Configuration applicative (.env / AppConfig)](#1-configuration-applicative-env--appconfig)
2. [Firebase](#2-firebase)
3. [Supabase](#3-supabase)
4. [Stripe](#4-stripe)
5. [Partenaires de paiement](#5-partenaires-de-paiement)
6. [Cloud Functions](#6-cloud-functions)
7. [Spécificités plateformes](#7-spécificités-plateformes)
8. [Checklist de configuration](#8-checklist-de-configuration)

---

## 1. Configuration applicative (.env / AppConfig)

La classe `AppConfig` (`lib/core/constants/app_config.dart`) centralise la configuration : environnement (Production vs Développement), clés API, feature flags.

### Source des valeurs

Deux mécanismes, dans cet ordre de priorité :

1. **`--dart-define`** à la compilation (prioritaire — utilisé pour les builds de production).
2. **Fichier `.env`** à la racine, chargé par `flutter_dotenv` au démarrage (`main.dart`) — utilisé en développement.

Le modèle de référence est **`.env.example`** (racine) : copier en `.env` et remplir. Il couvre : chiffrement (`ENCRYPTION_KEY`, 32 caractères), Firebase (clés par plateforme), Google OAuth & Maps, ReCAPTCHA (App Check), Stripe, **Supabase** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`), Twilio (OTP SMS), LiveKit (appels de groupe), RevenueCat, `TURN_SECRET` (coturn), deep links, Tenor/Giphy (GIFs).

> ⚠️ Ne jamais commiter `.env` (déjà dans `.gitignore`).

### Lancer l'application

**Développement :**
```bash
flutter run
# Ou explicitement :
flutter run --dart-define=PRODUCTION=false
```

**Production :**
```bash
flutter run --release \
  --dart-define=PRODUCTION=true \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
```

| Variable dart-define | Description | Défaut |
| :--- | :--- | :--- |
| `PRODUCTION` | Si `true`, active le mode Production (désactive logs debug, clés prod). | `false` |
| `STRIPE_PUBLISHABLE_KEY` | Clé publique Stripe pour la production. | `''` |

### Feature Flags

Les fonctionnalités expérimentales sont gérées via `FeatureFlagService` (`lib/core/services/feature_flag_service.dart`), qui peut utiliser **Firebase Remote Config** pour activer/désactiver des fonctionnalités à distance sans redéployer.

---

## 2. Firebase

La configuration client est gérée par `flutterfire` CLI :
- **Fichier généré :** `lib/firebase_options.dart`
- **Config CLI :** `firebase.json` et `.firebaserc`
- Mise à jour : `flutterfire configure`

### Console Firebase (projet **diaspo-niger**)

**Authentication → Sign-in method** — activer :
- Email/Password, Google, Apple (nécessite Apple Developer Account), Phone

**Firestore Database :**
- Mode : Production · Région : `eur3` (Europe) · Règles : `firestore.rules`

**Storage :**
- Bucket : `gs://diaspo-niger.appspot.com` · Règles : `storage.rules`

**Cloud Messaging (FCM) :**
1. Activer Cloud Messaging API (V1)
2. `google-services.json` → `android/app/`
3. `GoogleService-Info.plist` → `ios/Runner/`

---

## 3. Supabase

Depuis la migration (voir l'[ADR messagerie](../architecture/ADR-messaging-source-of-truth.md)), Supabase est la source de vérité de la messagerie (stockage + temps réel).

- **Côté app :** `SUPABASE_URL` et `SUPABASE_ANON_KEY` dans `.env` (clé anon uniquement — jamais la clé service_role côté client). Les écritures passent par une session authentifiée (bridge Firebase → Supabase) ; sans session, les RLS bloquent.
- **Côté serveur :** schéma et migrations dans `supabase/`, secrets des Edge Functions poussés via `scripts/push-supabase-secrets.ps1`.

---

## 4. Stripe

### Clés API (Dashboard → Developers → API keys)

| Clé | Utilisation | Où la mettre |
|-----|-------------|--------------|
| `pk_test_xxx` | Publique (test) | `.env` / `app_config.dart` |
| `pk_live_xxx` | Publique (prod) | `--dart-define` lors du build |
| `sk_test_xxx` | Secrète (test) | `functions/.env` |
| `sk_live_xxx` | Secrète (prod) | Firebase Secrets (`firebase functions:secrets:set`) |

> **IMPORTANT :** ne jamais exposer une clé secrète (`sk_...`) côté client.

Le **Merchant ID** Apple Pay est défini dans `AppConfig.stripeMerchantIdentifier` (`merchant.com.diasponiger`) et doit correspondre à la configuration Apple Developer.

### Webhook paiements (Dashboard → Developers → Webhooks)

```
URL: https://us-central1-diaspo-niger.cloudfunctions.net/stripeWebhook
Events: payment_intent.succeeded, payment_intent.payment_failed
```
Copier le **Webhook secret** (`whsec_xxx`) → `functions/.env`.

### Stripe Connect (transferts vers vendeurs/créateurs)

**Dashboard → Settings → Connect** : activer Connect, type **Express**, configurer les payouts.

**Webhook Connect :**
```
URL: https://us-central1-diaspo-niger.cloudfunctions.net/stripeConnectWebhook
Events: account.updated, transfer.created, transfer.failed, payout.paid, payout.failed
```

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_CONNECT_WEBHOOK_SECRET
firebase deploy --only firestore:rules,functions
```

### Virements automatiques (Dashboard → Settings → Payouts)

```
Payout schedule: Automatic · Frequency: Daily/Weekly/Monthly · Bank account: [IBAN]
```

---

## 5. Partenaires de paiement

Mynita, Wave, Visa Direct et Mastercard Send : voir **[PARTNER_API_CONFIGURATION.md](PARTNER_API_CONFIGURATION.md)** (variables `functions/.env`, webhooks, mode mock `PARTNER_MOCK_MODE`).

---

## 6. Cloud Functions

### Fichier `functions/.env`

Le modèle de référence est **`functions/.env.example`**. Variables actuelles :

| Variable | Rôle |
|---|---|
| `STRIPE_SECRET_KEY` | Clé secrète Stripe |
| `STRIPE_WEBHOOK_SECRET` | Secret du webhook paiements |
| `ENCRYPTION_KEY` | Clé AES-256 (32 caractères) — **doit être identique** à celle de l'app Flutter ; la changer casse le déchiffrement des messages existants |
| `REVENUECAT_WEBHOOK_AUTH` | Header d'autorisation du webhook RevenueCat |
| `TURN_SECRET` | Secret partagé HMAC pour les credentials TURN éphémères — **doit être identique** au `static-auth-secret` du serveur coturn (voir [COTURN_VPS_SETUP.md](../ops/COTURN_VPS_SETUP.md)) |

Le `.env` est injecté automatiquement au déploiement (`firebase deploy` affiche `injecting env (N) from .env`). En production, préférer les Firebase Secrets pour les clés live.

### Déployer et vérifier

```bash
cd functions
npm install
firebase deploy --only functions

# Logs
firebase functions:log --only stripeWebhook
firebase functions:list   # inventaire des fonctions déployées
```

---

## 7. Spécificités plateformes

- **Android** — signature release (keystore, `key.properties`) : voir [DEPLOYMENT.md](../deploiement/DEPLOYMENT.md). Clé Google Maps : `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`).
- **iOS** — Info.plist, entitlements, URL schemes (Google Sign-In), capacités : voir [IOS_CONFIGURATION.md](IOS_CONFIGURATION.md). Clé Maps : `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey`).
- **Deep links / Universal Links** : voir [APP_LINKS_SETUP.md](APP_LINKS_SETUP.md).
- **OAuth** : voir [OAUTH_SECURITY_SETUP.md](OAUTH_SECURITY_SETUP.md).

---

## 8. Checklist de configuration

### Pré-déploiement
- [ ] `.env` racine rempli (copie de `.env.example`)
- [ ] `google-services.json` dans `android/app/`
- [ ] `GoogleService-Info.plist` dans `ios/Runner/`
- [ ] Supabase : URL + clé anon dans `.env`, migrations `supabase/` appliquées
- [ ] Compte Stripe activé et vérifié, webhooks configurés
- [ ] `functions/.env` rempli (copie de `functions/.env.example`)
- [ ] Keystore Android généré, certificats iOS configurés

### Cloud Functions
- [ ] `npm install` dans `functions/`
- [ ] `firebase deploy --only functions` réussi
- [ ] Webhooks testés

### Application
- [ ] `flutter pub get` · `dart run build_runner build`
- [ ] `flutter analyze` sans erreurs · `flutter test` passe

### Production
- [ ] `PARTNER_MOCK_MODE=false` (si partenaires actifs)
- [ ] Clés API de production (Stripe live via Secrets, `--dart-define`)
- [ ] Tests end-to-end réussis

---

## Ressources

- [Documentation Stripe](https://stripe.com/docs) · [Flutter Stripe](https://pub.dev/packages/flutter_stripe)
- [Documentation Firebase](https://firebase.google.com/docs) · [Documentation Supabase](https://supabase.com/docs)
- Support Stripe : https://support.stripe.com · Support Firebase : https://firebase.google.com/support
