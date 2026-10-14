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

  /// Une lecture qui échoue **lève** ; les défauts ne sont rendus que pour un
  /// document absent.
  ///
  /// Avant, toute erreur — refus de permission compris — rendait les défauts
  /// de [AppSettingsModel] comme s'ils venaient du serveur. L'écran Réglages
  /// les affichait, et « Enregistrer » écrasait la section serveur avec eux
  /// (`set(merge)` section par section). Et la porte des routes sous drapeau
  /// (`decisionPorte`, `lib/core/router/porte_drapeaux.dart`) a une issue
  /// « drapeaux illisibles » qu'elle ne voyait jamais : elle décidait sur des
  /// défauts pris pour des valeurs lues (audit du 2026-10-14, § 5). Côté
  /// app, tous les consommateurs passent par `valueOrNull`, `hasError` ou
  /// `whenData` : un `AsyncError` leur donne les mêmes défauts qu'avant.
  @override
  Future<AppSettingsModel> getSettings() async {
    final doc = await _settingsDoc.get();
    if (doc.exists) {
      return AppSettingsModel.fromFirestore(doc);
    }

    // Aucun document : des défauts, qu'on tente de poser pour la suite — en
    // best-effort, l'app grand public n'a pas le droit d'écrire ici
    // (`firestore.rules` : app_config en écriture superAdmin seulement).
    final defaults = AppSettingsModel();
    try {
      await _settingsDoc.set(defaults.toJson());
    } catch (_) {
      // Refusé pour un non-superAdmin : les défauts suffisent.
    }
    return defaults;
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
