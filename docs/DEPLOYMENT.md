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

## 3. Déploiement Backend (Firebase)

Si vous avez modifié les règles de sécurité, les indexes ou les Cloud Functions.

```bash
# Déployer tout (Firestore Rules, Indexes, Functions, Storage Rules...)
firebase deploy

# Déployer uniquement les fonctions
firebase deploy --only functions

# Déployer uniquement les règles Firestore
firebase deploy --only firestore:rules
```

### Environnement de Production Firebase

Assurez-vous que le projet Firebase actif est bien celui de production :
```bash
firebase use production-project-alias
```
(Vous pouvez ajouter des alias via `firebase use --add`).

## 4. Checklist Avant Mise en Prod

- [ ] **AppConfig** : Vérifier que `PRODUCTION=true` est bien passé.
- [ ] **Stripe** : Vérifier que la clé `pk_live_...` est valide.
- [ ] **Logs** : Les logs de debug doivent être désactivés (géré par `AppConfig.isProduction`).
- [ ] **Icônes** : Vérifier les icônes de lancement (`flutter_launcher_icons`).
- [ ] **Permissions** : Vérifier que toutes les permissions (Camera, Location, etc.) ont des descriptions valides dans `Info.plist` et `AndroidManifest.xml`.
