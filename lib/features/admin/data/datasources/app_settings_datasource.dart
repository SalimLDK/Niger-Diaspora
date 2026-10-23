import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_settings_model.dart';

/// Datasource for app settings from Firebase
abstract class AppSettingsDataSource {
  /// Get current app settings
  Future<AppSettingsModel> getSettings();

  /// Remplace une section et laisse, dans le MÊME lot, son entrée d'historique
  /// (`app_config_history`) : ancienne valeur, nouvelle valeur, auteur, nature.
  /// Les règles Firestore refusent tout changement de `settings` qui n'en porte
  /// pas — il n'existe donc plus d'écriture non tracée, ni de `updateSettings`
  /// qui remplacerait le document entier.
  ///
  /// [kind] : `update`, ou `restore` pour un retour arrière ([restoredFrom] :
  /// l'entrée dont on reprend l'ancienne valeur).
  Future<void> updateSection(
    String section,
    Map<String, dynamic> data,
    String updatedBy, {
    String? reason,
    String kind = 'update',
    String? restoredFrom,
  });

  /// Stream settings changes
  Stream<AppSettingsModel> watchSettings();
}

class AppSettingsDataSourceImpl implements AppSettingsDataSource {
  final FirebaseFirestore _firestore;
  final String? Function() _uidCourant;
  static const String _collection = 'app_config';
  static const String _documentId = 'settings';

  AppSettingsDataSourceImpl({
    FirebaseFirestore? firestore,
    String? Function()? uidCourant,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uidCourant =
            uidCourant ?? (() => FirebaseAuth.instance.currentUser?.uid);

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
  Future<void> updateSection(
    String section,
    Map<String, dynamic> data,
    String updatedBy, {
    String? reason,
    String kind = 'update',
    String? restoredFrom,
  }) async {
    final uid = _uidCourant();
    if (uid == null) {
      throw StateError('Réglages : aucune session, écriture refusée');
    }
    final histo = _firestore.collection('app_config_history').doc();

    // Une transaction : l'« avant » enregistré est celui que ce lot remplace
    // vraiment, même si un autre superAdmin a modifié la section entre-temps
    // (Firestore rejoue alors la transaction avec la valeur à jour).
    await _firestore.runTransaction((tx) async {
      final actuel = await tx.get(_settingsDoc);
      final avant = ((actuel.data() as Map<String, dynamic>?)?[section] as Map?)
          ?.cast<String, dynamic>();
      tx.set(histo, {
        'section': section,
        'before': avant,
        'after': data,
        'by': uid,
        'at': FieldValue.serverTimestamp(),
        'kind': kind,
        if (restoredFrom != null) 'restoredFrom': restoredFrom,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      });
      tx.set(_settingsDoc, {
        section: data,
        'updatedBy': updatedBy,
        'lastUpdated': FieldValue.serverTimestamp(),
        // Le document cite son entrée : c'est ce que les règles vérifient.
        'lastChangeId': histo.id,
      }, SetOptions(merge: true));
    });
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
