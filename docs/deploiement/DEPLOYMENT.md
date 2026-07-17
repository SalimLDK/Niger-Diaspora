# Déploiement en Production — Diaspo Niger

Guide unique de mise en production (fusion des anciens `DEPLOYMENT.md` et `PRODUCTION_GUIDE.md`). La configuration préalable (clés, `.env`, Stripe, Firebase, Supabase) est décrite dans [CONFIGURATION.md](../configuration/CONFIGURATION.md).

## Table des matières

1. [Tests & validation locale](#1-tests--validation-locale)
2. [Android : signature et build](#2-android--signature-et-build)
3. [iOS : archive et distribution](#3-ios--archive-et-distribution)
4. [Backend Firebase](#4-backend-firebase)
5. [Service de devises](#5-service-de-devises-multi-currency)
6. [Cloud Functions principales](#6-cloud-functions-principales)
7. [Google Play Store](#7-google-play-store)
8. [Monitoring post-production](#8-monitoring-post-production)
9. [Checklist finale](#9-checklist-finale)
10. [Mises à jour futures](#10-mises-à-jour-futures)
11. [Dépannage](#11-dépannage)

---

## 1. Tests & validation locale

```bash
flutter analyze
flutter clean && flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run --release   # test en conditions réelles sur appareil
```

Points à vérifier avant tout build :
- [ ] Aucune erreur `flutter analyze`, aucun crash au démarrage
- [ ] Messagerie, notifications, transferts d'argent, marketplace, carte fonctionnels
- [ ] Version incrémentée dans `pubspec.yaml` (`version: x.y.z+build`)

---

## 2. Android : signature et build

### Keystore (première fois seulement)

⚠️ **Ne jamais commiter ce fichier ni perdre le mot de passe — sans lui, plus aucune mise à jour possible sur le Play Store. Faire une sauvegarde en lieu sûr.**

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias upload
```

### `android/key.properties` (ignoré par git)

```properties
storePassword=VOTRE_MOT_DE_PASSE_STORE
keyPassword=VOTRE_MOT_DE_PASSE_KEY
keyAlias=upload
storeFile=../upload-keystore.jks
```

`android/app/build.gradle.kts` lit ce fichier (`signingConfigs.release`) et active `isMinifyEnabled` + `isShrinkResources` en release — déjà en place, rien à modifier.

### Builds

```bash
# App Bundle (format requis pour le Play Store)
flutter build appbundle --release \
  --dart-define=PRODUCTION=true \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
# → build/app/outputs/bundle/release/app-release.aab

# APK (distribution directe)
flutter build apk --release \
  --dart-define=PRODUCTION=true \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
# → build/app/outputs/flutter-apk/app-release.apk

# Tester le build release sur appareil
flutter install --release
```

---

## 3. iOS : archive et distribution

1. Ouvrir `ios/Runner.xcworkspace` dans Xcode.
2. Cible **Runner** → **Signing & Capabilities** : vérifier Team et Bundle Identifier.
3. Mettre à jour version et build number dans **General**.
4. **Product → Archive**, puis **Distribute App** → TestFlight / App Store.

Depuis la CLI (recommandé pour ne pas oublier les `--dart-define`) :

```bash
flutter build ipa --release \
  --dart-define=PRODUCTION=true \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
```

Configuration iOS détaillée (Info.plist, entitlements, capacités) : [IOS_CONFIGURATION.md](../configuration/IOS_CONFIGURATION.md).

---

## 4. Backend Firebase

### Projet actif

```bash
firebase use            # voir le projet actuel
firebase use <alias>    # changer de projet
firebase use --add      # ajouter un alias
```

### Déploiement

```bash
cd functions && npm install && cd ..

firebase deploy                                   # tout (rules, indexes, functions, storage…)
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage:rules
firebase deploy --only functions,firestore:rules,firestore:indexes
```

Les variables de `functions/.env` sont injectées au déploiement ; les clés live passent par `firebase functions:secrets:set` (voir [CONFIGURATION.md §6](../configuration/CONFIGURATION.md#6-cloud-functions)).

### Vérifications

- `firestore.rules` : sécurisées (aucun `allow read, write: if true;`), toutes les collections couvertes
- `firebase functions:list` : toutes les fonctions déployées, aucune erreur dans `firebase functions:log`

---

## 5. Service de devises (Multi-Currency)

L'application supporte 40+ devises avec conversion automatique via [exchangerate-api.com](https://www.exchangerate-api.com/) (plan gratuit : 1500 requêtes/mois).

1. Créer un compte et récupérer la clé API.
2. La configurer dans Firestore `app_settings/general` :

```json
{
  "exchangeRateApiKey": "YOUR_API_KEY",
  "exchangeRateRefreshMinutes": 60
}
```

**Devises supportées** : Afrique (XOF, XAF, NGN, GHS, MAD, ZAR, KES, EGP, TZS, ETB), Europe (EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, TRY, RUB), Amériques (USD, CAD, MXN, ARS, CLP, COP, BRL), Asie (CNY, JPY, INR, KRW, SGD, HKD, THB, MYR, PHP, IDR, VND, PKR), Moyen-Orient (AED, SAR, QAR, KWD), Océanie (AUD, NZD).

**Fallback** : si l'API est indisponible, des taux de secours sont utilisés (EUR/XOF : 655.957, taux fixe zone CFA ; les autres sont approximatifs, modifiables dans les paramètres admin). Les taux sont mis en cache 1 heure.

---

## 6. Cloud Functions principales

> Liste indicative des fonctions clés — l'inventaire complet s'obtient avec `firebase functions:list`.

| Fonction | Déclencheur | Description |
|----------|-------------|-------------|
| `sendNotificationOnCreate` | Firestore `notifications/{id}` | Envoie des push notifications |
| `onMessageCreated` | Realtime DB `messages/{convId}/{msgId}` | Notifications de messages |
| `sendEventReminders` | Scheduled (hourly) | Rappels d'événements (24h avant) |
| `createStripePaymentIntent` | Firestore `payment_intents/{id}` | Crée un PaymentIntent Stripe |
| `stripeWebhook` | HTTP | Reçoit les webhooks Stripe |
| `onOrderCreated` | Firestore `orders/{id}` | Décrémente le stock, notifie le vendeur |
| `onOrderUpdated` | Firestore `orders/{id}` update | Statuts de commande (shipped, delivered, cancelled, completed) |
| `notifyLocalEventCreated` | Firestore `events/{id}` | Notifie les utilisateurs locaux d'un nouvel événement |
| `getTurnCredentials` | Callable | Credentials TURN éphémères pour les appels 1-à-1 |
| `createLiveKitRoom` / `getLiveKitToken` | Callable | Appels de groupe via LiveKit |

Types de notifications et canaux Android : voir [PUSH_NOTIFICATIONS_REFERENCE.md](../notifications/PUSH_NOTIFICATIONS_REFERENCE.md).

---

## 7. Google Play Store

**Console :** https://play.google.com/console

Le contenu de la fiche boutique (titre, descriptions, notes de version) est versionné par release — voir **[releases/1.2.0+14/GOOGLE_PLAY_v1.2.0.md](../../releases/1.2.0+14/GOOGLE_PLAY_v1.2.0.md)** pour la dernière version publiée.

### Assets graphiques requis

| Asset | Taille | Notes |
|---|---|---|
| Icône | 512 × 512 px PNG | |
| Bannière de fonctionnalité | 1024 × 500 px | Pas de transparence |
| Screenshots téléphone | 1080 × 1920 (ou 1080 × 2340) | Min 2, max 8 — sources dans `playstore_assets/` |
| Bannière TV (optionnel) | 1280 × 720 px | |

Écrans à capturer : connexion, carte de la diaspora, conversation, groupes, transfert d'argent, marketplace, événements, profil.

### Classification et conformité

- **Public cible :** 13+ · **Catégorie :** Social · **Tarification :** Gratuit, sans publicité
- Questionnaire : interaction utilisateurs **Oui** (chat), partage d'infos personnelles **Oui**, violence/contenu sexuel/langage grossier **Non**
- **Politique de confidentialité** (obligatoire) : `https://diaspo-niger.web.app/privacy-policy.html` — source : [docs/legal/POLITIQUE_CONFIDENTIALITE.md](../legal/POLITIQUE_CONFIDENTIALITE.md)
- **CGU** : `https://diaspo-niger.web.app/terms-of-service.html` — source : [docs/legal/CONDITIONS_GENERALES_UTILISATION.md](../legal/CONDITIONS_GENERALES_UTILISATION.md)
- **Sécurité des données** : collecte (profil, localisation approximative, messages/médias, transactions), chiffrement en transit et au repos, pas de partage publicitaire avec des tiers

### Release

1. **Production → Créer une release** (ou Test interne / fermé / ouvert pour une bêta)
2. Uploader `app-release.aab`, renseigner nom de version et notes de version
3. Pays : tous, avec priorité Niger, France, USA, Canada, Afrique de l'Ouest
4. Soumettre pour révision — délai habituel 1 à 3 jours (jusqu'à 7), publication automatique après approbation

---

## 8. Monitoring post-production

**Firebase Console** (https://console.firebase.google.com) : Analytics (utilisateurs actifs), Crashlytics (crashes), Performance, Cloud Messaging (taux de livraison), Firestore (quotas), Functions (erreurs).

**Play Console** : avis (y répondre), statistiques d'installation, rapports de crash Android, acquisition.

**Alertes à configurer :** taux de crash > 1 %, quota Firestore > 80 %, erreurs Cloud Functions, nouveaux avis Play Store.

---

## 9. Checklist finale

### Code & configuration
- [ ] Version incrémentée dans `pubspec.yaml`
- [ ] `PRODUCTION=true` passé au build, `pk_live_...` valide
- [ ] Aucune clé API sensible dans le code, logs debug désactivés (`AppConfig.isProduction`)
- [ ] Keystore sauvegardé, `key.properties` et keystore dans `.gitignore`

### Backend
- [ ] Projet Firebase de production actif (`firebase use`)
- [ ] Functions, Firestore rules + indexes, Storage rules déployés
- [ ] Clé exchangerate-api configurée dans `app_settings/general`

### Tests fonctionnels
- [ ] Paiement test Stripe (4242 4242 4242 4242), puis cycle commande complet (pending → shipped → delivered → completed)
- [ ] Push notifications (messages, groupes, événements)
- [ ] Authentification (login/logout), transferts, marketplace, carte, panier multi-devises
- [ ] Tests sur plusieurs appareils, performance OK

### Play Store
- [ ] Fiche boutique complète (descriptions, icône, screenshots, bannière)
- [ ] Classification du contenu, sécurité des données, politique de confidentialité et CGU en ligne
- [ ] AAB uploadé, notes de version rédigées, soumis pour révision

---

## 10. Mises à jour futures

```yaml
# pubspec.yaml — format VERSION_NAME+VERSION_CODE
version: 1.2.1+15
```

- **Patch** (1.2.0 → 1.2.1) : corrections de bugs · **Minor** (1.2.0 → 1.3.0) : nouvelles fonctionnalités · **Major** : changements importants

```bash
# Workflow : modifier le code → incrémenter la version → tester → build → upload
flutter run --release
flutter clean && flutter pub get
flutter build appbundle --release --dart-define=PRODUCTION=true --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
# Play Console → Production → Nouvelle release → Upload AAB
```

Archiver les binaires et notes de chaque release dans `releases/<version>/`.

---

## 11. Dépannage

**« Stripe not initialized »** — vérifier `StripeService.instance.initialize()` dans `main.dart` et la clé publishable dans `app_config.dart`/`.env`.

**« Payment intent creation timeout »** — functions déployées ? `STRIPE_SECRET_KEY` présent dans `functions/.env` ? Consulter `firebase functions:log`.

**« Utilisateur non connecté »** — vérifier l'état d'auth Firebase ; utiliser `await ref.read(currentUserAsyncProvider.future)` plutôt que `.valueOrNull`.

**Erreur d'index Firestore** — suivre le lien dans l'erreur, ou `firebase deploy --only firestore:indexes`.

**« Exchange rate API failed »** — clé API dans `app_settings/general` ? Quota (1500 req/mois) dépassé ? L'app bascule sur les taux de fallback.

**« Stock insuffisant » à la commande** — `onOrderCreated` vérifie le stock et annule automatiquement si insuffisant ; voir `firebase functions:log --only onOrderCreated`.

**Prix incorrects dans le panier** — `CurrencyService.instance.initialize()` appelé ? Cache d'1 h ; forcer avec `CurrencyService.instance.fetchRates()`.

```bash
# Commandes utiles
firebase functions:log --follow
cd functions && npm run serve     # test local des functions
flutter analyze
dart run build_runner build --delete-conflicting-outputs
```
