import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_settings_model.dart';

/// Datasource for app settings from Firebase
abstract class AppSettingsDataSource {
  /// Get current app settings
  Future<AppSettingsModel> getSettings();

  /// Update app settings
  Future<void> updateSettings(AppSettingsModel settings, String updatedBy);

  /// Update a specific section
  Future<void> updateSection(
      String section, Map<String, dynamic> data, String updatedBy);

  /// Stream settings changes
  Stream<AppSettingsModel> watchSettings();
}

class AppSettingsDataSourceImpl implements AppSettingsDataSource {
  final FirebaseFirestore _firestore;
  static const String _collection = 'app_config';
  static const String _documentId = 'settings';

  AppSettingsDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference get _settingsDoc =>
      _firestore.collection(_collection).doc(_documentId);

  @override
  Future<AppSettingsModel> getSettings() async {
    try {
      final doc = await _settingsDoc.get();

      if (!doc.exists) {
        // Create default settings if they don't exist
        final defaults = AppSettingsModel();
        await _settingsDoc.set(defaults.toJson());
        return defaults;
      }

      return AppSettingsModel.fromFirestore(doc);
    } catch (e) {
      // Return defaults on error
      return AppSettingsModel();
    }
  }

  @override
  Future<void> updateSettings(
      AppSettingsModel settings, String updatedBy) async {
    final data = settings.toJson();
    data['updatedBy'] = updatedBy;
    data['lastUpdated'] = FieldValue.serverTimestamp();

    await _settingsDoc.set(data, SetOptions(merge: true));
  }

  @override
  Future<void> updateSection(
    String section,
    Map<String, dynamic> data,
    String updatedBy,
  ) async {
    await _settingsDoc.set({
      section: data,
      'updatedBy': updatedBy,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<AppSettingsModel> watchSettings() {
    return _settingsDoc.snapshots().map((doc) {
      if (!doc.exists) {
        return AppSettingsModel();
      }
      return AppSettingsModel.fromFirestore(doc);
    });
  }
}
