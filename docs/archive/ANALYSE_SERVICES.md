# Analyse des Services - DiaspoNiger

> Document genere le 23/02/2026
> Ce document liste tous les problemes identifies dans les services de l'application avec des solutions detaillees.

---

## Table des matieres

1. [Problemes Critiques (Securite/Finance)](#1-problemes-critiques-securitefinance)
2. [Service Transferts d'Argent](#2-service-transferts-dargent)
3. [Service Salons Audio](#3-service-salons-audio)
4. [Service Podcasts](#4-service-podcasts)
5. [Service Marketplace](#5-service-marketplace)
6. [Service Annuaire Entreprises](#6-service-annuaire-entreprises)
7. [Service Ambassades](#7-service-ambassades)
8. [Problemes Transversaux](#8-problemes-transversaux)

---

## 1. Problemes Critiques (Securite/Finance)

### 1.1 Calculs financiers cote client (Audio Rooms)

**Fichier:** `lib/features/audio_rooms/data/datasources/monetization_remote_datasource.dart:132`

**Probleme:** La commission de 15% est calculee cote client. Un utilisateur malveillant peut modifier les valeurs avant envoi a Firestore.

**Solution:**
```javascript
// functions/index.js - Ajouter une Cloud Function
exports.processTip = functions.firestore
  .document('tips/{tipId}')
  .onCreate(async (snap, context) => {
    const tip = snap.data();
    const amount = tip.amount;
    
    // Calcul serveur uniquement
    const COMMISSION_RATE = 0.15;
    const commissionAmount = Math.round(amount * COMMISSION_RATE);
    const creatorAmount = amount - commissionAmount;
    
    // Mettre a jour avec les vraies valeurs
    await snap.ref.update({
      commissionAmount,
      creatorAmount,
      processedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
```

---

### 1.2 Transaction atomique manquante pour payout

**Fichier:** `lib/features/audio_rooms/data/datasources/monetization_remote_datasource.dart:394`

**Probleme:** `FieldValue.increment(-amount)` sans transaction peut causer un solde negatif si deux demandes simultanees.

**Solution:**
```dart
// Remplacer l'implementation actuelle par une transaction
Future<Either<Failure, PayoutEntity>> requestPayout({
  required String creatorId,
  required int amount,
  required String currency,
}) async {
  try {
    return await _firestore.runTransaction((transaction) async {
      final profileRef = _firestore
          .collection('creator_profiles')
          .doc(creatorId);
      
      final profileSnap = await transaction.get(profileRef);
      final currentBalance = profileSnap.data()?['availableBalance'] ?? 0;
      
      // Verification atomique
      if (currentBalance < amount) {
        throw Exception('Solde insuffisant');
      }
      
      // Decrement securise
      transaction.update(profileRef, {
        'availableBalance': FieldValue.increment(-amount),
        'pendingPayouts': FieldValue.increment(amount),
      });
      
      // Creer le payout
      final payoutRef = _firestore.collection('payouts').doc();
      transaction.set(payoutRef, {
        'id': payoutRef.id,
        'creatorId': creatorId,
        'amount': amount,
        'currency': currency,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return Right(PayoutEntity(...));
    });
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

---

### 1.3 Bug calcul frais Marketplace

**Fichier:** `lib/features/marketplace/data/repositories/marketplace_repository_impl.dart:139`

**Probleme:** `platformFee * 100` est applique deux fois, faussant le montant vendeur.

**Code actuel (FAUX):**
```dart
final sellerAmount = (amount - platformFee * 100).round() / 100;
```

**Solution:**
```dart
// Le platformFee est deja en pourcentage decimal (ex: 0.05 pour 5%)
// amount est en unite monetaire (ex: 10000 XOF)

// Calcul correct:
final platformFeeAmount = (amount * platformFeePercent).round();
final sellerAmount = amount - platformFeeAmount;

// OU si platformFee est deja le montant calcule:
final sellerAmount = amount - platformFee;
```

---

### 1.4 Collecte carte bancaire sans SDK securise

**Fichier:** `lib/features/transfers/presentation/screens/add_recipient_screen.dart`

**Probleme:** Risque de non-conformite PCI-DSS si les numeros de carte sont collectes directement.

**Solution:**
```dart
// Utiliser Stripe Elements ou un SDK certifie
// Ne JAMAIS stocker les numeros de carte cote client

// Exemple avec stripe_sdk
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> addCard() async {
  // Utiliser le CardField securise de Stripe
  await Stripe.instance.createPaymentMethod(
    params: PaymentMethodParams.card(
      paymentMethodData: PaymentMethodData(),
    ),
  );
  
  // Seul le paymentMethodId est stocke, jamais le numero
}
```

---

## 2. Service Transferts d'Argent

### 2.1 Erreurs et Bugs

#### 2.1.1 Gestion etat instable avec Future.microtask

**Fichier:** `lib/features/transfers/presentation/providers/transfer_provider.dart:121,181`

**Probleme:** Utilisation de `Future.microtask` comme workaround pour eviter "Future already completed".

**Solution:**
```dart
// Avant (problematique)
Future.microtask(() {
  ref.invalidate(someProvider);
});

// Apres (correct)
// Utiliser un StateNotifier avec gestion explicite
class TransferNotifier extends StateNotifier<AsyncValue<TransferState>> {
  TransferNotifier(this._ref) : super(const AsyncValue.loading());
  
  final Ref _ref;
  
  Future<void> createTransfer(TransferParams params) async {
    // Ne pas modifier l'etat si deja dispose
    if (!mounted) return;
    
    state = const AsyncValue.loading();
    
    try {
      final result = await _repository.createTransfer(params);
      if (!mounted) return;
      
      state = AsyncValue.data(result);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }
}
```

---

#### 2.1.2 Precision monetaire avec double

**Fichier:** `lib/features/transfers/data/repositories/transfer_repository_impl.dart:100`

**Probleme:** `double` peut introduire des erreurs de precision (ex: 0.1 + 0.2 = 0.30000000000000004)

**Solution:**
```dart
// Option 1: Travailler en centimes (int)
// Tous les montants en centimes/millimes
final amountInCents = (amountInput * 100).round();
final feeInCents = (amountInCents * feePercent).round();
final totalInCents = amountInCents + feeInCents;

// Affichage uniquement
String formatAmount(int cents) => (cents / 100).toStringAsFixed(2);

// Option 2: Utiliser le package decimal
// pubspec.yaml: decimal: ^2.3.0
import 'package:decimal/decimal.dart';

final amount = Decimal.parse('100.50');
final fee = amount * Decimal.parse('0.025');
final total = amount + fee;
```

---

#### 2.1.3 Validation numero telephone insuffisante

**Fichier:** `lib/features/transfers/presentation/screens/send_money_screen.dart:456`

**Solution:**
```dart
// Ajouter une validation par pays
// pubspec.yaml: phone_numbers: ^2.0.0

import 'package:phone_numbers/phone_numbers.dart';

bool isValidPhoneNumber(String phone, String countryCode) {
  try {
    final phoneNumber = PhoneNumber.parse(phone, regionCode: countryCode);
    return phoneNumber.isValid();
  } catch (e) {
    return false;
  }
}

// Utilisation dans le formulaire
validator: (value) {
  if (value == null || value.isEmpty) {
    return l10n.phoneRequired;
  }
  if (!isValidPhoneNumber(value, selectedCountry.code)) {
    return l10n.invalidPhoneForCountry(selectedCountry.name);
  }
  return null;
},
```

---

### 2.2 Strings non localisees

**Fichiers concernes:**
- `add_recipient_screen.dart:39-62`
- `send_money_screen.dart:55,67,356,822,883`

**Solution:**

1. Ajouter les cles dans `lib/l10n/app_en.arb`:
```json
{
  "sendMoney": "Send Money",
  "resetForm": "Reset",
  "debitAccountInfo": "Debit account information",
  "confirmTransfer": "Confirm transfer",
  "transferIrreversible": "This action is irreversible. Do you want to continue?",
  "countryFrance": "France",
  "countryGermany": "Germany",
  "countryUSA": "United States"
}
```

2. Ajouter dans `lib/l10n/app_fr.arb`:
```json
{
  "sendMoney": "Envoyer de l'argent",
  "resetForm": "Reinitialiser",
  "debitAccountInfo": "Informations du compte a debiter",
  "confirmTransfer": "Confirmer le transfert",
  "transferIrreversible": "Cette action est irreversible. Voulez-vous continuer?",
  "countryFrance": "France",
  "countryGermany": "Allemagne",
  "countryUSA": "Etats-Unis"
}
```

3. Remplacer dans le code:
```dart
// Avant
Text('Envoyer de l\'argent')

// Apres
Text(l10n.sendMoney)
```

---

### 2.3 Fonctionnalites a ajouter

#### Persistance formulaire multi-etapes

```dart
// Creer un provider pour persister l'etat du formulaire
final transferFormProvider = StateNotifierProvider<TransferFormNotifier, TransferFormState>((ref) {
  return TransferFormNotifier(ref);
});

class TransferFormState {
  final int currentStep;
  final RecipientEntity? recipient;
  final double? amount;
  final String? currency;
  final String? note;
  
  // Serialisation pour SharedPreferences
  Map<String, dynamic> toJson() => {...};
  factory TransferFormState.fromJson(Map<String, dynamic> json) => ...;
}

class TransferFormNotifier extends StateNotifier<TransferFormState> {
  TransferFormNotifier(this._ref) : super(TransferFormState.initial()) {
    _loadSavedForm();
  }
  
  Future<void> _loadSavedForm() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('transfer_form_draft');
    if (saved != null) {
      state = TransferFormState.fromJson(jsonDecode(saved));
    }
  }
  
  Future<void> saveStep(int step, dynamic data) async {
    // Mettre a jour et persister
    state = state.copyWith(currentStep: step, ...);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transfer_form_draft', jsonEncode(state.toJson()));
  }
  
  Future<void> clearForm() async {
    state = TransferFormState.initial();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('transfer_form_draft');
  }
}
```

---

## 3. Service Salons Audio

### 3.1 Erreurs et Bugs

#### 3.1.1 Utilisateur fantome apres dispose

**Fichier:** `lib/features/audio_rooms/presentation/screens/audio_room_screen.dart:53`

**Probleme:** `leaveRoom()` dans dispose peut ne pas s'executer correctement.

**Solution:**
```dart
@override
void dispose() {
  // Appel synchrone pour marquer le depart
  _markUserAsLeaving();
  super.dispose();
}

void _markUserAsLeaving() {
  // Utiliser une Cloud Function pour cleanup
  // Cela garantit le nettoyage meme si l'app crash
  FirebaseFunctions.instance
      .httpsCallable('onUserLeaveRoom')
      .call({'roomId': widget.roomId, 'userId': _currentUserId});
}

// Cloud Function (functions/index.js)
exports.onUserLeaveRoom = functions.https.onCall(async (data, context) => {
  const { roomId, userId } = data;
  
  await admin.firestore()
    .collection('audio_rooms')
    .doc(roomId)
    .collection('participants')
    .doc(userId)
    .update({
      status: 'left',
      leftAt: admin.firestore.FieldValue.serverTimestamp()
    });
});

// Ajouter aussi un cleanup automatique via scheduled function
exports.cleanupStaleParticipants = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const staleThreshold = Date.now() - 2 * 60 * 1000; // 2 minutes
    
    // Nettoyer les participants sans heartbeat recent
    const staleParticipants = await admin.firestore()
      .collectionGroup('participants')
      .where('lastHeartbeat', '<', new Date(staleThreshold))
      .where('status', '==', 'active')
      .get();
    
    const batch = admin.firestore().batch();
    staleParticipants.docs.forEach(doc => {
      batch.update(doc.ref, { status: 'stale' });
    });
    
    await batch.commit();
  });
```

---

#### 3.1.2 Race condition joinRoom

**Fichier:** `lib/features/audio_rooms/presentation/providers/audio_room_provider.dart:268`

**Solution:**
```dart
// Ajouter un mutex/lock
import 'package:mutex/mutex.dart';

class AudioRoomSessionNotifier extends StateNotifier<AudioRoomSessionState> {
  final _joinLock = Mutex();
  bool _isJoining = false;
  
  Future<void> joinRoom(String roomId) async {
    // Eviter les appels concurrents
    if (_isJoining) return;
    
    await _joinLock.protect(() async {
      _isJoining = true;
      try {
        // Annuler l'abonnement precedent
        await _roomSubscription?.cancel();
        _roomSubscription = null;
        
        // Attendre que le document existe
        final roomDoc = await _firestore
            .collection('audio_rooms')
            .doc(roomId)
            .get();
        
        if (!roomDoc.exists) {
          throw Exception('Room not found');
        }
        
        // Maintenant s'abonner
        _roomSubscription = _firestore
            .collection('audio_rooms')
            .doc(roomId)
            .snapshots()
            .listen(_onRoomUpdate);
            
      } finally {
        _isJoining = false;
      }
    });
  }
}
```

---

### 3.2 Strings non localisees

**Action requise:** Ajouter toutes les cles dans les fichiers ARB

```json
// app_en.arb
{
  "saveAsPodcast": "Save as Podcast",
  "publishRecording": "Publish this recording",
  "closeRoom": "Close room",
  "moderationMode": "Moderation Mode (invisible)",
  "noEventFound": "No event found",
  "noGroupFound": "No group found",
  "noEmbassyFound": "No embassy found",
  "userNotConnected": "User not connected",
  "paidRoomsNotAllowed": "Paid rooms are not allowed",
  "send": "Send"
}

// app_fr.arb
{
  "saveAsPodcast": "Sauver comme Podcast",
  "publishRecording": "Publier cet enregistrement",
  "closeRoom": "Fermer le salon",
  "moderationMode": "Mode Moderation (invisible)",
  "noEventFound": "Aucun evenement trouve",
  "noGroupFound": "Aucun groupe trouve",
  "noEmbassyFound": "Aucune ambassade trouvee",
  "userNotConnected": "Utilisateur non connecte",
  "paidRoomsNotAllowed": "Les salons payants ne sont pas autorises",
  "send": "Envoyer"
}
```

---

### 3.3 Transfert d'hote manquant

**Solution:**
```dart
// Ajouter dans audio_room_provider.dart
Future<void> transferHost(String newHostId) async {
  final room = state.room;
  if (room == null) return;
  
  // Verifier que l'utilisateur actuel est l'hote
  if (room.hostId != _currentUserId) {
    throw Exception('Only host can transfer ownership');
  }
  
  await _firestore.collection('audio_rooms').doc(room.id).update({
    'hostId': newHostId,
    'hostTransferredAt': FieldValue.serverTimestamp(),
    'previousHostId': _currentUserId,
  });
}

// Dans leaveRoom(), proposer le transfert si hote
Future<void> leaveRoom() async {
  final room = state.room;
  if (room == null) return;
  
  if (room.hostId == _currentUserId) {
    // Chercher un co-hote ou speaker pour transferer
    final coHosts = room.participants
        .where((p) => p.role == ParticipantRole.coHost || p.role == ParticipantRole.speaker)
        .where((p) => p.id != _currentUserId)
        .toList();
    
    if (coHosts.isNotEmpty) {
      // Transferer au premier co-hote
      await transferHost(coHosts.first.id);
    } else {
      // Pas de successeur, fermer le salon
      await _dataSource.endRoom(room.id);
    }
  }
  
  // Quitter normalement
  await _removeParticipant(_currentUserId);
}
```

---

## 4. Service Podcasts

### 4.1 Erreurs et Bugs

#### 4.1.1 Recherche non scalable

**Fichier:** `lib/features/podcasts/data/datasources/podcast_remote_datasource.dart:341`

**Probleme:** Charge tous les podcasts puis filtre cote client.

**Solution:**
```dart
// Option 1: Utiliser Algolia ou Typesense pour la recherche
// pubspec.yaml: algolia_helper_flutter: ^1.0.0

class PodcastSearchService {
  final SearchClient _algolia;
  
  PodcastSearchService() : _algolia = SearchClient(
    appId: 'YOUR_APP_ID',
    apiKey: 'YOUR_SEARCH_API_KEY',
  );
  
  Future<List<PodcastEntity>> search(String query) async {
    final response = await _algolia.searchIndex(
      indexName: 'podcasts',
      searchQuery: query,
    );
    
    return response.hits.map((hit) => PodcastEntity.fromAlgolia(hit)).toList();
  }
}

// Option 2: Utiliser Firebase Extensions - Search with Algolia
// Ou creer un index manuel avec Cloud Functions

// Option 3: Si petit volume, utiliser array-contains sur des tags
Future<List<PodcastModel>> searchPodcasts(String query) async {
  final queryLower = query.toLowerCase();
  final queryWords = queryLower.split(' ');
  
  // Recherche sur le premier mot (prefixe)
  final snapshot = await _firestore
      .collection('podcasts')
      .where('status', isEqualTo: 'published')
      .where('searchKeywords', arrayContainsAny: queryWords.take(10).toList())
      .limit(20)
      .get();
  
  return snapshot.docs.map((doc) => PodcastModel.fromFirestore(doc)).toList();
}

// Lors de la creation/mise a jour du podcast, generer les keywords
List<String> generateSearchKeywords(String title, String description) {
  final words = <String>{};
  
  // Ajouter le titre en mots
  words.addAll(title.toLowerCase().split(' '));
  
  // Ajouter les prefixes pour autocompletion
  for (final word in title.toLowerCase().split(' ')) {
    for (int i = 1; i <= word.length; i++) {
      words.add(word.substring(0, i));
    }
  }
  
  return words.toList();
}
```

---

#### 4.1.2 Publication sans moderation

**Fichier:** `lib/features/podcasts/presentation/providers/podcast_provider.dart:178`

**Solution:**
```dart
// Changer le workflow de publication
Future<void> createPodcast(PodcastParams params) async {
  // ...
  
  final podcast = PodcastModel(
    // ...
    status: 'pending_review', // Au lieu de 'published'
    // ...
  );
  
  await _firestore.collection('podcasts').doc(podcast.id).set(podcast.toJson());
  
  // Notifier les moderateurs
  await _notifyModerators(podcast.id);
}

// Cloud Function pour auto-moderation basique
exports.onPodcastCreated = functions.firestore
  .document('podcasts/{podcastId}')
  .onCreate(async (snap, context) => {
    const podcast = snap.data();
    
    // Verification automatique basique
    const hasInappropriateContent = await checkContentModeration(
      podcast.title,
      podcast.description
    );
    
    if (hasInappropriateContent) {
      await snap.ref.update({ status: 'rejected', rejectionReason: 'content_policy' });
    } else {
      // Auto-approuver si le createur est verifie
      const creator = await admin.firestore()
        .collection('profiles')
        .doc(podcast.creatorId)
        .get();
      
      if (creator.data()?.isVerified) {
        await snap.ref.update({ status: 'published', publishedAt: new Date() });
      }
      // Sinon reste en pending_review pour moderation manuelle
    }
  });
```

---

### 4.2 Mini-player global manquant

**Solution:** Implementer un service audio global

```dart
// lib/core/services/audio_player_service.dart
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._();
  static AudioPlayerService get instance => _instance;
  
  AudioPlayerService._();
  
  final AudioPlayer _player = AudioPlayer();
  
  // Etat reactif
  final _currentEpisodeController = BehaviorSubject<PodcastEpisodeEntity?>();
  Stream<PodcastEpisodeEntity?> get currentEpisode => _currentEpisodeController.stream;
  
  Stream<Duration> get position => _player.positionStream;
  Stream<Duration?> get duration => _player.durationStream;
  Stream<PlayerState> get playerState => _player.playerStateStream;
  
  Future<void> playEpisode(PodcastEpisodeEntity episode) async {
    _currentEpisodeController.add(episode);
    await _player.setUrl(episode.audioUrl);
    await _player.play();
  }
  
  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> stop() async {
    await _player.stop();
    _currentEpisodeController.add(null);
  }
}

// Provider Riverpod
final audioPlayerServiceProvider = Provider((ref) => AudioPlayerService.instance);

final currentPlayingEpisodeProvider = StreamProvider<PodcastEpisodeEntity?>((ref) {
  return ref.watch(audioPlayerServiceProvider).currentEpisode;
});

// Widget Mini-player a ajouter dans MainShell
class MiniPlayer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(currentPlayingEpisodeProvider).valueOrNull;
    
    if (episode == null) return const SizedBox.shrink();
    
    return Container(
      height: 64,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // Artwork
          CachedNetworkImage(imageUrl: episode.imageUrl, width: 64, height: 64),
          
          // Info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(episode.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(episode.podcastTitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          
          // Controls
          IconButton(
            icon: const Icon(Icons.play_pause),
            onPressed: () {
              final service = ref.read(audioPlayerServiceProvider);
              // Toggle play/pause
            },
          ),
          
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(audioPlayerServiceProvider).stop(),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. Service Marketplace

### 5.1 Bug calcul frais (CRITIQUE)

**Fichier:** `lib/features/marketplace/data/repositories/marketplace_repository_impl.dart:139`

Voir section 1.3 pour la solution detaillee.

---

### 5.2 Commandes sans transaction

**Fichier:** `lib/features/marketplace/presentation/screens/cart_screen.dart:133`

**Solution:**
```dart
// Utiliser un batch ou une transaction
Future<void> checkout(List<CartItem> items) async {
  final batch = _firestore.batch();
  final orderIds = <String>[];
  
  try {
    for (final item in items) {
      // Verifier le stock avant
      final productRef = _firestore.collection('products').doc(item.productId);
      final productSnap = await productRef.get();
      final currentStock = productSnap.data()?['quantity'] ?? 0;
      
      if (currentStock < item.quantity) {
        throw InsufficientStockException(item.productId, currentStock);
      }
      
      // Creer la commande
      final orderRef = _firestore.collection('orders').doc();
      orderIds.add(orderRef.id);
      
      batch.set(orderRef, {
        'id': orderRef.id,
        'productId': item.productId,
        'quantity': item.quantity,
        'status': 'pending_payment',
        // ...
      });
      
      // Decreementer le stock
      batch.update(productRef, {
        'quantity': FieldValue.increment(-item.quantity),
      });
    }
    
    // Commit atomique
    await batch.commit();
    
    // Maintenant traiter le paiement
    await _processPayment(orderIds);
    
  } catch (e) {
    // Rollback si necessaire (les commandes pending seront nettoyees)
    rethrow;
  }
}

class InsufficientStockException implements Exception {
  final String productId;
  final int availableStock;
  
  InsufficientStockException(this.productId, this.availableStock);
  
  @override
  String toString() => 'Stock insuffisant pour $productId: $availableStock disponible(s)';
}
```

---

### 5.3 Compression images manquante

**Solution:**
```dart
// lib/core/services/image_compressor_service.dart
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressorService {
  static Future<File?> compressImage(
    File file, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 85,
  }) async {
    final filePath = file.path;
    final lastIndex = filePath.lastIndexOf('.');
    final extension = filePath.substring(lastIndex);
    final outPath = '${filePath.substring(0, lastIndex)}_compressed$extension';
    
    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outPath,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
    );
    
    return result != null ? File(result.path) : null;
  }
  
  static Future<List<File>> compressImages(List<File> files) async {
    final compressed = <File>[];
    
    for (final file in files) {
      final result = await compressImage(file);
      if (result != null) {
        compressed.add(result);
      }
    }
    
    return compressed;
  }
}

// Utilisation dans create_product_screen.dart
Future<void> _uploadImages() async {
  // Compresser avant upload
  final compressedImages = await ImageCompressorService.compressImages(_selectedImages);
  
  for (final image in compressedImages) {
    final url = await _uploadToStorage(image);
    _imageUrls.add(url);
  }
}
```

---

## 6. Service Annuaire Entreprises

### 6.1 Badge Premium sur boost expire

**Fichier:** `lib/features/businesses/presentation/screens/business_detail_screen.dart:213`

**Solution:**
```dart
// Toujours utiliser isBoostActive au lieu de isBoosted
// Dans business_entity.dart, la methode existe deja:
bool get isBoostActive => isBoosted && 
    boostExpiresAt != null && 
    boostExpiresAt!.isAfter(DateTime.now());

// Remplacer dans business_detail_screen.dart
// Avant
if (business.isBoosted)
  _buildPremiumBadge(),

// Apres
if (business.isBoostActive)
  _buildPremiumBadge(),

// Ajouter une Cloud Function pour nettoyer les boosts expires
exports.cleanupExpiredBoosts = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    
    const expiredBoosts = await admin.firestore()
      .collection('businesses')
      .where('isBoosted', '==', true)
      .where('boostExpiresAt', '<', now)
      .get();
    
    const batch = admin.firestore().batch();
    expiredBoosts.docs.forEach(doc => {
      batch.update(doc.ref, {
        isBoosted: false,
        boostType: null
      });
    });
    
    await batch.commit();
    console.log(`Cleaned up ${expiredBoosts.size} expired boosts`);
  });
```

---

### 6.2 Pagination manquante

**Solution:**
```dart
// Modifier business_provider.dart
class BusinessListNotifier extends StateNotifier<AsyncValue<List<BusinessEntity>>> {
  static const int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  
  Future<void> loadBusinesses({bool refresh = false}) async {
    if (refresh) {
      _lastDocument = null;
      _hasMore = true;
      state = const AsyncValue.loading();
    }
    
    if (!_hasMore) return;
    
    try {
      Query query = _firestore
          .collection('businesses')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      final snapshot = await query.get();
      
      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      
      final newBusinesses = snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc).toEntity())
          .toList();
      
      final currentList = state.valueOrNull ?? [];
      
      if (refresh) {
        state = AsyncValue.data(newBusinesses);
      } else {
        state = AsyncValue.data([...currentList, ...newBusinesses]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  bool get hasMore => _hasMore;
}

// Dans l'UI, utiliser un ScrollController
class _BusinessesScreenState extends ConsumerState<BusinessesScreen> {
  final _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Charger plus si proche du bas
      final notifier = ref.read(businessListProvider.notifier);
      if (notifier.hasMore) {
        notifier.loadBusinesses();
      }
    }
  }
}
```

---

### 6.3 Autocompletion ville

**Solution:**
```dart
// Utiliser Google Places Autocomplete ou une liste predefinies
// Option simple avec liste predefinies pour le Niger

const nigerCities = [
  'Niamey', 'Zinder', 'Maradi', 'Agadez', 'Tahoua',
  'Dosso', 'Diffa', 'Tillaberi', 'Arlit', 'Birni N\'Konni',
];

// Widget autocomplete
class CityAutocomplete extends StatelessWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;
  
  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialValue ?? ''),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return nigerCities;
        }
        return nigerCities.where((city) =>
            city.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: l10n.city,
            prefixIcon: const Icon(Icons.location_city),
          ),
        );
      },
    );
  }
}
```

---

## 7. Service Ambassades

### 7.1 Coordonnees nulles = ocean

**Fichier:** `lib/features/embassies/data/models/embassy_model.dart:157`

**Solution:**
```dart
// Ne pas utiliser 0,0 comme defaut
EmbassyEntity toEntity() {
  return EmbassyEntity(
    // ...
    latitude: latitude, // Garder null si pas de coordonnees
    longitude: longitude,
    hasLocation: latitude != null && longitude != null,
    // ...
  );
}

// Dans l'UI, verifier avant d'afficher la carte
Widget build(BuildContext context) {
  if (!embassy.hasLocation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.location_off),
            const SizedBox(width: 8),
            Text(l10n.locationNotAvailable),
          ],
        ),
      ),
    );
  }
  
  return GoogleMap(
    initialCameraPosition: CameraPosition(
      target: LatLng(embassy.latitude!, embassy.longitude!),
      zoom: 15,
    ),
    // ...
  );
}
```

---

### 7.2 Upload pieces jointes manquant

**Solution:**
```dart
// Ajouter dans administrative_request_screen.dart
class _AdministrativeRequestScreenState extends State<AdministrativeRequestScreen> {
  final List<File> _attachments = [];
  
  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
    );
    
    if (result != null) {
      setState(() {
        _attachments.addAll(result.files.map((f) => File(f.path!)));
      });
    }
  }
  
  Future<List<String>> _uploadAttachments(String requestId) async {
    final urls = <String>[];
    
    for (int i = 0; i < _attachments.length; i++) {
      final file = _attachments[i];
      final ref = FirebaseStorage.instance
          .ref('administrative_requests/$requestId/attachment_$i');
      
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    
    return urls;
  }
  
  // Dans le formulaire, ajouter un bouton
  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.attachments, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._attachments.map((file) => Chip(
              label: Text(file.path.split('/').last),
              onDeleted: () => setState(() => _attachments.remove(file)),
            )),
            ActionChip(
              avatar: const Icon(Icons.add),
              label: Text(l10n.addDocument),
              onPressed: _pickDocument,
            ),
          ],
        ),
        Text(
          l10n.acceptedFormats('PDF, JPG, PNG'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
```

---

## 8. Problemes Transversaux

### 8.1 Localisation (i18n)

**Probleme:** Des centaines de strings sont hardcodees en francais dans tous les services.

**Solution systematique:**

1. **Creer un script pour detecter les strings hardcodees:**
```bash
# Chercher les patterns suspects
grep -rn "Text('" lib/features/ --include="*.dart" | grep -v "l10n\." | grep -v "widget\." > hardcoded_strings.txt
```

2. **Ajouter les cles manquantes dans les fichiers ARB:**
   - `lib/l10n/app_en.arb` (Anglais - reference)
   - `lib/l10n/app_fr.arb` (Francais)

3. **Regenerer les fichiers de localisation:**
```bash
flutter gen-l10n
```

4. **Pattern de remplacement:**
```dart
// Avant
Text('Aucun resultat')

// Apres
Text(AppLocalizations.of(context)!.noResults)
// ou avec l'alias
Text(l10n.noResults)
```

---

### 8.2 Pagination globale

Tous les services chargent des listes completes depuis Firestore. Implementer la pagination partout:

```dart
// Pattern reutilisable
mixin PaginatedListMixin<T> on StateNotifier<AsyncValue<List<T>>> {
  int get pageSize => 20;
  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  
  Future<QuerySnapshot> getPage(Query baseQuery) async {
    Query query = baseQuery.limit(pageSize);
    
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument!);
    }
    
    return query.get();
  }
  
  void processPage(QuerySnapshot snapshot, List<T> Function(QueryDocumentSnapshot) mapper) {
    if (snapshot.docs.length < pageSize) {
      hasMore = false;
    }
    
    if (snapshot.docs.isNotEmpty) {
      lastDocument = snapshot.docs.last;
    }
  }
  
  void reset() {
    lastDocument = null;
    hasMore = true;
  }
}
```

---

### 8.3 Gestion des erreurs coherente

Creer un mapper d'erreurs centralise:

```dart
// lib/core/errors/failure_mapper.dart
String mapFailureToMessage(Failure failure, AppLocalizations l10n) {
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    ServerFailure(:final message) => message ?? l10n.errorServer,
    AuthFailure() => l10n.errorAuth,
    PermissionFailure() => l10n.errorPermission,
    NotFoundFailure() => l10n.errorNotFound,
    ValidationFailure(:final field) => l10n.errorValidation(field),
    _ => l10n.errorUnknown,
  };
}

// Widget reutilisable pour les erreurs
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = error is Failure 
        ? mapFailureToMessage(error as Failure, l10n)
        : l10n.errorUnknown;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## Checklist de correction

### Priorite CRITIQUE (a faire immediatement)
- [ ] Deplacer calculs financiers vers Cloud Functions (Audio Rooms)
- [ ] Corriger bug calcul frais Marketplace
- [ ] Ajouter transactions atomiques pour payouts
- [ ] Securiser collecte donnees carte bancaire

### Priorite HAUTE (semaine 1)
- [ ] Localiser tous les ecrans (300+ strings)
- [ ] Implementer pagination sur toutes les listes
- [ ] Corriger race conditions Audio Rooms
- [ ] Ajouter mini-player global Podcasts

### Priorite MOYENNE (semaine 2-3)
- [ ] Ajouter upload pieces jointes Ambassades
- [ ] Implementer transfert d'hote Audio Rooms
- [ ] Ajouter compression images Marketplace
- [ ] Corriger gestion etats vides partout

### Priorite BASSE (backlog)
- [ ] Autocompletion villes Annuaire
- [ ] Filtres historique Transferts
- [ ] Recherche full-text Marketplace/Podcasts
- [ ] Horaires ouverture Annuaire

---

> **Note:** Ce document doit etre mis a jour au fur et a mesure des corrections.
> Cocher les elements completes et ajouter la date de correction.
