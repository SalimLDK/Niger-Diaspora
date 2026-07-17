# Configuration des Notifications Push

Ce document décrit la configuration requise pour les notifications push avec réponse directe (style WhatsApp) sur Android et iOS.

## Fonctionnalités

- **Réponse directe** : Répondre à un message sans ouvrir l'application
- **Marquer comme lu** : Marquer une conversation comme lue depuis la notification
- **Groupement** : Les notifications sont groupées par conversation (style WhatsApp)

---

## Android

### Fichiers configurés

| Fichier | Contenu |
|---------|---------|
| `android/app/src/main/res/drawable/ic_reply.xml` | Icône bouton "Répondre" |
| `android/app/src/main/res/drawable/ic_mark_read.xml` | Icône bouton "Lu" |
| `android/app/src/main/AndroidManifest.xml` | Permission `POST_NOTIFICATIONS` |

### Permissions requises

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### Canaux de notification

Les canaux sont créés dans `lib/core/services/notification_service.dart` :

- `messages` - Messages (haute priorité)
- `friends_channel` - Demandes d'amis
- `groups_channel` - Activités de groupe
- `events_channel` - Événements
- `calls_channel` - Appels entrants (priorité max)
- `orders_channel` - Commandes marketplace

### Vérifications utilisateur

1. **Permissions** : Paramètres > Apps > Diaspo Niger > Notifications > Autoriser
2. **Optimisation batterie** : Désactiver pour l'app (requis pour le background)
3. **Fabricants spécifiques** : Xiaomi, Samsung, Huawei peuvent bloquer par défaut

---

## iOS

### Fichiers configurés

#### 1. Info.plist

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
    <string>processing</string>
    <string>remote-notification</string>  <!-- Requis pour push en background -->
</array>
```

#### 2. Runner.entitlements

```xml
<key>aps-environment</key>
<string>development</string>  <!-- Changer en "production" pour l'App Store -->
```

#### 3. AppDelegate.swift

```swift
import UserNotifications

// Dans didFinishLaunchingWithOptions:
if #available(iOS 10.0, *) {
    UNUserNotificationCenter.current().delegate = self
}
```

### Configuration Xcode requise

1. **Ouvrir le projet** dans Xcode (`ios/Runner.xcworkspace`)

2. **Activer Push Notifications** :
   - Runner > Signing & Capabilities
   - Cliquer sur "+ Capability"
   - Ajouter "Push Notifications"

3. **Activer Background Modes** :
   - Dans Signing & Capabilities
   - Ajouter "Background Modes"
   - Cocher "Remote notifications"

### Configuration Apple Developer Console

1. **Créer une clé APNs** :
   - Aller sur [Apple Developer](https://developer.apple.com)
   - Certificates, Identifiers & Profiles > Keys
   - Créer une nouvelle clé avec "Apple Push Notifications service (APNs)"
   - Télécharger le fichier `.p8`

2. **Configurer Firebase** :
   - Firebase Console > Project Settings > Cloud Messaging
   - Section "Apple app configuration"
   - Uploader la clé APNs (.p8)
   - Entrer le Key ID et Team ID

### Production

Pour la publication sur l'App Store, modifier `Runner.entitlements` :

```xml
<key>aps-environment</key>
<string>production</string>
```

---

## Architecture du code

### Services impliqués

```
lib/core/services/
├── notification_service.dart      # Service principal
├── background_reply_service.dart  # Envoi de messages en background
└── encryption_service.dart        # Chiffrement des messages
```

### Flux de réponse directe

```
1. Notification reçue avec actions "Répondre" / "Lu"
2. Utilisateur tape sa réponse dans la notification
3. notificationActionBackgroundHandler() appelé
4. BackgroundReplyService.sendReply() :
   - Initialise Firebase
   - Récupère userId depuis SharedPreferences
   - Chiffre le message
   - Envoie à Firebase RTDB
   - Met à jour Firestore (lastMessage, unreadCount)
```

### Catégorie iOS pour les actions

Définie dans `notification_service.dart` :

```dart
DarwinNotificationCategory(
  'message_category',
  actions: <DarwinNotificationAction>[
    DarwinNotificationAction.text(
      kReplyActionId,
      'Répondre',
      buttonTitle: 'Envoyer',
      placeholder: 'Tapez votre réponse...',
    ),
    DarwinNotificationAction.plain(
      kMarkReadActionId,
      'Marquer comme lu',
    ),
  ],
)
```

---

## Dépannage

### Android

| Problème | Solution |
|----------|----------|
| Notifications non reçues | Vérifier FCM token dans Firestore |
| Boutons d'action absents | Vérifier les fichiers drawable |
| Réponse non envoyée | Vérifier les logs de `BackgroundReplyService` |

### iOS

| Problème | Solution |
|----------|----------|
| Notifications non reçues | Vérifier certificat APNs dans Firebase |
| Actions non affichées | Vérifier `categoryIdentifier` dans la notification |
| Background non fonctionnel | Vérifier `UIBackgroundModes` et entitlements |

---

## Tests

### Tester les notifications

1. **Depuis Firebase Console** :
   - Cloud Messaging > Send test message
   - Entrer le FCM token de l'appareil

2. **Depuis le code** :
   - Utiliser la Cloud Function `sendNotification`

### Tester la réponse directe

1. Envoyer un message depuis un autre compte
2. Recevoir la notification
3. Glisser vers le bas (ou appui long sur iOS)
4. Vérifier la présence des boutons "Répondre" et "Lu"
5. Taper une réponse et envoyer
6. Vérifier que le message apparaît dans la conversation
