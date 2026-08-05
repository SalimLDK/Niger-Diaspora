import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_label.dart';
import 'key_manager_service.dart';
import 'models/e2ee_models.dart';
import 'secure_key_storage.dart';
import 'sender_key_service.dart';

/// Provider pour le service de synchronisation multi-device
final deviceSyncServiceProvider = Provider<DeviceSyncService>((ref) {
  final storage = ref.watch(secureKeyStorageProvider);
  final keyManager = ref.watch(keyManagerServiceProvider);
  final senderKeyService = ref.watch(senderKeyServiceProvider);
  return DeviceSyncService(
    storage: storage,
    keyManager: keyManager,
    senderKeyService: senderKeyService,
  );
});

/// Service de synchronisation et gestion des appareils multiples
///
/// Chaque appareil a sa propre identité cryptographique (Identity Key).
/// Quand Alice envoie un message à Bob, elle doit chiffrer pour TOUS
/// les appareils de Bob (et pour ses propres autres appareils).
///
/// Limite: Maximum 5 appareils par compte
class DeviceSyncService {
  final SecureKeyStorage _storage;
  final KeyManagerService _keyManager;
  final SenderKeyService _senderKeyService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const int maxDevicesPerUser = 5;

  DeviceSyncService({
    required SecureKeyStorage storage,
    required KeyManagerService keyManager,
    required SenderKeyService senderKeyService,
  }) : _storage = storage,
       _keyManager = keyManager,
       _senderKeyService = senderKeyService;

  // ============================================================
  // ENREGISTREMENT D'APPAREIL
  // ============================================================

  /// Enregistre l'appareil actuel pour un utilisateur
  ///
  /// Si l'utilisateur a déjà atteint la limite d'appareils,
  /// retourne une erreur.
  Future<DeviceRegistrationResult> registerCurrentDevice(String userId) async {
    // Vérifier le nombre d'appareils existants
    final existingDevices = await getMyDevices(userId);
    if (existingDevices.length >= maxDevicesPerUser) {
      return const DeviceRegistrationResult(
        success: false,
        error: DeviceRegistrationError.maxDevicesReached,
        message:
            'Maximum de $maxDevicesPerUser appareils atteint. '
            'Veuillez supprimer un appareil existant.',
      );
    }

    // Récupérer les informations de l'appareil
    final deviceName = await _getDeviceName();
    final platform = _getPlatform();

    // Vérifier si cet appareil est déjà enregistré
    final existingDeviceId = await _storage.getDeviceId(userId);
    if (existingDeviceId != null) {
      // Mettre à jour lastActive
      await _updateDeviceLastActive(userId, existingDeviceId);
      return DeviceRegistrationResult(
        success: true,
        deviceId: existingDeviceId,
        isExistingDevice: true,
      );
    }

    // Initialiser les clés E2EE pour ce nouvel appareil
    await _keyManager.initializeKeys(userId);

    // Récupérer le deviceId généré
    final deviceId = await _storage.getDeviceId(userId);
    if (deviceId == null) {
      return const DeviceRegistrationResult(
        success: false,
        error: DeviceRegistrationError.keyGenerationFailed,
        message: 'Échec de la génération des clés E2EE',
      );
    }

    // Mettre à jour les informations de l'appareil sur Firebase
    await _firestore
        .collection('user_keys')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .update({
          'deviceName': deviceName,
          'platform': platform,
          'lastActive': FieldValue.serverTimestamp(),
        });

    debugPrint('DeviceSyncService: Registered device $deviceId for $userId');

    return DeviceRegistrationResult(
      success: true,
      deviceId: deviceId,
      isExistingDevice: false,
    );
  }

  /// Récupère le nom de l'appareil — délègue au libellé partagé, pour que la
  /// liste des appareils et les métadonnées de sauvegarde ne divergent pas.
  Future<String> _getDeviceName() => currentDeviceLabel();

  /// Récupère la plateforme
  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Met à jour le timestamp lastActive d'un appareil
  Future<void> _updateDeviceLastActive(String userId, String deviceId) async {
    await _firestore
        .collection('user_keys')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .update({'lastActive': FieldValue.serverTimestamp()});
  }

  // ============================================================
  // GESTION DES APPAREILS
  // ============================================================

  /// Récupère la liste des appareils de l'utilisateur.
  ///
  /// Source de vérité : table Supabase `e2ee_devices` (là où les clés sont
  /// réellement publiées). L'ancienne implémentation lisait Firestore, qui
  /// n'est plus alimenté → la liste apparaissait vide.
  Future<List<E2EEDeviceInfo>> getMyDevices(String userId) async {
    DateTime parseTs(dynamic v) => v is String
        ? (DateTime.tryParse(v)?.toLocal() ?? DateTime.now())
        : DateTime.now();
    try {
      // `device_name` est arrivé par migration (20260720120200) et peut ne pas
      // être déployée partout : sans le repli, un PGRST204 viderait toute la
      // liste des appareils au lieu de perdre seulement le libellé.
      List<dynamic> rows;
      try {
        rows = await _supabase
            .from('e2ee_devices')
            .select(
              'device_id, device_name, identity_key, platform, created_at, last_active',
            )
            .eq('user_id', userId);
      } catch (_) {
        rows = await _supabase
            .from('e2ee_devices')
            .select('device_id, identity_key, platform, created_at, last_active')
            .eq('user_id', userId);
      }

      final list = (rows).map((r) {
        final m = r as Map<String, dynamic>;
        final platform = m['platform'] as String? ?? 'unknown';
        final customName = (m['device_name'] as String?)?.trim();
        return E2EEDeviceInfo(
          deviceId: m['device_id'] as String? ?? '',
          deviceName:
              (customName != null && customName.isNotEmpty)
                  ? customName
                  : _platformLabel(platform),
          platform: platform,
          identityKeyPublic: m['identity_key'] as String? ?? '',
          createdAt: parseTs(m['created_at']),
          lastActive: parseTs(m['last_active']),
        );
      }).toList();
      list.sort((a, b) => b.lastActive.compareTo(a.lastActive));
      return list;
    } catch (e) {
      debugPrint('DeviceSyncService: Error getting devices (supabase): $e');
      return [];
    }
  }

  /// Libellé lisible dérivé de la plateforme (la table n'a pas de nom
  /// d'appareil personnalisé).
  String _platformLabel(String platform) {
    switch (platform) {
      case 'android':
        return 'Appareil Android';
      case 'ios':
        return 'iPhone / iPad';
      case 'macos':
        return 'Mac';
      case 'windows':
        return 'Ordinateur Windows';
      case 'linux':
        return 'Ordinateur Linux';
      case 'web':
        return 'Navigateur web';
      default:
        return 'Appareil';
    }
  }

  /// Récupère l'appareil actuel
  Future<E2EEDeviceInfo?> getCurrentDevice(String userId) async {
    final deviceId = await _storage.getDeviceId(userId);
    if (deviceId == null) return null;

    final devices = await getMyDevices(userId);
    return devices.where((d) => d.deviceId == deviceId).firstOrNull;
  }

  /// Supprime un appareil (déconnexion à distance)
  ///
  /// Ne peut pas supprimer l'appareil actuel via cette méthode.
  Future<bool> removeDevice(String userId, String deviceId) async {
    final currentDeviceId = await _storage.getDeviceId(userId);
    if (currentDeviceId == deviceId) {
      debugPrint('DeviceSyncService: Cannot remove current device');
      return false;
    }

    try {
      // Retirer de la liste des appareils actifs (RPC atomique) puis supprimer
      // la ligne dans Supabase (source de vérité des clés E2EE).
      await _supabase.rpc('e2ee_remove_active_device', params: {
        'p_user_id': userId,
        'p_device_id': deviceId,
      });
      await _supabase
          .from('e2ee_devices')
          .delete()
          .eq('user_id', userId)
          .eq('device_id', deviceId);

      debugPrint('DeviceSyncService: Removed device $deviceId (supabase)');
      return true;
    } catch (e) {
      debugPrint('DeviceSyncService: Error removing device (supabase): $e');
      return false;
    }
  }

  /// Renomme un appareil.
  ///
  /// Écrit dans Supabase, **là où [getMyDevices] lit**. L'implémentation
  /// précédente écrivait dans Firestore `user_keys/{uid}/devices` : le nom
  /// partait bien quelque part, mais la liste ne le relisait jamais — renommer
  /// n'avait aucun effet visible.
  Future<bool> renameDevice(
    String userId,
    String deviceId,
    String newName,
  ) async {
    try {
      await _supabase
          .from('e2ee_devices')
          .update({'device_name': newName})
          .eq('user_id', userId)
          .eq('device_id', deviceId);

      debugPrint('DeviceSyncService: Renamed device $deviceId to $newName');
      return true;
    } catch (e) {
      debugPrint('DeviceSyncService: Error renaming device: $e');
      return false;
    }
  }

  // ============================================================
  // RÉCUPÉRATION DES APPAREILS D'UN DESTINATAIRE
  // ============================================================

  /// Récupère tous les appareils d'un destinataire
  Future<List<RecipientDevice>> getRecipientDevices(String recipientId) async {
    try {
      final snapshot =
          await _firestore
              .collection('user_keys')
              .doc(recipientId)
              .collection('devices')
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return RecipientDevice(
          userId: recipientId,
          deviceId: doc.id,
          registrationId: data['registrationId'] as int? ?? 0,
          identityKey: data['identityKey'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('DeviceSyncService: Error getting recipient devices: $e');
      return [];
    }
  }

  /// Vérifie si un destinataire supporte E2EE
  Future<bool> recipientSupportsE2EE(String recipientId) async {
    try {
      final doc =
          await _firestore.collection('user_keys').doc(recipientId).get();
      if (!doc.exists) return false;

      final data = doc.data();
      return data?['e2eeEnabled'] == true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // SYNCHRONISATION DES SENDER KEYS
  // ============================================================

  /// Synchronise les Sender Keys d'un groupe vers un nouvel appareil
  ///
  /// Appelé quand un utilisateur ajoute un nouvel appareil et doit
  /// recevoir les Sender Keys des groupes auxquels il appartient.
  Future<void> syncGroupKeysToNewDevice(
    String userId,
    String newDeviceId,
    List<String> groupIds,
  ) async {
    for (final groupId in groupIds) {
      await _senderKeyService.fetchPendingDistributions(groupId);
    }

    debugPrint('DeviceSyncService: Synced sender keys to device $newDeviceId');
  }

  /// Notifie les autres appareils d'un changement
  Future<void> notifyOtherDevices(
    String userId,
    DeviceNotificationType type, {
    Map<String, dynamic>? data,
  }) async {
    final currentDeviceId = await _storage.getDeviceId(userId);

    await _firestore
        .collection('user_keys')
        .doc(userId)
        .collection('device_notifications')
        .add({
          'type': type.name,
          'fromDeviceId': currentDeviceId,
          'data': data ?? {},
          'createdAt': FieldValue.serverTimestamp(),
          'processedBy': [currentDeviceId],
        });
  }

  /// Écoute les notifications pour cet appareil
  Stream<List<DeviceNotification>> listenForNotifications(String userId) {
    final currentDeviceId = _storage.getMetadata('e2ee_device_id_$userId');

    return _firestore
        .collection('user_keys')
        .doc(userId)
        .collection('device_notifications')
        .where('processedBy', arrayContains: currentDeviceId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return DeviceNotification(
              id: doc.id,
              type: DeviceNotificationType.values.firstWhere(
                (t) => t.name == data['type'],
                orElse: () => DeviceNotificationType.unknown,
              ),
              fromDeviceId: data['fromDeviceId'] as String,
              data: data['data'] as Map<String, dynamic>? ?? {},
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList();
        });
  }

  /// Marque une notification comme traitée
  Future<void> markNotificationProcessed(
    String userId,
    String notificationId,
  ) async {
    final currentDeviceId = await _storage.getDeviceId(userId);

    await _firestore
        .collection('user_keys')
        .doc(userId)
        .collection('device_notifications')
        .doc(notificationId)
        .update({
          'processedBy': FieldValue.arrayUnion([currentDeviceId]),
        });
  }

  // ============================================================
  // SELF-MESSAGING (AUTO-ENVOI)
  // ============================================================

  /// Récupère les autres appareils de l'utilisateur (pour self-messaging)
  Future<List<RecipientDevice>> getMyOtherDevices(String userId) async {
    final currentDeviceId = await _storage.getDeviceId(userId);
    final allDevices = await getRecipientDevices(userId);

    return allDevices.where((d) => d.deviceId != currentDeviceId).toList();
  }

  // ============================================================
  // DÉCONNEXION
  // ============================================================

  /// Déconnecte l'appareil actuel (supprime ses clés)
  Future<void> logoutCurrentDevice(String userId) async {
    final deviceId = await _storage.getDeviceId(userId);
    if (deviceId == null) return;

    try {
      // Supprimer les One-Time Pre-Keys
      final otpCollection = _firestore
          .collection('user_keys')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .collection('oneTimePreKeys');

      final otpDocs = await otpCollection.get();
      for (final doc in otpDocs.docs) {
        await doc.reference.delete();
      }

      // Supprimer l'appareil de Firebase
      await _firestore
          .collection('user_keys')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .delete();

      // Mettre à jour la liste des appareils actifs
      await _firestore.collection('user_keys').doc(userId).update({
        'activeDevices': FieldValue.arrayRemove([deviceId]),
      });

      // Supprimer les données locales
      await _storage.clearAllData(userId);

      // Notifier les autres appareils
      await notifyOtherDevices(
        userId,
        DeviceNotificationType.deviceRemoved,
        data: {'removedDeviceId': deviceId},
      );

      debugPrint('DeviceSyncService: Logged out device $deviceId');
    } catch (e) {
      debugPrint('DeviceSyncService: Error during logout: $e');
    }
  }
}

/// Résultat de l'enregistrement d'un appareil
class DeviceRegistrationResult {
  final bool success;
  final String? deviceId;
  final bool isExistingDevice;
  final DeviceRegistrationError? error;
  final String? message;

  const DeviceRegistrationResult({
    required this.success,
    this.deviceId,
    this.isExistingDevice = false,
    this.error,
    this.message,
  });
}

/// Erreurs d'enregistrement d'appareil
enum DeviceRegistrationError {
  maxDevicesReached,
  keyGenerationFailed,
  networkError,
  unknown,
}

/// Appareil d'un destinataire (pour le chiffrement)
class RecipientDevice {
  final String userId;
  final String deviceId;
  final int registrationId;
  final String identityKey;

  const RecipientDevice({
    required this.userId,
    required this.deviceId,
    required this.registrationId,
    required this.identityKey,
  });
}

/// Types de notifications entre appareils
enum DeviceNotificationType {
  /// Un nouvel appareil a été ajouté
  deviceAdded,

  /// Un appareil a été supprimé
  deviceRemoved,

  /// Les clés ont été mises à jour
  keysUpdated,

  /// Une Sender Key a été distribuée
  senderKeyDistributed,

  /// Inconnu
  unknown,
}

/// Notification entre appareils
class DeviceNotification {
  final String id;
  final DeviceNotificationType type;
  final String fromDeviceId;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  const DeviceNotification({
    required this.id,
    required this.type,
    required this.fromDeviceId,
    required this.data,
    required this.createdAt,
  });
}
