import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'connectivity_service.dart';

/// Types d'actions offline
enum OfflineActionType {
  create,
  update,
  delete,
}

/// Modèle pour une action en attente de synchronisation
class PendingAction {
  final String id;
  final String collection;
  final String? documentId;
  final OfflineActionType actionType;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final int retryCount;

  PendingAction({
    required this.id,
    required this.collection,
    this.documentId,
    required this.actionType,
    this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'documentId': documentId,
    'actionType': actionType.name,
    'data': data,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'retryCount': retryCount,
  };

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
    id: json['id'] as String,
    collection: json['collection'] as String,
    documentId: json['documentId'] as String?,
    actionType: OfflineActionType.values.firstWhere(
      (e) => e.name == json['actionType'],
    ),
    data: json['data'] as Map<String, dynamic>?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    retryCount: json['retryCount'] as int? ?? 0,
  );

  PendingAction copyWith({int? retryCount}) => PendingAction(
    id: id,
    collection: collection,
    documentId: documentId,
    actionType: actionType,
    data: data,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
  );
}

/// Sort d'une action après une reprise de connexion.
enum SyncOutcome {
  /// Partie au serveur.
  sent,

  /// A échoué mais sera retentée à la prochaine reconnexion.
  retrying,

  /// Abandonnée après le nombre maximal de tentatives — l'action est perdue,
  /// et c'est la seule chose que l'utilisateur doit absolument savoir.
  abandoned,
}

/// Ce qu'est devenue une action mise en file pendant la coupure.
class SyncedActionReport {
  final String collection;
  final OfflineActionType actionType;
  final SyncOutcome outcome;

  const SyncedActionReport({
    required this.collection,
    required this.actionType,
    required this.outcome,
  });
}

/// Bilan d'une reprise de connexion (maquette 3b).
///
/// La bannière hors-ligne disait seulement « N en attente ». Après une longue
/// coupure, l'utilisateur a besoin de savoir ce qui est réellement parti et
/// ce qui a été abandonné, action par action.
class ReconnectionReport {
  /// Début de la coupure, si on a pu l'observer (null si l'app a démarré
  /// déjà hors ligne).
  final DateTime? offlineSince;
  final DateTime reconnectedAt;
  final List<SyncedActionReport> actions;

  const ReconnectionReport({
    required this.offlineSince,
    required this.reconnectedAt,
    required this.actions,
  });

  Duration? get outageDuration =>
      offlineSince == null ? null : reconnectedAt.difference(offlineSince!);

  int get sentCount =>
      actions.where((a) => a.outcome == SyncOutcome.sent).length;
  int get abandonedCount =>
      actions.where((a) => a.outcome == SyncOutcome.abandoned).length;
  int get retryingCount =>
      actions.where((a) => a.outcome == SyncOutcome.retrying).length;
}

/// Service de synchronisation offline
class OfflineSyncService {
  static const String _pendingActionsBox = 'pending_actions';
  static const String _syncMetadataBox = 'sync_metadata';
  static const int _maxRetries = 3;

  static OfflineSyncService? _instance;
  static OfflineSyncService get instance => _instance ??= OfflineSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isInitialized = false;

  // Stream controller pour notifier les changements de sync
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  final _reconnectionController =
      StreamController<ReconnectionReport>.broadcast();

  /// Émis une fois par reprise de connexion, uniquement s'il y avait quelque
  /// chose en attente — sinon il n'y a rien à raconter à l'utilisateur.
  Stream<ReconnectionReport> get reconnectionStream =>
      _reconnectionController.stream;

  /// Début de la coupure en cours (null tant qu'on est en ligne).
  DateTime? _offlineSince;

  OfflineSyncService._();

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.openBox<String>(_pendingActionsBox);
    await Hive.openBox<String>(_syncMetadataBox);

    // Écouter les changements de connectivité
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        syncPendingActions();
      } else {
        // Horodater la coupure pour pouvoir en donner la durée au retour.
        _offlineSince ??= DateTime.now();
      }
    });

    _isInitialized = true;

    // Synchroniser au démarrage si connecté
    if (await _connectivity.isConnected()) {
      syncPendingActions();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
    _reconnectionController.close();
  }

  /// Ajoute une action à la queue offline
  Future<void> queueAction({
    required String collection,
    String? documentId,
    required OfflineActionType actionType,
    Map<String, dynamic>? data,
  }) async {
    final box = Hive.box<String>(_pendingActionsBox);

    final action = PendingAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      collection: collection,
      documentId: documentId,
      actionType: actionType,
      data: data,
      createdAt: DateTime.now(),
    );

    await box.put(action.id, jsonEncode(action.toJson()));

    _syncStatusController.add(SyncStatus(
      pendingCount: box.length,
      isSyncing: false,
      lastError: null,
    ));

    // Tenter de synchroniser immédiatement si connecté
    if (await _connectivity.isConnected()) {
      syncPendingActions();
    }
  }

  /// Récupère toutes les actions en attente
  List<PendingAction> getPendingActions() {
    final box = Hive.box<String>(_pendingActionsBox);
    final actions = <PendingAction>[];

    for (final data in box.values) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        actions.add(PendingAction.fromJson(json));
      } catch (e) {
        debugPrint('OfflineSyncService: Error parsing pending action: $e');
      }
    }

    // Trier par date de création
    actions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return actions;
  }

  /// Nombre d'actions en attente
  int get pendingActionsCount => Hive.box<String>(_pendingActionsBox).length;

  /// Synchronise les actions en attente
  Future<void> syncPendingActions() async {
    if (_isSyncing) return;
    if (!await _connectivity.isConnected()) return;

    _isSyncing = true;
    final box = Hive.box<String>(_pendingActionsBox);

    _syncStatusController.add(SyncStatus(
      pendingCount: box.length,
      isSyncing: true,
      lastError: null,
    ));

    final actions = getPendingActions();
    String? lastError;
    // Bilan par action, pour l'écran de reprise (maquette 3b).
    final report = <SyncedActionReport>[];

    for (final action in actions) {
      try {
        await _executeAction(action);
        await box.delete(action.id);
        report.add(SyncedActionReport(
          collection: action.collection,
          actionType: action.actionType,
          outcome: SyncOutcome.sent,
        ));
      } catch (e) {
        debugPrint('OfflineSyncService: Error syncing action ${action.id}: $e');
        lastError = e.toString();

        // Incrémenter le compteur de retry
        final updatedAction = action.copyWith(retryCount: action.retryCount + 1);

        if (updatedAction.retryCount >= _maxRetries) {
          // Supprimer après max retries
          await box.delete(action.id);
          debugPrint('OfflineSyncService: Action ${action.id} removed after $_maxRetries retries');
          report.add(SyncedActionReport(
            collection: action.collection,
            actionType: action.actionType,
            outcome: SyncOutcome.abandoned,
          ));
        } else {
          // Mettre à jour avec le nouveau retry count
          await box.put(action.id, jsonEncode(updatedAction.toJson()));
          report.add(SyncedActionReport(
            collection: action.collection,
            actionType: action.actionType,
            outcome: SyncOutcome.retrying,
          ));
        }
      }
    }

    _isSyncing = false;

    _syncStatusController.add(SyncStatus(
      pendingCount: box.length,
      isSyncing: false,
      lastError: lastError,
    ));

    // Rien n'était en attente : la reprise est un non-événement, on ne
    // dérange pas l'utilisateur avec un récap vide.
    if (report.isNotEmpty) {
      _reconnectionController.add(ReconnectionReport(
        offlineSince: _offlineSince,
        reconnectedAt: DateTime.now(),
        actions: report,
      ));
    }
    _offlineSince = null;
  }

  /// Exécute une action sur Firestore
  Future<void> _executeAction(PendingAction action) async {
    final collection = _firestore.collection(action.collection);

    switch (action.actionType) {
      case OfflineActionType.create:
        if (action.documentId != null && action.data != null) {
          await collection.doc(action.documentId).set(action.data!);
        } else if (action.data != null) {
          await collection.add(action.data!);
        }
        break;

      case OfflineActionType.update:
        if (action.documentId != null && action.data != null) {
          await collection.doc(action.documentId).update(action.data!);
        }
        break;

      case OfflineActionType.delete:
        if (action.documentId != null) {
          await collection.doc(action.documentId).delete();
        }
        break;
    }
  }

  /// Enregistre la dernière synchronisation
  Future<void> recordLastSync(String key) async {
    final box = Hive.box<String>(_syncMetadataBox);
    await box.put('${key}_lastSync', DateTime.now().toUtc().toIso8601String());
  }

  /// Récupère la dernière synchronisation
  DateTime? getLastSync(String key) {
    final box = Hive.box<String>(_syncMetadataBox);
    final timestamp = box.get('${key}_lastSync');
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp)?.toLocal();
  }

  /// Vérifie si une synchronisation est nécessaire
  bool needsSync(String key, {Duration maxAge = const Duration(minutes: 5)}) {
    final lastSync = getLastSync(key);
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > maxAge;
  }

  /// Efface toutes les actions en attente
  Future<void> clearPendingActions() async {
    await Hive.box<String>(_pendingActionsBox).clear();
    _syncStatusController.add(SyncStatus(
      pendingCount: 0,
      isSyncing: false,
      lastError: null,
    ));
  }
}

/// Status de synchronisation
class SyncStatus {
  final int pendingCount;
  final bool isSyncing;
  final String? lastError;

  SyncStatus({
    required this.pendingCount,
    required this.isSyncing,
    this.lastError,
  });

  bool get hasPendingActions => pendingCount > 0;
}
