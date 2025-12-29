# Guide de Déploiement en Production

Ce document décrit les étapes pour préparer et déployer **Diaspo Niger** en production.

## 1. Préparation Android

### Création du Keystore (Si inexistant)

Pour signer l'application Android, vous avez besoin d'un fichier Keystore (.jks).
**ATTENTION : Ne jamais commiter ce fichier ni perdre le mot de passe.**

```bash
keytool -genkey -v -keystore android/upload-keystore.jks ^
        -keyalg RSA -keysize 2048 -validity 10000 ^
        -alias upload
```

### Configuration `key.properties`

Créez un fichier `android/key.properties` (ce fichier est ignoré par git) :

```properties
storePassword=VOTRE_MOT_DE_PASSE_STORE
keyPassword=VOTRE_MOT_DE_PASSE_KEY
keyAlias=upload
storeFile=../upload-keystore.jks
```

### Génération de l'App Bundle (AAB)

L'App Bundle est le format recommandé pour le Google Play Store.

```bash
flutter build appbundle --release ^
  --dart-define=PRODUCTION=true ^
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
```

Le fichier sera généré dans `build/app/outputs/bundle/release/app-release.aab`.

## 2. Préparation iOS

1.  Ouvrir le projet dans Xcode : `open ios/Runner.xcworkspace`.
2.  Sélectionner la cible **Runner**.
3.  Onglet **Signing & Capabilities** : S'assurer que la bonne Team et le bon Bundle Identifier sont sélectionnés.
4.  Mettre à jour la version et le build number dans **General**.
5.  Menu **Product > Archive**.
6.  Une fois l'archive créée, utiliser **Distribute App** pour envoyer sur TestFlight / App Store.

**Note :** N'oubliez pas les drapeaux `--dart-define` si vous buildez depuis la ligne de commande ou assurez-vous qu'ils sont configurés dans les schemes Xcode (plus complexe, privilégiez le build CLI ou CI/CD).

Pour générer une IPA (Ad-hoc/Enterprise) depuis CLI :
```bash
flutter build ipa --release ^
  --dart-define=PRODUCTION=true ^
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
```

## 3. Configuration Stripe

### Côté Client (Flutter App)

La clé publishable Stripe est configurée dans `lib/core/constants/app_config.dart` :

- **Développement** : Utilise `_testPublishableKey` (pk_test_...)
- **Production** : Passez via `--dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...`

Obtenez vos clés sur : https://dashboard.stripe.com/apikeys

### Côté Serveur (Cloud Functions)

La clé secrète Stripe doit être configurée dans Firebase Functions :

```bash
# Pour le développement (test)
firebase functions:config:set stripe.secret_key="sk_test_VOTRE_CLE_SECRETE"

# Pour la production (live)
firebase functions:config:set stripe.secret_key="sk_live_VOTRE_CLE_SECRETE"
```

**IMPORTANT** : Ne jamais exposer la clé secrète (sk_...) côté client !

### Configuration du Webhook Stripe (Optionnel mais recommandé)

Pour recevoir les mises à jour de paiement en temps réel :

1. Allez sur https://dashboard.stripe.com/webhooks
2. Ajoutez un endpoint : `https://REGION-PROJECT.cloudfunctions.net/stripeWebhook`
3. Sélectionnez les événements : `payment_intent.succeeded`, `payment_intent.payment_failed`
4. Copiez le webhook secret et configurez-le :

```bash
firebase functions:config:set stripe.webhook_secret="whsec_..."
```

## 4. Déploiement Backend (Firebase)

### Installation des dépendances Cloud Functions

```bash
cd functions
npm install
cd ..
```

### Déploiement

```bash
# Déployer tout (Firestore Rules, Indexes, Functions, Storage Rules...)
firebase deploy

# Déployer uniquement les fonctions
firebase deploy --only functions

# Déployer uniquement les règles Firestore
firebase deploy --only firestore:rules

# Déployer uniquement les indexes Firestore
firebase deploy --only firestore:indexes

# Déployer plusieurs éléments
firebase deploy --only functions,firestore:rules,firestore:indexes
```

### Vérifier la configuration des Functions

```bash
# Voir la configuration actuelle
firebase functions:config:get

# Devrait afficher quelque chose comme :
# {
#   "stripe": {
#     "secret_key": "sk_...",
#     "webhook_secret": "whsec_..."
#   }
# }
```

### Environnement de Production Firebase

Assurez-vous que le projet Firebase actif est bien celui de production :
```bash
# Voir le projet actuel
firebase use

# Changer de projet
firebase use production-project-alias

# Ajouter un alias
firebase use --add
```

## 5. Service de Devises (Multi-Currency)

L'application supporte plus de 40 devises avec conversion automatique des taux.

### Configuration de l'API de taux de change

Le service utilise [exchangerate-api.com](https://www.exchangerate-api.com/) (plan gratuit : 1500 requêtes/mois).

1. Créez un compte sur https://www.exchangerate-api.com/
2. Récupérez votre clé API
3. Configurez la clé dans les paramètres admin de l'application (Firestore `app_settings/general`)

**Structure du document `app_settings/general` :**
```json
{
  "exchangeRateApiKey": "YOUR_API_KEY",
  "exchangeRateRefreshMinutes": 60
}
```

### Devises Supportées

- **Afrique** : XOF (FCFA BCEAO), XAF (FCFA BEAC), NGN, GHS, MAD, ZAR, KES, EGP, TZS, ETB
- **Europe** : EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, TRY, RUB
- **Amériques** : USD, CAD, MXN, ARS, CLP, COP, BRL
- **Asie** : CNY, JPY, INR, KRW, SGD, HKD, THB, MYR, PHP, IDR, VND, PKR
- **Moyen-Orient** : AED, SAR, QAR, KWD
- **Océanie** : AUD, NZD

### Taux de Fallback

Si l'API n'est pas configurée ou indisponible, des taux de fallback sont utilisés :
- EUR/XOF : 655.957 (taux fixe de la zone CFA)
- Les autres taux sont approximatifs et peuvent être mis à jour dans les paramètres admin

## 6. Cloud Functions Disponibles

| Fonction | Déclencheur | Description |
|----------|-------------|-------------|
| `sendNotificationOnCreate` | Firestore `notifications/{id}` | Envoie des push notifications |
| `onMessageCreated` | Realtime DB `messages/{convId}/{msgId}` | Notifications de messages |
| `sendChatNotification` | Firestore `conversations/{id}` update | Désactivé (utiliser onMessageCreated) |
| `sendEventReminders` | Scheduled (hourly) | Rappels d'événements (24h avant) |
| `createStripePaymentIntent` | Firestore `payment_intents/{id}` | Crée un PaymentIntent Stripe |
| `stripeWebhook` | HTTP | Reçoit les webhooks Stripe |
| `onOrderCreated` | Firestore `orders/{id}` | Décrémente le stock, notifie le vendeur |
| `onOrderUpdated` | Firestore `orders/{id}` update | Gère les changements de statut (shipped, delivered, cancelled, completed) |
| `notifyLocalEventCreated` | Firestore `events/{id}` | Notifie les utilisateurs locaux d'un nouvel événement |

### Types de Notifications

| Type | Canal Android | Description |
|------|---------------|-------------|
| `message` | `messages` | Nouveaux messages de chat |
| `order`, `newOrder` | `orders_channel` | Nouvelle commande |
| `orderPaid` | `orders_channel` | Paiement reçu |
| `orderShipped` | `orders_channel` | Commande expédiée |
| `orderDelivered` | `orders_channel` | Commande livrée |
| `orderCancelled` | `orders_channel` | Commande annulée |
| `orderCompleted` | `orders_channel` | Paiement libéré |
| `eventReminder` | `event_reminders_channel` | Rappel d'événement |
| `eventAttendance`, `localEvent` | `events_channel` | Événements |
| `friendRequest`, `friendAccepted` | `friends_channel` | Amis |

## 7. Checklist Avant Mise en Prod

### Configuration App
- [ ] **AppConfig** : Vérifier que `PRODUCTION=true` est bien passé
- [ ] **Stripe Publishable Key** : Vérifier que `pk_live_...` est valide
- [ ] **Logs** : Les logs de debug sont désactivés (`AppConfig.isProduction`)

### Firebase
- [ ] **Projet Firebase** : Utiliser le projet de production (`firebase use`)
- [ ] **Stripe Secret Key** : Configurée dans functions config
- [ ] **Cloud Functions** : Déployées et fonctionnelles
- [ ] **Firestore Rules** : Déployées et sécurisées
- [ ] **Firestore Indexes** : Déployés
- [ ] **Storage Rules** : Déployées

### Multi-Devises
- [ ] **API Key** : Clé exchangerate-api.com configurée dans `app_settings/general`
- [ ] **Taux de Fallback** : Vérifier les taux de fallback si l'API est indisponible
- [ ] **Devise par défaut** : XOF configurée comme devise principale

### App Mobile
- [ ] **Icônes** : Vérifier les icônes de lancement (`flutter_launcher_icons`)
- [ ] **Splash Screen** : Vérifier le splash screen
- [ ] **Permissions** : Descriptions valides dans `Info.plist` et `AndroidManifest.xml`
- [ ] **Version** : Numéro de version incrémenté

### Tests
- [ ] **Paiement Test** : Tester avec une carte test Stripe (4242 4242 4242 4242)
- [ ] **Notifications** : Vérifier les push notifications
- [ ] **Authentification** : Tester login/logout
- [ ] **Marketplace** : Tester création produit, commande, paiement
- [ ] **Panier Multi-Devises** : Tester l'ajout de produits avec différentes devises
- [ ] **Conversion de Prix** : Vérifier l'affichage des prix convertis
- [ ] **Gestion des Commandes** : Tester le cycle complet (pending → shipped → delivered → completed)

## 8. Commandes Utiles

```bash
# Voir les logs des Cloud Functions
firebase functions:log

# Voir les logs en temps réel
firebase functions:log --follow

# Tester localement les functions
cd functions && npm run serve

# Analyser le code Flutter
flutter analyze

# Générer les fichiers freezed/riverpod
dart run build_runner build --delete-conflicting-outputs
```

## 9. Dépannage

### Erreur "Stripe not initialized"
- Vérifiez que `StripeService.instance.initialize()` est appelé dans `main.dart`
- Vérifiez que la clé publishable est correcte dans `app_config.dart`

### Erreur "Payment intent creation timeout"
- Vérifiez que les Cloud Functions sont déployées
- Vérifiez que `stripe.secret_key` est configuré : `firebase functions:config:get`
- Consultez les logs : `firebase functions:log`

### Erreur "Utilisateur non connecté"
- Vérifiez l'état d'authentification Firebase
- Utilisez `await ref.read(currentUserAsyncProvider.future)` au lieu de `.valueOrNull`

### Erreur Firestore Index
- Suivez le lien dans l'erreur pour créer l'index
- Ou déployez les indexes : `firebase deploy --only firestore:indexes`

### Erreur "Exchange rate API failed"
- Vérifiez que la clé API est correcte dans `app_settings/general`
- Vérifiez les quotas de l'API (1500 requêtes/mois pour le plan gratuit)
- L'application utilisera les taux de fallback en cas d'erreur

### Erreur "Stock insuffisant" lors de la commande
- La Cloud Function `onOrderCreated` vérifie le stock disponible
- Si le stock est insuffisant, la commande est automatiquement annulée
- Consultez les logs : `firebase functions:log --only onOrderCreated`

### Prix affichés incorrects dans le panier
- Vérifiez que le service de devises est initialisé (`CurrencyService.instance.initialize()`)
- Les taux sont mis en cache pendant 1 heure
- Pour forcer un rafraîchissement : `CurrencyService.instance.fetchRates()`
