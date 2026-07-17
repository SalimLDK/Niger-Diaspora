# Configuration iOS Critique avant Release

Ce fichier recense tous les points de configuration iOS importants à vérifier avant de soumettre l'application sur l'App Store.

## 1. Deep Links & Universal Links (CRITIQUE)
Nous avons activé les Universal Links pour `diasponiger.com` et `diasponiger.web.app`.

### ⚠️ Action Requise dans Xcode
Le fichier `Runner.entitlements` a été créé mais **doit être lié au projet Xcode** si ce n'est pas déjà fait automatiquement.

1. Ouvrir le projet `ios/Runner.xcworkspace` dans Xcode.
2. Sélectionner la target **Runner**.
3. Aller dans l'onglet **Signing & Capabilities**.
4. Vérifier que la section **Associated Domains** est présente.
   - Si elle est absente : Cliquez sur **+ Capability** et ajoutez **Associated Domains**.
   - Ajoutez les domaines suivants :
     - `applinks:diasponiger.web.app`
     - `applinks:diasponiger.com`

## 2. URL Schemes
L'application répond au schéma d'URL personnalisé : `diasponiger://`
Ceci est configuré dans `Info.plist` sous `CFBundleURLTypes`.

## 3. Permissions (Info.plist)
Vérifiez que les messages d'explication (Usage Descriptions) sont clairs et valides pour Apple Review.

| Clé | Message actuel | Usage |
|-----|----------------|-------|
| `NSCameraUsageDescription` | "Nous avons besoin d'accéder à votre caméra pour scanner les QR codes des profils" | Scan QR Code |
| `NSMicrophoneUsageDescription` | "Nous avons besoin d'accéder à votre microphone pour envoyer des messages vocaux" | Messagerie Vocale |
| `NSPhotoLibraryAddUsageDescription` | "Nous avons besoin de cette permission pour sauvegarder des images dans votre galerie" | Téléchargement d'images |

## 4. Autres Vérifications
- **Icônes** : Générées via `flutter_launcher_icons`. Vérifiez qu'elles apparaissent correctement sur le simulateur.
- **Version** : Assurez-vous que `FLUTTER_BUILD_NAME` (version) et `FLUTTER_BUILD_NUMBER` (build) sont incrémentés dans `pubspec.yaml` avant l'archive.
