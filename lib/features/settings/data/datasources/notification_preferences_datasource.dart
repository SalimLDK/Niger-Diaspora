import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/notification_preferences_model.dart';

abstract class NotificationPreferencesDataSource {
  Future<NotificationPreferencesModel> getPreferences(String userId);
  Future<void> updatePreferences(String userId, NotificationPreferencesModel preferences);
}

class NotificationPreferencesDataSourceImpl implements NotificationPreferencesDataSource {
  final FirebaseFirestore _firestore;

  NotificationPreferencesDataSourceImpl({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<NotificationPreferencesModel> getPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .get();

      if (!doc.exists) {
        return const NotificationPreferencesModel();
      }

      final data = doc.data();
      if (data == null || data['notificationPreferences'] == null) {
        return const NotificationPreferencesModel();
      }

      return NotificationPreferencesModel.fromJson(
        Map<String, dynamic>.from(data['notificationPreferences']),
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la récupération des préférences');
    }
  }

  @override
  Future<void> updatePreferences(String userId, NotificationPreferencesModel preferences) async {
    try {
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .set({
        'notificationPreferences': preferences.toJson(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise à jour des préférences');
    }
  }
}
