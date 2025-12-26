# Configuration de l'Application

Ce document détaille la gestion de la configuration pour l'application **Diaspo Niger**.

## 1. AppConfig (`lib/core/constants/app_config.dart`)

La classe `AppConfig` centralise la configuration de l'application, notamment la détection de l'environnement (Production vs Développement) et les clés API (Stripe).

### Variables d'Environnement

L'application utilise `dart-define` pour injecter des valeurs lors de la compilation.

| Variable | Description | Défaut |
| :--- | :--- | :--- |
| `PRODUCTION` | Si `true`, active le mode Production (désactive logs debug, clés prod). | `false` |
| `STRIPE_PUBLISHABLE_KEY` | Clé publique Stripe pour la production. | `''` |

### Comment lancer l'application

**Développement (Debug) :**
```bash
flutter run
# Ou explicitement :
flutter run --dart-define=PRODUCTION=false
```

**Production (Release) :**
```bash
flutter run --release --dart-define=PRODUCTION=true --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...
```

## 2. Firebase

La configuration Firebase est gérée par `flutterfire` CLI.

-   **Fichier :** `lib/firebase_options.dart` (Généré automatiquement)
-   **Config CLI :** `firebase.json` et `.firebaserc`

Pour mettre à jour la configuration Firebase (exemple : ajout d'une nouvelle plateforme ou changement de projet) :

```bash
flutterfire configure
```

## 3. Feature Flags

Les fonctionnalités expérimentales ou progressives sont gérées via `FeatureFlagService` (`lib/core/services/feature_flag_service.dart`).
Ce service peut utiliser **Firebase Remote Config** pour activer/désactiver des fonctionnalités à distance sans redéployer l'application.

## 4. Google Maps

Les clés API Google Maps sont configurées nativement dans les fichiers de plateforme :

-   **Android** : `android/app/src/main/AndroidManifest.xml`
    ```xml
    <meta-data android:name="com.google.android.geo.API_KEY" android:value="VOTRE_CLE_API"/>
    ```
-   **iOS** : `ios/Runner/AppDelegate.swift` (via `GMSServices.provideAPIKey`)

## 5. Stripe

La configuration Stripe dépend de l'environnement (voir `AppConfig`).
Le **Merchant ID** pour Apple Pay est défini dans `AppConfig.stripeMerchantIdentifier` et doit correspondre à la configuration côté Apple Developer Account.
