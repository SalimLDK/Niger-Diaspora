import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../models/legal_content_model.dart';

abstract class LegalRemoteDataSource {
  Future<LegalContentModel> getTerms();
  Future<LegalContentModel> getPrivacyPolicy();
  Future<LegalContentModel> getCodeOfConduct();
  Future<UserLegalAcceptance?> getUserAcceptance(String userId);
  Future<void> saveUserAcceptance(String userId, UserLegalAcceptance acceptance);
  Future<bool> needsAcceptance(String userId);
}

class LegalRemoteDataSourceImpl implements LegalRemoteDataSource {
  final FirebaseFirestore _firestore;
  final CacheService _cache = CacheService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  LegalRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _legalCollection =>
      _firestore.collection(FirebaseCollections.legalContent);

  @override
  Future<LegalContentModel> getTerms() async {
    return _getLegalContent('terms');
  }

  @override
  Future<LegalContentModel> getPrivacyPolicy() async {
    return _getLegalContent('privacy');
  }

  @override
  Future<LegalContentModel> getCodeOfConduct() async {
    return _getLegalContent('conduct');
  }

  Future<LegalContentModel> _getLegalContent(String type) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final doc = await _legalCollection.doc(type).get();

        if (!doc.exists) {
          throw ServerException('Contenu légal non trouvé');
        }

        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Convertir les timestamps
        if (data['updatedAt'] is Timestamp) {
          data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toUtc().toIso8601String();
        }

        // Convertir les sections
        if (data['sections'] is List) {
          data['sections'] = (data['sections'] as List).map((s) {
            if (s is Map<String, dynamic>) {
              return s;
            }
            return <String, dynamic>{};
          }).toList();
        }

        final content = LegalContentModel.fromJson(data);

        // Mettre en cache
        await _cache.cacheLegalContent(type, content.toJson());

        return content;
      } else {
        // Mode hors ligne
        final cachedData = _cache.getCachedLegalContent(type);
        if (cachedData != null) {
          return LegalContentModel.fromJson(cachedData);
        }
        throw ServerException('Contenu non disponible hors ligne');
      }
    } on FirebaseException catch (e) {
      final cachedData = _cache.getCachedLegalContent(type);
      if (cachedData != null) {
        return LegalContentModel.fromJson(cachedData);
      }
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<UserLegalAcceptance?> getUserAcceptance(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || data['legalAcceptance'] == null) return null;

      final acceptanceData = data['legalAcceptance'] as Map<String, dynamic>;

      // Convertir le timestamp
      if (acceptanceData['acceptedAt'] is Timestamp) {
        acceptanceData['acceptedAt'] =
            (acceptanceData['acceptedAt'] as Timestamp).toDate().toUtc().toIso8601String();
      }

      return UserLegalAcceptance.fromJson(acceptanceData);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<void> saveUserAcceptance(String userId, UserLegalAcceptance acceptance) async {
    try {
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .update({
        'legalAcceptance': {
          'termsVersion': acceptance.termsVersion,
          'privacyVersion': acceptance.privacyVersion,
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la sauvegarde');
    }
  }

  @override
  Future<bool> needsAcceptance(String userId) async {
    try {
      // Récupérer les versions actuelles
      final termsDoc = await _legalCollection.doc('terms').get();
      final privacyDoc = await _legalCollection.doc('privacy').get();

      if (!termsDoc.exists || !privacyDoc.exists) {
        return false; // Pas de contenu légal, pas besoin d'acceptation
      }

      final termsVersion = (termsDoc.data() as Map<String, dynamic>)['version'] as String?;
      final privacyVersion = (privacyDoc.data() as Map<String, dynamic>)['version'] as String?;

      // Récupérer l'acceptation de l'utilisateur
      final userAcceptance = await getUserAcceptance(userId);

      if (userAcceptance == null) {
        return true; // Jamais accepté
      }

      // Vérifier si les versions correspondent
      return userAcceptance.termsVersion != termsVersion ||
          userAcceptance.privacyVersion != privacyVersion;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la vérification');
    }
  }
}
