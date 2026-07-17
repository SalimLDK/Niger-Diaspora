# 📱 Guide Complet des Push Notifications - Diaspo Niger

## Table des Matières
1. [Vue d'ensemble](#vue-densemble)
2. [Types de Notifications](#types-de-notifications)
3. [Canaux Android](#canaux-android)
4. [Modes d'Affichage](#modes-daffichage)
5. [Maquettes & Combinaisons](#maquettes--combinaisons)
6. [Actions & Interactions](#actions--interactions)

---

## Vue d'ensemble

Le système de notifications de Diaspo Niger utilise:
- **Firebase Cloud Messaging (FCM)** pour l'envoi
- **flutter_local_notifications** pour l'affichage local
- **15 canaux Android** avec configurations spécifiques
- **3 styles d'affichage**: MessagingStyle (chat), BigPictureStyle (images), Simple
- **Support complet E2EE** pour les messages chiffrés
- **Groupement style WhatsApp** des notifications
- **Actions directes**: Répondre rapide, Marquer comme lu

---

## Types de Notifications

### 1. 💬 MESSAGE
**Nom complète**: `NotificationType.message`  
**Statut**: Plus haute priorité  
**Canal Android**: `messages`  
**Priorité**: `HIGH`

#### Objectif
Notifier l'utilisateur d'un nouveau message reçu dans une conversation 1:1 ou groupe.

#### Contenu Typique
```
Titre: "Nom de la personne" (1:1) ou "Nom du Groupe" (groupe)
Corps: "Prenom: Contenu du message" ou "Prenom: 📸 Photo"
```

#### Mode d'Affichage
- **Appareil au repos (background)**: Notification classique avec actions
- **App au foreground**: Banner in-app + notification
- **Style Android**: **MessagingStyle** (comme WhatsApp)
  - Affiche l'historique des derniers messages
  - Photo de profil de l'expéditeur
  - Affichage en thread

#### Vibration & Son
```
Vibration: [0, 100, 50, 100] (court, comme WhatsApp)
Son: default (son système)
LED: Couleur primaire (bleu)
```

#### Actions Disponibles
1. **Répondre rapide** (Réply)
   - Permet d'envoyer un message sans ouvrir l'app
   - Confirmation de l'envoi immédiate
2. **Marquer comme lu** 
   - Marque la conversation comme lue

#### Cloud Function Trigger
- `onMessageCreated`: Déclenché lors de la création d'un message en Realtime Database
- Respecte les préférences utilisateur (muted conversations, message preview)
- Support de la décryption E2EE côté client

#### Maquette d'Affichage

**CONFIGURATION: Historique de 3 messages groupés**
```
┌─────────────────────────────────┐
│ 👤 Jérôme M.                    │
├─────────────────────────────────┤
│ Salut comment ça va?            │
│ Tu fais quoi ce soir?           │
│ Message le plus récent...       │
├─────────────────────────────────┤
│ [Répondre]  [Marquer comme lu]  │
└─────────────────────────────────┘
```

**CONFIGURATION: Message avec image**
```
┌─────────────────────────────────┐
│ 👤 Marie                         │
├─────────────────────────────────┤
│ 📸 Photo                         │
│ (Miniature de l'image)           │
├─────────────────────────────────┤
│ [Répondre]  [Marquer comme lu]  │
└─────────────────────────────────┘
```

**CONFIGURATION: Message vocal**
```
┌─────────────────────────────────┐
│ 👤 Ahmed                         │
├─────────────────────────────────┤
│ 🎙️ Message vocal                │
│ (Durée: 2:34)                   │
├─────────────────────────────────┤
│ [Répondre]  [Marquer comme lu]  │
└─────────────────────────────────┘
```

---

### 2. 👥 FRIEND REQUEST
**Nom complète**: `NotificationType.friendRequest`  
**Statut**: Haute priorité  
**Canal Android**: `friends_channel`  
**Priorité**: `HIGH`

#### Objectif
Notifier l'utilisateur qu'une personne a envoyé une demande d'amitié.

#### Contenu Typique
```
Titre: "Ahmed a envoyé une demande d'ami"
Corps: "Vérifiez son profil et acceptez ou refusez"
```

#### Mode d'Affichage
- **Style Android**: Simple (pas de MessagingStyle)
- **Groupement**: Par type d'utilisateur demandeur
- **Photo de profil**: Avatar du demandeur

#### Vibration & Son
```
Vibration: [0, 200, 100, 200]
Son: Notification sound
LED: Bleu (#2196F3)
```

#### Actions Disponibles
- Accepter (ouvre le profil)
- Refuser (supprime la notification)
- Ouvrir le profil

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 👤 Ahmed a envoyé une demande   │
│ d'amitié                         │
├─────────────────────────────────┤
│ Vérifiez son profil et          │
│ acceptez ou refusez             │
├─────────────────────────────────┤
│ [ACCEPTER]  [REFUSER]           │
└─────────────────────────────────┘
```

---

### 3. ✅ FRIEND ACCEPTED / FRIEND REQUEST ACCEPTED
**Nom complète**: `NotificationType.friendAccepted` / `friendRequestAccepted`  
**Statut**: Normale  
**Canal Android**: `friends_channel`  
**Priorité**: `HIGH`

#### Objectif
Confirmer que la demande d'amitié a été acceptée.

#### Contenu Typique
```
Titre: "Ahmed a accepté votre demande d'ami"
Corps: "Vous pouvez maintenant vous envoyer des messages"
```

#### Vibration & Son
```
Vibration: [0, 200, 100, 200]
Son: Notification son
LED: Vert (#4CAF50)
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ ✅ Ahmed a accepté votre        │
│ demande d'amitié                │
├─────────────────────────────────┤
│ Vous pouvez maintenant vous     │
│ envoyer des messages            │
└─────────────────────────────────┘
```

---

### 4. 👫 NEW FOLLOWER
**Nom complète**: `NotificationType.newFollower`  
**Statut**: Normale  
**Canal Android**: `friends_channel`  
**Priorité**: `HIGH`

#### Objectif
Notifier qu'une personne suit l'utilisateur.

#### Contenu Typique
```
Titre: "Ahmed vous suit"
Corps: "Ahmed s'intéresse à votre profil"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 👤 Ahmed vous suit              │
├─────────────────────────────────┤
│ Ahmed s'intéresse à votre       │
│ profil                          │
├─────────────────────────────────┤
│ [SUIVRE EN RETOUR]  [VOIR]      │
└─────────────────────────────────┘
```

---

### 5. 👫 NEW MEMBER (GROUP)
**Nom complète**: `NotificationType.newMember`  
**Statut**: Normale  
**Canal Android**: `groups_channel`  
**Priorité**: `HIGH`

#### Objectif
Notifier qu'un nouveau membre a rejoint le groupe.

#### Contenu Typique
```
Titre: "Ahmed a rejoint le groupe"
Corps: "Nom du Groupe"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 👤 Ahmed a rejoint              │
│ Entrepreneurs Niamey             │
├─────────────────────────────────┤
│ Bienvenue au groupe!            │
├─────────────────────────────────┤
│ [VOIR LE GROUPE]                │
└─────────────────────────────────┘
```

---

### 6. 📬 GROUP INVITE
**Nom complète**: `NotificationType.groupInvite`  
**Statut**: Haute priorité  
**Canal Android**: `groups_channel`  
**Priorité**: `HIGH`

#### Objectif
Inviter l'utilisateur à rejoindre un groupe.

#### Contenu Typique
```
Titre: "Ahmed vous invite dans un groupe"
Corps: "Entrepreneurs Niamey"
```

#### Mode d'Affichage
- **Groupement**: Par groupe
- **Actions directes**: Accepter/Refuser

#### Vibration & Son
```
Vibration: [0, 200, 100, 200]
Son: Notification
LED: Violet (#9C27B0)
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 📬 Ahmed vous invite dans       │
│ un groupe                       │
├─────────────────────────────────┤
│ 🏢 Entrepreneurs Niamey         │
│ Description du groupe...        │
├─────────────────────────────────┤
│ [ACCEPTER]  [REFUSER]           │
└─────────────────────────────────┘
```

---

### 7. 🤝 GROUP JOIN REQUEST
**Nom complète**: `NotificationType.groupJoinRequest`  
**Statut**: Normale  
**Canal Android**: `groups_channel`  
**Priorité**: `HIGH`

#### Objectif
Notifier un admin qu'une personne demande à rejoindre le groupe.

#### Contenu Typique
```
Titre: "Ahmed demande à rejoindre Entrepreneurs Niamey"
Corps: "Approuver ou refuser cette demande"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 🤝 Ahmed demande à rejoindre    │
│ Entrepreneurs Niamey            │
├─────────────────────────────────┤
│ Approuver ou refuser cette      │
│ demande                         │
├─────────────────────────────────┤
│ [APPROUVER]  [REFUSER]          │
└─────────────────────────────────┘
```

---

### 8. ✔️ GROUP REQUEST APPROVED / REJECTED
**Nom complète**: `NotificationType.groupRequestApproved` / `groupRequestRejected`  
**Statut**: Normale  
**Canal Android**: `groups_channel`  
**Priorité**: `NORMAL`

#### Contenu Typique (APPROVED)
```
Titre: "Vous avez été approuvé pour Entrepreneurs Niamey"
Corps: "Vous pouvez maintenant rejoindre le groupe"
```

#### Contenu Typique (REJECTED)
```
Titre: "Votre demande a été refusée"
Corps: "Entrepreneurs Niamey"
```

#### Maquette d'Affichage (APPROVED)
```
┌─────────────────────────────────┐
│ ✅ Vous avez été approuvé pour  │
│ Entrepreneurs Niamey            │
├─────────────────────────────────┤
│ Vous pouvez maintenant          │
│ rejoindre le groupe             │
├─────────────────────────────────┤
│ [REJOINDRE]                     │
└─────────────────────────────────┘
```

#### Maquette d'Affichage (REJECTED)
```
┌─────────────────────────────────┐
│ ❌ Votre demande a été refusée  │
├─────────────────────────────────┤
│ Entrepreneurs Niamey            │
└─────────────────────────────────┘
```

---

### 9. 📅 EVENT REMINDER
**Nom complète**: `NotificationType.eventReminder`  
**Statut**: Haute priorité  
**Canal Android**: `event_reminders_channel`  
**Priorité**: `HIGH`

#### Objectif
Rappeler l'utilisateur d'un événement à venir (15 min / 1h / 1 jour avant).

#### Contenu Typique
```
Titre: "Rappel: Conférence entrepreneuriale"
Corps: "Commence dans 1 heure à Niamey"
```

#### Vibration & Son
```
Vibration: [0, 250, 100, 250]
Son: Notification
LED: Orange (#FF9800)
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 📅 Rappel: Conférence           │
│ entrepreneuriale                │
├─────────────────────────────────┤
│ 🕐 Commence dans 1 heure        │
│ 📍 Niamey                       │
│ 👥 23 participants              │
├─────────────────────────────────┤
│ [VOIR L'ÉVÉNEMENT]              │
└─────────────────────────────────┘
```

---

### 10. 📅 EVENT UPDATE
**Nom complète**: `NotificationType.eventUpdate`  
**Statut**: Normale  
**Canal Android**: `events_channel`  
**Priorité**: `NORMAL`

#### Objectif
Notifier d'un changement dans un événement auquel l'utilisateur participe.

#### Contenu Typique
```
Titre: "Conférence entrepreneuriale - Mise à jour"
Corps: "Le lieu a été changé. Voir les détails"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 📝 Mise à jour: Conférence      │
│ entrepreneuriale                │
├─────────────────────────────────┤
│ 🔔 Le lieu a été changé         │
│ 📍 Niamey - Centre culturel     │
├─────────────────────────────────┤
│ [VOIR LES DÉTAILS]              │
└─────────────────────────────────┘
```

---

### 11. 📍 LOCAL EVENT / NEARBY EVENT
**Nom complète**: `NotificationType.localEvent`  
**Statut**: Normale  
**Canal Android**: `events_channel`  
**Priorité**: `NORMAL`

#### Objectif
Notifier d'un événement à proximité de l'utilisateur.

#### Contenu Typique
```
Titre: "Festival local à proximité"
Corps: "Découvrez les événements près de vous"
```

#### Mode d'Affichage
- **Basé sur la géolocalisation**
- **Envoyé toutes les 2 heures** (configurable)
- **Distance**: Événements à moins de 50km

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 📍 Festival local à proximité   │
├─────────────────────────────────┤
│ 🎪 Festival de la Culture       │
│ 📍 2.5 km - Parc Central        │
│ 🕐 Samedi 18:00                 │
├─────────────────────────────────┤
│ [VOIR]  [INTÉRESSÉ]             │
└─────────────────────────────────┘
```

---

### 12. 👥 NEARBY MEMBER
**Nom complète**: `NotificationType.nearbyMember`  
**Statut**: Normale  
**Canal Android**: `proximity_channel`  
**Priorité**: `NORMAL`

#### Objectif
Notifier qu'une personne du réseau se trouve à proximité.

#### Contenu Typique
```
Titre: "Ahmed est à proximité"
Corps: "À 500m de vous"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 📍 Ahmed est à proximité         │
├─────────────────────────────────┤
│ À 500m de vous                  │
│ 📍 Rue Principale, Niamey       │
├─────────────────────────────────┤
│ [VOIR LE PROFIL]  [CONTACTER]   │
└─────────────────────────────────┘
```

---

### 13. 🚨 PROXIMITY ALERT
**Nom complète**: `NotificationType.proximityAlert`  
**Statut**: Urgente  
**Canal Android**: `proximity_channel`  
**Priorité**: `MAX`

#### Objectif
Alerte de sécurité: quelqu'un s'est rapproché rapidement.

#### Contenu Typique
```
Titre: "Alerte de sécurité"
Corps: "Quelqu'un s'est rapproché de vous rapidement"
```

#### Vibration & Son
```
Vibration: [0, 500, 200, 500, 200, 500] (long répétitif)
Son: Alerte urgente
LED: Rouge (#FF0000)
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 🚨 ALERTE DE SÉCURITÉ          │
├─────────────────────────────────┤
│ Quelqu'un s'est rapproché       │
│ très rapidement                 │
├─────────────────────────────────┤
│ [VOIR LA CARTE]  [SIGNALER]     │
└─────────────────────────────────┘
```

---

### 14. ✅ EVENT ATTENDANCE
**Nom complète**: `NotificationType.eventAttendance`  
**Statut**: Normale  
**Canal Android**: `events_channel`  
**Priorité**: `NORMAL`

#### Objectif
Notifier qu'une personne participera à un événement.

#### Contenu Typique
```
Titre: "Ahmed participera à Conférence entrepreneuriale"
Corps: "Rejoignez les 23 autres participants"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ ✅ Ahmed participera à          │
│ Conférence entrepreneuriale     │
├─────────────────────────────────┤
│ 👥 23 autres participants       │
├─────────────────────────────────┤
│ [VOIR LES PARTICIPANTS]         │
└─────────────────────────────────┘
```

---

## 🛍️ COMMANDES / MARKETPLACE

### 15. 📦 NEW ORDER
**Nom complète**: `NotificationType.newOrder`  
**Statut**: Haute priorité (Vendeur) / Normale (Acheteur)  
**Canal Android**: `orders_channel`  
**Priorité**: `HIGH`

#### Objectif (Vendeur)
Notifier qu'une nouvelle commande a été reçue.

#### Contenu Typique (Vendeur)
```
Titre: "Nouvelle commande de Ahmed"
Corps: "Montant: 50.000 FCFA - 2 articles"
```

#### Objectif (Acheteur)
Confirmer que la commande a été créée.

#### Contenu Typique (Acheteur)
```
Titre: "Commande confirmée"
Corps: "Commande #12345 - Total: 50.000 FCFA"
```

#### Vibration & Son
```
Vibration: [0, 250, 100, 250]
Son: Notification
LED: Teal (#009688)
```

#### Maquette d'Affichage (VENDEUR)
```
┌─────────────────────────────────┐
│ 📦 Nouvelle commande de Ahmed   │
├─────────────────────────────────┤
│ 🛍️ 2 articles                   │
│ 💰 50.000 FCFA                   │
│ 📍 Livraison: Niamey            │
├─────────────────────────────────┤
│ [VOIR LA COMMANDE]  [ACCEPTER]  │
└─────────────────────────────────┘
```

#### Maquette d'Affichage (ACHETEUR)
```
┌─────────────────────────────────┐
│ ✅ Commande confirmée           │
├─────────────────────────────────┤
│ 📦 #12345                       │
│ 💰 50.000 FCFA                   │
│ 🏪 Boutique Name                │
├─────────────────────────────────┤
│ [SUIVRE LA COMMANDE]            │
└─────────────────────────────────┘
```

---

### 16. ✅ ORDER PAID
**Nom complète**: `NotificationType.orderPaid`  
**Statut**: Haute priorité  
**Canal Android**: `orders_channel`  
**Priorité**: `HIGH`

#### Objectif
Confirmer que le paiement a été reçu.

#### Contenu Typique (Vendeur)
```
Titre: "Paiement reçu - Commande #12345"
Corps: "50.000 FCFA de Ahmed"
```

#### Contenu Typique (Acheteur)
```
Titre: "Paiement confirmé"
Corps: "Votre commande est en cours de préparation"
```

#### Maquette d'Affichage (VENDEUR)
```
┌─────────────────────────────────┐
│ ✅ Paiement reçu                │
├─────────────────────────────────┤
│ 📦 Commande #12345              │
│ 💰 50.000 FCFA                   │
│ 👤 Ahmed                        │
├─────────────────────────────────┤
│ [VOIR LA COMMANDE]              │
└─────────────────────────────────┘
```

---

### 17. 🚚 ORDER SHIPPED
**Nom complète**: `NotificationType.orderShipped`  
**Statut**: Normale  
**Canal Android**: `orders_channel`  
**Priorité**: `NORMAL`

#### Objectif
Notifier que la commande est en transit.

#### Contenu Typique
```
Titre: "Votre commande est expédiée"
Corps: "Suivi: #12345 - Livraison estimée: 2-3 jours"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ 🚚 Votre commande est expédiée  │
├─────────────────────────────────┤
│ 📦 #12345                       │
│ 🗓️ Livraison: 15-17 Juin       │
│ 📍 Niamey                       │
├─────────────────────────────────┤
│ [SUIVRE LE COLIS]               │
└─────────────────────────────────┘
```

---

### 18. 📦 ORDER DELIVERED
**Nom complète**: `NotificationType.orderDelivered`  
**Statut**: Normale  
**Canal Android**: `orders_channel`  
**Priorité**: `NORMAL`

#### Objectif
Confirmer que la commande a été livrée.

#### Contenu Typique
```
Titre: "Votre commande a été livrée"
Corps: "Commande #12345 - Veuillez confirmer la réception"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ ✅ Votre commande a été livrée  │
├─────────────────────────────────┤
│ 📦 #12345                       │
│ 📍 Niamey - Rue Principale      │
│ 🕐 14:32 - Aujourd'hui          │
├─────────────────────────────────┤
│ [CONFIRMER]  [SIGNALER UN PROBLÈME] │
└─────────────────────────────────┘
```

---

### 19. ❌ ORDER CANCELLED
**Nom complète**: `NotificationType.orderCancelled`  
**Statut**: Normale  
**Canal Android**: `orders_channel`  
**Priorité**: `NORMAL`

#### Objectif
Notifier que la commande a été annulée.

#### Contenu Typique
```
Titre: "Commande annulée"
Corps: "Commande #12345 - Remboursement en cours"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ ❌ Commande annulée            │
├─────────────────────────────────┤
│ 📦 #12345                       │
│ 💰 Remboursement: 50.000 FCFA   │
│ ⏱️ Délai: 3-5 jours            │
├─────────────────────────────────┤
│ [CONTACTER LE SUPPORT]          │
└─────────────────────────────────┘
```

---

### 20. ✅ ORDER COMPLETED
**Nom complète**: `NotificationType.orderCompleted`  
**Statut**: Normale  
**Canal Android**: `orders_channel`  
**Priorité**: `NORMAL`

#### Objectif
Confirmer que la commande est complètement traitée.

#### Contenu Typique
```
Titre: "Commande complète"
Corps: "Merci pour votre achat! Laissez un avis"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ ✅ Commande complète            │
├─────────────────────────────────┤
│ 📦 #12345                       │
│ 💰 50.000 FCFA                   │
│ 🏆 Merci pour votre achat!      │
├─────────────────────────────────┤
│ [LAISSER UN AVIS]  [VOIR D'AUTRES PRODUITS] │
└─────────────────────────────────┘
```

---

### 21. 💬 MENTION
**Nom complète**: `NotificationType.mention`  
**Statut**: Haute priorité  
**Canal Android**: `general_channel`  
**Priorité**: `HIGH`

#### Objectif
Notifier que l'utilisateur a été mentionné dans un post ou commentaire.

#### Contenu Typique
```
Titre: "Ahmed vous a mentionné"
Corps: "Consulte ce post intéressant pour les entrepreneurs"
```

#### Maquette d'Affichage
```
┌─────────────────────────────────┐
│ @ Ahmed vous a mentionné        │
├─────────────────────────────────┤
│ "Consulte ce post intéressant   │
│ pour les entrepreneurs..."      │
├─────────────────────────────────┤
│ [VOIR LE POST]                  │
└─────────────────────────────────┘
```

---

### 22. 🎙️ GENERAL (DEFAULT)
**Nom complète**: `NotificationType.general`  
**Statut**: Basse priorité  
**Canal Android**: `general_channel`  
**Priorité**: `NORMAL`

#### Objectif
Notifications générales et système.

#### Contenu Typique
```
Titre: "Information importante"
Corps: "Contenu du message système"
```

#### Vibration & Son
```
Vibration: [0, 250, 100, 250]
Son: Notification
LED: Couleur primaire
```

---

## Canaux Android

| # | Canal ID | Nom | Importance | Son | Vibration | LED | Badges | Type |
|---|----------|------|-----------|-----|-----------|-----|--------|------|
| 1 | `messages` | Messages | HIGH | ✅ | ✅ | ✅ Bleu | ✅ | Messages 1:1 & Groupe |
| 2 | `friends_channel` | Demandes d'amis | HIGH | ✅ | ✅ | ✅ Bleu | ✅ | Amitié |
| 3 | `groups_channel` | Groupes | HIGH | ✅ | ✅ | ✅ Violet | ✅ | Activités groupe |
| 4 | `events_channel` | Événements | NORMAL | ✅ | ✅ | ✅ Orange | ✅ | Événements |
| 5 | `event_reminders_channel` | Rappels d'événements | HIGH | ✅ | ✅ | - | - | Rappels événement |
| 6 | `audio_rooms_reminders_channel` | Salles audio | HIGH | ✅ | ✅ | - | - | Audio rooms |
| 7 | `podcast_reminders_channel` | Podcasts | NORMAL | ✅ | ✅ | - | - | Nouveaux épisodes |
| 8 | `transfer_reminders_channel` | Transferts | HIGH | ✅ | ✅ | - | - | Transferts programmés |
| 9 | `general_channel` | Général | NORMAL | ✅ | ✅ | - | - | Système |
| 10 | `proximity_channel` | Proximité | HIGH | ✅ | ✅ | - | - | Personnes à proximité |
| 11 | `orders_channel` | Commandes | HIGH | ✅ | ✅ | - | - | Marketplace |
| 12 | `calls_channel` | Appels | MAX | ✅ | ✅ | ✅ Primaire | ✅ | Appels entrants |
| 13 | `quick_reply_confirmation` | Réponses rapides | LOW | ❌ | ❌ | - | - | Confirmations |
| 14 | `background_location` | Position | LOW | ❌ | ❌ | - | ❌ | Service location |
| 15 | `support` | Support | HIGH | ✅ | ✅ | - | - | Support client |

---

## Modes d'Affichage

### 1. 🎯 MessagingStyle (WhatsApp-like)
**Utilisé pour**: Messages (type: `message`)

**Caractéristiques**:
- Affichage en thread/conversation
- Historique des 3-5 derniers messages
- Avatar de l'expéditeur
- Actions: Répondre, Marquer comme lu
- Groupement automatique par conversation
- Support E2EE

**Exemple**:
```
╔════════════════════════════════════╗
║ Jérôme M.                          ║
║ ┌─────────────────────────────┐    ║
║ │ Comment ça va?               │    ║
║ │ Tu fais quoi ce soir?        │    ║
║ │ J'aimerais te proposer...    │    ║
║ └─────────────────────────────┘    ║
║                                    ║
║ [↻ RÉPONDRE] [✓ MARQUER COMME LU] ║
╚════════════════════════════════════╝
```

---

### 2. 🖼️ BigPictureStyle (Images)
**Utilisé pour**: Messages avec images

**Caractéristiques**:
- Image de grande taille
- Titre et texte au-dessous
- Aperçu rapide de l'image
- Clique pour ouvrir

**Exemple**:
```
╔════════════════════════════════════╗
║ Marie                              ║
║ ┌─────────────────────────────┐    ║
║ │     [IMAGE GRANDE]          │    ║
║ │     (Miniature de photo)    │    ║
║ │                             │    ║
║ │ 📸 Photo                    │    ║
║ └─────────────────────────────┘    ║
║                                    ║
║ [↻ RÉPONDRE] [✓ MARQUER COMME LU] ║
╚════════════════════════════════════╝
```

---

### 3. 📋 Simple Style
**Utilisé pour**: Tous les autres types (amis, événements, commandes, etc.)

**Caractéristiques**:
- Titre + Corps
- Icône du type
- Actions contextuelles
- Badge de l'app

**Exemple**:
```
╔════════════════════════════════════╗
║ 📬 Ahmed vous invite dans un       ║
║ groupe                             ║
║ ┌─────────────────────────────┐    ║
║ │ 🏢 Entrepreneurs Niamey      │    ║
║ │ Description du groupe...    │    ║
║ └─────────────────────────────┘    ║
║                                    ║
║ [ACCEPTER]  [REFUSER]              ║
╚════════════════════════════════════╝
```

---

## Maquettes & Combinaisons

### COMBINAISON 1️⃣: Scénario Simple (1 Message)
```
╔═════════════════════════════════════════════╗
║  NOTIFICATION SIMPLE                        ║
├─────────────────────────────────────────────┤
║ 💬                                          ║
║ Jérôme M.                                  ║
║ ─────────────────────────────────────────   ║
║ Salut, comment ça va?                       ║
│ [Tap pour ouvrir]                           ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: messages
PRIORITÉ: HIGH
SON: Default
VIBRATION: Courte
LED: Couleur primaire
```

---

### COMBINAISON 2️⃣: Scénario Groupe (3+ Messages)
```
╔═════════════════════════════════════════════╗
║  NOTIFICATION EN GROUPE (MessagingStyle)   ║
├─────────────────────────────────────────────┤
║ Entrepreneurs Niamey                        ║
║ ─────────────────────────────────────────   ║
║ 👤 Jérôme:  Comment ça va?                 ║
║ 👤 Ahmed:   Ça va bien!                    ║
║ 👤 Marie:   À bientôt                      ║
║                                             ║
║ [↻ RÉPONDRE]  [✓ MARQUER COMME LU]         ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: messages
PRIORITÉ: HIGH
GROUPEMENT: Automatique par conversation
SON: Default
VIBRATION: Courte répétée
LED: Clignotant primaire
```

---

### COMBINAISON 3️⃣: Scénario Image/Vidéo
```
╔═════════════════════════════════════════════╗
║  NOTIFICATION IMAGE (BigPictureStyle)      ║
├─────────────────────────────────────────────┤
║ Marie                                       ║
║ ─────────────────────────────────────────   ║
║ ┌─────────────────────────────────────────┐ ║
║ │  📸 PHOTO / 🎥 VIDÉO (THUMBNAIL)       │ ║
║ │                                         │ ║
║ │  (Affichage miniature haute qualité)  │ ║
║ └─────────────────────────────────────────┘ ║
║                                             ║
║ [↻ RÉPONDRE]  [✓ MARQUER COMME LU]         ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: messages
STYLE: BigPictureStyle
```

---

### COMBINAISON 4️⃣: Scénario Appel Entrant (FULL SCREEN)
```
╔═════════════════════════════════════════════╗
║                                             ║
║        📞 APPEL ENTRANT                     ║
║                                             ║
║        Jérôme M.                            ║
║                                             ║
║        📱 [Écran complet native - CallKit]  ║
║                                             ║
║   [↻ REFUSER]  [✓ ACCEPTER]                ║
║                                             ║
╚═════════════════════════════════════════════╝

PLATFORM: Native (CallKit iOS / ConnectionService Android)
TYPE: Full Screen Notification
CANAL: calls_channel
PRIORITÉ: MAX
SON: Sonnerie système (répétitif)
VIBRATION: Longue répétée
AFFICHAGE: Sur écran verrouillé & foreground
```

---

### COMBINAISON 5️⃣: Demande d'Ami
```
╔═════════════════════════════════════════════╗
║  NOTIFICATION ACTION                        ║
├─────────────────────────────────────────────┤
║ 👤 Ahmed a envoyé une demande d'ami        ║
║ ─────────────────────────────────────────   ║
║ Vérifiez son profil et acceptez ou refusez ║
║                                             ║
║ [ACCEPTER]  [REFUSER]  [VOIR LE PROFIL]    ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: friends_channel
PRIORITÉ: HIGH
SON: Notification
VIBRATION: Medium [0,200,100,200]
LED: Bleu
ACTIONS: 3 boutons
```

---

### COMBINAISON 6️⃣: Notification Urgente (Alerte Sécurité)
```
╔═════════════════════════════════════════════╗
║  🚨 ALERTE URGENTE                          ║
├─────────────────────────────────────────────┤
║ Alerte de sécurité                          ║
║ ─────────────────────────────────────────   ║
║ Quelqu'un s'est rapproché très rapidement  ║
║                                             ║
║ [VOIR LA CARTE]  [SIGNALER]                 ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: proximity_channel
PRIORITÉ: MAX
SON: Alerte urgente (HIGH)
VIBRATION: Longue répétée [0,500,200,500,200,500]
LED: Rouge clignotant
AFFICHAGE: Tête-à-tête (headsup)
```

---

### COMBINAISON 7️⃣: Commande Marketplace
```
╔═════════════════════════════════════════════╗
║  NOTIFICATION COMMANDE                      ║
├─────────────────────────────────────────────┤
║ 📦 Nouvelle commande de Ahmed               ║
║ ─────────────────────────────────────────   ║
║ 🛍️  2 articles                              ║
║ 💰 50.000 FCFA                               ║
║ 📍 Livraison: Niamey                        ║
║                                             ║
║ [VOIR LA COMMANDE]  [ACCEPTER]              ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: orders_channel
PRIORITÉ: HIGH (vendeur)
ACTIONS: 2 boutons
SON: Notification
VIBRATION: [0,250,100,250]
```

---

### COMBINAISON 8️⃣: Rappel d'Événement
```
╔═════════════════════════════════════════════╗
║  NOTIFICATION RAPPEL                        ║
├─────────────────────────────────────────────┤
║ 📅 Rappel: Conférence entrepreneuriale     ║
║ ─────────────────────────────────────────   ║
║ 🕐 Commence dans 1 heure                    ║
║ 📍 Niamey                                   ║
║ 👥 23 participants                          ║
║                                             ║
║ [VOIR L'ÉVÉNEMENT]                          ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: event_reminders_channel
PRIORITÉ: HIGH
ACTIONS: 1 bouton
SON: Notification
VIBRATION: [0,250,100,250]
LED: Orange
```

---

### COMBINAISON 9️⃣: Commande Livrée
```
╔═════════════════════════════════════════════╗
║  NOTIFICATION STATUT                        ║
├─────────────────────────────────────────────┤
║ ✅ Votre commande a été livrée              ║
║ ─────────────────────────────────────────   ║
║ 📦 #12345                                   ║
║ 📍 Rue Principale, Niamey                   ║
║ 🕐 14:32 - Aujourd'hui                      ║
║                                             ║
║ [CONFIRMER]  [SIGNALER PROBLÈME]            ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: orders_channel
PRIORITÉ: NORMAL
ACTIONS: 2 boutons
```

---

### COMBINAISON 🔟: Requête Groupe (Admin)
```
╔═════════════════════════════════════════════╗
║  NOTIFICATION DÉCISION                      ║
├─────────────────────────────────────────────┤
║ 🤝 Ahmed demande à rejoindre                ║
║ Entrepreneurs Niamey                        ║
║ ─────────────────────────────────────────   ║
║ Approuver ou refuser cette demande          ║
║                                             ║
║ [APPROUVER]  [REFUSER]                      ║
╚═════════════════════════════════════════════╝

PLATFORM: Android (notification système)
CANAL: groups_channel
PRIORITÉ: HIGH
ACTIONS: 2 boutons avec confirmations
```

---

## Actions & Interactions

### Actions Disponibles par Type

| Type | Actions | Comportement |
|------|---------|-------------|
| **Message** | • Répondre rapide<br>• Marquer comme lu | App ouvre conversation / Marque en background |
| **Friend Request** | • Accepter<br>• Refuser<br>• Voir profil | Direct dans app |
| **Group Invite** | • Accepter<br>• Refuser | Direct dans app |
| **Event Reminder** | • Voir l'événement<br>• Rejoindre | Direct dans app |
| **Order** | • Accepter/Rejeter<br>• Voir détails | Direct dans app |
| **Generale** | • Ouvrir | Ouvre l'écran cible |

---

### Comportements de Groupement

```
Messages:
  └─ Groupé par: Conversation ID
     └─ Summary: "5 messages de 2 personnes"

Commandes:
  └─ Groupé par: Type d'ordre
     └─ Summary: "3 nouvelles commandes"

Demandes d'amis:
  └─ Groupé par: Type
     └─ Summary: "2 nouvelles demandes"

Événements:
  └─ Groupé par: Événement
     └─ Summary: "2 mises à jour d'événement"
```

---

## 📲 Badge Compteur

**Icône app**:
- Nombre total de notifications non lues
- Mis à jour en temps réel
- Sync multi-appareil
- Réinitialise après lecture/tap

---

## 🔔 Son & Vibration

### Sons Disponibles
- `default`: Son de notification système
- `notification`: Son de notification standard
- `alarm`: Son d'alerte

### Patterns de Vibration

| Type | Pattern |
|------|---------|
| **Message** | `[0, 100, 50, 100]` (Rapide) |
| **Amis** | `[0, 200, 100, 200]` (Medium) |
| **Événement** | `[0, 250, 100, 250]` (Medium) |
| **Appel** | `[0, 500, 200, 500, 200, 500]` (Long répétitif) |
| **Alerte** | `[0, 500, 200, 500]` (Urgence) |

---

## Heure Silencieuse (Quiet Hours)

**Configuration**:
- Plage horaire (ex: 22:00 - 08:00)
- Support pour minuit traversée

**Comportement**:
- ❌ Pas de son
- ❌ Pas de vibration
- ✅ Affichage visuel uniquement
- ⚠️ Appels entrants: Non silencieux (toujours alerte)

---

## Permissions & Préférences

### Demande Permission

```
Contexte: First app launch
Titre: "Autorisez les notifications?"
Corps: "Pour recevoir les mises à jour en temps réel"
[Autoriser]  [Pas maintenant]
```

### Préférences Utilisateur

- [ ] Notifications globales
- [ ] Aperçu des messages
- [ ] Son
- [ ] Vibration
- [ ] Heure silencieuse
- [ ] Notifications par type (messages, amis, groupes, etc.)

---

## Déchiffrement E2EE

**Pour messages chiffrés**:
1. Notification affichée avec: "🔒 Message chiffré"
2. Client déchiffre à la première lecture
3. Affichage du vrai contenu

**Fallback**:
```
Si déchiffrage impossible:
└─ Afficher: "📱 Message sécurisé"
```

---

## Multi-appareil Sync

**Scenario**: Notification lue sur Appareil A
```
1. User lit sur Appareil A
2. Notification syncée vers Firestore
3. Appareil B & C reçoivent dismiss signal
4. Notification supprimée des autres appareils
5. Badge mis à jour partout
```

---

## Résumé Graphique

```
┌─────────────────────────────────────────────┐
│          ARCHITECTURE NOTIFICATIONS         │
├─────────────────────────────────────────────┤
│                                             │
│  Cloud Functions (Triggers)                │
│  ├─ onMessageCreated                       │
│  ├─ sendNotificationOnCreate                │
│  ├─ onOrderUpdated                          │
│  └─ [+15 autres triggers]                   │
│         │                                   │
│         ▼                                   │
│  Firebase Cloud Messaging (FCM)             │
│         │                                   │
│         ▼                                   │
│  Local Notifications                       │
│  ├─ MessagingStyle (Messages)               │
│  ├─ BigPictureStyle (Images)                │
│  ├─ Simple Style (Autres)                   │
│  └─ CallKit Native (Appels)                 │
│         │                                   │
│         ▼                                   │
│  Affichage Utilisateur                     │
│  ├─ Écran fermé (Lock Screen)               │
│  ├─ Écran déverrouillé (Heads-up)           │
│  ├─ App foreground (Banner)                 │
│  └─ 15 Canaux Android                       │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Checklist Implémentation

Pour ajouter une nouvelle notification:

- [ ] Ajouter le type dans `NotificationType` enum
- [ ] Ajouter le label et icon dans `NotificationTypeExtension`
- [ ] Créer le canal Android si nécessaire
- [ ] Ajouter la Cloud Function trigger
- [ ] Définir le style d'affichage (MessagingStyle/BigPictureStyle/Simple)
- [ ] Ajouter les actions si applicable
- [ ] Configurer son/vibration/LED
- [ ] Tester sur Android + iOS
- [ ] Documenter dans ce guide
- [ ] Définir les conditions d'envoi

---

**Dernière mise à jour**: 2026-05-07  
**Statut**: Production  
**Toutes les notifications supportées et documentées** ✅
