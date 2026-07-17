# Flux des Appels - Diaspo Niger

## Architecture Globale

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Appelant (A)  │     │    Firebase     │     │   Appelé (B)    │
│                 │     │  Firestore/RTDB │     │                 │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │    WebRTC P2P         │                       │
         │◄─────────────────────────────────────────────►│
         │   (Audio/Video)       │                       │
```

## Composants Impliqués

| Composant | Fichier | Rôle |
|-----------|---------|------|
| CallProvider | `call_provider.dart` | État et logique des appels |
| WebRTCService | `webrtc_service.dart` | Connexion peer-to-peer |
| NativeCallService | `native_call_service.dart` | UI native (CallKit/ConnectionService) |
| CallScreen | `call_screen.dart` | Interface utilisateur |
| IncomingCallOverlay | `incoming_call_overlay.dart` | Overlay appel entrant |
| RingtoneService | `ringtone_service.dart` | Sonneries et vibrations |
| CallRemoteDataSource | `call_remote_datasource.dart` | Firestore/RTDB |

---

## 1. Initiation d'un Appel (Appelant A)

```
┌──────────────────────────────────────────────────────────────────┐
│                    INITIATION DE L'APPEL                         │
└──────────────────────────────────────────────────────────────────┘

Utilisateur clique "Appeler"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Vérification blocage                 │
│    checkBlockStatus(userId, calleeId)   │
│    - A a bloqué B ? → Erreur            │
│    - B a bloqué A ? → Erreur            │
└─────────────────────────────────────────┘
         │ OK
         ▼
┌─────────────────────────────────────────┐
│ 2. Vérification disponibilité           │
│    isUserBusy(calleeId)                 │
│    - B déjà en appel ? → Status "busy"  │
└─────────────────────────────────────────┘
         │ OK
         ▼
┌─────────────────────────────────────────┐
│ 3. Création document Firestore          │
│    Collection: calls                     │
│    {                                     │
│      callerId, calleeId,                │
│      callerName, calleeName,            │
│      type: audio/video,                 │
│      status: "ringing",                 │
│      createdAt: timestamp               │
│    }                                     │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 4. Affichage UI native                  │
│    NativeCallService.showOutgoingCall() │
│    - Android: ConnectionService         │
│    - iOS: CallKit                       │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 5. Initialisation WebRTC                │
│    - getUserMedia (caméra/micro)        │
│    - createPeerConnection               │
│    - createOffer                        │
│    - Envoi offer via RTDB               │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 6. Démarrage timeout (45s)              │
│    Si pas de réponse → status "missed"  │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 7. Navigation vers CallScreen           │
│    context.push('/calls/${call.id}')    │
└─────────────────────────────────────────┘
```

---

## 2. Réception d'un Appel (Appelé B)

```
┌──────────────────────────────────────────────────────────────────┐
│                    RÉCEPTION DE L'APPEL                          │
└──────────────────────────────────────────────────────────────────┘

Firebase envoie notification FCM
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. NotificationService reçoit message   │
│    type: "incoming_call"                │
│    data: callId, callerName, isVideo    │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 2. Affichage UI native                  │
│    NativeCallService.showIncomingCall() │
│    - Sonnerie + vibration               │
│    - Boutons Accepter/Refuser           │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 3. incomingCallProvider détecte         │
│    Stream Firestore avec status         │
│    whereIn: ['ringing'] + calleeId=me   │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 4. Affichage IncomingCallOverlay        │
│    - Photo appelant                     │
│    - Nom appelant                       │
│    - Boutons: Accepter / Refuser        │
│    - Option: Accepter audio seulement   │
└─────────────────────────────────────────┘
```

---

## 3. Acceptation de l'Appel

```
┌──────────────────────────────────────────────────────────────────┐
│                    ACCEPTATION DE L'APPEL                        │
└──────────────────────────────────────────────────────────────────┘

Utilisateur B clique "Accepter"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Mise à jour Firestore                │
│    status: "ringing" → "connecting"     │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 2. Arrêt sonnerie                       │
│    RingtoneService.stopRinging()        │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 3. Initialisation WebRTC (B)            │
│    - getUserMedia                       │
│    - createPeerConnection               │
│    - Récupération offer de RTDB         │
│    - setRemoteDescription(offer)        │
│    - createAnswer                       │
│    - Envoi answer via RTDB              │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 4. Échange ICE candidates               │
│    A ←──── RTDB ────► B                 │
│    (via Firebase Realtime Database)     │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 5. Connexion P2P établie                │
│    status: "connecting" → "connected"   │
│    connectedAt: timestamp               │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 6. Navigation vers CallScreen           │
│    Affichage vidéo locale + distante    │
└─────────────────────────────────────────┘
```

---

## 4. Refus de l'Appel

```
┌──────────────────────────────────────────────────────────────────┐
│                      REFUS DE L'APPEL                            │
└──────────────────────────────────────────────────────────────────┘

Utilisateur B clique "Refuser"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Mise à jour Firestore                │
│    status: "ringing" → "declined"       │
│    endedAt: timestamp                   │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 2. Arrêt sonnerie (B)                   │
│    Fermeture IncomingCallOverlay        │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 3. Appelant (A) détecte changement      │
│    callByIdProvider écoute le document  │
│    status == "declined"                 │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 4. Affichage message (A)                │
│    "Appel refusé"                       │
│    Fermeture CallScreen                 │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 5. Création message d'appel             │
│    Dans la conversation A-B             │
│    type: "call", status: "declined"     │
└─────────────────────────────────────────┘
```

---

## 5. Fin d'Appel

```
┌──────────────────────────────────────────────────────────────────┐
│                       FIN DE L'APPEL                             │
└──────────────────────────────────────────────────────────────────┘

Utilisateur (A ou B) clique "Raccrocher"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Mise à jour Firestore                │
│    status: "connected" → "ended"        │
│    endedAt: timestamp                   │
│    duration: calculée                   │
│    endedBy: userId                      │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 2. Cleanup WebRTC                       │
│    - Fermer localStream                 │
│    - Fermer remoteStream                │
│    - Fermer peerConnection              │
│    - Supprimer données RTDB             │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 3. Autre partie détecte fin             │
│    callByIdProvider: status == "ended"  │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 4. Fermeture CallScreen                 │
│    - Désactiver wakelock                │
│    - Désactiver PiP                     │
│    - Désactiver proximity sensor        │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 5. Création message d'appel             │
│    type: "call"                         │
│    duration: "2:34"                     │
│    status: "ended"                      │
└─────────────────────────────────────────┘
```

---

## 6. Signaling WebRTC via Firebase

```
┌──────────────────────────────────────────────────────────────────┐
│                    SIGNALING WEBRTC                              │
└──────────────────────────────────────────────────────────────────┘

Firebase Realtime Database
└── calls
    └── {callId}
        ├── offer          ← Créé par A (SDP offer)
        ├── answer         ← Créé par B (SDP answer)
        ├── callerCandidates
        │   └── {candidateId}  ← ICE candidates de A
        └── calleeCandidates
            └── {candidateId}  ← ICE candidates de B

Séquence:
1. A crée offer → écrit dans RTDB
2. B écoute offer → reçoit
3. B crée answer → écrit dans RTDB
4. A écoute answer → reçoit
5. A & B échangent ICE candidates via RTDB
6. Connexion P2P établie
```

---

## 7. États de l'Appel (CallStatus)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MACHINE D'ÉTATS                                    │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────┐
                              │ ringing │ ◄─── État initial
                              └────┬────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           │                       │                       │
           ▼                       ▼                       ▼
    ┌────────────┐         ┌────────────┐          ┌────────────┐
    │  declined  │         │ connecting │          │   missed   │
    └────────────┘         └─────┬──────┘          └────────────┘
         │                       │                       │
         │                       ▼                       │
         │                ┌────────────┐                 │
         │                │ connected  │                 │
         │                └─────┬──────┘                 │
         │                      │                        │
         │         ┌────────────┼────────────┐          │
         │         │            │            │          │
         │         ▼            ▼            ▼          │
         │  ┌────────────┐ ┌────────┐ ┌────────────┐    │
         │  │reconnecting│ │ onHold │ │   error    │    │
         │  └─────┬──────┘ └───┬────┘ └─────┬──────┘    │
         │        │            │            │           │
         │        └────────────┼────────────┘           │
         │                     │                        │
         │                     ▼                        │
         │              ┌────────────┐                  │
         └─────────────►│   ended    │◄─────────────────┘
                        └────────────┘

États terminaux: ended, declined, missed, error, busy
```

---

## 8. Timeouts et Guards

| Timeout | Durée | Action |
|---------|-------|--------|
| Ringing | 45s | Marquer "missed" |
| Connection | 15s | Erreur "connection_timeout" |
| Remote Stream | 10s | Warning utilisateur |
| ICE Gathering | 30s | Continuer sans attendre |

| Guard | Protection |
|-------|------------|
| `isInitiating` | Empêche appels multiples simultanés |
| `isEnding` | Empêche double raccrochage |
| `_isCallInProgress` | WebRTC: un seul appel actif |
| Block check | Empêche appels entre utilisateurs bloqués |
| Busy check | Empêche appels vers utilisateur occupé |

---

## 9. Fichiers Clés

```
lib/
├── features/calls/
│   ├── data/
│   │   ├── datasources/
│   │   │   └── call_remote_datasource.dart    # Firestore/RTDB
│   │   ├── models/
│   │   │   └── call_model.dart                # Modèle Firestore
│   │   └── repositories/
│   │       └── call_repository_impl.dart      # Implémentation
│   ├── domain/
│   │   ├── entities/
│   │   │   └── call_entity.dart               # Entité + CallStatus
│   │   └── repositories/
│   │       └── call_repository.dart           # Interface
│   └── presentation/
│       ├── providers/
│       │   └── call_provider.dart             # État Riverpod
│       ├── screens/
│       │   ├── call_screen.dart               # UI appel en cours
│       │   └── call_history_screen.dart       # Historique
│       └── widgets/
│           ├── active_call_indicator.dart     # Banner vert
│           └── incoming_call_overlay.dart     # Overlay entrant
│
├── core/services/
│   ├── webrtc_service.dart                    # WebRTC P2P
│   ├── native_call_service.dart               # CallKit/ConnectionService
│   ├── ringtone_service.dart                  # Sonneries
│   ├── proximity_service.dart                 # Capteur proximité
│   └── pip_service.dart                       # Picture-in-Picture
│
└── app.dart                                   # Overlay management
```

---

## 10. Diagramme de Séquence Complet

```
    Appelant (A)              Firebase                  Appelé (B)
         │                       │                          │
         │──── checkBlock() ────►│                          │
         │◄─── OK ──────────────│                          │
         │                       │                          │
         │──── createCall() ────►│                          │
         │     status=ringing    │──── FCM notification ───►│
         │                       │                          │
         │◄─── callId ──────────│                          │
         │                       │                          │
         │──── createOffer() ───►│ (RTDB)                   │
         │                       │                          │
         │      🔔 45s timeout   │      🔔 Sonnerie         │
         │                       │                          │
         │                       │◄─── watchCall() ────────│
         │                       │                          │
         │                       │     [User accepts]       │
         │                       │                          │
         │                       │◄─── status=connecting ──│
         │◄─── status change ───│                          │
         │                       │                          │
         │                       │◄─── createAnswer() ─────│
         │◄─── answer (RTDB) ───│                          │
         │                       │                          │
         │◄──── ICE candidates ────────────────────────────►│
         │                       │                          │
         │◄════════════════ P2P Connected ════════════════►│
         │                       │                          │
         │──── status=connected ►│                          │
         │                       │                          │
         │       📞 APPEL EN COURS 📞                       │
         │                       │                          │
         │     [User hangs up]   │                          │
         │                       │                          │
         │──── status=ended ────►│                          │
         │──── cleanup() ───────►│                          │
         │                       │──── status change ──────►│
         │                       │                          │
         │                       │◄─── cleanup() ──────────│
         │                       │                          │
         ▼                       ▼                          ▼
```

---

## 11. Exemples de Code

### 11.1 Initier un Appel

```dart
// Depuis un écran de conversation ou profil
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CallButton extends ConsumerWidget {
  final String targetUserId;
  final String targetDisplayName;
  final String? targetPhotoUrl;
  final bool isVideo;

  const CallButton({
    required this.targetUserId,
    required this.targetDisplayName,
    this.targetPhotoUrl,
    this.isVideo = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(isVideo ? Icons.videocam : Icons.call),
      onPressed: () => _initiateCall(context, ref),
    );
  }

  Future<void> _initiateCall(BuildContext context, WidgetRef ref) async {
    // 1. Récupérer le notifier
    final callNotifier = ref.read(currentCallNotifierProvider.notifier);

    // 2. Initier l'appel
    final call = await callNotifier.initiateCall(
      calleeId: targetUserId,
      calleeName: targetDisplayName,
      calleePhotoUrl: targetPhotoUrl,
      isVideo: isVideo,
    );

    // 3. Si succès, naviguer vers l'écran d'appel
    if (call != null && context.mounted) {
      context.push('/calls/${call.id}');
    }

    // 4. Si erreur, afficher message
    final state = ref.read(currentCallNotifierProvider);
    if (state.error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### 11.2 Écouter les Appels Entrants

```dart
// Dans app.dart ou un widget parent
class CallListener extends ConsumerWidget {
  final Widget child;

  const CallListener({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écouter les appels entrants
    final incomingCallAsync = ref.watch(incomingCallProvider);

    return Stack(
      children: [
        child,
        // Afficher l'overlay si appel entrant
        if (incomingCallAsync.valueOrNull != null)
          IncomingCallOverlay(
            call: incomingCallAsync.value!,
            onAccept: () => _handleAccept(context, ref, incomingCallAsync.value!),
            onDecline: () => _handleDecline(ref, incomingCallAsync.value!),
            onAcceptAudioOnly: () => _handleAcceptAudioOnly(context, ref, incomingCallAsync.value!),
          ),
      ],
    );
  }

  void _handleAccept(BuildContext context, WidgetRef ref, CallEntity call) {
    ref.read(currentCallNotifierProvider.notifier).acceptCall(call);
    context.push('/calls/${call.id}');
  }

  void _handleDecline(WidgetRef ref, CallEntity call) {
    ref.read(currentCallNotifierProvider.notifier).declineCall(call.id);
  }

  void _handleAcceptAudioOnly(BuildContext context, WidgetRef ref, CallEntity call) {
    ref.read(currentCallNotifierProvider.notifier).acceptCall(call, audioOnly: true);
    context.push('/calls/${call.id}');
  }
}
```

### 11.3 Réagir aux Changements d'État

```dart
// Dans CallScreen
class CallScreen extends ConsumerStatefulWidget {
  final String callId;

  const CallScreen({required this.callId, super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _isEnding = false;

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(currentCallProvider);

    // Écouter les changements de status du document Firestore
    ref.listen<AsyncValue<CallEntity?>>(
      callByIdProvider(widget.callId),
      (previous, next) {
        final call = next.valueOrNull;
        if (call == null) return;

        // Détecter fin distante
        if (_isTerminalStatus(call.status) && !_isEnding) {
          _handleRemoteEnd(call.status);
        }
      },
    );

    return Scaffold(
      body: _buildCallUI(callState),
    );
  }

  bool _isTerminalStatus(CallStatus status) {
    return [
      CallStatus.ended,
      CallStatus.declined,
      CallStatus.missed,
      CallStatus.error,
    ].contains(status);
  }

  void _handleRemoteEnd(CallStatus status) {
    _isEnding = true;

    // Afficher message approprié
    final message = switch (status) {
      CallStatus.declined => 'Appel refusé',
      CallStatus.missed => 'Pas de réponse',
      CallStatus.error => 'Erreur de connexion',
      _ => 'Appel terminé',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    // Cleanup et fermer
    ref.read(webRTCServiceProvider).hangUp();
    if (mounted) Navigator.of(context).pop();
  }
}
```

### 11.4 Raccrocher un Appel

```dart
// Bouton raccrocher dans CallScreen
class HangUpButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      backgroundColor: Colors.red,
      onPressed: () => _endCall(context, ref),
      child: const Icon(Icons.call_end, color: Colors.white),
    );
  }

  Future<void> _endCall(BuildContext context, WidgetRef ref) async {
    // 1. Appeler endCall sur le notifier
    await ref.read(currentCallNotifierProvider.notifier).endCall();

    // 2. Fermer l'écran
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
```

### 11.5 Vérifier le Blocage avant Appel

```dart
// Exemple manuel de vérification (déjà intégré dans initiateCall)
Future<bool> canCallUser(WidgetRef ref, String targetUserId) async {
  final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) return false;

  final repository = ref.read(blockedUsersRepositoryProvider);
  final result = await repository.checkBlockStatus(
    currentUser.id,
    targetUserId,
  );

  return result.fold(
    (failure) => false, // En cas d'erreur, bloquer par précaution
    (status) {
      // Vrai si aucun blocage dans les deux sens
      return !status.userBlockedTarget && !status.targetBlockedUser;
    },
  );
}
```

### 11.6 Afficher l'Indicateur d'Appel Actif

```dart
// Widget qui montre un banner quand un appel est en cours
class ActiveCallBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCallAsync = ref.watch(activeCallProvider);
    final call = activeCallAsync.valueOrNull;

    if (call == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/calls/${call.id}'),
      child: Container(
        color: Colors.green,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.call, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Appel en cours avec ${call.calleeName}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            // Timer d'appel
            _CallDurationTimer(startTime: call.connectedAt),
          ],
        ),
      ),
    );
  }
}

class _CallDurationTimer extends StatefulWidget {
  final DateTime? startTime;

  const _CallDurationTimer({this.startTime});

  @override
  State<_CallDurationTimer> createState() => _CallDurationTimerState();
}

class _CallDurationTimerState extends State<_CallDurationTimer> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.startTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.startTime!);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }
}
```

### 11.7 Gestion des Erreurs

```dart
// Erreurs possibles et leur gestion
void handleCallError(BuildContext context, String? error, String? errorCode) {
  final message = switch (errorCode) {
    'blocked_user' => 'Impossible d\'appeler cet utilisateur',
    'busy' => 'L\'utilisateur est déjà en appel',
    'connection_timeout' => 'Délai de connexion dépassé',
    'media_permission_denied' => 'Accès au micro/caméra refusé',
    'network_error' => 'Erreur réseau',
    'already_in_call' => 'Vous êtes déjà en appel',
    _ => error ?? 'Une erreur est survenue',
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ),
  );
}

// Utilisation dans un widget
ref.listen<CurrentCallState>(
  currentCallNotifierProvider,
  (previous, next) {
    if (next.error != null && previous?.error == null) {
      handleCallError(context, next.error, next.errorCode);
    }
  },
);
```

### 11.8 Exemple Complet : Bouton d'Appel dans une Conversation

```dart
class ConversationAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String recipientId;
  final String recipientName;
  final String? recipientPhotoUrl;

  const ConversationAppBar({
    required this.recipientId,
    required this.recipientName,
    this.recipientPhotoUrl,
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: Text(recipientName),
      actions: [
        // Bouton appel audio
        IconButton(
          icon: const Icon(Icons.call),
          tooltip: 'Appel audio',
          onPressed: () => _startCall(context, ref, isVideo: false),
        ),
        // Bouton appel vidéo
        IconButton(
          icon: const Icon(Icons.videocam),
          tooltip: 'Appel vidéo',
          onPressed: () => _startCall(context, ref, isVideo: true),
        ),
      ],
    );
  }

  Future<void> _startCall(
    BuildContext context,
    WidgetRef ref, {
    required bool isVideo,
  }) async {
    // Vérifier qu'on n'est pas déjà en appel
    final currentCall = ref.read(currentCallProvider).call;
    if (currentCall != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous êtes déjà en appel')),
      );
      return;
    }

    // Initier l'appel
    final call = await ref.read(currentCallNotifierProvider.notifier).initiateCall(
      calleeId: recipientId,
      calleeName: recipientName,
      calleePhotoUrl: recipientPhotoUrl,
      isVideo: isVideo,
    );

    // Naviguer si succès
    if (call != null && context.mounted) {
      context.push('/calls/${call.id}');
    }

    // Gérer les erreurs
    final state = ref.read(currentCallNotifierProvider);
    if (state.error != null && context.mounted) {
      handleCallError(context, state.error, state.errorCode);
    }
  }
}
```

---

## 12. Debugging

### Logs Utiles

```dart
// Activer les logs détaillés WebRTC
import 'package:flutter_webrtc/flutter_webrtc.dart';

WebRTC.platformIsDesktop; // Check platform
Helper.setMicrophoneMute(true); // Mute
Helper.setVolume(1.0); // Set volume

// Logs dans les providers
debugPrint('CallProvider: Initiating call to $calleeId');
debugPrint('CallProvider: Block status - userBlockedTarget: ${status.userBlockedTarget}');
debugPrint('WebRTC: ICE connection state: $state');
debugPrint('WebRTC: Peer connection state: $state');
```

### États à Vérifier en Debug

| Point de Vérification | Provider/Service | Valeur Attendue |
|----------------------|------------------|-----------------|
| Utilisateur connecté | `currentUserProvider` | Non null |
| Appel actif | `activeCallProvider` | CallEntity ou null |
| État WebRTC | `WebRTCService.connectionState` | connected |
| Streams locaux | `WebRTCService.localStream` | Non null |
| Streams distants | `WebRTCService.remoteStream` | Non null après connexion |

### Problèmes Courants

| Problème | Cause Probable | Solution |
|----------|----------------|----------|
| Pas de sonnerie | Permission notification | Vérifier `NotificationService.requestPermission()` |
| Écran noir vidéo | Permission caméra | Vérifier `Permission.camera.request()` |
| Pas d'audio | Permission micro ou mute | Vérifier permissions et `isMuted` |
| Appel ne connecte pas | ICE candidates bloqués | Vérifier firewall/NAT, utiliser TURN server |
| Overlay ne se ferme pas | Provider pas écouté | Utiliser `callByIdProvider` |

---

## 13. Scénarios d'Utilisation

### Scénario 1 : Appel Audio Réussi

**Contexte :** Alice veut appeler Bob. Les deux sont disponibles et ont une bonne connexion.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL AUDIO RÉUSSI                                               │
│ Durée totale : ~5 secondes pour connexion + durée appel                     │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Appelant)                     Firebase                      Bob (Appelé)
      │                                 │                                │
 [Clique "Appeler"]                     │                                │
      │                                 │                                │
      ├──── checkBlockStatus() ────────►│                                │
      │◄─── OK (pas de blocage) ───────│                                │
      │                                 │                                │
      ├──── createCall(ringing) ───────►│                                │
      │                                 │──── FCM Push ─────────────────►│
      │                                 │                                │
      │     [Écran CallScreen]          │                        [Sonnerie]
      │     [Ringback tone]             │                   [IncomingCallOverlay]
      │                                 │                                │
      │     ⏱️ Timeout 45s démarre      │                                │
      │                                 │                                │
      │                                 │                   [Bob clique "Accepter"]
      │                                 │                                │
      │                                 │◄─── updateStatus(connecting) ──│
      │◄─── status changed ────────────│                                │
      │                                 │                                │
      │     [Ringback stop]             │                   [Sonnerie stop]
      │                                 │                                │
      │◄════════════ Échange SDP/ICE via RTDB ════════════════════════►│
      │                                 │                                │
      │     [Audio connecté]            │                   [Audio connecté]
      │                                 │                                │
      ├──── updateStatus(connected) ───►│                                │
      │                                 │                                │
      │◄════════════════ APPEL EN COURS ════════════════════════════════►│
      │     [Timer démarre: 00:00]      │                   [Timer: 00:00]
      │                                 │                                │
      │         ... 5 minutes ...       │                                │
      │                                 │                                │
 [Alice raccroche]                      │                                │
      │                                 │                                │
      ├──── endCall(ended) ────────────►│                                │
      │     [cleanup WebRTC]            │──── status changed ───────────►│
      │                                 │                                │
      │     [Écran se ferme]            │                   [Détecte ended]
      │                                 │                   [cleanup WebRTC]
      │                                 │                   [Écran se ferme]
      │                                 │                                │
      │     [Message appel créé]        │                   [Message appel créé]
      │     "Appel audio - 5:00"        │                   "Appel audio - 5:00"
      ▼                                 ▼                                ▼
```

**Résultat Final :**
- Status appel : `ended`
- Durée : 5 minutes
- Message dans conversation : "Appel audio - 5:00"

---

### Scénario 2 : Appel Refusé

**Contexte :** Alice appelle Bob, mais Bob refuse l'appel.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL REFUSÉ                                                     │
│ Durée totale : ~3-10 secondes (temps de réaction de Bob)                    │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Appelant)                     Firebase                      Bob (Appelé)
      │                                 │                                │
 [Clique "Appeler"]                     │                                │
      │                                 │                                │
      ├──── createCall(ringing) ───────►│──── FCM Push ─────────────────►│
      │                                 │                                │
      │     [Écran CallScreen]          │                        [Sonnerie]
      │     [Ringback tone]             │                   [IncomingCallOverlay]
      │     [Affiche: "Appel en cours"] │                                │
      │                                 │                                │
      │                                 │                   [Bob clique "Refuser"]
      │                                 │                                │
      │                                 │◄─── updateStatus(declined) ────│
      │                                 │                   [Sonnerie stop]
      │                                 │                   [Overlay fermé]
      │                                 │                                │
      │◄─── status changed ────────────│                                │
      │                                 │                                │
      │     [callByIdProvider détecte   │                                │
      │      status == declined]        │                                │
      │                                 │                                │
      │     [Ringback stop]             │                                │
      │     [Snackbar: "Appel refusé"]  │                                │
      │     [Écran se ferme]            │                                │
      │                                 │                                │
      │     [Message appel créé]        │                   [Message appel créé]
      │     "📞 Appel refusé"           │                   "📞 Appel refusé"
      ▼                                 ▼                                ▼
```

**Résultat Final :**
- Status appel : `declined`
- Durée : 0 (pas de connexion)
- Message dans conversation : "Appel refusé"

---

### Scénario 3 : Appel Manqué (Timeout)

**Contexte :** Alice appelle Bob, mais Bob ne répond pas dans les 45 secondes.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL MANQUÉ (TIMEOUT)                                           │
│ Durée totale : 45 secondes                                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Appelant)                     Firebase                      Bob (Appelé)
      │                                 │                                │
 [Clique "Appeler"]                     │                                │
      │                                 │                                │
      ├──── createCall(ringing) ───────►│──── FCM Push ─────────────────►│
      │                                 │                                │
      │     [Écran CallScreen]          │                        [Sonnerie]
      │     [Ringback tone]             │                   [IncomingCallOverlay]
      │                                 │                                │
      │     ⏱️ Timeout 45s démarre      │                   ⏱️ Timeout 45s démarre
      │                                 │                                │
      │     ... 45 secondes ...         │                   [Bob ignore]
      │                                 │                   ... 45 secondes ...
      │                                 │                                │
      │     ⏱️ TIMEOUT !                │                   ⏱️ TIMEOUT !
      │                                 │                                │
      ├──── updateStatus(missed) ──────►│                                │
      │                                 │                   [Overlay détecte missed]
      │     [Ringback stop]             │                   [Sonnerie stop]
      │     [Snackbar: "Pas de réponse"]│                   [Overlay fermé]
      │     [Écran se ferme]            │                                │
      │                                 │                                │
      │     [Message appel créé]        │                   [Notification:]
      │     "📞 Pas de réponse"         │                   "Appel manqué de Alice"
      ▼                                 ▼                                ▼
```

**Résultat Final :**
- Status appel : `missed`
- Bob reçoit une notification "Appel manqué"
- Message dans conversation : "Appel manqué"

---

### Scénario 4 : Appel vers Utilisateur Bloqué

**Contexte :** Alice essaie d'appeler Bob, mais Bob a bloqué Alice.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL VERS UTILISATEUR BLOQUÉ                                    │
│ Durée totale : ~1 seconde (vérification immédiate)                          │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Appelant)                     Firebase                      Bob (Appelé)
      │                                 │                                │
 [Clique "Appeler Bob"]                 │                                │
      │                                 │                                │
      ├──── checkBlockStatus() ────────►│                                │
      │                                 │                                │
      │     [Requête Firestore:         │                                │
      │      Alice.blockedUserIds?      │                                │
      │      Bob.blockedUserIds?]       │                                │
      │                                 │                                │
      │◄─── Résultat: Bob a bloqué ────│                                │
      │     Alice (targetBlockedUser)   │                                │
      │                                 │                                │
      │     ❌ APPEL BLOQUÉ             │                                │
      │                                 │                                │
      │     [Snackbar rouge:]           │                                │
      │     "Vous ne pouvez pas         │                                │
      │      appeler cet utilisateur"   │                                │
      │                                 │                                │
      │     [Pas de navigation]         │                   [Aucun impact]
      │     [Pas de document créé]      │                   [Aucune notif]
      ▼                                 ▼                                ▼
```

**Résultat Final :**
- Aucun appel créé
- Message d'erreur affiché à Alice
- Bob n'est pas dérangé

**Note :** Même comportement si Alice a bloqué Bob (message: "Vous avez bloqué cet utilisateur")

---

### Scénario 5 : Appel vers Utilisateur Occupé

**Contexte :** Alice appelle Bob, mais Bob est déjà en appel avec Charlie.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL VERS UTILISATEUR OCCUPÉ                                    │
│ Durée totale : ~1-2 secondes                                                │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Appelant)                     Firebase                      Bob (Appelé)
      │                                 │                                │
      │                                 │           [En appel avec Charlie]
      │                                 │                                │
 [Clique "Appeler Bob"]                 │                                │
      │                                 │                                │
      ├──── checkBlockStatus() ────────►│                                │
      │◄─── OK ────────────────────────│                                │
      │                                 │                                │
      ├──── isUserBusy(bob) ───────────►│                                │
      │                                 │                                │
      │     [Requête Firestore:         │                                │
      │      calls où callerId=bob      │                                │
      │      OU calleeId=bob            │                                │
      │      ET status IN [ringing,     │                                │
      │        connecting, connected]]  │                                │
      │                                 │                                │
      │◄─── Résultat: Bob occupé ──────│                                │
      │                                 │                                │
      │     [Crée appel avec            │                                │
      │      status="busy"]             │                                │
      │                                 │                                │
      │     [Snackbar:]                 │                                │
      │     "L'utilisateur est          │                   [Aucun impact]
      │      déjà en appel"             │                   [Appel avec Charlie
      │                                 │                    continue]
      │     [Pas de navigation]         │                                │
      ▼                                 ▼                                ▼
```

**Résultat Final :**
- Status appel : `busy`
- Message d'erreur affiché à Alice
- Bob continue son appel avec Charlie sans interruption

---

### Scénario 6 : Appelant Annule Avant Réponse

**Contexte :** Alice appelle Bob, puis change d'avis et raccroche avant que Bob réponde.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPELANT ANNULE                                                  │
│ Durée totale : ~5-15 secondes                                               │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Appelant)                     Firebase                      Bob (Appelé)
      │                                 │                                │
 [Clique "Appeler"]                     │                                │
      │                                 │                                │
      ├──── createCall(ringing) ───────►│──── FCM Push ─────────────────►│
      │                                 │                                │
      │     [Écran CallScreen]          │                        [Sonnerie]
      │     [Ringback tone]             │                   [IncomingCallOverlay]
      │                                 │                                │
      │     ... 10 secondes ...         │                   [Bob hésite]
      │                                 │                                │
 [Alice clique "Raccrocher"]            │                                │
      │                                 │                                │
      ├──── updateStatus(ended) ───────►│                                │
      │     endReason: "cancelled"      │──── status changed ───────────►│
      │                                 │                                │
      │     [Ringback stop]             │                   [callByIdProvider
      │     [Écran se ferme]            │                    détecte ended]
      │                                 │                                │
      │                                 │                   [Sonnerie stop]
      │                                 │                   [Overlay fermé auto]
      │                                 │                                │
      │     [Message appel créé]        │                   [Notification:]
      │     "📞 Appel annulé"           │                   "Appel manqué de Alice"
      ▼                                 ▼                                ▼
```

**Résultat Final :**
- Status appel : `ended` (avec endReason: "cancelled")
- Overlay de Bob se ferme automatiquement
- Message dans conversation : "Appel annulé"

---

### Scénario 7 : Perte de Connexion Pendant l'Appel

**Contexte :** Alice et Bob sont en appel, puis Alice perd sa connexion Internet.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : PERTE DE CONNEXION                                               │
│ Durée totale : variable (timeout reconnexion: 30s)                          │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Appelant)                     Firebase                      Bob (Appelé)
      │                                 │                                │
      │◄═══════════════ APPEL EN COURS (connected) ═════════════════════►│
      │                                 │                                │
      │     [Timer: 02:30]              │                   [Timer: 02:30]
      │                                 │                                │
  💥 [Alice perd le WiFi]               │                                │
      │                                 │                                │
      │     [WebRTC détecte:            │                                │
      │      iceConnectionState         │                   [WebRTC détecte:
      │      = disconnected]            │                    iceConnectionState
      │                                 │                    = disconnected]
      │                                 │                                │
      ├──── updateStatus(reconnecting)─►│                                │
      │                                 │                                │
      │     [UI: "Reconnexion..."]      │                   [UI: "Reconnexion..."]
      │     [Overlay orange]            │                   [Overlay orange]
      │                                 │                                │
      │     ⏱️ Timeout 30s reconnexion  │                                │
      │                                 │                                │
      │     ... tentatives ICE ...      │                                │
      │                                 │                                │
      │                              OPTION A: Reconnexion réussie
      │                                 │                                │
  📶 [Alice retrouve le WiFi]           │                                │
      │                                 │                                │
      │     [WebRTC rétablit P2P]       │                   [WebRTC rétablit P2P]
      │                                 │                                │
      ├──── updateStatus(connected) ───►│                                │
      │                                 │                                │
      │     [UI normale]                │                   [UI normale]
      │     [Appel continue]            │                   [Appel continue]
      │                                 │                                │
      │                              OPTION B: Timeout (pas de reconnexion)
      │                                 │                                │
      │     ⏱️ TIMEOUT 30s !            │                                │
      │                                 │                                │
      ├──── updateStatus(ended) ───────►│                                │
      │     endReason: "connection_lost"│                                │
      │                                 │                                │
      │     [Snackbar: "Connexion       │                   [Détecte ended]
      │      perdue"]                   │                   [Snackbar: "Appel
      │     [Écran se ferme]            │                    terminé"]
      │                                 │                   [Écran se ferme]
      ▼                                 ▼                                ▼
```

**Résultat Final (si timeout) :**
- Status appel : `ended` (endReason: "connection_lost")
- Message dans conversation avec durée jusqu'à la perte

---

### Scénario 8 : Appel Vidéo avec Basculement Audio

**Contexte :** Alice appelle Bob en vidéo, mais Bob accepte en audio uniquement.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL VIDÉO → ACCEPTÉ EN AUDIO                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Appelant)                     Firebase                      Bob (Appelé)
      │                                 │                                │
 [Clique "Appel vidéo"]                 │                                │
      │                                 │                                │
      ├──── createCall(ringing)────────►│                                │
      │     type: "video"               │──── FCM Push ─────────────────►│
      │                                 │     type: "video"              │
      │                                 │                                │
      │     [Caméra activée]            │                   [IncomingCallOverlay]
      │     [Aperçu local affiché]      │                   [Affiche: "Appel vidéo"]
      │                                 │                   [Boutons:]
      │                                 │                   [✓ Accepter vidéo]
      │                                 │                   [🎤 Audio seulement]
      │                                 │                   [✕ Refuser]
      │                                 │                                │
      │                                 │           [Bob clique "Audio seulement"]
      │                                 │                                │
      │                                 │◄─── acceptCall(audioOnly:true)─│
      │                                 │                                │
      │◄─── answer (sans vidéo) ───────│                                │
      │                                 │                                │
      │     [Détecte: pas de           │                   [Caméra désactivée]
      │      remoteVideoTrack]         │                   [Micro activé]
      │                                 │                                │
      │     [UI: Appel vidéo mais      │                                │
      │      Bob sans caméra]          │                                │
      │     [Avatar Bob affiché]       │                                │
      │                                 │                                │
      │◄═══════════════ APPEL AUDIO (Alice vidéo, Bob audio) ═══════════►│
      ▼                                 ▼                                ▼
```

**Résultat Final :**
- Appel connecté
- Alice voit sa propre vidéo + avatar de Bob
- Bob entend Alice (et voit sa vidéo si UI le permet)
- Économie de bande passante côté Bob

---

### Scénario 9 : Double Appel Simultané (Race Condition)

**Contexte :** Alice et Bob s'appellent exactement en même temps.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPELS SIMULTANÉS (RACE CONDITION)                               │
└─────────────────────────────────────────────────────────────────────────────┘

Alice                                Firebase                           Bob
  │                                     │                                 │
  │ [Clique "Appeler Bob"]              │           [Clique "Appeler Alice"]
  │                                     │                                 │
  ├──── createCall(Alice→Bob) ─────────►│◄───── createCall(Bob→Alice) ────│
  │     callId: ABC                     │        callId: XYZ              │
  │                                     │                                 │
  │     [2 documents créés              │                                 │
  │      presque simultanément]         │                                 │
  │                                     │                                 │
  │     [incomingCallProvider détecte   │    [incomingCallProvider détecte│
  │      appel XYZ de Bob]              │     appel ABC d'Alice]          │
  │                                     │                                 │
  │     🔄 RÉSOLUTION :                 │                                 │
  │     Comparer les callIds            │                                 │
  │     "ABC" < "XYZ" alphabétiquement  │                                 │
  │     → Appel ABC gagne               │                                 │
  │                                     │                                 │
  ├──── cancelCall(XYZ) ───────────────►│                                 │
  │     (en tant qu'appelé)             │                                 │
  │                                     │                                 │
  │                                     │◄───── acceptCall(ABC) ──────────│
  │                                     │       (Bob accepte l'appel      │
  │                                     │        d'Alice qui a "gagné")   │
  │                                     │                                 │
  │◄════════════════════ APPEL ABC CONNECTÉ ════════════════════════════►│
  ▼                                     ▼                                 ▼
```

**Résolution de la Race Condition :**
- Comparer les `callId` lexicographiquement
- Le plus "petit" gagne
- L'autre appel est automatiquement annulé
- Alternative : timestamp createdAt (le premier créé gagne)

---

### Scénario 10 : Appel depuis Notification (App Fermée)

**Contexte :** L'app est fermée. Alice reçoit un appel de Bob via notification FCM.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL REÇU APP FERMÉE                                            │
└─────────────────────────────────────────────────────────────────────────────┘

Bob (Appelant)                       Firebase                    Alice (Appelé)
      │                                 │                              │
      │                                 │                          [App fermée]
      │                                 │                              │
 [Clique "Appeler Alice"]               │                              │
      │                                 │                              │
      ├──── createCall(ringing) ───────►│                              │
      │                                 │                              │
      │                                 │──── FCM Data Message ───────►│
      │                                 │     (high priority)          │
      │                                 │                              │
      │                                 │                          [Android:]
      │                                 │                          ConnectionService
      │                                 │                          reçoit le message
      │                                 │                              │
      │                                 │                          [iOS:]
      │                                 │                          CallKit PushKit
      │                                 │                          reçoit le message
      │                                 │                              │
      │     [CallScreen + ringback]     │                          [UI système:]
      │                                 │                          Full-screen
      │                                 │                          incoming call
      │                                 │                          [Sonnerie système]
      │                                 │                              │
      │                                 │                      [Alice décroche]
      │                                 │                              │
      │                                 │                          [App démarre]
      │                                 │                          [Splash rapide]
      │                                 │                          [acceptCall()]
      │                                 │                              │
      │                                 │◄─── updateStatus(connecting)─│
      │                                 │                              │
      │◄═══════════════════ CONNEXION P2P ═══════════════════════════►│
      │                                 │                              │
      │     [Appel connecté]            │                   [CallScreen s'ouvre]
      ▼                                 ▼                              ▼
```

**Points Clés :**
- FCM high priority pour wake up l'appareil
- iOS : PushKit + CallKit obligatoire pour VoIP
- Android : ConnectionService pour UI système
- L'app démarre en arrière-plan puis affiche CallScreen

---

## 14. Appels de Groupe

### Architecture des Appels de Groupe

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TOPOLOGIES D'APPELS DE GROUPE                            │
└─────────────────────────────────────────────────────────────────────────────┘

MODE MESH (2-4 participants)              MODE SFU (5+ participants)
─────────────────────────────             ────────────────────────────

    Alice ◄──────► Bob                         Alice
      │ ╲         ╱ │                            │
      │  ╲       ╱  │                            ▼
      │   ╲     ╱   │                      ┌──────────┐
      │    ╲   ╱    │                      │  LiveKit │
      │     ╲ ╱     │                      │   SFU    │
      │      ╳      │                      │  Server  │
      │     ╱ ╲     │                      └──────────┘
      │    ╱   ╲    │                       ▲  │  ▲
      │   ╱     ╲   │                      │  │  │
      │  ╱       ╲  │                 Bob──┘  │  └──Charlie
      ▼ ╱         ╲ ▼                         ▼
   Charlie ◄──────► David                   David

Chaque participant connecté               Tous connectés à un serveur
directement aux autres                    central qui redistribue
(N*(N-1)/2 connexions)                    les flux (N connexions)
```

### États d'un Appel de Groupe (GroupCallStatus)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MACHINE D'ÉTATS - APPEL DE GROUPE                        │
└─────────────────────────────────────────────────────────────────────────────┘

                           ┌─────────┐
                           │ waiting │ ◄─── État initial (host seul)
                           └────┬────┘
                                │
                                │ Premier participant rejoint
                                ▼
                           ┌─────────┐
                           │  active │ ◄─── Appel en cours
                           └────┬────┘
                                │
                                │ Dernier participant quitte
                                ▼
                           ┌─────────┐
                           │  ended  │ ◄─── Appel terminé
                           └─────────┘
```

### États d'un Participant (ParticipantConnectionState)

```
┌──────────────┐     ┌───────────┐     ┌──────────────┐
│  connecting  │────►│ connected │────►│ disconnected │
└──────────────┘     └─────┬─────┘     └──────────────┘
                           │                   ▲
                           ▼                   │
                    ┌──────────────┐           │
                    │ reconnecting │───────────┘
                    └──────────────┘
```

### Composants des Appels de Groupe

| Composant | Fichier | Rôle |
|-----------|---------|------|
| GroupCallEntity | `group_call_entity.dart` | Entité appel de groupe |
| GroupParticipantEntity | `group_participant_entity.dart` | Entité participant |
| GroupCallService | `group_call_service.dart` | Gestion mesh WebRTC |
| LiveKitService | `livekit_service.dart` | Gestion SFU (5+ participants) |
| GroupCallScreen | `group_call_screen.dart` | Interface utilisateur |
| GroupCallProvider | `group_call_provider.dart` | État Riverpod |

### Structure Firebase pour Appels de Groupe

```
Firebase Realtime Database
└── group_calls
    └── {callId}
        ├── e2ee_key
        │   ├── keyId: "abc123"
        │   └── encryptedKey: "..."
        ├── participants
        │   ├── {userId1}
        │   │   └── joinedAt: timestamp
        │   ├── {userId2}
        │   │   └── joinedAt: timestamp
        │   └── {userId3}
        │       └── joinedAt: timestamp
        └── signaling
            ├── {fromUserId}
            │   └── {toUserId}
            │       ├── offer: { type, sdp }
            │       ├── answer: { type, sdp }
            │       └── candidates
            │           ├── {candidateId1}: { candidate, sdpMid, sdpMLineIndex }
            │           └── {candidateId2}: { ... }
            └── ...
```

---

### Scénario 11 : Création d'un Appel de Groupe (Mesh - 3 participants)

**Contexte :** Alice crée un appel de groupe avec Bob et Charlie.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL DE GROUPE MESH (3 PARTICIPANTS)                            │
│ Mode : Mesh (connexions P2P directes entre tous)                            │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Host)                   Firebase RTDB                    Bob & Charlie
      │                             │                                │
 [Crée appel de groupe]             │                                │
 [Sélectionne Bob, Charlie]         │                                │
      │                             │                                │
      ├──── createGroupCall() ─────►│                                │
      │     status: "waiting"       │                                │
      │     hostId: Alice           │                                │
      │     participantIds: [A,B,C] │                                │
      │                             │                                │
      │     [GroupCallScreen]       │──── FCM Push ─────────────────►│
      │     [Attente participants]  │     "Alice vous appelle"       │
      │                             │                                │
      │                             │                        [Bob reçoit notif]
      │                             │                        [Charlie reçoit notif]
      │                             │                                │
      │                             │                        [Bob clique "Rejoindre"]
      │                             │◄─── registerParticipant(Bob) ──│
      │                             │                                │
      │◄─── onParticipantJoined ───│                                │
      │     participantId: Bob      │                                │
      │                             │                                │
      │     [Création connexion     │                                │
      │      P2P Alice ↔ Bob]       │                                │
      │                             │                                │
      ├──── offer (Alice→Bob) ─────►│                                │
      │                             │◄─── answer (Bob→Alice) ────────│
      │◄─── ICE candidates ────────────────────────────────────────►│
      │                             │                                │
      │◄════════════ ALICE ↔ BOB CONNECTÉS ═════════════════════════►│
      │                             │                                │
      │                             │                       [Charlie clique "Rejoindre"]
      │                             │◄─── registerParticipant(Charlie)│
      │                             │                                │
      │◄─── onParticipantJoined ───│                                │
      │     participantId: Charlie  │                                │
      │                             │                                │
      │     [Création connexions:   │                   [Création connexions:
      │      - Alice ↔ Charlie      │                    - Bob ↔ Charlie
      │      - Bob ↔ Charlie]       │                    - Alice ↔ Charlie]
      │                             │                                │
      │                     Échange SDP/ICE entre tous               │
      │                             │                                │
      │◄════════════════ TOUS CONNECTÉS (MESH) ═════════════════════►│
      │                             │                                │
      │     [3 vidéos affichées:]   │                   [3 vidéos affichées:]
      │     - Ma vidéo (locale)     │                   - Ma vidéo
      │     - Bob (distant)         │                   - Alice (distant)
      │     - Charlie (distant)     │                   - Autre (distant)
      ▼                             ▼                                ▼
```

**Connexions Mesh Créées :**
```
Alice ◄──────────────────► Bob
  │                         │
  │                         │
  ▼                         ▼
Charlie ◄─────────────────►
```
- 3 participants = 3 connexions P2P (N*(N-1)/2 = 3*2/2 = 3)

---

### Scénario 12 : Participant Rejoint un Appel en Cours

**Contexte :** Alice et Bob sont en appel. Charlie rejoint plus tard.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : REJOINDRE APPEL EN COURS                                         │
└─────────────────────────────────────────────────────────────────────────────┘

Alice                              Bob                            Charlie
  │                                 │                                │
  │◄══════════ EN APPEL ══════════►│                                │
  │     [Timer: 02:30]              │                                │
  │                                 │                                │
  │                                 │               [Reçoit notification]
  │                                 │               [Clique "Rejoindre"]
  │                                 │                                │
  │◄─── onParticipantJoined(Charlie) ───────────────────────────────│
  │                                 │◄─── onParticipantJoined ──────│
  │                                 │                                │
  │     [UI: "Charlie a rejoint"]   │     [UI: "Charlie a rejoint"] │
  │                                 │                                │
  │     [Création P2P: Alice↔Charlie]                                │
  │                                 │     [Création P2P: Bob↔Charlie]│
  │                                 │                                │
  │◄═════════════════ ÉCHANGE SDP/ICE ══════════════════════════════►│
  │                                 │                                │
  │     [3 vidéos maintenant]       │     [3 vidéos]   [3 vidéos]   │
  │                                 │                                │
  │     participantCount: 3         │                                │
  ▼                                 ▼                                ▼
```

**Points Clés :**
- Les connexions existantes restent actives
- Seules les nouvelles connexions vers Charlie sont créées
- L'UI s'adapte dynamiquement (grille 2x2 → 2x2 avec 3 vidéos)

---

### Scénario 13 : Participant Quitte l'Appel

**Contexte :** Alice, Bob et Charlie en appel. Bob quitte.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : PARTICIPANT QUITTE                                               │
└─────────────────────────────────────────────────────────────────────────────┘

Alice                              Bob                            Charlie
  │                                 │                                │
  │◄══════════ APPEL 3 PERSONNES ══════════════════════════════════►│
  │                                 │                                │
  │                        [Bob clique "Quitter"]                    │
  │                                 │                                │
  │                                 ├──── removeParticipant ─────────┤
  │                                 │     (Firebase RTDB)            │
  │                                 │                                │
  │◄─── onParticipantLeft(Bob) ────│                                │
  │                                 │──── onParticipantLeft ────────►│
  │                                 │                                │
  │     [_disconnectFromParticipant(Bob)]           [disconnect(Bob)]│
  │     - Fermer PeerConnection     │                                │
  │     - Supprimer remote stream   │                                │
  │     - Cleanup renderer          │                                │
  │                                 │                                │
  │     [UI: "Bob a quitté"]        │     [Écran fermé] [UI: "Bob a quitté"]
  │                                 │                                │
  │◄═════════════════ APPEL CONTINUE (Alice ↔ Charlie) ═════════════►│
  │                                 │                                │
  │     [2 vidéos maintenant]       │                   [2 vidéos]   │
  │     participantCount: 2         │                                │
  ▼                                 ▼                                ▼
```

**Points Clés :**
- L'appel continue tant qu'il reste 2+ participants
- Les connexions vers Bob sont fermées proprement
- Les ressources (renderers, streams) sont libérées

---

### Scénario 14 : Appel de Groupe avec Plus de 4 Participants (SFU)

**Contexte :** Appel de groupe avec 6 personnes → utilise LiveKit SFU.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : APPEL DE GROUPE SFU (6 PARTICIPANTS)                             │
│ Mode : SFU via LiveKit (serveur central)                                    │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Host)                   LiveKit Server                   5 autres
      │                             │                                │
 [Crée appel 6 personnes]           │                                │
      │                             │                                │
      ├──── createGroupCall() ─────►│                                │
      │     mode: "sfu"             │                                │
      │     participantIds: [6]     │                                │
      │                             │                                │
      │                        [Création Room LiveKit]               │
      │                        livekitRoomName: "room_xyz"           │
      │                             │                                │
      │◄─── roomToken ─────────────│                                │
      │                             │                                │
      │──── connect(token) ────────►│                                │
      │     [Publie son stream]     │                                │
      │                             │                                │
      │                             │◄─── FCM + roomToken ──────────│
      │                             │     (envoyé à chaque invité)   │
      │                             │                                │
      │                             │◄─── connect(token) ───────────│
      │                             │     [Bob se connecte]          │
      │                             │                                │
      │◄─── onParticipantJoined ───│                                │
      │     [Reçoit stream de Bob]  │                                │
      │                             │                                │
      │                             │◄─── connect(token) ───────────│
      │                             │     [Charlie se connecte]      │
      │                             │     ...                        │
      │                             │     [6ème se connecte]         │
      │                             │                                │
      │◄═══════════ TOUS CONNECTÉS VIA LIVEKIT SFU ═════════════════►│
      │                             │                                │
      │     [UI: Grille 3x2]        │                   [UI: Grille 3x2]
      │     - 6 vidéos              │                   - 6 vidéos
      │     - Qualité adaptative    │                   - Qualité adaptative
      ▼                             ▼                                ▼
```

**Avantages du Mode SFU :**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MESH vs SFU                                         │
├─────────────────────────────────┬───────────────────────────────────────────┤
│            MESH                 │                  SFU                      │
├─────────────────────────────────┼───────────────────────────────────────────┤
│ 4 participants:                 │ 6 participants:                           │
│ - 6 connexions P2P              │ - 6 connexions (vers serveur)             │
│ - Envoie stream 3 fois          │ - Envoie stream 1 fois                    │
│ - Upload: 3x bandwidth          │ - Upload: 1x bandwidth                    │
│                                 │                                           │
│ 6 participants (si mesh):       │ Qualité adaptative:                       │
│ - 15 connexions P2P !!!         │ - Serveur ajuste qualité par client      │
│ - Envoie stream 5 fois          │ - Simulcast pour différentes résolutions │
│ - Upload: 5x bandwidth          │                                           │
└─────────────────────────────────┴───────────────────────────────────────────┘
```

---

### Scénario 15 : Basculement Mesh → SFU (5ème participant)

**Contexte :** Appel mesh à 4 personnes. Un 5ème veut rejoindre.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : TRANSITION MESH → SFU                                            │
└─────────────────────────────────────────────────────────────────────────────┘

4 participants (Mesh)          Firebase/LiveKit               Eve (5ème)
      │                             │                                │
      │◄══════ APPEL MESH 4P ═════►│                                │
      │  (6 connexions P2P)         │                                │
      │                             │                                │
      │                             │               [Eve clique "Rejoindre"]
      │                             │                                │
      │     [shouldSwitchToSfu      │                                │
      │      == true]               │                                │
      │                             │                                │
      │──── Détection: 5ème ───────►│                                │
      │     participant             │                                │
      │                             │                                │
      │                        [Création Room LiveKit]               │
      │                             │                                │
      │     ⚠️ TRANSITION SFU       │                                │
      │                             │                                │
      │──── 1. Créer connexion ────►│                                │
      │        LiveKit              │                                │
      │                             │                                │
      │──── 2. Transférer ─────────►│                                │
      │        streams              │                                │
      │                             │                                │
      │──── 3. Fermer connexions ──►│                                │
      │        mesh                 │                                │
      │                             │                                │
      │◄═══════════ TOUS SUR LIVEKIT SFU ═══════════════════════════►│
      │                             │                                │
      │     [UI: "Passage en mode   │                                │
      │      serveur pour           │                                │
      │      meilleure qualité"]    │                                │
      │                             │                                │
      │     [5 vidéos maintenant]   │                   [5 vidéos]   │
      ▼                             ▼                                ▼
```

**Note :** La transition est transparente pour les utilisateurs.

---

### Scénario 16 : Host Quitte l'Appel de Groupe

**Contexte :** Alice (host) quitte. L'appel doit continuer avec un nouveau host.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : HOST QUITTE - TRANSFERT DE RÔLE                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Alice (Host)                       Firebase                      Bob, Charlie
      │                             │                                │
      │◄══════════ APPEL EN COURS (Alice = Host) ═══════════════════►│
      │                             │                                │
 [Alice clique "Quitter"]           │                                │
      │                             │                                │
      │──── leaveCall() ───────────►│                                │
      │                             │                                │
      │                        [Logique de transfert:]               │
      │                        - Trouver participant le plus ancien  │
      │                        - Bob.joinedAt < Charlie.joinedAt     │
      │                        - Nouveau host = Bob                  │
      │                             │                                │
      │                             │──── updateGroupCall() ────────►│
      │                             │     hostId: Bob                │
      │                             │                                │
      │     [Écran fermé]           │                   [UI: "Alice a quitté"]
      │                             │                   [UI: "Bob est maintenant
      │                             │                        l'organisateur"]
      │                             │                                │
      │                             │◄══════ APPEL CONTINUE ════════►│
      │                             │        Bob = nouveau host       │
      ▼                             ▼                                ▼
```

**Règles de Transfert de Host :**
1. Le participant avec le `joinedAt` le plus ancien devient host
2. Ou le premier dans la liste alphabétique si même timestamp
3. L'appel se termine si dernier participant quitte

---

### Scénario 17 : Fonctionnalités Pendant l'Appel de Groupe

**Contexte :** Actions disponibles pendant un appel de groupe.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ FONCTIONNALITÉS APPEL DE GROUPE                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           INTERFACE APPEL DE GROUPE                         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    GRILLE VIDÉO (2x2 ou 3x2)                        │   │
│  │  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐             │   │
│  │  │               │ │               │ │               │             │   │
│  │  │    Alice      │ │     Bob       │ │   Charlie     │             │   │
│  │  │   (Vous)      │ │   🔇 muté     │ │  📷 cam off   │             │   │
│  │  │   🎤 ●●●●     │ │               │ │   [Avatar]    │             │   │
│  │  │               │ │               │ │               │             │   │
│  │  └───────────────┘ └───────────────┘ └───────────────┘             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         BARRE D'ACTIONS                             │   │
│  │                                                                      │   │
│  │   🔇        📷        ✋        🔄        📤        🚪              │   │
│  │  Mute    Caméra    Main     Switch   Partage   Quitter             │   │
│  │          ON/OFF   Levée    Caméra   Écran                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Participants: 3/10    │    Durée: 05:23    │    🔒 E2EE activé    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Actions Disponibles :**

| Action | Code | Description |
|--------|------|-------------|
| Mute/Unmute | `toggleMute()` | Active/désactive le micro |
| Caméra ON/OFF | `toggleCamera()` | Active/désactive la caméra |
| Lever la main | `raiseHand()` | Signale vouloir parler |
| Switch caméra | `switchCamera()` | Passe avant↔arrière |
| Partage écran | `startScreenShare()` | Partage l'écran (SFU uniquement) |
| Quitter | `leaveCall()` | Quitte l'appel |

---

### Scénario 18 : Indicateurs Visuels en Appel de Groupe

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ INDICATEURS VISUELS PAR PARTICIPANT                                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   ┌─────────────────────────────┐                                          │
│   │   ┌─────────────────────┐   │                                          │
│   │   │                     │   │  ← Bordure verte = parle actuellement    │
│   │   │       VIDEO         │   │                                          │
│   │   │                     │   │  ← Bordure orange = reconnexion          │
│   │   │                     │   │                                          │
│   │   └─────────────────────┘   │                                          │
│   │                             │                                          │
│   │  👑 Alice (Host)      🔒   │  ← 👑 = Host, 🔒 = E2EE vérifié          │
│   │                             │                                          │
│   │  🔇 │ 📷❌ │ ✋ │ 📶●●●○○ │  ← Statuts: muté, cam off, main, réseau  │
│   └─────────────────────────────┘                                          │
│                                                                             │
│   Légende:                                                                  │
│   🔇 = Micro muté              📷❌ = Caméra désactivée                    │
│   ✋ = Main levée               📶 = Qualité réseau (1-5 barres)           │
│   👑 = Host de l'appel         🔒 = E2EE vérifié                           │
│   ●●●●○ = Niveau audio          │                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Scénario 19 : Qualité Vidéo Adaptative (SFU)

**Contexte :** Gestion automatique de la qualité selon le réseau.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : QUALITÉ ADAPTATIVE (SIMULCAST)                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Émetteur (Alice)                LiveKit SFU                    Récepteurs
      │                             │                                │
      │     [Encode 3 qualités:]    │                                │
      │     - High: 720p            │                                │
      │     - Medium: 360p          │                                │
      │     - Low: 180p             │                                │
      │                             │                                │
      ├──── Tous les streams ──────►│                                │
      │                             │                                │
      │                             │        [Bob: bonne connexion]  │
      │                             │──── High (720p) ──────────────►│
      │                             │                                │
      │                             │        [Charlie: connexion     │
      │                             │         moyenne]               │
      │                             │──── Medium (360p) ────────────►│
      │                             │                                │
      │                             │        [David: mauvaise        │
      │                             │         connexion]             │
      │                             │──── Low (180p) ───────────────►│
      │                             │                                │
      │                        [Adaptation dynamique:]               │
      │                        - Si Bob perd du réseau → passe en   │
      │                          Medium automatiquement              │
      │                        - Si David récupère → passe en High  │
      ▼                             ▼                                ▼
```

**VideoQuality Enum :**
```dart
enum VideoQuality {
  low,    // 180p - mauvais réseau
  medium, // 360p - défaut
  high,   // 720p - bon réseau
}
```

---

### Scénario 20 : Erreur - Participant Ne Peut Pas Se Connecter

**Contexte :** Charlie essaie de rejoindre mais a des problèmes réseau.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : ÉCHEC DE CONNEXION PARTICIPANT                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Alice & Bob                        Firebase                        Charlie
      │                             │                                │
      │◄═════════ EN APPEL ════════►│                                │
      │                             │                                │
      │                             │               [Charlie clique "Rejoindre"]
      │                             │◄─── registerParticipant ───────│
      │                             │                                │
      │◄─── onParticipantJoined ───│                                │
      │     [Charlie visible:       │                                │
      │      "Connexion..."]        │                                │
      │                             │                                │
      │                             │               [Échange SDP...]
      │                             │               [ICE candidates...]
      │                             │                                │
      │                             │               ⏱️ Timeout ICE (30s)
      │                             │                                │
      │                             │               [connectionState:
      │                             │                disconnected]
      │                             │                                │
      │                             │               [UI Charlie:]
      │                             │               "Impossible de se
      │                             │                connecter. Vérifiez
      │                             │                votre connexion."
      │                             │                                │
      │                             │◄─── removeParticipant ─────────│
      │                             │     (auto après échec)         │
      │                             │                                │
      │◄─── onParticipantLeft ─────│                                │
      │     [Charlie retiré]        │                                │
      │                             │                                │
      │     [UI: "Charlie n'a pas   │               [Bouton: "Réessayer"]
      │      pu se connecter"]      │                                │
      ▼                             ▼                                ▼
```

**Causes Possibles :**
- Réseau restrictif (NAT symétrique)
- Firewall bloquant WebRTC
- Serveur TURN non disponible
- Permissions micro/caméra refusées

---

### Scénario 21 : Dernier Participant Restant (Fin d'Appel de Groupe)

**Contexte :** Il reste 2 participants (Alice et Bob). Bob quitte. Que devient Alice ?

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCÉNARIO : DERNIER PARTICIPANT - FIN AUTOMATIQUE                            │
└─────────────────────────────────────────────────────────────────────────────┘

Alice                              Firebase                           Bob
  │                                   │                                 │
  │◄══════════ APPEL 2 PERSONNES ════►│◄════════════════════════════════►│
  │     participantCount: 2           │                                 │
  │                                   │                                 │
  │                                   │                [Bob clique "Quitter"]
  │                                   │                                 │
  │                                   │◄──── removeParticipant(Bob) ────│
  │                                   │                                 │
  │◄─── onParticipantLeft(Bob) ──────│                [Écran fermé]    │
  │                                   │                                 │
  │     participantCount: 1           │                                 │
  │                                   │                                 │
  │     ⚠️ DÉTECTION: SEUL RESTANT    │                                 │
  │                                   │                                 │
  │                                   │                                 │
  │  ╔═══════════════════════════════════════════════════════════════╗ │
  │  ║ ✅ IMPLÉMENTÉ : FIN AUTOMATIQUE IMMÉDIATE                     ║ │
  │  ╠═══════════════════════════════════════════════════════════════╣ │
  │  ║                                                                ║ │
  │  ║  Détection à 2 niveaux :                                      ║ │
  │  ║  1. onParticipantLeft (mesh) → détection immédiate            ║ │
  │  ║  2. Firestore subscription → backup pour SFU                  ║ │
  │  ║                                                                ║ │
  │  ║  [Résultat Alice:]                                            ║ │
  │  ║  - Détection immédiate (pas d'attente)                        ║ │
  │  ║  - Status appel → "ended"                                     ║ │
  │  ║  - endReason → "all_participants_left"                        ║ │
  │  ║  - Écran se ferme automatiquement                             ║ │
  │  ╚═══════════════════════════════════════════════════════════════╝ │
  │                                   │                                 │
  ▼                                   ▼                                 ▼
```

**Code Implémenté dans `group_call_provider.dart` :**

```dart
// 1. Détection rapide via callback mesh (onParticipantLeft)
onParticipantLeft: (participantId) {
  final newStreams = Map<String, MediaStream>.from(state.remoteStreams);
  newStreams.remove(participantId);
  state = state.copyWith(remoteStreams: newStreams);

  // Si plus aucun stream distant → on est seul
  if (newStreams.isEmpty && state.isConnected && !state.isLeaving) {
    _endCallAsLastParticipant();
  }
}

// 2. Détection via Firestore (backup et SFU)
void _checkIfLastParticipant(List<GroupParticipantEntity> participants) {
  final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null || state.call == null) return;

  final otherParticipants = participants
      .where((p) => p.oderId != currentUser.id && !p.hasLeft)
      .toList();

  if (otherParticipants.isEmpty && state.isConnected && !state.isLeaving) {
    _endCallAsLastParticipant();
  }
}

// 3. Fin automatique
Future<void> _endCallAsLastParticipant() async {
  if (state.call == null || state.isLeaving) return;

  await _firestore.collection('group_calls').doc(state.call!.id).update({
    'status': 'ended',
    'endedAt': FieldValue.serverTimestamp(),
    'endReason': 'all_participants_left',
  });

  await leaveCall(reason: 'all_participants_left');
}
```

**Différence avec Appel 1-à-1 :**

| Aspect | Appel 1-à-1 | Appel de Groupe |
|--------|-------------|-----------------|
| Minimum participants | 2 (sinon fin) | 2 (sinon fin*) |
| Un quitte | Appel terminé | Continue si 2+ restants |
| Dernier seul | N/A | Fin automatique ou timeout |
| Message fin | "Appel terminé" | "Tous les participants ont quitté" |

*Note : Un appel de groupe avec 1 seul participant n'a pas de sens, donc il se termine.

---

### Scénario 22 : Comparaison Comportements de Fin

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              MATRICE DE COMPORTEMENT - FIN D'APPEL DE GROUPE                │
└─────────────────────────────────────────────────────────────────────────────┘

┌────────────────────┬─────────────────────────────────────────────────────────┐
│ Situation          │ Comportement                                            │
├────────────────────┼─────────────────────────────────────────────────────────┤
│ 5 → 4 participants │ Appel continue normalement                              │
│                    │ UI: "X a quitté l'appel"                                │
├────────────────────┼─────────────────────────────────────────────────────────┤
│ 4 → 3 participants │ Appel continue normalement                              │
│                    │ UI: "X a quitté l'appel"                                │
├────────────────────┼─────────────────────────────────────────────────────────┤
│ 3 → 2 participants │ Appel continue normalement                              │
│                    │ UI: "X a quitté l'appel"                                │
├────────────────────┼─────────────────────────────────────────────────────────┤
│ 2 → 1 participant  │ ⚠️ FIN AUTOMATIQUE                                      │
│                    │ UI: "Tous les participants ont quitté"                  │
│                    │ Action: Fermeture écran + cleanup                       │
├────────────────────┼─────────────────────────────────────────────────────────┤
│ Host quitte        │ Si 2+ restants: Transfert de rôle                       │
│ (n'importe quand)  │ Si 1 restant: Fin automatique                           │
├────────────────────┼─────────────────────────────────────────────────────────┤
│ Tous quittent      │ Appel status → "ended"                                  │
│ simultanément      │ endReason: "all_participants_left"                      │
└────────────────────┴─────────────────────────────────────────────────────────┘
```

**Diagramme de Décision :**

```
                    ┌─────────────────────────┐
                    │ Un participant quitte   │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │ Combien restent ?       │
                    └───────────┬─────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
        ┌───────────┐    ┌───────────┐    ┌───────────┐
        │   0 ou 1  │    │    2+     │    │  Host ?   │
        └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
              │                │                 │
              ▼                ▼                 ▼
        ┌───────────┐    ┌───────────┐    ┌───────────┐
        │ FIN AUTO  │    │ CONTINUE  │    │ TRANSFERT │
        │ de l'appel│    │ l'appel   │    │ du rôle   │
        └───────────┘    └───────────┘    └───────────┘
```
