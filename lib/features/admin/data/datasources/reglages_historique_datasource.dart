import 'package:cloud_firestore/cloud_firestore.dart';

/// L'historique des réglages (`app_config_history`, ajout seul).
///
/// Chaque modification de `app_config/settings` y laisse une entrée écrite dans
/// le même lot : la section touchée, sa valeur avant et après, qui, quand, et
/// la nature (modification ou retour arrière). Les règles Firestore interdisent
/// d'y réécrire ou d'y supprimer quoi que ce soit.

/// Une clé dont la valeur diffère entre l'avant et l'après.
class DifferenceReglage {
  const DifferenceReglage(this.cle, this.avant, this.apres);
  final String cle;
  final Object? avant;
  final Object? apres;
}

class EntreeHistoriqueReglage {
  const EntreeHistoriqueReglage({
    required this.id,
    required this.section,
    required this.apres,
    required this.par,
    required this.nature,
    this.avant,
    this.date,
    this.restaureDepuis,
    this.motif,
  });

  final String id;
  final String section;
  final Map<String, dynamic>? avant;
  final Map<String, dynamic> apres;
  final String par;
  final DateTime? date;
  final String nature; // update | restore
  final String? restaureDepuis;
  final String? motif;

  /// On ne restaure que ce dont on connaît l'état d'avant : la toute première
  /// valeur d'une section n'en a pas.
  bool get restaurable => avant != null;

  factory EntreeHistoriqueReglage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data();
    Map<String, dynamic>? carte(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    return EntreeHistoriqueReglage(
      id: d.id,
      section: m['section'] as String? ?? '?',
      avant: carte(m['before']),
      apres: carte(m['after']) ?? const {},
      par: m['by'] as String? ?? '?',
      date: (m['at'] as Timestamp?)?.toDate(),
      nature: m['kind'] as String? ?? 'update',
      restaureDepuis: m['restoredFrom'] as String?,
      motif: m['reason'] as String?,
    );
  }

  /// Les clés (premier niveau) dont la valeur a changé.
  List<DifferenceReglage> get differences {
    final a = avant ?? const <String, dynamic>{};
    final cles = {...a.keys, ...apres.keys}.toList()..sort();
    return [
      for (final k in cles)
        if (!_egal(a[k], apres[k])) DifferenceReglage(k, a[k], apres[k]),
    ];
  }
}

bool _egal(Object? x, Object? y) {
  if (x is Map && y is Map) {
    if (x.length != y.length) return false;
    for (final k in x.keys) {
      if (!y.containsKey(k) || !_egal(x[k], y[k])) return false;
    }
    return true;
  }
  if (x is List && y is List) {
    if (x.length != y.length) return false;
    for (var i = 0; i < x.length; i++) {
      if (!_egal(x[i], y[i])) return false;
    }
    return true;
  }
  return x == y;
}

class ReglagesHistoriqueSource {
  ReglagesHistoriqueSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  /// Les plus récentes d'abord. Une lecture qui échoue LÈVE : un historique
  /// illisible n'est pas un historique vide.
  Future<List<EntreeHistoriqueReglage>> lire({int limite = 50}) async {
    final snap = await _firestore
        .collection('app_config_history')
        .orderBy('at', descending: true)
        .limit(limite)
        .get();
    return [for (final d in snap.docs) EntreeHistoriqueReglage.fromDoc(d)];
  }
}
