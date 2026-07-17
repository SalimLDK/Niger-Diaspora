# Configuration des App Links / Universal Links

Ce guide explique comment configurer les liens profonds pour que l'application s'ouvre automatiquement quand un utilisateur clique sur un lien `https://diaspo-niger.web.app/...`.

## Architecture

```
Utilisateur clique sur un lien
         │
         ▼
https://diaspo-niger.web.app/groups/abc123
         │
         ├─── App installée ? ──► Ouvre l'app directement
         │
         └─── App non installée ? ──► Ouvre le site web
                                      (qui peut rediriger vers le store)
```

## Fichiers de configuration

### 1. Android - assetlinks.json

**Emplacement :** `public/.well-known/assetlinks.json`

```json
[
    {
        "relation": [
            "delegate_permission/common.handle_all_urls"
        ],
        "target": {
            "namespace": "android_app",
            "package_name": "com.diasponiger.diaspo_niger",
            "sha256_cert_fingerprints": [
                "VOTRE_SHA256_DEBUG",
                "VOTRE_SHA256_RELEASE"
            ]
        }
    }
]
```

**Pour obtenir les SHA256 :**

```bash
# Debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA256

# Release
keytool -list -v -keystore votre-keystore.jks -alias votre-alias | grep SHA256
```

### 2. iOS - apple-app-site-association

**Emplacement :** `public/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.diasponiger.diaspo_niger",
        "paths": [
          "/groups/*",
          "/profile/*",
          "/p/u/*",
          "/events/*",
          "/businesses/*",
          "/marketplace/*",
          "/audio-rooms/*",
          "/podcasts/*",
          "/calls/*",
          "/invite"
        ]
      }
    ]
  },
  "webcredentials": {
    "apps": [
      "TEAM_ID.com.diasponiger.diaspo_niger"
    ]
  }
}
```

**Pour obtenir le TEAM_ID :**
1. Connectez-vous sur [developer.apple.com](https://developer.apple.com/account)
2. Allez dans "Membership"
3. Copiez le "Team ID"

## Configuration Android

### AndroidManifest.xml

L'intent-filter suivant doit être présent dans `android/app/src/main/AndroidManifest.xml` :

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="diaspo-niger.web.app" />
</intent-filter>
```

## Configuration iOS

### Xcode

1. Ouvrez le projet dans Xcode
2. Sélectionnez la cible principale
3. Allez dans "Signing & Capabilities"
4. Cliquez sur "+ Capability"
5. Ajoutez "Associated Domains"
6. Ajoutez : `applinks:diaspo-niger.web.app`

## Déploiement

### 1. Déployer sur Firebase Hosting

```bash
firebase deploy --only hosting:diaspo-niger
```

### 2. Vérifier le déploiement

Testez ces URLs dans un navigateur :

| Plateforme | URL de vérification |
|------------|---------------------|
| Android | https://diaspo-niger.web.app/.well-known/assetlinks.json |
| iOS | https://diaspo-niger.web.app/.well-known/apple-app-site-association |

### 3. Vérifier avec les outils officiels

**Android :**
```bash
# Via ADB
adb shell am start -a android.intent.action.VIEW -d "https://diaspo-niger.web.app/groups/test"

# Via l'outil Google
# https://developers.google.com/digital-asset-links/tools/generator
```

**iOS :**
- Testez sur un vrai appareil (pas le simulateur)
- Envoyez-vous un lien par iMessage et cliquez dessus

## Dépannage

### Android : Le lien ouvre le navigateur au lieu de l'app

1. **Vérifiez que `autoVerify="true"`** est présent dans l'intent-filter
2. **Vérifiez les SHA256** dans assetlinks.json
3. **Effacez les données de l'app** : Paramètres → Apps → Diaspo Niger → Effacer les données
4. **Réinstallez l'app** pour forcer la revérification

### iOS : Le lien n'ouvre pas l'app

1. **Vérifiez le TEAM_ID** dans apple-app-site-association
2. **Vérifiez Associated Domains** dans Xcode
3. **Testez sur un vrai appareil** (pas le simulateur)
4. **Attendez quelques minutes** - iOS met en cache les fichiers d'association

### Erreur "Lien dynamique introuvable"

Cette erreur apparaît si vous utilisez encore Firebase Dynamic Links (déprécié). Assurez-vous que :
- `deep_link_service.dart` utilise `https://diaspo-niger.web.app` comme base URL
- Vous n'utilisez plus `diasponiger.page.link`

## Headers Firebase Hosting

Le fichier `firebase.json` doit inclure ces headers :

```json
{
    "source": "/.well-known/assetlinks.json",
    "headers": [
        { "key": "Content-Type", "value": "application/json" }
    ]
},
{
    "source": "/.well-known/apple-app-site-association",
    "headers": [
        { "key": "Content-Type", "value": "application/json" }
    ]
}
```

## Liens générés

Exemples de liens générés par l'application :

| Type | Exemple |
|------|---------|
| Groupe | `https://diaspo-niger.web.app/groups/abc123` |
| Profil | `https://diaspo-niger.web.app/p/u/user123` |
| Événement | `https://diaspo-niger.web.app/events/evt456` |
| Produit | `https://diaspo-niger.web.app/marketplace/prod789` |
| Salon audio | `https://diaspo-niger.web.app/audio-rooms/room321` |
| Podcast | `https://diaspo-niger.web.app/podcasts/pod654` |

## Ressources

- [Android App Links](https://developer.android.com/training/app-links)
- [iOS Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Digital Asset Links Generator](https://developers.google.com/digital-asset-links/tools/generator)
