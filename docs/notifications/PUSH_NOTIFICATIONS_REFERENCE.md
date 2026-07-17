# 📊 Tableau Récapitulatif Complet - Push Notifications

## Référence Rapide - Toutes les Notifications

| # | Type | Canal | Priorité | Son | Vibration | LED | Groupement | Actions | Trigger |
|---|------|-------|----------|-----|-----------|-----|-----------|---------|---------|
| **MESSAGES** |
| 1 | Message (1:1/Groupe) | `messages` | HIGH | ✅ | ✅ [0,100,50,100] | 🔵 Bleu | Par conversation | 2 (Répondre, LU) | onMessageCreated |
| **AMIS** |
| 2 | Friend Request | `friends_channel` | HIGH | ✅ | ✅ [0,200,100,200] | 🔵 Bleu | Par demandeur | 2 (Accepter, Refuser) | onFriendRequestCreated |
| 3 | Friend Accepted | `friends_channel` | HIGH | ✅ | ✅ [0,200,100,200] | 🔵 Bleu | Non groupé | 1 (Discuter) | onFriendRequestAccepted |
| 4 | New Follower | `friends_channel` | HIGH | ✅ | ✅ | 🔵 Bleu | Par follower | 1 (Suivre retour) | onNewFollower |
| **GROUPES** |
| 5 | Group Invite | `groups_channel` | HIGH | ✅ | ✅ [0,200,100,200] | 🟣 Violet | Par groupe | 2 (Accepter, Refuser) | onGroupInviteCreated |
| 6 | New Member | `groups_channel` | HIGH | ✅ | ✅ | 🟣 Violet | Par groupe | 1 (Voir groupe) | onMemberJoined |
| 7 | Group Join Request | `groups_channel` | HIGH | ✅ | ✅ | 🟣 Violet | Par groupe | 2 (Approuver, Refuser) | onGroupRequestCreated |
| 8 | Request Approved | `groups_channel` | NORMAL | ✅ | ✅ | 🟣 Violet | Non groupé | 1 (Rejoindre) | onGroupRequestApproved |
| 9 | Request Rejected | `groups_channel` | NORMAL | ✅ | ✅ | 🟣 Violet | Non groupé | 0 | onGroupRequestRejected |
| **ÉVÉNEMENTS** |
| 10 | Event Reminder | `event_reminders_channel` | HIGH | ✅ | ✅ [0,250,100,250] | 🟠 Orange | Par événement | 1 (Voir événement) | Programmé (1h/15m/1j avant) |
| 11 | Event Update | `events_channel` | NORMAL | ✅ | ✅ | 🟠 Orange | Par événement | 1 (Voir détails) | onEventUpdated |
| 12 | Local Event | `events_channel` | NORMAL | ✅ | ✅ | 🟠 Orange | Par région | 2 (Voir, Intéressé) | Géolocalisation (2h frequency) |
| 13 | Event Attendance | `events_channel` | NORMAL | ✅ | ✅ | 🟠 Orange | Par événement | 1 (Voir participants) | onAttendanceConfirmed |
| **PROXIMITÉ** |
| 14 | Nearby Member | `proximity_channel` | NORMAL | ✅ | ✅ | - | Non groupé | 2 (Voir, Contacter) | Géolocalisation (5-10m) |
| 15 | Proximity Alert 🚨 | `proximity_channel` | MAX | ✅ ALERTE | ✅ [0,500,200,500,200,500] | 🔴 ROUGE | Non groupé | 3 (Map, Signal, Share) | Rapprochement soudain (< 100m en 5m) |
| **MARKETPLACE** |
| 16 | New Order | `orders_channel` | HIGH | ✅ | ✅ [0,250,100,250] | 🟦 Teal | Par vendeur | 2 (Accepter, Voir) | onOrderCreated |
| 17 | Order Paid | `orders_channel` | HIGH | ✅ | ✅ | 🟦 Teal | Par vendeur | 1 (Commencer) | onOrderPaid |
| 18 | Order Shipped | `orders_channel` | NORMAL | ✅ | ✅ | 🟦 Teal | Par commande | 1 (Suivre colis) | onOrderShipped |
| 19 | Order Delivered | `orders_channel` | NORMAL | ✅ | ✅ | 🟦 Teal | Par commande | 2 (Confirmer, Signaler) | onOrderDelivered |
| 20 | Order Cancelled | `orders_channel` | NORMAL | ✅ | ✅ | 🟦 Teal | Non groupé | 1 (Contacter support) | onOrderCancelled |
| 21 | Order Completed | `orders_channel` | NORMAL | ✅ | ✅ | 🟦 Teal | Non groupé | 1 (Laisser avis) | onOrderCompleted |
| **APPELS** |
| 22 | Incoming Call | `calls_channel` | MAX | ✅ | ✅ [0,500,200,500] | 🟢 Vert | Non groupé | 2 (Accepter, Refuser) | onCallCreated |
| 23 | Missed Call | `calls_channel` | HIGH | ✅ | ✅ | 🟢 Vert | Par appelant | 1 (Rappeler) | onCallMissed |
| **AUTRES** |
| 24 | Mention | `general_channel` | HIGH | ✅ | ✅ | 🔵 Primaire | Par post | 1 (Voir post) | onMention |
| 25 | General | `general_channel` | NORMAL | ✅ | ✅ | 🔵 Primaire | Non groupé | 1 (Ouvrir) | System events |

---

## Canaux Android Détaillés

```json
{
  "notification_channels": [
    {
      "id": "messages",
      "name": "Messages",
      "importance": "HIGH",
      "description": "Notifications pour les nouveaux messages",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "enabled",
      "led_color": "Primary (Bleu)",
      "badge": "enabled",
      "examples": ["Message 1:1", "Message groupe", "Message vocal", "Message avec image"]
    },
    {
      "id": "friends_channel",
      "name": "Demandes d'amis",
      "importance": "HIGH",
      "description": "Notifications pour les amis",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "enabled",
      "led_color": "Bleu",
      "badge": "enabled",
      "examples": ["Friend request", "Friend accepted", "New follower"]
    },
    {
      "id": "groups_channel",
      "name": "Groupes",
      "importance": "HIGH",
      "description": "Activités de groupe",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "enabled",
      "led_color": "Violet",
      "badge": "enabled",
      "examples": ["Group invite", "Join request", "New member", "Request approved/rejected"]
    },
    {
      "id": "events_channel",
      "name": "Événements",
      "importance": "NORMAL",
      "description": "Événements et mises à jour",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "enabled",
      "led_color": "Orange",
      "badge": "enabled",
      "examples": ["Event update", "Local event", "Event attendance"]
    },
    {
      "id": "event_reminders_channel",
      "name": "Rappels d'événements",
      "importance": "HIGH",
      "description": "Rappels programmés",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["Event reminder (1h before)", "Event reminder (15m before)"]
    },
    {
      "id": "audio_rooms_reminders_channel",
      "name": "Salles audio",
      "importance": "HIGH",
      "description": "Rappels de salles audio",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["Audio room starting"]
    },
    {
      "id": "podcast_reminders_channel",
      "name": "Podcasts",
      "importance": "NORMAL",
      "description": "Nouveaux épisodes",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["New podcast episode"]
    },
    {
      "id": "transfer_reminders_channel",
      "name": "Transferts",
      "importance": "HIGH",
      "description": "Rappels de transferts",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["Scheduled transfer reminder"]
    },
    {
      "id": "proximity_channel",
      "name": "Proximité",
      "importance": "HIGH",
      "description": "Personnes à proximité",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["Nearby member", "Proximity alert"]
    },
    {
      "id": "orders_channel",
      "name": "Commandes",
      "importance": "HIGH",
      "description": "Notifications marketplace",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["New order", "Order paid", "Order shipped", "Order delivered"]
    },
    {
      "id": "calls_channel",
      "name": "Appels",
      "importance": "MAX",
      "description": "Appels entrants",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "enabled",
      "led_color": "Primary",
      "badge": "enabled",
      "examples": ["Incoming call", "Missed call"]
    },
    {
      "id": "general_channel",
      "name": "Général",
      "importance": "NORMAL",
      "description": "Notifications système",
      "sound": "enabled",
      "vibration": "enabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["General system notifications", "Mentions"]
    },
    {
      "id": "quick_reply_confirmation",
      "name": "Confirmations",
      "importance": "LOW",
      "description": "Confirmations d'actions",
      "sound": "disabled",
      "vibration": "disabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["Reply sent confirmation", "Pending reply notification"]
    },
    {
      "id": "background_location",
      "name": "Position",
      "importance": "LOW",
      "description": "Service de position",
      "sound": "disabled",
      "vibration": "disabled",
      "lights": "disabled",
      "led_color": null,
      "badge": "disabled",
      "examples": ["Background location service notification"]
    }
  ]
}
```

---

## Styles d'Affichage

| Style | Types | Caractéristiques | Exemple |
|-------|-------|------------------|---------|
| **MessagingStyle** | Message | Historique de messages, avatars, conversations groupées | Groupe: 3 messages de 2 personnes |
| **BigPictureStyle** | Message + Image/Vidéo | Image grande, preview rapide | Photo envoyée par Marie |
| **Simple Style** | Tous les autres | Titre + Corps, icône, actions | Demande d'ami, Commande |
| **CallKit Native** | Appel entrant | Écran complet, Lock screen | Appel vidéo Jérôme |

---

## Patterns de Vibration

```
MESSAGE:           [0, 100, 50, 100]       (Rapide - 150ms total)
FRIEND:            [0, 200, 100, 200]      (Medium - 500ms total)
EVENT/ORDER:       [0, 250, 100, 250]      (Medium - 600ms total)
CALL/ALERT:        [0, 500, 200, 500, 200, 500]  (Long répétitif - 1700ms)
SECURITY ALERT:    [0, 500, 200, 500]      (Urgence - 1200ms)
```

---

## Cas d'Usage & Déclencheurs

### Messages
```
DÉCLENCHEUR: onMessageCreated (Cloud Function - europe-west1)
├─ Nouveau message en Realtime Database
├─ Pour tous les participants sauf l'expéditeur
├─ Respecte muteConversation
├─ Respecte showMessagePreview
├─ Support E2EE
└─ Stocké en Firestore pour historique
```

### Demandes d'Amis
```
DÉCLENCHEUR: onFriendRequestCreated (Cloud Function)
├─ Utilisateur A envoie demande à Utilisateur B
├─ Utilisateur B reçoit notification
├─ Actions: Accepter ou Refuser
└─ Stocké en Firestore
```

### Commandes
```
DÉCLENCHEUR: Plusieurs Cloud Functions
├─ onOrderCreated: Nouvelle commande (Vendeur)
├─ onOrderPaid: Paiement confirmé (Vendeur + Acheteur)
├─ onOrderShipped: Commande expédiée (Acheteur)
├─ onOrderDelivered: Livraison (Acheteur)
└─ onOrderCancelled: Annulation (Acheteur)
```

### Appels
```
DÉCLENCHEUR: onCallCreated (Cloud Function)
├─ Appel entrant initialisé
├─ Affichage natif (CallKit iOS / ConnectionService Android)
├─ Timeout: 45 secondes
├─ Support audio + vidéo
└─ Ignores Quiet Hours (urgence)
```

### Proximité
```
DÉCLENCHEUR: Background location service
├─ Scan toutes les 5-10 minutes
├─ Compare distance avec utilisateurs actifs
├─ Alerte si < 50km (normal) ou < 100m en 5m (urgence)
└─ Respecte preferences utilisateur
```

---

## Permissions & Préférences Utilisateur

### Contrôles Globaux
- [ ] Notifications globales (ON/OFF)
- [ ] Aperçu des messages (ON/OFF)
- [ ] Son (ON/OFF)
- [ ] Vibration (ON/OFF)

### Contrôles par Type
- [ ] Messages
- [ ] Demandes d'amis
- [ ] Groupes
- [ ] Événements
- [ ] Commandes
- [ ] Appels

### Paramètres Avancés
- **Heure silencieuse**: 22:00 - 08:00 (personnalisable)
- **Muted conversations**: 1h / 8h / 24h / Forever
- **Show message preview**: Oui/Non

---

## Platform Spécifique

### Android
```
- Importance levels: 1 (MIN) à 5 (MAX)
- Notification channels (Android 8+)
- LED colors (RGB)
- Vibration patterns
- Heads-up notifications (urgentes)
- Grouping & summary
```

### iOS
```
- Critical alerts: Non (app-side alert permission)
- Sound: default (system)
- Badge: app icon
- Notification categories: message_category
- Direct reply: Supported
- Provisional authorization
```

---

## Performance & Optimisation

### Limiations
- Max 10 notifications par minute par type
- Max 3 notifications groupées simultanément
- Batch send max: 500 tokens FCM
- Avatar cache: 30 jours (temp directory)

### Optimisations
- Avatar downloading: Async, 3s timeout
- Person cache: En mémoire (performance)
- Token cleanup: Automatic dead token removal
- E2EE: Client-side decryption (privacy)

---

## Checklist Intégration

Pour supporter une nouvelle notification:

```
BACKEND:
[ ] Créer Cloud Function trigger
[ ] Ajouter type dans Firestore notification doc
[ ] Implémenter logique de sélection des tokens
[ ] Définir le canal Android cible

FLUTTER:
[ ] Ajouter NotificationType enum
[ ] Implémenter NotificationTypeExtension (label + icon)
[ ] Ajouter le canal Android si nouveau
[ ] Implémenter le style d'affichage
[ ] Ajouter les actions si applicable
[ ] Tester sur Android + iOS

CONFIGURATION:
[ ] Définir vibration pattern
[ ] Définir LED color
[ ] Configurer priorité
[ ] Documenter dans ce guide
[ ] Ajouter aux préférences utilisateur
```

---

## Questions Fréquentes

### Q: Comment grouper des notifications?
```
R: Par groupKey automatique:
   - Messages: "messages_{conversationId}"
   - Commandes: "order_{vendorId}"
   - Amis: "friend_{senderId}"
   Affichage: Summary + historique
```

### Q: Comment ignorer Quiet Hours?
```
R: Définir Importance.max + playSound: true
   Exemple: Appels, Alertes sécurité
```

### Q: Comment supporter E2EE?
```
R: Client-side decryption dans handler foreground
   Cloud Function envoie: messagePreview + encryptionFlag
   Client: Déchiffre si possible, sinon affiche fallback
```

### Q: Timeout Appel?
```
R: 45 secondes (configurable)
   Après: Affichage "Appel manqué" + Missed Call notification
```

---

**Dernière mise à jour**: 2026-05-07  
**Total Notifications**: 25 types  
**Canaux Android**: 14  
**Styles**: 4  
**Cloud Functions**: 20+  
**Statut**: ✅ Production Ready
