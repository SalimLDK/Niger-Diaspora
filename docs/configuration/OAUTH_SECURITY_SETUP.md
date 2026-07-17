# Configuration de Sécurité OAuth - Diaspo Niger

Ce document décrit les étapes de configuration nécessaires pour sécuriser les flux OAuth et prévenir l'usurpation d'identité sur Google Cloud.

## Table des matières

1. [Prérequis](#prérequis)
2. [Configuration Google Cloud Console](#configuration-google-cloud-console)
3. [Configuration Firebase](#configuration-firebase)
4. [Variables d'environnement](#variables-denvironnement)
5. [Monitoring et alertes](#monitoring-et-alertes)
6. [Checklist de sécurité](#checklist-de-sécurité)

---

## Prérequis

- Accès administrateur à Google Cloud Console
- Accès administrateur à Firebase Console
- Clés SHA-1 et SHA-256 de vos keystores (debug et release)

---

## Configuration Google Cloud Console

### 1. Vérification des identifiants OAuth

1. Accédez à [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Sélectionnez votre projet
3. Pour chaque Client ID OAuth 2.0 :

#### Android (Type: Android)
```
Restrictions:
- Package name: com.diasponiger.diaspo_niger
- SHA-1 certificate fingerprint: [Votre SHA-1 release]
```

Pour obtenir le SHA-1 :
```bash
# Debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release keystore
keytool -list -v -keystore [path/to/release.keystore] -alias [alias]
```

#### iOS (Type: iOS)
```
Restrictions:
- Bundle ID: com.diasponiger.diaspoNiger
```

#### Web (Type: Web application)
```
Origines JavaScript autorisées:
- https://diasponiger.com
- https://diaspo-niger.web.app
- http://localhost:3000 (développement uniquement)

URI de redirection autorisés:
- https://diasponiger.com/auth/callback
- https://diaspo-niger.firebaseapp.com/__/auth/handler
```

### 2. Configuration de l'écran de consentement OAuth

1. Allez dans **APIs & Services > OAuth consent screen**
2. Vérifiez que l'application est en mode **Production** (si publiée)
3. Configurez les scopes minimaux requis :
   - `email`
   - `profile`
   - `openid`

### 3. Activation des alertes de sécurité

1. Allez dans **Security > Security Center**
2. Activez les notifications pour :
   - Activités de connexion inhabituelles
   - Modifications des identifiants OAuth
   - Tentatives d'accès non autorisées

---

## Configuration Firebase

### 1. App Check

App Check protège vos ressources backend contre les abus.

#### Android
- **Production** : Play Integrity (recommandé)
- **Développement** : Debug Provider

```
Firebase Console > App Check > Applications > com.diasponiger.diaspo_niger
- Provider: Play Integrity
- Enforcement: Enabled
```

#### iOS
- **Production** : App Attest
- **Développement** : Debug Provider

```
Firebase Console > App Check > Applications > iOS
- Provider: App Attest
- Enforcement: Enabled
```

#### Web
```
Firebase Console > App Check > Applications > Web
- Provider: reCAPTCHA Enterprise
- Enforcement: Enabled
```

### 2. Debug Tokens

Pour le développement, enregistrez vos debug tokens :

1. Firebase Console > App Check > Manage debug tokens
2. Ajoutez les tokens de vos appareils de développement
3. Format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 3. Firebase Authentication Settings

1. Allez dans **Authentication > Settings**
2. Configurez :
   - **User actions** : Désactivez l'auto-création si non nécessaire
   - **Authorized domains** : Listez uniquement vos domaines
   - **Password policy** : Minimum 8 caractères, complexité requise

---

## Variables d'environnement

### Production Build

```bash
flutter build apk --release \
  --dart-define=PRODUCTION=true \
  --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxx
```

### Development Build

```bash
flutter run \
  --dart-define=STRIPE_TEST_PUBLISHABLE_KEY=pk_test_xxx
```

### Variables requises

| Variable | Description | Production | Développement |
|----------|-------------|------------|---------------|
| `PRODUCTION` | Mode production | `true` | `false` |
| `GOOGLE_WEB_CLIENT_ID` | OAuth Web Client ID | Requis | Optionnel |
| `STRIPE_PUBLISHABLE_KEY` | Clé Stripe live | Requis (`pk_live_`) | - |
| `STRIPE_TEST_PUBLISHABLE_KEY` | Clé Stripe test | - | Recommandé |

---

## Monitoring et alertes

### 1. Cloud Monitoring

Configurez des alertes pour :

```yaml
# Tentatives d'authentification échouées
metric.type="firebaseauth.googleapis.com/user/sign_in_failure_count"
threshold: > 100/hour
notification: email + SMS

# Utilisation anormale de l'API
metric.type="serviceruntime.googleapis.com/api/request_count"
threshold: > 10000/minute
notification: email

# App Check rejections
metric.type="firebaseappcheck.googleapis.com/api/token/invalid_count"
threshold: > 50/hour
notification: email
```

### 2. Firebase Crashlytics

Surveillez les erreurs liées à l'authentification :
- `FirebaseAuthException`
- `GoogleSignInException`
- `PlatformException` (sign_in_failed)

### 3. Audit Logs

Activez les logs d'audit dans Cloud Console :
1. **IAM & Admin > Audit Logs**
2. Activez pour :
   - Cloud Identity-Aware Proxy API
   - Firebase Auth
   - Cloud Functions

---

## Checklist de sécurité

### Avant le déploiement

- [ ] SHA-1/SHA-256 de production enregistrés dans Google Cloud
- [ ] Domaines OAuth restreints aux domaines de production
- [ ] App Check activé et enforced pour tous les providers
- [ ] Variables d'environnement de production configurées
- [ ] Clé Stripe live (`pk_live_`) configurée
- [ ] Mode production activé (`PRODUCTION=true`)

### Configuration Firebase

- [ ] Firestore Security Rules déployées
- [ ] App Check enforcement activé
- [ ] Authorized domains configurés
- [ ] Debug tokens de développement enregistrés

### Monitoring

- [ ] Alertes Cloud Monitoring configurées
- [ ] Crashlytics activé
- [ ] Audit logs activés
- [ ] Dashboard de monitoring créé

### Révocation d'urgence

En cas de compromission suspectée :

1. **Révoquer les secrets OAuth** :
   ```
   Google Cloud Console > Credentials > [Client ID] > Reset secret
   ```

2. **Révoquer les tokens utilisateur** :
   ```
   Firebase Console > Authentication > [User] > Disable account
   ```

3. **Régénérer les clés Stripe** :
   ```
   Stripe Dashboard > Developers > API keys > Roll key
   ```

4. **Forcer la déconnexion globale** :
   - Modifier `session_id` dans Firestore pour tous les utilisateurs

---

## Support

Pour toute question de sécurité :
- Ouvrez un ticket prioritaire via le support interne
- Contactez l'équipe de sécurité

---

*Dernière mise à jour : Février 2026*
