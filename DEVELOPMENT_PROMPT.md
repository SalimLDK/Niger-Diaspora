# 🇳🇪 PROMPT DE DÉVELOPPEMENT - NIGER DIASPORA APP

## 📋 CONTEXTE DU PROJET

Tu es un développeur Flutter senior chargé de développer "Niger Diaspora", une plateforme mobile de mise en relation de la diaspora nigérienne. L'application doit être développée avec **Flutter**, **Riverpod** (state management) et **Firebase** (backend).

---

## 🎯 OBJECTIFS TECHNIQUES

### **Architecture**
- **Clean Architecture** (Domain, Data, Presentation)
- **SOLID Principles**
- **Separation of Concerns**
- **Dependency Injection** avec Riverpod
- **Error Handling** robuste
- **Offline-First** avec cache local

### **Stack Technique**
- **Frontend**: Flutter 3.24+ (Dart 3.5+)
- **State Management**: Riverpod 2.5+
- **Backend**: Firebase
  - Firebase Auth (authentification)
  - Cloud Firestore (base de données)
  - Firebase Storage (fichiers/images)
  - Cloud Functions (logique serveur)
  - Firebase Cloud Messaging (notifications push)
- **Local Storage**: Hive / Shared Preferences
- **Maps**: Google Maps Flutter
- **Routing**: GoRouter
- **DI**: Riverpod

### **Packages Essentiels**
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  
  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  firebase_storage: ^12.3.4
  firebase_messaging: ^15.1.3
  
  # UI
  google_fonts: ^6.2.1
  cached_network_image: ^3.4.1
  shimmer: ^3.0.0
  flutter_svg: ^2.0.10
  
  # Maps
  google_maps_flutter: ^2.9.0
  geolocator: ^13.0.1
  geocoding: ^3.0.0
  
  # Utils
  go_router: ^14.6.2
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  equatable: ^2.0.5
  dartz: ^0.10.1
  intl: ^0.19.0
  
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.3.2
  
  # Image
  image_picker: ^1.1.2
  
  # Networking
  dio: ^5.7.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # Code Generation
  build_runner: ^2.4.12
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.3
  
  # Linting
  flutter_lints: ^4.0.0
  
  # Testing
  mockito: ^5.4.4
  fake_cloud_firestore: ^3.0.3
```

---

## 📁 STRUCTURE DU PROJET (CLEAN ARCHITECTURE)

```
lib/
├── main.dart
├── app.dart
│
├── core/                           # Fonctionnalités transversales
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_assets.dart
│   │   └── firebase_collections.dart
│   ├── errors/
│   │   ├── failures.dart
│   │   └── exceptions.dart
│   ├── network/
│   │   └── network_info.dart
│   ├── utils/
│   │   ├── validators.dart
│   │   ├── date_formatter.dart
│   │   └── image_compressor.dart
│   └── theme/
│       ├── app_theme.dart
│       └── theme_provider.dart
│
├── features/                       # Features de l'app
│   │
│   ├── auth/                      # Feature: Authentication
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_remote_datasource.dart
│   │   │   │   └── auth_local_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── sign_in_with_email.dart
│   │   │       ├── sign_in_with_google.dart
│   │   │       ├── sign_up.dart
│   │   │       ├── sign_out.dart
│   │   │       └── get_current_user.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── auth_provider.dart
│   │       │   └── auth_state.dart
│   │       ├── screens/
│   │       │   ├── splash_screen.dart
│   │       │   ├── login_screen.dart
│   │       │   └── register_screen.dart
│   │       └── widgets/
│   │           ├── custom_text_field.dart
│   │           └── auth_button.dart
│   │
│   ├── profile/                   # Feature: Profil utilisateur
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── profile_remote_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── profile_model.dart
│   │   │   └── repositories/
│   │   │       └── profile_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── profile_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── profile_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_profile.dart
│   │   │       ├── update_profile.dart
│   │   │       └── upload_avatar.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── profile_provider.dart
│   │       ├── screens/
│   │       │   ├── profile_screen.dart
│   │       │   └── edit_profile_screen.dart
│   │       └── widgets/
│   │           ├── profile_avatar.dart
│   │           ├── profile_stat_card.dart
│   │           └── info_section.dart
│   │
│   ├── home/                      # Feature: Accueil
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       │   └── home_screen.dart
│   │       └── widgets/
│   │           ├── profile_card.dart
│   │           ├── feed_card.dart
│   │           └── stat_card.dart
│   │
│   ├── map/                       # Feature: Niger Map (géolocalisation)
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── location_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── user_location_model.dart
│   │   │   └── repositories/
│   │   │       └── location_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user_location_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── location_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_nearby_users.dart
│   │   │       └── update_user_location.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── map_provider.dart
│   │       ├── screens/
│   │       │   └── map_screen.dart
│   │       └── widgets/
│   │           ├── custom_map.dart
│   │           ├── user_marker.dart
│   │           └── filter_chips.dart
│   │
│   ├── messages/                  # Feature: Messagerie
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── messaging_remote_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── conversation_model.dart
│   │   │   │   └── message_model.dart
│   │   │   └── repositories/
│   │   │       └── messaging_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── conversation_entity.dart
│   │   │   │   └── message_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── messaging_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_conversations.dart
│   │   │       ├── send_message.dart
│   │   │       └── mark_as_read.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── conversations_provider.dart
│   │       │   └── chat_provider.dart
│   │       ├── screens/
│   │       │   ├── messages_screen.dart
│   │       │   └── chat_screen.dart
│   │       └── widgets/
│   │           ├── conversation_item.dart
│   │           └── message_bubble.dart
│   │
│   ├── groups/                    # Feature: Groupes
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       │   ├── groups_screen.dart
│   │       │   └── group_details_screen.dart
│   │       └── widgets/
│   │           └── group_card.dart
│   │
│   ├── search/                    # Feature: Recherche
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── events/                    # Feature: Événements
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── settings/                  # Feature: Paramètres
│       ├── data/
│       ├── domain/
│       └── presentation/
│
└── shared/                        # Composants partagés
    ├── widgets/
    │   ├── custom_button.dart
    │   ├── custom_text_field.dart
    │   ├── loading_indicator.dart
    │   ├── error_widget.dart
    │   └── bottom_navigation.dart
    └── providers/
        └── app_state_provider.dart
```

---

## 🔥 PHASE 1: SETUP & CONFIGURATION

### **1.1 Initialisation du projet**

```bash
# Créer le projet Flutter
flutter create niger_diaspora
cd niger_diaspora

# Configuration Firebase
# 1. Créer un projet Firebase (https://console.firebase.google.com)
# 2. Ajouter les apps Android et iOS
# 3. Télécharger google-services.json et GoogleService-Info.plist

# Installer FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurer Firebase automatiquement
flutterfire configure
```

### **1.2 Configuration Firebase**

**Fichier `lib/core/constants/firebase_collections.dart`**:
```dart
class FirebaseCollections {
  static const String users = 'users';
  static const String profiles = 'profiles';
  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String groups = 'groups';
  static const String events = 'events';
  static const String locations = 'user_locations';
  static const String notifications = 'notifications';
}
```

**Firestore Security Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // Profiles collection
    match /profiles/{profileId} {
      allow read: if request.auth != null;
      allow create: if request.auth.uid == profileId;
      allow update, delete: if request.auth.uid == profileId;
    }
    
    // Conversations
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participantIds;
    }
    
    // Messages
    match /conversations/{conversationId}/messages/{messageId} {
      allow read: if request.auth != null && 
        request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
      allow create: if request.auth != null;
    }
    
    // Groups
    match /groups/{groupId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        request.auth.uid in resource.data.adminIds;
    }
    
    // User locations (for map feature)
    match /user_locations/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

### **1.3 Fichier main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  runApp(
    const ProviderScope(
      child: NigerDiasporaApp(),
    ),
  );
}
```

---

## 🎨 PHASE 2: CORE & THEME

### **2.1 Theme Configuration**

**`lib/core/constants/app_colors.dart`**:
```dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color orangePrimary = Color(0xFFFF8C42);
  static const Color orangeLight = Color(0xFFFFB380);
  static const Color orangeDark = Color(0xFFE67A2E);
  
  // Secondary Colors
  static const Color greenPrimary = Color(0xFF4CAF50);
  static const Color greenLight = Color(0xFF80C883);
  static const Color greenDark = Color(0xFF388E3C);
  
  // Neutral Colors
  static const Color beige = Color(0xFFE6D5B8);
  static const Color beigeLight = Color(0xFFF5EFE7);
  static const Color beigeDark = Color(0xFFD4C4A8);
  
  // Text Colors
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMedium = Color(0xFF4A4A4A);
  static const Color textLight = Color(0xFF8A8A8A);
  
  // Base Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFAFAFA);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF4CAF50);
  
  // Gradients
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [orangePrimary, orangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient greenGradient = LinearGradient(
    colors: [greenPrimary, greenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
```

**`lib/core/theme/app_theme.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.orangePrimary,
        secondary: AppColors.greenPrimary,
        surface: AppColors.white,
        background: AppColors.background,
        error: AppColors.error,
      ),
      
      // Typography
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        displayMedium: GoogleFonts.fraunces(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          color: AppColors.textMedium,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: AppColors.textMedium,
        ),
      ),
      
      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.white,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      
      // Card
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: AppColors.white,
      ),
      
      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.beigeDark,
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.beigeDark,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.orangePrimary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
      ),
      
      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orangePrimary,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.orangePrimary,
        unselectedItemColor: AppColors.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
```

---

## 🔐 PHASE 3: AUTHENTICATION FEATURE (COMPLET)

### **3.1 Domain Layer**

**`lib/features/auth/domain/entities/user_entity.dart`**:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

@freezed
class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) = _UserEntity;
}
```

**`lib/features/auth/domain/repositories/auth_repository.dart`**:
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });
  
  Future<Either<Failure, UserEntity>> signInWithGoogle();
  
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  
  Future<Either<Failure, void>> signOut();
  
  Future<Either<Failure, UserEntity?>> getCurrentUser();
  
  Stream<UserEntity?> get authStateChanges;
}
```

**`lib/features/auth/domain/usecases/sign_in_with_email.dart`**:
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInWithEmail {
  final AuthRepository repository;

  SignInWithEmail(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
  }) async {
    return await repository.signInWithEmail(
      email: email,
      password: password,
    );
  }
}
```

### **3.2 Data Layer**

**`lib/features/auth/data/models/user_model.dart`**:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const UserModel._();
  
  const factory UserModel({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastLoginAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      phoneNumber: phoneNumber,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );
  }
}

// Timestamp Converter
class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    return date != null ? Timestamp.fromDate(date) : null;
  }
}
```

**`lib/features/auth/data/datasources/auth_remote_datasource.dart`**:
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });
  
  Future<UserModel> signInWithGoogle();
  
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  
  Future<void> signOut();
  
  Future<UserModel?> getCurrentUser();
  
  Stream<UserModel?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _googleSignIn = googleSignIn;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw ServerException('User is null after sign in');
      }

      // Update last login
      await _updateLastLogin(credential.user!.uid);

      return _mapFirebaseUserToModel(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw ServerException(e.message ?? 'Sign in failed');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw ServerException('Google sign in aborted');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw ServerException('User is null after Google sign in');
      }

      // Create or update user document
      await _createOrUpdateUserDocument(userCredential.user!);

      return _mapFirebaseUserToModel(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      throw ServerException(e.message ?? 'Google sign in failed');
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw ServerException('User is null after sign up');
      }

      // Update display name
      await credential.user!.updateDisplayName(displayName);

      // Create user document in Firestore
      await _createOrUpdateUserDocument(credential.user!);

      return _mapFirebaseUserToModel(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw ServerException(e.message ?? 'Sign up failed');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw ServerException('Sign out failed');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return _mapFirebaseUserToModel(user);
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) return null;
      return _mapFirebaseUserToModel(user);
    });
  }

  // Helper methods
  UserModel _mapFirebaseUserToModel(User user) {
    return UserModel(
      id: user.uid,
      email: user.email!,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      phoneNumber: user.phoneNumber,
      createdAt: user.metadata.creationTime,
      lastLoginAt: user.metadata.lastSignInTime,
    );
  }

  Future<void> _createOrUpdateUserDocument(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    
    final docSnapshot = await userDoc.get();
    
    if (!docSnapshot.exists) {
      // Create new user document
      await userDoc.set({
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'phoneNumber': user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Update last login
      await userDoc.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _updateLastLogin(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }
}
```

**`lib/features/auth/data/repositories/auth_repository_impl.dart`**:
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      final userModel = await remoteDataSource.signInWithGoogle();
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userModel = await remoteDataSource.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final userModel = await remoteDataSource.getCurrentUser();
      return Right(userModel?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return remoteDataSource.authStateChanges.map((userModel) {
      return userModel?.toEntity();
    });
  }
}
```

### **3.3 Presentation Layer**

**`lib/features/auth/presentation/providers/auth_provider.dart`**:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/sign_out.dart';
import 'auth_state.dart';

part 'auth_provider.g.dart';

// Repository Provider
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  final remoteDataSource = AuthRemoteDataSourceImpl(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    googleSignIn: GoogleSignIn(),
  );

  return AuthRepositoryImpl(remoteDataSource: remoteDataSource);
}

// Use Cases Providers
@riverpod
SignInWithEmail signInWithEmailUseCase(SignInWithEmailUseCaseRef ref) {
  return SignInWithEmail(ref.watch(authRepositoryProvider));
}

@riverpod
SignInWithGoogle signInWithGoogleUseCase(SignInWithGoogleUseCaseRef ref) {
  return SignInWithGoogle(ref.watch(authRepositoryProvider));
}

@riverpod
SignUp signUpUseCase(SignUpUseCaseRef ref) {
  return SignUp(ref.watch(authRepositoryProvider));
}

@riverpod
SignOut signOutUseCase(SignOutUseCaseRef ref) {
  return SignOut(ref.watch(authRepositoryProvider));
}

// Auth State Provider
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    _listenToAuthChanges();
    return const AuthState.initial();
  }

  void _listenToAuthChanges() {
    ref.listen(authRepositoryProvider, (previous, next) {
      next.authStateChanges.listen((user) {
        if (user != null) {
          state = AuthState.authenticated(user);
        } else {
          state = const AuthState.unauthenticated();
        }
      });
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthState.loading();

    final result = await ref.read(signInWithEmailUseCaseProvider).call(
          email: email,
          password: password,
        );

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (user) => state = AuthState.authenticated(user),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AuthState.loading();

    final result = await ref.read(signInWithGoogleUseCaseProvider).call();

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (user) => state = AuthState.authenticated(user),
    );
  }

  Future<void> signUp(String email, String password, String displayName) async {
    state = const AuthState.loading();

    final result = await ref.read(signUpUseCaseProvider).call(
          email: email,
          password: password,
          displayName: displayName,
        );

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (user) => state = AuthState.authenticated(user),
    );
  }

  Future<void> signOut() async {
    final result = await ref.read(signOutUseCaseProvider).call();

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (_) => state = const AuthState.unauthenticated(),
    );
  }
}

// Current User Provider
@riverpod
Stream<UserEntity?> currentUser(CurrentUserRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}
```

**`lib/features/auth/presentation/providers/auth_state.dart`**:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/user_entity.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(UserEntity user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.error(String message) = _Error;
}
```

**`lib/features/auth/presentation/screens/login_screen.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      ref.read(authNotifierProvider.notifier).signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }

  void _handleGoogleSignIn() {
    ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        authenticated: (_) => context.go('/home'),
        error: (message) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        ),
      );
    });

    return Scaffold(
      backgroundColor: AppColors.beigeLight,
      body: SafeArea(
        child: authState.maybeWhen(
          loading: () => const Center(child: CircularProgressIndicator()),
          orElse: () => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.orangeGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        '🇳🇪',
                        style: TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'Bienvenue',
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Rejoins la diaspora nigérienne',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMedium,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Social Sign In
                  AuthButton(
                    onPressed: _handleGoogleSignIn,
                    icon: '🔍',
                    label: 'Continuer avec Google',
                    backgroundColor: AppColors.white,
                    textColor: AppColors.textDark,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'ou',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textLight,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Email Field
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre email';
                      }
                      if (!value.contains('@')) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password Field
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Mot de passe',
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre mot de passe';
                      }
                      if (value.length < 6) {
                        return 'Le mot de passe doit contenir au moins 6 caractères';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Login Button
                  CustomButton(
                    onPressed: _handleLogin,
                    label: 'Se connecter',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pas encore de compte ? ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textLight,
                            ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          "S'inscrire",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.orangePrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 📱 PHASE 4: FEATURES PRINCIPALES

Continue le développement avec les mêmes principes Clean Architecture pour:

### **4.1 Profile Feature**
- CRUD opérations sur profil utilisateur
- Upload/Update photo de profil
- Gestion des préférences

### **4.2 Map Feature (Niger Map)**
- Intégration Google Maps
- Géolocalisation en temps réel
- Filtres et recherche de proximité
- Markers personnalisés

### **4.3 Messaging Feature**
- Chat en temps réel avec Firestore
- Notifications push
- Support images/fichiers
- Indicateurs de lecture

### **4.4 Groups Feature**
- Création/gestion de groupes
- Publications et commentaires
- Membres et admins

### **4.5 Events Feature**
- Calendrier d'événements
- RSVP et participation
- Géolocalisation des événements

---

## 🎨 BONNES PRATIQUES & GUIDELINES

### **Code Quality**
1. **Suivre les principes SOLID**
2. **Utiliser Freezed pour immutabilité**
3. **Validation des inputs**
4. **Error handling avec Either (dartz)**
5. **Logging avec logger package**
6. **Documentation des fonctions complexes**

### **State Management avec Riverpod**
1. **Un Provider par use case**
2. **StateNotifier pour états complexes**
3. **AutoDispose pour mémoire**
4. **Family pour providers paramétrés**

### **Performance**
1. **Lazy loading des listes**
2. **Pagination Firestore**
3. **Cache images avec cached_network_image**
4. **Optimistic UI updates**

### **Sécurité**
1. **Validation côté client ET serveur**
2. **Firestore Security Rules strictes**
3. **Jamais exposer les clés API**
4. **Sanitize user inputs**

### **Testing**
```dart
// Unit Tests
test/unit/
├── auth/
│   ├── repositories/
│   ├── usecases/
│   └── providers/

// Widget Tests
test/widget/
├── screens/
└── widgets/

// Integration Tests
integration_test/
└── app_test.dart
```

---

## 🚀 COMMANDES DE DÉVELOPPEMENT

```bash
# Code generation (après modifications de models/providers)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode (auto-rebuild)
flutter pub run build_runner watch --delete-conflicting-outputs

# Linting
flutter analyze

# Tests
flutter test

# Integration tests
flutter test integration_test

# Build Android
flutter build apk --release

# Build iOS
flutter build ios --release
```

---

## 📝 ORDRE DE DÉVELOPPEMENT RECOMMANDÉ

### **Sprint 1 (Semaine 1-2): Foundation**
1. Setup projet et Firebase
2. Core (theme, constants, errors)
3. Auth feature complet
4. Bottom Navigation
5. Routing avec GoRouter

### **Sprint 2 (Semaine 3-4): Core Features**
6. Profile feature
7. Home screen (feed basique)
8. Search/Discovery

### **Sprint 3 (Semaine 5-6): Social Features**
9. Messaging (1-to-1)
10. Groups
11. Events

### **Sprint 4 (Semaine 7-8): Advanced Features**
12. Niger Map (géolocalisation)
13. Notifications push
14. Offline support

### **Sprint 5 (Semaine 9-10): Polish & Deploy**
15. Testing complet
16. Performance optimization
17. Bug fixes
18. App Store deployment

---

## ✅ CHECKLIST QUALITÉ

Avant chaque commit, vérifie:
- [ ] Code formatté (`flutter format .`)
- [ ] Pas d'erreurs lint (`flutter analyze`)
- [ ] Tests passent (`flutter test`)
- [ ] Documentation à jour
- [ ] Pas de TODO non résolu
- [ ] Performance acceptable (< 60fps)
- [ ] Accessible (contrast, tap targets)

---

## 🎯 RÉSUMÉ

**Tu développes une app Flutter avec:**
- ✅ Clean Architecture (3 layers)
- ✅ Riverpod pour state management
- ✅ Firebase pour backend
- ✅ Freezed pour immutabilité
- ✅ GoRouter pour navigation
- ✅ Error handling avec Either
- ✅ Code generation
- ✅ Tests (unit, widget, integration)

**Principes clés:**
1. **Separation of Concerns** - Chaque couche a sa responsabilité
2. **Dependency Injection** - via Riverpod providers
3. **Immutability** - avec Freezed
4. **Error Handling** - Either<Failure, Success>
5. **Clean Code** - Lisible, maintenable, testable

**Commence par l'auth feature** (exemple complet fourni), puis reproduis la même structure pour les autres features.

Bon développement ! 🚀
