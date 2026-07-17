# Plan d'implémentation : Appels de groupe avec E2EE et Simulcast

## Architecture cible

### 3 modes de communication :

1. **Appels 1:1** (code actuel)
   - WebRTC peer-to-peer direct
   - Votre coturn comme relais TURN
   - E2EE via `flutter_webrtc` FrameCryptor

2. **Appels de groupe Mesh (2-4 participants)**
   - Chaque participant connecté à tous les autres
   - Réutilise votre WebRTCService avec plusieurs RTCPeerConnection
   - E2EE avec clé partagée via Firebase (chiffrée)
   - Coturn pour le relais

3. **Appels de groupe SFU (5+ participants)**
   - LiveKit server sur votre VPS
   - SDK `livekit_client` Flutter
   - E2EE intégré dans LiveKit
   - Simulcast natif (3 couches de qualité)
   - Coturn peut servir les clients bloqués

---

## Fichiers à créer/modifier

### 1. Nouveaux fichiers - Core Services

- `lib/core/services/group_call_service.dart` - Service mesh pour appels de groupe
- `lib/core/services/livekit_service.dart` - Service LiveKit pour grands groupes
- `lib/core/services/e2ee_service.dart` - Service E2EE (clés, chiffrement)
- `lib/core/services/call_quality_service.dart` - Gestion qualité/simulcast

### 2. Nouveaux fichiers - Group Calls Feature

**Domain**
- `lib/features/group_calls/domain/entities/group_call_entity.dart`
- `lib/features/group_calls/domain/entities/group_participant_entity.dart`
- `lib/features/group_calls/domain/repositories/group_call_repository.dart`

**Data**
- `lib/features/group_calls/data/models/group_call_model.dart`
- `lib/features/group_calls/data/models/group_participant_model.dart`
- `lib/features/group_calls/data/datasources/group_call_remote_datasource.dart`
- `lib/features/group_calls/data/repositories/group_call_repository_impl.dart`

**Presentation**
- `lib/features/group_calls/presentation/providers/group_call_provider.dart`
- `lib/features/group_calls/presentation/screens/group_call_screen.dart`
- `lib/features/group_calls/presentation/widgets/participant_grid.dart`
- `lib/features/group_calls/presentation/widgets/participant_tile.dart`
- `lib/features/group_calls/presentation/widgets/group_call_controls.dart`
- `lib/features/group_calls/presentation/widgets/e2ee_indicator.dart`
- `lib/features/group_calls/presentation/widgets/quality_selector.dart`

### 3. Fichiers à modifier

- `pubspec.yaml` - Ajouter `livekit_client`, `cryptography`
- `lib/core/router/app_router.dart` - Routes group calls
- `lib/core/router/routes/calls_routes.dart` - Nouvelles routes
- `database.rules.json` - Rules pour `group_calls`
- `firestore.rules` - Collection `group_calls`
- `lib/l10n/app_en.arb` et `app_fr.arb` - Nouvelles traductions

---

## Implémentation détaillée

### Phase 1: E2EE pour appels 1:1 existants

Ajouter le chiffrement de bout en bout aux appels actuels via `flutter_webrtc` FrameCryptor :

```dart
// e2ee_service.dart
class E2EEService {
  FrameCryptor? _frameCryptor;

  Future<void> enableE2EE(RTCPeerConnection pc, String sharedKey) async {
    final keyProvider = await FrameCryptorFactory.instance.createDefaultKeyProvider(...);
    await keyProvider.setKey(key: sharedKey);

    _frameCryptor = await FrameCryptorFactory.instance.createFrameCryptorForSender(
      participantId: participantId,
      sender: sender,
      algorithm: Algorithm.kAesGcm,
      keyProvider: keyProvider,
    );
    await _frameCryptor?.setEnabled(true);
  }
}
```

### Phase 2: Appels de groupe Mesh (2-4 participants)

```dart
// group_call_service.dart
class GroupCallService {
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};

  // Pour chaque participant, créer une RTCPeerConnection
  Future<void> connectToParticipant(String participantId, String callId) async {
    final pc = await createPeerConnection(IceServerConfig.iceServers);
    _peerConnections[participantId] = pc;

    // Ajouter notre stream local
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // E2EE pour cette connexion
    await _e2eeService.enableE2EE(pc, _groupSharedKey);

    // Signaling via Firebase RTDB
    _setupSignaling(participantId, callId);
  }
}
```

### Phase 3: LiveKit pour grands groupes (5+)

```dart
// livekit_service.dart
class LiveKitService {
  Room? _room;

  Future<void> connectToRoom({
    required String roomName,
    required String token,
    bool enableSimulcast = true,
    bool enableE2EE = true,
  }) async {
    final roomOptions = RoomOptions(
      adaptiveStream: true,
      dynacast: true, // Simulcast automatique
      e2ee: enableE2EE ? E2EEOptions(keyProvider: _keyProvider) : null,
      defaultVideoPublishOptions: VideoPublishOptions(
        simulcast: enableSimulcast,
        videoSimulcastLayers: [
          VideoParameters.presetH180, // Low quality
          VideoParameters.presetH360, // Medium
          VideoParameters.presetH720, // High
        ],
      ),
    );

    _room = await LiveKitClient.connect(
      'wss://livekit.diasponiger.com',
      token,
      roomOptions: roomOptions,
    );
  }
}
```

### Phase 4: Backend LiveKit (Cloud Functions)

```javascript
// functions/index.js - Nouveau endpoint pour tokens LiveKit
exports.getLiveKitToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated');

  const { roomName, participantName } = data;
  const apiKey = functions.config().livekit.api_key;
  const apiSecret = functions.config().livekit.api_secret;

  const at = new AccessToken(apiKey, apiSecret, {
    identity: context.auth.uid,
    name: participantName,
  });

  at.addGrant({
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
  });

  return { token: at.toJwt() };
});
```

---

## Configuration serveur LiveKit

Sur votre VPS Hostinger (72.62.212.223), installer LiveKit :

```bash
# Installation LiveKit
curl -sSL https://get.livekit.io | bash

# Configuration /etc/livekit/livekit.yaml
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: true

turn:
  enabled: true
  domain: turn.diasponiger.com
  tls_port: 5349
  udp_port: 3478
  external_tls: true

keys:
  API_KEY: YOUR_GENERATED_KEY

# Ou utiliser votre coturn existant :
turn:
  enabled: false  # Désactiver le TURN intégré

rtc:
  turn_servers:
    - host: turn.diasponiger.com
      username: diasponiger
      credential: [ANCIEN-SECRET-ROTE-2026-07-16]
      protocol: udp
      port: 3478
```

---

## Firebase Rules à ajouter

### database.rules.json
```json
"group_calls": {
  "$callId": {
    ".read": "auth != null",
    ".write": "auth != null",
    "participants": {
      "$participantId": {
        ".validate": "newData.hasChildren(['joinedAt'])"
      }
    },
    "signaling": {
      "$fromId": {
        "$toId": {
          ".validate": "newData.hasChildren(['type'])"
        }
      }
    },
    "e2ee_key": {
      ".read": "data.parent().child('participants').child(auth.uid).exists()",
      ".write": "!data.exists() || data.parent().child('hostId').val() === auth.uid"
    }
  }
}
```

### firestore.rules
```javascript
match /group_calls/{callId} {
  allow read: if request.auth != null &&
    (request.auth.uid in resource.data.participantIds ||
     request.auth.uid == resource.data.hostId);
  allow create: if request.auth != null;
  allow update: if request.auth != null &&
    request.auth.uid in resource.data.participantIds;
  allow delete: if request.auth != null &&
    request.auth.uid == resource.data.hostId;
}
```

---

## Dépendances à ajouter

```yaml
# pubspec.yaml
dependencies:
  # LiveKit pour SFU (groupes 5+)
  livekit_client: ^2.3.0

  # Crypto pour E2EE
  cryptography: ^2.7.0
```

---

## Sélection automatique du mode

```dart
// Dans group_call_provider.dart
enum GroupCallMode { mesh, sfu }

GroupCallMode selectCallMode(int participantCount) {
  // Mesh pour 2-4 personnes (inclut l'initiateur)
  if (participantCount <= 4) return GroupCallMode.mesh;
  // SFU pour 5+ personnes
  return GroupCallMode.sfu;
}
```

---

## Ordre d'implémentation

1. **E2EE Service** - Base pour tout le chiffrement
2. **Group Call Entity/Model** - Structure de données
3. **Firebase Rules** - Permettre le signaling
4. **Group Call Service (Mesh)** - Appels 2-4 personnes
5. **Group Call Provider** - État Riverpod
6. **Group Call Screen** - UI de base
7. **LiveKit Service** - Intégration LiveKit
8. **Backend LiveKit token** - Cloud Function
9. **Sélection automatique mesh/SFU** - Logique de bascule
10. **Simulcast UI** - Sélecteur de qualité

---

## Tests requis

- E2EE : Vérifier que les frames sont chiffrés (Wireshark)
- Mesh : Appel à 3-4 personnes, vérifier toutes les connexions
- SFU : Appel à 5+ personnes via LiveKit
- Simulcast : Vérifier les 3 couches dans le dashboard LiveKit
- Transition : Appel qui passe de 4 à 5 participants (mesh → SFU)
