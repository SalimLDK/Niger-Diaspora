# 🎨 Maquettes Détaillées des Push Notifications

## Index des Maquettes
1. [Messages](#messages)
2. [Amis](#amis)
3. [Groupes](#groupes)
4. [Événements](#événements)
5. [Commandes](#commandes)
6. [Appels](#appels)
7. [Proximité](#proximité)
8. [États de Commandes](#états-de-commandes)

---

## Messages

### 📱 Maquette 1.1: Message Simple (1:1)

**STATE: Notification arrivée**
```
ANDROID PHONE SCREEN (Edge to Edge)
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     09:34  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ ▶ 💬 Jérôme M.                  │   ┃
┃ │    Salut, comment ça va?        │   ┃
┃ │    ├─ [↻ RÉPONDRE]              │   ┃
┃ │    └─ [✓ LU]                    │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS:
├─ Icône: 💬 (bleu, couleur primaire)
├─ Titre: "Jérôme M."
├─ Corps: "Salut, comment ça va?"
├─ Actions: 2 boutons inline
├─ Vibration: Courte vibration
├─ Son: Notification default
├─ LED: Clignotement bleu (priorité HIGH)
├─ Groupement: Par conversation
├─ Dismiss: Swipe left
└─ Tap: Ouvre la conversation
```

---

### 📱 Maquette 1.2: Messages Multiples (Groupés - WhatsApp Style)

**STATE: 3 messages groupés**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     09:34  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 💬 Entrepreneurs Niamey         │   ┃
┃ │ 3 nouveaux messages             │   ┃
┃ │                                 │   ┃
┃ │ ┌──────────────────────────────┐ │   ┃
┃ │ │ 👤 Jérôme:                    │ │   ┃
┃ │ │    Salut les gars!           │ │   ┃
┃ │ │                              │ │   ┃
┃ │ │ 👤 Ahmed:                    │ │   ┃
┃ │ │    Ça va?                    │ │   ┃
┃ │ │                              │ │   ┃
┃ │ │ 👤 Marie:                    │ │   ┃
┃ │ │    À bientôt!                │ │   ┃
┃ │ └──────────────────────────────┘ │   ┃
┃ │                                 │   ┃
┃ │ ├─ [↻ RÉPONDRE]                │   ┃
┃ │ └─ [✓ LU]                      │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

STYLE: MessagingStyle (Android Native)
├─ Groupe de conversation
├─ Affichage des 3 derniers messages
├─ Avatars des expéditeurs
├─ Historique visible
├─ Badge de compteur: "3 nouveaux"
└─ Actions groupées: Reply & Mark as read
```

---

### 📱 Maquette 1.3: Message avec Image

**STATE: Image miniature affichée**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     09:34  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 💬 Marie                        │   ┃
┃ │                                 │   ┃
┃ │ ┌─────────────────────────────┐ │   ┃
┃ │ │         [IMAGE]             │ │   ┃
┃ │ │      [THUMBNAIL]            │ │   ┃
┃ │ │  (200x200 px approx)        │ │   ┃
┃ │ └─────────────────────────────┘ │   ┃
┃ │                                 │   ┃
┃ │ 📸 Photo                        │   ┃
┃ │                                 │   ┃
┃ │ ├─ [↻ RÉPONDRE]                │   ┃
┃ │ └─ [✓ LU]                      │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

STYLE: BigPictureStyle
├─ Image affichée en grand
├─ Titre: "Marie"
├─ Corps: "📸 Photo"
├─ Tap on image: Ouvre la photo en plein écran
└─ Tap on notification: Ouvre la conversation
```

---

### 📱 Maquette 1.4: Message Vocal

**STATE: Message vocal reçu**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     09:34  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 💬 Ahmed                        │   ┃
┃ │                                 │   ┃
┃ │ 🎙️ Message vocal                │   ┃
┃ │    [▶ 2:34]                    │   ┃
┃ │                                 │   ┃
┃ │ ├─ [↻ RÉPONDRE]                │   ┃
┃ │ └─ [✓ LU]                      │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS:
├─ Icône: 🎙️ 
├─ Durée visible: "2:34"
├─ Tap: Rejoue l'audio
└─ Actions: Répondre & Marquer comme lu
```

---

## Amis

### 👥 Maquette 2.1: Demande d'Ami

**STATE: Demande reçue**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     09:45  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 👤 Ahmed a envoyé une demande   │   ┃
┃ │ d'amitié                        │   ┃
┃ │                                 │   ┃
┃ │ Vérifiez son profil et acceptez │   ┃
┃ │ ou refusez                      │   ┃
┃ │                                 │   ┃
┃ │ [ACCEPTER]  [REFUSER]           │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CANAL: friends_channel (BLEU LED)
├─ Priorité: HIGH
├─ Vibration: [0, 200, 100, 200]
├─ Son: Notification
├─ Actions: 2 boutons
├─ Badge: 1
└─ Groupement: Par demandeur
```

---

### ✅ Maquette 2.2: Demande Acceptée

**STATE: Confirmation d'acceptation**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     09:46  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ ✅ Ahmed a accepté votre        │   ┃
┃ │ demande d'amitié                │   ┃
┃ │                                 │   ┃
┃ │ Vous pouvez maintenant vous     │   ┃
┃ │ envoyer des messages            │   ┃
┃ │                                 │   ┃
┃ │ [DISCUTER]  [VUE D'ENSEMBLE]    │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS:
├─ Icône: ✅ (vert)
├─ Priorité: NORMAL
├─ Auto-dismiss: Après 5 secondes
└─ Actions: Messaging direct
```

---

## Groupes

### 📬 Maquette 3.1: Invitation Groupe

**STATE: Invitation reçue**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     10:00  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 📬 Ahmed vous invite dans un    │   ┃
┃ │ groupe                          │   ┃
┃ │                                 │   ┃
┃ │ 🏢 Entrepreneurs Niamey         │   ┃
┃ │    Réseau des entrepreneurs     │   ┃
┃ │    de Niamey                    │   ┃
┃ │    👥 156 membres               │   ┃
┃ │                                 │   ┃
┃ │ [ACCEPTER]  [REFUSER]           │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CANAL: groups_channel (VIOLET LED)
├─ Priorité: HIGH
├─ Groupement: Par groupe
├─ Actions: 2 boutons (Accepter/Refuser)
└─ Tap: Affiche les détails du groupe
```

---

### 🤝 Maquette 3.2: Demande Adhésion Groupe (Admin)

**STATE: Admin voit une demande**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     10:15  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 🤝 Ahmed demande à rejoindre    │   ┃
┃ │ Entrepreneurs Niamey            │   ┃
┃ │                                 │   ┃
┃ │ Approuver ou refuser cette      │   ┃
┃ │ demande                         │   ┃
┃ │                                 │   ┃
┃ │ 👤 Ahmed B.                     │   ┃
┃ │    "Je suis entrepreneur"       │   ┃
┃ │    Message personnel...         │   ┃
┃ │                                 │   ┃
┃ │ [APPROUVER]  [REFUSER]          │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS:
├─ Affiche le message de présentation
├─ Actions: Approuver/Refuser
├─ Tap: Voir le profil complet
└─ Confirmation requise après action
```

---

## Événements

### 📅 Maquette 4.1: Rappel d'Événement (1 heure avant)

**STATE: Rappel proactif**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     09:00  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 📅 Rappel: Conférence           │   ┃
┃ │ entrepreneuriale                │   ┃
┃ │                                 │   ┃
┃ │ 🕐 Commence dans 1 heure        │   ┃
┃ │ 📍 Niamey - Centre culturel     │   ┃
┃ │ 👥 23 participants              │   ┃
┃ │                                 │   ┃
┃ │ [VOIR L'ÉVÉNEMENT]              │   ┃
┃ │ [JE NE PEUX PAS]                │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CANAL: event_reminders_channel (ORANGE LED)
├─ Priorité: HIGH
├─ Vibration: [0, 250, 100, 250]
├─ Programmé: 1h, 15min, 1 jour avant
├─ Actions: 2 boutons
└─ Groupement: Par événement
```

---

### 🗺️ Maquette 4.2: Événement Localisation Proche

**STATE: Événement local détecté**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     14:30  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 📍 Festival local à proximité   │   ┃
┃ │                                 │   ┃
┃ │ 🎪 Festival de la Culture       │   ┃
┃ │    Parc Central                 │   ┃
┃ │    📍 2.5 km de vous            │   ┃
┃ │    🕐 Samedi 18:00 - Dimanche   │   ┃
┃ │    👥 ~500 participants         │   ┃
┃ │                                 │   ┃
┃ │ [VOIR LA CARTE]  [INTÉRESSÉ]    │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS:
├─ Basé sur géolocalisation
├─ Distance: < 50km
├─ Frequency: Toutes les 2h max
├─ Priorité: NORMAL
└─ Actions: Voir/Marquer intéressé
```

---

## Commandes

### 🛍️ Maquette 5.1: Nouvelle Commande (Vendeur)

**STATE: Nouvelle commande reçue**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     12:30  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 📦 Nouvelle commande de Ahmed   │   ┃
┃ │                                 │   ┃
┃ │ 🛍️  2 articles                  │   ┃
┃ │    • Article 1 - 25.000 FCFA    │   ┃
┃ │    • Article 2 - 25.000 FCFA    │   ┃
┃ │                                 │   ┃
┃ │ 💰 Total: 50.000 FCFA           │   ┃
┃ │ 📍 Livraison: Niamey (rue X)    │   ┃
┃ │ 🕐 Demandée pour: Vendredi      │   ┃
┃ │                                 │   ┃
┃ │ [ACCEPTER]  [REFUSER]           │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CANAL: orders_channel (TEAL LED)
├─ Priorité: HIGH (vendeur)
├─ Vibration: [0, 250, 100, 250]
├─ Son: Notification
├─ Actions: 2 boutons
└─ Groupement: Par vendeur ou par jour
```

---

### ✅ Maquette 5.2: Paiement Confirmé

**STATE: Paiement reçu**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     12:45  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ ✅ Paiement reçu                │   ┃
┃ │                                 │   ┃
┃ │ 📦 Commande #12345              │   ┃
┃ │ 💰 50.000 FCFA                   │   ┃
┃ │ 👤 De: Ahmed                    │   ┃
┃ │ 📍 Livraison à: Rue Principale  │   ┃
┃ │                                 │   ┃
┃ │ [VUE D'ENSEMBLE]  [COMMENCER]   │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS (VENDEUR):
├─ Montant exact
├─ Informations de livraison
├─ Actions: Continuer/Accepter
└─ Priorité: HIGH
```

---

### 🚚 Maquette 5.3: Commande Expédiée

**STATE: En transit**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     14:00  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 🚚 Votre commande est expédiée  │   ┃
┃ │                                 │   ┃
┃ │ 📦 #12345                       │   ┃
┃ │ 📦 Statut: En livraison         │   ┃
┃ │ 🗓️ Livraison estimée:          │   ┃
┃ │    15-17 Juin                  │   ┃
┃ │ 📍 Destinataire: Niamey         │   ┃
┃ │ 👤 Livreur: Ali                 │   ┃
┃ │ 📱 +227 XXX XX XX               │   ┃
┃ │                                 │   ┃
┃ │ [SUIVRE LE COLIS]               │   ┃
┃ │ [CONTACTER LE LIVREUR]          │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS:
├─ Numéro de suivi
├─ Estimé de livraison
├─ Contact livreur
├─ Actions: Suivi/Contact
└─ Priorité: NORMAL
```

---

### 📦 Maquette 5.4: Commande Livrée

**STATE: Livraison confirmée**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     15:30  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ ✅ Votre commande a été livrée  │   ┃
┃ │                                 │   ┃
┃ │ 📦 #12345                       │   ┃
┃ │ 📍 Rue Principale, Niamey       │   ┃
┃ │ 🕐 14:32 - Aujourd'hui          │   ┃
┃ │ 👤 Réceptionnaire: Gardien      │   ┃
┃ │                                 │   ┃
┃ │ Veuillez confirmer la réception │   ┃
┃ │                                 │   ┃
┃ │ [CONFIRMER]  [SIGNALER]         │   ┃
┃ │ [LAISSER UN AVIS]               │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS:
├─ Lieu exact de livraison
├─ Heure et date
├─ Réceptionnaire
├─ Actions: Confirmer/Signaler/Avis
└─ Priorité: NORMAL
```

---

## Appels

### 📞 Maquette 6.1: Appel Entrant (FULL SCREEN)

**STATE: Call Kit Native Display**
```
iOS SCREEN (Full Screen - Lock Screen)
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                       ┃
┃                                       ┃
┃                 📱                     ┃
┃            APPEL ENTRANT              ┃
┃                                       ┃
┃            Jérôme M.                 ┃
┃                                       ┃
┃        [Photo/Avatar - 150x150]       ┃
┃                                       ┃
┃                                       ┃
┃      [Refuser ❌]   [Accepter ✓]     ┃
┃                                       ┃
┃                                       ┃
┃      (Sonnerie continue)              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

ANDROID SCREEN (Full Screen)
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                       ┃
┃        APPEL VIDÉO ENTRANT           ┃
┃                                       ┃
┃              Jérôme M.               ┃
┃                                       ┃
┃        [Avatar - Photo GDE]           ┃
┃                                       ┃
┃        Appel vidéo en cours...       ┃
┃                                       ┃
┃      [Refuser ❌]   [Accepter ✓]     ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CARACTÉRISTIQUES:
├─ Écran verrouillé: Affichage complet (CallKit)
├─ App foreground: Affichage in-app
├─ Sonnerie: Long répétitif (45s timeout)
├─ Vibration: [0, 500, 200, 500, 200, 500]
├─ Type: Audio ou Vidéo
├─ Actions: Refuser/Accepter
└─ Important: Non-silencieux (ignore Quiet Hours)
```

---

### 📱 Maquette 6.2: Appel Manqué (Missed Call)

**STATE: Après 45 secondes sans réponse**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     09:34  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 📞 Appel manqué de Jérôme M.    │   ┃
┃ │                                 │   ┃
┃ │ 🕐 09:32 - Il y a 2 min         │   ┃
┃ │                                 │   ┃
┃ │ [RAPPELER]  [VUE D'ENSEMBLE]    │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

DÉTAILS:
├─ Titre: "Appel manqué"
├─ Corps: Nom + heure
├─ Actions: Rappeler/Voir
├─ Priorité: HIGH
└─ Groupement: Par personne (si multiples)
```

---

## Proximité

### 🗺️ Maquette 7.1: Personne à Proximité

**STATE: Personne détectée à proximité**
```
ANDROID PHONE SCREEN
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     16:00  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 📍 Ahmed est à proximité         │   ┃
┃ │                                 │   ┃
┃ │ À 500m de vous                  │   ┃
┃ │ 📍 Rue Principale, Niamey       │   ┃
┃ │                                 │   ┃
┃ │ Dernier vu: À l'instant         │   ┃
┃ │                                 │   ┃
┃ │ [VOIR LE PROFIL]  [CONTACTER]   │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CANAL: proximity_channel
├─ Priorité: NORMAL
├─ Distance: < 1km
├─ Frequency: Toutes les 5-10 min
├─ Actions: Voir/Contacter
└─ Groupement: Non groupé
```

---

### 🚨 Maquette 7.2: Alerte de Sécurité (URGENT)

**STATE: Rapprochement soudain**
```
ANDROID PHONE SCREEN (HEADS-UP)
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃     16:15  🔋 📶                      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                       ┃
┃ ┌─────────────────────────────────┐   ┃
┃ │ 🚨 ALERTE DE SÉCURITÉ          │   ┃
┃ │                                 │   ┃
┃ │ Quelqu'un s'est rapproché       │   ┃
┃ │ très rapidement                 │   ┃
┃ │                                 │   ┃
┃ │ Distance: 100m (réduite de 2km  │   ┃
┃ │ en 5 minutes)                   │   ┃
┃ │                                 │   ┃
┃ │ [VOIR LA CARTE]  [SIGNALER]     │   ┃
┃ │ [PARTAGER MA POSITION]          │   ┃
┃ │                                 │   ┃
┃ │ ❌ ━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ┃
┃ └─────────────────────────────────┘   ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

CARACTÉRISTIQUES:
├─ Affichage: Heads-up (reste visible)
├─ Son: Alerte urgente (LOUD)
├─ Vibration: Long répétitif
├─ LED: ROUGE clignotant
├─ Priorité: MAX
├─ Actions: 3 boutons (Map/Report/Share)
└─ Important: Bypass Quiet Hours
```

---

## États de Commandes

### Tableau Récapitulatif des États

```
STATE PROGRESSION:
1. NEW ORDER
   ├─ Vendeur: "Nouvelle commande de Ahmed"
   └─ Acheteur: "Commande confirmée"
        ▼
2. PAID
   ├─ Vendeur: "Paiement reçu 50.000 FCFA"
   └─ Acheteur: "Paiement confirmé"
        ▼
3. PREPARED
   ├─ Vendeur: "Commande en préparation"
   └─ Acheteur: "Votre commande est prêt"
        ▼
4. SHIPPED
   ├─ Vendeur: "Commande expédiée"
   └─ Acheteur: "En livraison - Suivi: #12345"
        ▼
5. DELIVERED
   ├─ Vendeur: "Commande livrée à Ahmed"
   └─ Acheteur: "Confirmez réception"
        ▼
6. COMPLETED
   ├─ Vendeur: "Transaction complètée"
   └─ Acheteur: "Laisser un avis"
        ▼
CANCELLED (at any state)
   ├─ Vendeur: "Commande annulée"
   └─ Acheteur: "Remboursement en cours"
```

---

## Légende Symboles

```
📱 = Affichage sur téléphone
🔋 = État batterie
📶 = Signal Wi-Fi/Réseau
💬 = Message
👤 = Profil utilisateur
📍 = Localisation
🕐 = Heure/Temps
👥 = Groupe/Participants
🛍️ = Article/Produit
💰 = Argent/Prix
🚚 = Livraison
📦 = Colis/Commande
📞 = Appel
✅ = Confirmé/Positif
❌ = Bouton dismiss
🚨 = Alerte/Urgence
[  ] = Bouton d'action
├─  = Propriété/Détail
▼  = Suite logique
```

---

**Créé**: 2026-05-07  
**Statut**: ✅ Complet  
**Maquettes**: 15 + Variants
