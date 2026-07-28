# Documentation des APIs Internes - Diaspo Niger

## Table des matières

1. [Services Core](#services-core)
2. [Gestion des Erreurs](#gestion-des-erreurs)
3. [Feature: Authentication](#feature-authentication)
4. [Feature: Profile](#feature-profile)
5. [Feature: Groups](#feature-groups)
6. [Feature: Messages](#feature-messages)
7. [Feature: Search](#feature-search)
8. [Feature: Legal](#feature-legal)
9. [Feature: Home](#feature-home)
10. [Providers Riverpod](#providers-riverpod)

---

## Services Core

### ConnectivityService

Service de gestion de la connectivité réseau.

```dart
class ConnectivityService {
  static ConnectivityService get instance;

  /// Vérifie si l'appareil est connecté
  Future<bool> isConnected();

  /// Stream des changements de connectivité
  Stream<bool> onConnectivityChanged;
}
```

**Usage:**
```dart
final isOnline = await ConnectivityService.instance.isConnected();
```

---

### CacheService

Service de mise en cache local avec Hive.

```dart
class CacheService {
  static CacheService get instance;

  /// Cache le profil utilisateur
  Future<void> cacheProfile(ProfileModel profile);

  /// Récupère le profil mis en cache
  ProfileModel? getCachedProfile(String userId);

  /// Cache le contenu légal
  Future<void> cacheLegalContent(String type, Map<String, dynamic> data);

  /// Récupère le contenu légal mis en cache
  Map<String, dynamic>? getCachedLegalContent(String type);

  /// Efface tout le cache
  Future<void> clearAll();
}
```

---

### AnalyticsService

Service d'analytics avec Firebase Analytics.

```dart
class AnalyticsService {
  static AnalyticsService get instance;

  /// Log un événement personnalisé
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]);

  /// Log une vue d'écran
  Future<void> logScreenView(String screenName, {String? screenClass});

  /// Log une recherche
  Future<void> logSearch(String searchTerm);

  /// Log une erreur
  Future<void> logError(String error, {String? stackTrace});

  // === Funnels ===

  /// Log une étape du funnel d'onboarding
  Future<void> logOnboardingStep(OnboardingStep step);

  /// Log une étape du funnel e-commerce
  Future<void> logEcommerceStep(EcommerceStep step, {Map<String, dynamic>? params});

  /// Log une étape du funnel de transfert
  Future<void> logTransferStep(TransferStep step, {Map<String, dynamic>? params});

  // === User Properties ===

  Future<void> setUserProperty(String name, String value);
  Future<void> setUserId(String? userId);
}
```

**Enums:**
```dart
enum OnboardingStep { started, profileCreated, interestsSelected, completed }
enum EcommerceStep { viewProduct, addToCart, startCheckout, completeCheckout }
enum TransferStep { initiated, recipientSelected, amountEntered, confirmed, completed }
```

---

### OfflineSyncService

Service de synchronisation hors-ligne.

```dart
class OfflineSyncService {
  static OfflineSyncService get instance;

  /// Ajoute une action à la file d'attente
  Future<void> addPendingAction(PendingAction action);

  /// Synchronise toutes les actions en attente
  Future<SyncResult> syncPendingActions();

  /// Stream du statut de synchronisation
  Stream<SyncStatus> get syncStatusStream;

  /// Nombre d'actions en attente
  int get pendingActionsCount;

  /// Efface la file d'attente
  Future<void> clearPendingActions();
}

class PendingAction {
  final String id;
  final String type; // 'create', 'update', 'delete'
  final String collection;
  final String? documentId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
}

class SyncStatus {
  final bool isSyncing;
  final int pendingCount;
  final int syncedCount;
  final String? lastError;
}
```

---

### DeepLinkService

Service de génération et gestion des liens dynamiques.

```dart
class DeepLinkService {
  static DeepLinkService get instance;

  /// Génère un lien de profil
  Future<String> generateProfileLink(String userId, {String? displayName});

  /// Génère un lien de groupe
  Future<String> generateGroupLink(String groupId, {String? groupName});

  /// Génère un lien d'événement
  Future<String> generateEventLink(String eventId, {String? eventName});

  /// Génère un lien de commerce
  Future<String> generateBusinessLink(String businessId, {String? businessName});

  /// Génère un lien de produit
  Future<String> generateProductLink(String productId, {String? productName});

  /// Partage un lien
  Future<void> shareLink(String link, {String? subject, String? text});

  /// Écoute les liens entrants
  Stream<Uri> get incomingLinks;
}
```

---

## Gestion des Erreurs

### ErrorHandler

Gestionnaire centralisé des erreurs.

```dart
class ErrorHandler {
  /// Convertit une exception en Failure user-friendly
  static Failure handleException(dynamic exception);

  /// Log une erreur avec contexte
  static void logError(dynamic error, StackTrace? stackTrace, {String? context});

  /// Affiche un snackbar d'erreur
  static void showErrorSnackbar(BuildContext context, Failure failure);
}
```

### AppErrorMessages

Messages d'erreur localisés (FR/EN).

```dart
class AppErrorMessages {
  /// Définit la locale (fr/en)
  static void setLocale(Locale locale);

  // Erreurs générales
  static String get unexpectedError;
  static String get serverError;
  static String get networkError;

  // Erreurs d'authentification
  static String get userNotFound;
  static String get wrongPassword;
  static String get invalidEmail;
  static String get emailAlreadyInUse;
  static String get weakPassword;
  static String get tooManyRequests;

  // Erreurs spécifiques
  static String get profileNotFound;
  static String get groupNotFound;
  static String get eventNotFound;
  static String get productNotAvailable;
  static String get transferFailed;

  // Messages offline
  static String get offlineMode;
  static String get syncInProgress;
  static String get syncComplete;
  static String pendingChanges(int count);

  // Helpers
  static String format(String message, Map<String, String> params);
  static String fromCode(String code);
}
```

### Failures

Types d'erreurs du domaine.

```dart
abstract class Failure {
  final String message;
}

class ServerFailure extends Failure {}
class NetworkFailure extends Failure {}
class CacheFailure extends Failure {}
class AuthFailure extends Failure {}
class ValidationFailure extends Failure {}
class PermissionFailure extends Failure {}
```

---

## Feature: Authentication

### AuthRemoteDataSource

```dart
abstract class AuthRemoteDataSource {
  /// Connexion avec email/mot de passe
  Future<UserModel> signInWithEmailAndPassword(String email, String password);

  /// Inscription
  Future<UserModel> signUpWithEmailAndPassword(String email, String password, String displayName);

  /// Connexion avec Google
  Future<UserModel> signInWithGoogle();

  /// Déconnexion
  Future<void> signOut();

  /// Récupère l'utilisateur actuel
  Future<UserModel?> getCurrentUser();

  /// Stream de l'état d'authentification
  Stream<UserModel?> get authStateChanges;

  /// Envoie un email de réinitialisation
  Future<void> sendPasswordResetEmail(String email);

  /// Met à jour le profil
  Future<void> updateProfile({String? displayName, String? photoUrl});
}
```

### AuthRepository

```dart
abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Either<Failure, UserEntity>> signInWithGoogle();

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, UserEntity?>> getCurrentUser();

  Stream<UserEntity?> get authStateChanges;

  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
}
```

### Providers

```dart
// État de l'utilisateur actuel
final currentUserProvider = StreamProvider<UserEntity?>((ref) => ...);

// Notifier pour les actions d'authentification
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(() => ...);

// Méthodes du AuthNotifier
class AuthNotifier {
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password, String displayName);
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
}
```

---

## Feature: Profile

### ProfileRemoteDataSource

```dart
abstract class ProfileRemoteDataSource {
  /// Récupère un profil par ID
  Future<ProfileModel> getProfile(String userId);

  /// Met à jour un profil
  Future<void> updateProfile(ProfileModel profile);

  /// Recherche des profils
  Future<List<ProfileModel>> searchProfiles(String query);

  /// Récupère les profils à proximité
  Future<List<ProfileModel>> getNearbyProfiles(double lat, double lng, double radius);

  /// Upload une photo de profil
  Future<String> uploadProfilePhoto(String userId, File photo);
}
```

### ProfileRepository

```dart
abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile(String userId);
  Future<Either<Failure, void>> updateProfile(ProfileEntity profile);
  Future<Either<Failure, List<ProfileEntity>>> searchProfiles(String query);
  Future<Either<Failure, List<ProfileEntity>>> getNearbyProfiles({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  });
  Future<Either<Failure, String>> uploadProfilePhoto(String userId, File photo);
}
```

---

## Feature: Groups

### GroupRemoteDataSource

```dart
abstract class GroupRemoteDataSource {
  Future<GroupModel> getGroup(String groupId);
  Future<List<GroupModel>> getUserGroups(String userId);
  Future<List<GroupModel>> searchGroups(String query);
  Future<GroupModel> createGroup(GroupModel group);
  Future<void> updateGroup(GroupModel group);
  Future<void> deleteGroup(String groupId);
  Future<void> joinGroup(String groupId, String userId);
  Future<void> leaveGroup(String groupId, String userId);
  Future<List<GroupMemberModel>> getGroupMembers(String groupId);
}
```

### GroupRepository

```dart
abstract class GroupRepository {
  Future<Either<Failure, GroupEntity>> getGroup(String groupId);
  Future<Either<Failure, List<GroupEntity>>> getUserGroups(String userId);
  Future<Either<Failure, List<GroupEntity>>> searchGroups(String query);
  Future<Either<Failure, GroupEntity>> createGroup(GroupEntity group);
  Future<Either<Failure, void>> updateGroup(GroupEntity group);
  Future<Either<Failure, void>> deleteGroup(String groupId);
  Future<Either<Failure, void>> joinGroup(String groupId, String userId);
  Future<Either<Failure, void>> leaveGroup(String groupId, String userId);
}
```

---

## Feature: Messages

> ⚠️ **Section périmée (vérifié le 2026-07-25)** : décrite ici comme un `MessageRemoteDataSource` purement Firestore/RTDB, sans aucune mention de Supabase. Depuis la migration actée par l'[ADR messagerie](ADR-messaging-source-of-truth.md) (2026-07-15), Supabase est la source de vérité du stockage et du temps réel des messages ; Firebase RTDB ne joue plus qu'un rôle résiduel. Les signatures ci-dessous ne reflètent pas l'implémentation actuelle — se référer au code (`lib/features/messages/data/`) plutôt qu'à ce document.

### MessageRemoteDataSource

```dart
abstract class MessageRemoteDataSource {
  /// Récupère les conversations d'un utilisateur
  Future<List<ConversationModel>> getConversations(String userId);

  /// Récupère les messages d'une conversation
  Future<List<MessageModel>> getMessages(String conversationId, {int limit = 50});

  /// Envoie un message
  Future<MessageModel> sendMessage(MessageModel message);

  /// Marque une conversation comme lue
  Future<void> markAsRead(String conversationId, String userId);

  /// Recherche dans les conversations
  Future<List<ConversationModel>> searchConversations(String userId, String query);

  /// Stream des messages en temps réel
  Stream<List<MessageModel>> getMessagesStream(String conversationId);

  /// Stream des conversations en temps réel
  Stream<List<ConversationModel>> getConversationsStream(String userId);
}
```

### MessageRepository

```dart
abstract class MessageRepository {
  Future<Either<Failure, List<ConversationEntity>>> getConversations(String userId);
  Future<Either<Failure, List<MessageEntity>>> getMessages(String conversationId);
  Future<Either<Failure, MessageEntity>> sendMessage(MessageEntity message);
  Future<Either<Failure, void>> markAsRead(String conversationId, String userId);
  Stream<List<ConversationEntity>> watchConversations(String userId);
  Stream<List<MessageEntity>> watchMessages(String conversationId);
}
```

---

## Feature: Search

### SearchRemoteDataSource

```dart
abstract class SearchRemoteDataSource {
  /// Recherche globale
  Future<SearchResultModel> searchAll({
    required String query,
    String? userId,
    int limit = 20,
  });

  /// Recherche de profils
  Future<List<ProfileModel>> searchProfiles({required String query, int limit = 20});

  /// Recherche de groupes
  Future<List<GroupModel>> searchGroups({required String query, int limit = 20});

  /// Recherche d'amis
  Future<List<FriendModel>> searchFriends({
    required String userId,
    required String query,
    int limit = 20,
  });

  /// Recherche de conversations
  Future<List<ConversationModel>> searchConversations({
    required String userId,
    required String query,
    int limit = 20,
  });

  /// Gestion des recherches récentes
  Future<List<String>> getRecentSearches({required String userId, int limit = 10});
  Future<void> saveRecentSearch({required String userId, required String query});
  Future<void> removeRecentSearch({required String userId, required String query});
  Future<void> clearRecentSearches({required String userId});
}
```

### SearchRepository

```dart
abstract class SearchRepository {
  Future<Either<Failure, SearchResult>> searchAll({
    required String query,
    required String? userId,
    int limit = 20,
  });

  Future<Either<Failure, List<ProfileModel>>> searchProfiles({
    required String query,
    int limit = 20,
  });

  Future<Either<Failure, List<GroupEntity>>> searchGroups({
    required String query,
    int limit = 20,
  });

  Future<Either<Failure, List<FriendEntity>>> searchFriends({
    required String userId,
    required String query,
    int limit = 20,
  });

  Future<Either<Failure, List<ConversationEntity>>> searchConversations({
    required String userId,
    required String query,
    int limit = 20,
  });

  Future<Either<Failure, List<String>>> getRecentSearches({
    required String userId,
    int limit = 10,
  });

  Future<Either<Failure, void>> saveRecentSearch({
    required String userId,
    required String query,
  });

  Future<Either<Failure, void>> clearRecentSearches({required String userId});
}
```

### Use Cases

```dart
class SearchAll {
  Future<Either<Failure, SearchResult>> call({
    required String query,
    required String? userId,
    int limit = 20,
  });
}

class SearchProfiles {
  Future<Either<Failure, List<ProfileModel>>> call({
    required String query,
    int limit = 20,
  });
}

class SearchGroups {
  Future<Either<Failure, List<GroupEntity>>> call({
    required String query,
    int limit = 20,
  });
}

class ManageRecentSearches {
  Future<Either<Failure, List<String>>> getRecent({required String userId});
  Future<Either<Failure, void>> save({required String userId, required String query});
  Future<Either<Failure, void>> remove({required String userId, required String query});
  Future<Either<Failure, void>> clearAll({required String userId});
}
```

---

## Feature: Legal

### LegalRemoteDataSource

```dart
abstract class LegalRemoteDataSource {
  /// Récupère les CGU
  Future<LegalContentModel> getTerms();

  /// Récupère la politique de confidentialité
  Future<LegalContentModel> getPrivacyPolicy();

  /// Récupère le code de conduite
  Future<LegalContentModel> getCodeOfConduct();

  /// Récupère l'acceptation de l'utilisateur
  Future<UserLegalAcceptance?> getUserAcceptance(String userId);

  /// Sauvegarde l'acceptation
  Future<void> saveUserAcceptance(String userId, UserLegalAcceptance acceptance);

  /// Vérifie si l'utilisateur doit accepter
  Future<bool> needsAcceptance(String userId);
}
```

### LegalRepository

```dart
abstract class LegalRepository {
  Future<Either<Failure, LegalContent>> getTerms();
  Future<Either<Failure, LegalContent>> getPrivacyPolicy();
  Future<Either<Failure, LegalContent>> getCodeOfConduct();
  Future<Either<Failure, LegalContent>> getLegalContent(LegalContentType type);
  Future<Either<Failure, List<LegalContent>>> getAllLegalContent();
  Future<Either<Failure, LegalAcceptance?>> getUserAcceptance(String userId);
  Future<Either<Failure, void>> saveUserAcceptance({
    required String userId,
    required LegalAcceptance acceptance,
  });
  Future<Either<Failure, LegalAcceptanceStatus>> checkAcceptanceStatus(String userId);
  Future<Either<Failure, bool>> needsAcceptance(String userId);
}
```

### Entities

```dart
@freezed
class LegalContent {
  final String id;
  final LegalContentType type;
  final String title;
  final String version;
  final List<LegalSection> sections;
  final DateTime updatedAt;
  final String? summary;

  bool get isRecentlyUpdated;
  String get fullContent;
}

enum LegalContentType { terms, privacy, conduct }

enum LegalAcceptanceStatus { neverAccepted, needsUpdate, upToDate }

@freezed
class LegalAcceptance {
  final String termsVersion;
  final String privacyVersion;
  final DateTime acceptedAt;
  final String? conductVersion;

  bool isUpToDate({...});
}
```

### Providers

```dart
// DataSource
final legalDataSourceProvider = Provider<LegalRemoteDataSource>((ref) => ...);

// Contenus légaux
final termsProvider = FutureProvider<LegalContentModel>((ref) => ...);
final privacyPolicyProvider = FutureProvider<LegalContentModel>((ref) => ...);
final codeOfConductProvider = FutureProvider<LegalContentModel>((ref) => ...);

// Vérification acceptation
final needsLegalAcceptanceProvider = FutureProvider<bool>((ref) => ...);

// Notifier pour accepter les conditions
final legalAcceptanceNotifierProvider = AsyncNotifierProvider<LegalAcceptanceNotifier, void>(() => ...);

class LegalAcceptanceNotifier {
  Future<void> acceptTerms();
}
```

---

## Feature: Home

### HomeRemoteDataSource

```dart
abstract class HomeRemoteDataSource {
  /// Récupère le contenu de la page d'accueil
  Future<HomeContentModel> getHomeContent(String userId);

  /// Récupère les statistiques
  Future<HomeStatsModel> getHomeStats(String userId);

  /// Récupère les membres à proximité
  Future<List<NearbyMemberModel>> getNearbyMembers({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 10,
  });

  /// Récupère les événements à venir
  Future<List<UpcomingEventModel>> getUpcomingEvents({
    required String userId,
    int limit = 5,
  });

  /// Récupère les actions rapides personnalisées
  Future<List<QuickActionModel>> getQuickActions(String userId);
}
```

### HomeRepository

```dart
abstract class HomeRepository {
  Future<Either<Failure, HomeContent>> getHomeContent(String userId);
  Future<Either<Failure, HomeStats>> getHomeStats(String userId);
  Future<Either<Failure, List<NearbyMember>>> getNearbyMembers({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 10,
  });
  Future<Either<Failure, List<UpcomingEvent>>> getUpcomingEvents({
    required String userId,
    int limit = 5,
  });
  Future<Either<Failure, List<QuickAction>>> getQuickActions(String userId);
  Future<Either<Failure, void>> refreshHomeContent(String userId);
}
```

### Entities

```dart
@freezed
class HomeContent {
  final String userId;
  final HomeStats? stats;
  final List<NearbyMember> nearbyMembers;
  final List<UpcomingEvent> upcomingEvents;
  final List<QuickAction> quickActions;
  final DateTime lastUpdated;
}

@freezed
class HomeStats {
  final int totalMembers;
  final int totalGroups;
  final int totalEvents;
  final int unreadMessages;
  final int pendingFriendRequests;
  final int nearbyMembersCount;
}

@freezed
class NearbyMember {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? city;
  final double distanceKm;
  final bool isOnline;
}

@freezed
class UpcomingEvent {
  final String eventId;
  final String title;
  final DateTime startDate;
  final String? location;
  final String? imageUrl;
  final int participantsCount;
}

@freezed
class QuickAction {
  final String id;
  final String label;
  final String iconName;
  final String route;
  final int order;
  final bool isEnabled;
}
```

---

## Providers Riverpod

### Configuration globale

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Patterns communs

#### AsyncValue handling

```dart
// Dans les widgets
ref.watch(someProvider).when(
  data: (data) => DataWidget(data),
  loading: () => const CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error.toString()),
);
```

#### Invalidation et refresh

```dart
// Rafraîchir un provider
ref.invalidate(someProvider);

// Ou avec refresh
ref.refresh(someProvider);
```

#### Écouter les changements

```dart
ref.listen<AsyncValue<SomeType>>(someProvider, (previous, next) {
  next.whenOrNull(
    error: (error, stack) {
      // Afficher un snackbar d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    },
  );
});
```

---

## Collections Firebase

```dart
class FirebaseCollections {
  static const String users = 'users';
  static const String profiles = 'profiles';
  static const String groups = 'groups';
  static const String events = 'events';
  static const String messages = 'messages';
  static const String conversations = 'conversations';
  static const String friends = 'friends';
  static const String businesses = 'businesses';
  static const String products = 'products';
  static const String transfers = 'transfers';
  static const String notifications = 'notifications';
  static const String legalContent = 'legal_content';
  static const String appConfig = 'app_config';
}
```

---

## Notes importantes

### Génération de code

Après modification des fichiers utilisant `freezed` ou `riverpod_annotation`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Pattern Either (dartz)

Toutes les méthodes de repository retournent `Either<Failure, T>`:

```dart
final result = await repository.getData();
result.fold(
  (failure) => // Gérer l'erreur,
  (data) => // Utiliser les données,
);
```

### Clean Architecture

Structure des features:
```
lib/features/{feature_name}/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── providers/
    ├── screens/
    └── widgets/
```
