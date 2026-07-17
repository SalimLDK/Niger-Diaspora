# Configuration iOS - Diaspo Niger

Ce document décrit toutes les configurations nécessaires pour le déploiement iOS de l'application Diaspo Niger.

## Table des matières

1. [Prérequis](#1-prérequis)
2. [Configuration Info.plist](#2-configuration-infoplist)
3. [Configuration Entitlements](#3-configuration-entitlements)
4. [Configuration AppDelegate](#4-configuration-appdelegate)
5. [Configuration Firebase](#5-configuration-firebase)
6. [Configuration des dépendances](#6-configuration-des-dépendances)
7. [Variables d'environnement](#7-variables-denvironnement)
8. [Checklist de production](#8-checklist-de-production)
9. [Sécurité](#9-sécurité)

---

## 1. Prérequis

### Version iOS minimale
- **Minimum**: iOS 11.0
- **Recommandé**: iOS 14.0+

### Outils requis
- Xcode 14.0 ou supérieur
- CocoaPods 1.11.0 ou supérieur
- Compte Apple Developer (payant pour distribution)
- Certificats de développement et distribution valides

### Installation des dépendances iOS
```bash
cd ios
pod install --repo-update
```

---

## 2. Configuration Info.plist

**Fichier**: `ios/Runner/Info.plist`

### 2.1 Permissions requises

```xml
<!-- Caméra (QR code, photos) -->
<key>NSCameraUsageDescription</key>
<string>Nous avons besoin d'accéder à votre caméra pour scanner les codes QR et prendre des photos</string>

<!-- Microphone (messages vocaux, appels) -->
<key>NSMicrophoneUsageDescription</key>
<string>Nous avons besoin d'accéder à votre microphone pour envoyer des messages vocaux et passer des appels</string>

<!-- Localisation (carte, services locaux) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Nous avons besoin de votre position pour afficher les services à proximité</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Nous avons besoin de votre position en arrière-plan pour les services de localisation</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Nous avons besoin de votre position pour vous notifier des événements proches</string>

<!-- Galerie photos -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Nous avons besoin d'accéder à votre galerie pour sélectionner des photos</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Nous avons besoin d'accéder à votre galerie pour sauvegarder des photos</string>

<!-- Face ID / Touch ID -->
<key>NSFaceIDUsageDescription</key>
<string>Nous utilisons Face ID pour sécuriser votre compte</string>

<!-- Calendrier (événements) -->
<key>NSCalendarsUsageDescription</key>
<string>Nous avons besoin d'accéder à votre calendrier pour ajouter des événements</string>

<!-- Contacts (optionnel) -->
<key>NSContactsUsageDescription</key>
<string>Nous avons besoin d'accéder à vos contacts pour vous aider à trouver vos amis</string>
```

### 2.2 Configuration Deep Links

```xml
<!-- Activer les deep links Flutter -->
<key>FlutterDeepLinkingEnabled</key>
<true/>

<!-- Schémas URL personnalisés -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>diasponiger</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>diasponiger</string>
        </array>
    </dict>
    <!-- Google Sign-In Callback -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>google</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.539228418594-t57j3s9ncgldbgk49a1td9f1hdrld7ic</string>
        </array>
    </dict>
</array>
```

### 2.3 Modes d'arrière-plan

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>           <!-- Messages vocaux, appels -->
    <string>fetch</string>           <!-- Actualisation en arrière-plan -->
    <string>location</string>        <!-- Localisation en arrière-plan -->
    <string>processing</string>      <!-- Traitement en arrière-plan -->
    <string>remote-notification</string>  <!-- Notifications push -->
</array>
```

---

## 3. Configuration Entitlements

**Fichier**: `ios/Runner/Runner.entitlements`

### 3.1 Configuration développement

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Push Notifications - Développement -->
    <key>aps-environment</key>
    <string>development</string>

    <!-- Associated Domains (Universal Links) -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:diasponiger.web.app</string>
        <string>applinks:diasponiger.com</string>
        <string>applinks:diasponiger.page.link</string>
    </array>
</dict>
</plist>
```

### 3.2 Configuration production

Créer un fichier `ios/Runner/Runner.entitlements.release` ou modifier pour la production :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Push Notifications - Production -->
    <key>aps-environment</key>
    <string>production</string>

    <!-- Associated Domains -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:diasponiger.web.app</string>
        <string>applinks:diasponiger.com</string>
        <string>applinks:diasponiger.page.link</string>
    </array>

    <!-- Apple Pay (pour Stripe) -->
    <key>com.apple.developer.in-app-payments</key>
    <array>
        <string>merchant.com.diasponiger</string>
    </array>

    <!-- Keychain Sharing -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.diasponiger.diaspoNiger</string>
    </array>
</dict>
</plist>
```

### 3.3 Activation des capabilities dans Xcode

1. Ouvrir `ios/Runner.xcworkspace` dans Xcode
2. Sélectionner la cible **Runner**
3. Aller dans **Signing & Capabilities**
4. Ajouter les capabilities suivantes :
   - **Push Notifications**
   - **Associated Domains**
   - **Background Modes** (avec les options cochées)
   - **Sign In with Apple** (si utilisé)
   - **Apple Pay** (si utilisé)

---

## 4. Configuration AppDelegate

**Fichier**: `ios/Runner/AppDelegate.swift`

### Configuration actuelle

```swift
import Flutter
import UIKit
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configuration Google Maps
        GMSServices.provideAPIKey("VOTRE_CLE_API_GOOGLE_MAPS")

        // Enregistrement des plugins Flutter
        GeneratedPluginRegistrant.register(with: self)

        // Configuration des notifications pour iOS 10+
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Gestion des deep links
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return super.application(app, open: url, options: options)
    }

    // Gestion des universal links
    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
```

### Recommandations de sécurité

Pour la production, ne pas hardcoder la clé API Google Maps. Utiliser plutôt :

```swift
// Option 1: Variable d'environnement via Info.plist
if let apiKey = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String {
    GMSServices.provideAPIKey(apiKey)
}

// Option 2: Fichier de configuration séparé (non versionné)
// Créer un fichier Config.swift avec la clé
```

---

## 5. Configuration Firebase

### 5.1 Fichier GoogleService-Info.plist

**Emplacement**: `ios/Runner/GoogleService-Info.plist`

Ce fichier est téléchargé depuis la console Firebase et contient :

| Clé | Description |
|-----|-------------|
| `BUNDLE_ID` | `com.diasponiger.diaspoNiger` |
| `PROJECT_ID` | `diaspo-niger` |
| `CLIENT_ID` | ID client OAuth pour Google Sign-In |
| `REVERSED_CLIENT_ID` | Schéma URL pour callback Google Sign-In |
| `API_KEY` | Clé API Firebase |
| `GCM_SENDER_ID` | ID expéditeur Cloud Messaging |
| `DATABASE_URL` | URL Realtime Database |
| `STORAGE_BUCKET` | Bucket Cloud Storage |

### 5.2 Configuration Push Notifications (APNs)

#### Étape 1: Créer une clé APNs

1. Aller dans [Apple Developer](https://developer.apple.com/account/resources/authkeys/list)
2. **Keys** → **+** → Créer une nouvelle clé
3. Nommer la clé (ex: "Diaspo Niger Push Key")
4. Cocher **Apple Push Notifications service (APNs)**
5. Télécharger le fichier `.p8` (ne peut être téléchargé qu'une fois!)
6. Noter le **Key ID**

#### Étape 2: Uploader dans Firebase

1. Console Firebase → **Project Settings** → **Cloud Messaging**
2. Section **Apple app configuration**
3. Uploader le fichier `.p8`
4. Entrer le **Key ID** et le **Team ID**

### 5.3 Vérification de la configuration

```bash
# Vérifier que le fichier GoogleService-Info.plist est présent
ls ios/Runner/GoogleService-Info.plist

# Vérifier la configuration Firebase
firebase apps:list
```

---

## 6. Configuration des dépendances

### 6.1 Google Maps

**Podfile** (`ios/Podfile`):
```ruby
platform :ios, '14.0'

# Ajouter si nécessaire
pod 'GoogleMaps'
```

**Restrictions API** (Google Cloud Console):
1. Aller dans APIs & Services → Credentials
2. Sélectionner la clé API
3. Restreindre à **iOS apps**
4. Ajouter le bundle ID: `com.diasponiger.diaspoNiger`

### 6.2 Stripe (Paiements)

**Configuration Apple Pay**:
1. Apple Developer → Identifiers → Merchant IDs
2. Créer `merchant.com.diasponiger`
3. Générer un certificat de paiement
4. Uploader dans le dashboard Stripe

**Entitlement requis**:
```xml
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.com.diasponiger</string>
</array>
```

### 6.3 WebRTC (Appels)

**Podfile**:
```ruby
# WebRTC nécessite un minimum iOS 12.0 pour les fonctionnalités avancées
platform :ios, '14.0'
```

**Permissions requises**:
- Microphone
- Caméra

### 6.4 Local Authentication (Biométrie)

Aucune configuration Podfile nécessaire. Seule la permission Face ID dans Info.plist est requise.

---

## 7. Variables d'environnement

### 7.1 Build avec dart-define

```bash
# Build développement
flutter build ios --debug \
  --dart-define=PRODUCTION=false \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx

# Build production
flutter build ipa --release \
  --dart-define=PRODUCTION=true \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxx \
  --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
```

### 7.2 Clés API à configurer

| Service | Variable | Où obtenir |
|---------|----------|------------|
| Google Maps | `GOOGLE_MAPS_API_KEY` | [Google Cloud Console](https://console.cloud.google.com) |
| Stripe | `STRIPE_PUBLISHABLE_KEY` | [Stripe Dashboard](https://dashboard.stripe.com) |
| Firebase | Automatique via GoogleService-Info.plist | [Firebase Console](https://console.firebase.google.com) |

### 7.3 Configuration Xcode pour variables d'environnement

Dans Xcode → Runner → Build Settings → User-Defined:

```
GOOGLE_MAPS_API_KEY = AIzaSyXXXXXXXXXXXXXXXXXXXXX
```

Puis dans Info.plist:
```xml
<key>GOOGLE_MAPS_API_KEY</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

---

## 8. Checklist de production

### 8.1 Avant la soumission

#### Signature et provisioning
- [ ] Team ID configuré dans Xcode
- [ ] Bundle ID correct: `com.diasponiger.diaspoNiger`
- [ ] Profil de provisioning valide (Distribution)
- [ ] Certificat de distribution valide

#### Capabilities
- [ ] Push Notifications activé
- [ ] Associated Domains configuré
- [ ] Background Modes activés
- [ ] Apple Pay configuré (si utilisé)

#### Fichiers de configuration
- [ ] Info.plist complet avec toutes les permissions
- [ ] Runner.entitlements avec `aps-environment` = `production`
- [ ] GoogleService-Info.plist correct pour la production

#### Sécurité
- [ ] Clé Google Maps restreinte au bundle ID iOS
- [ ] Clé Stripe en mode production (`pk_live_`)
- [ ] Pas de clés API en dur dans le code versionné
- [ ] Firebase App Check activé

#### Firebase
- [ ] Clé APNs uploadée
- [ ] Cloud Functions déployées
- [ ] Règles Firestore déployées
- [ ] Règles Storage déployées

### 8.2 Tests avant soumission

- [ ] Notifications push reçues correctement
- [ ] Deep links fonctionnent depuis Safari
- [ ] Google Sign-In fonctionne
- [ ] Paiements Stripe fonctionnent
- [ ] Localisation fonctionne
- [ ] Caméra et microphone fonctionnent
- [ ] Accès galerie photos fonctionne
- [ ] App ne crash pas sur différents appareils

### 8.3 App Store Connect

- [ ] Bundle ID enregistré
- [ ] Politique de confidentialité configurée
- [ ] Privacy labels configurés
- [ ] Version et numéro de build incrémentés
- [ ] Screenshots ajoutés (6.5", 5.5", iPad si nécessaire)
- [ ] Description et mots-clés mis à jour

---

## 9. Sécurité

### 9.1 Bonnes pratiques

1. **Ne jamais versionner les clés API**
   ```gitignore
   # .gitignore
   ios/Runner/GoogleService-Info.plist
   ios/Config.swift
   ```

2. **Utiliser des variables d'environnement**
   - dart-define pour les builds
   - Xcconfig pour les configurations Xcode

3. **Restreindre les clés API**
   - Google Maps: restreindre au bundle ID iOS
   - Firebase: App Check activé
   - Stripe: domaines autorisés configurés

### 9.2 Rotation des clés

Si une clé a été exposée:

1. **Google Maps**:
   - Créer une nouvelle clé dans Google Cloud Console
   - Restreindre l'ancienne avant de la supprimer

2. **Firebase**:
   - Regénérer GoogleService-Info.plist
   - Mettre à jour dans l'app

3. **Stripe**:
   - Régénérer les clés dans le dashboard
   - Mettre à jour les dart-define

### 9.3 Certificate Pinning (optionnel)

Pour une sécurité renforcée, implémenter le certificate pinning pour les appels API critiques.

---

## Commandes utiles

```bash
# Installation des pods
cd ios && pod install --repo-update && cd ..

# Nettoyage complet
flutter clean && cd ios && pod deintegrate && pod install && cd ..

# Build iOS debug
flutter build ios --debug

# Build iOS release (archive)
flutter build ipa --release

# Ouvrir dans Xcode
open ios/Runner.xcworkspace

# Vérifier la signature
codesign -dvvv ios/build/ios/iphoneos/Runner.app
```

---

## Support

Pour toute question sur la configuration iOS:
- Documentation Flutter: https://docs.flutter.dev/deployment/ios
- Documentation Firebase: https://firebase.google.com/docs/ios/setup
- Documentation Stripe: https://stripe.com/docs/payments/accept-a-payment?platform=ios
