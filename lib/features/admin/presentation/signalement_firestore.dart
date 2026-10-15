import 'package:cloud_firestore/cloud_firestore.dart';

import 'providers/admin_provider.dart';

/// Origine d'un signalement : l'app écrit dans Firestore (`reports`), le
/// panneau ne lisait que Supabase — où n'arrivent que les avis signalés.
const String sourceFirestore = 'firestore';
const String sourceSupabase = 'supabase';

DateTime? _enDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v.toLocal();
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

/// Un document Firestore de `reports` en [ReportEntity].
///
/// L'app l'écrit sous trois formes, et la lecture doit les prendre toutes :
/// - `report_remote_datasource` : `targetType`, `reporterId`, `reporterName`…
/// - `message_remote_datasource` (message signalé) : `type`, `reportedBy`,
///   sans nom ni instantané ;
/// - `conversation_actions_provider` (conversation) : `type`, `reporterId`.
/// Un champ absent ne fait jamais lever : le signalement s'affiche incomplet,
/// il ne disparaît pas de la file.
ReportEntity signalementDepuisFirestore(String id, Map<String, dynamic> d) {
  final instantane = d['contentSnapshot'];
  Map<String, dynamic>? instantaneLisible;
  if (instantane is Map) {
    instantaneLisible = instantane.cast<String, dynamic>();
    final pris = instantaneLisible['capturedAt'];
    if (pris is Timestamp) {
      instantaneLisible = {...instantaneLisible, 'capturedAt': pris.toDate()};
    }
  }
  return ReportEntity(
    id: id,
    reporterId: (d['reporterId'] ?? d['reportedBy']) as String? ?? '',
    reporterName: d['reporterName'] as String?,
    targetType: (d['targetType'] ?? d['type']) as String? ?? 'unknown',
    targetId: d['targetId'] as String? ?? '',
    targetName: (d['targetName'] ?? d['targetPreview']) as String?,
    conversationId: d['conversationId'] as String?,
    reason: d['reason'] as String? ?? '',
    description: d['description'] as String?,
    contentSnapshot: instantaneLisible != null
        ? ContentSnapshotData.fromMap(instantaneLisible)
        : null,
    reportedUserId: d['reportedUserId'] as String?,
    status: d['status'] as String? ?? 'pending',
    adminNote: d['adminNote'] as String?,
    reviewedBy: d['reviewedBy'] as String?,
    createdAt: _enDate(d['createdAt']),
    reviewedAt: _enDate(d['reviewedAt']),
    reportedUserNotified: d['reportedUserNotified'] as bool? ?? false,
    source: sourceFirestore,
  );
}

/// Statuts de Firestore rangés dans l'onglet « Traités » : tout sauf
/// `pending`, comme `neq('status', 'pending')` côté Supabase. Une liste
/// fermée parce que Firestore n'a pas de « différent de » qui se combine
/// avec le tri sur `createdAt` sans index dédié.
const List<String> statutsFirestoreTraites = [
  'underReview',
  'resolved',
  'dismissed',
];

/// Tous les statuts connus, pour l'onglet « Tous » quand un type est choisi
/// (l'index `targetType + status + createdAt` existe, pas `targetType +
/// createdAt`).
const List<String> statutsFirestoreTous = [
  'pending',
  ...statutsFirestoreTraites,
];

/// Plus récent d'abord ; une date inconnue passe en dernier.
int plusRecentDabord(ReportEntity a, ReportEntity b) {
  final da = a.createdAt;
  final db = b.createdAt;
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return db.compareTo(da);
}

/// Un signalement correspond-il à la recherche ? Les mêmes cinq champs que
/// le filtre `or(...)` de Supabase, comparés sans casse : Firestore n'a pas
/// de `ilike`, la recherche se fait donc sur les lignes lues.
bool signalementCorrespond(ReportEntity r, String recherche) {
  final q = recherche.trim().toLowerCase();
  if (q.isEmpty) return true;
  bool a(String? v) => v != null && v.toLowerCase().contains(q);
  return a(r.targetName) ||
      a(r.reporterName) ||
      a(r.reason) ||
      a(r.targetId) ||
      a(r.description);
}
