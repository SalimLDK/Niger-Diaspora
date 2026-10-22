import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Les démarches consulaires, côté administration.
///
/// Lecture : les tables (policy `consular.view`). Écriture : uniquement les
/// six RPC de la migration 20261018150000 — le serveur contrôle permission,
/// séparation auteur / approbateur, version de base, et écrit l'audit.

SupabaseClient get _supabase => Supabase.instance.client;

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Une démarche telle qu'elle est en base (publiée ou dépubliée).
class DemarcheAdmin {
  const DemarcheAdmin({
    required this.id,
    required this.contenu,
    required this.publiee,
    required this.version,
    this.sourceUrl,
    this.sourcePublisher,
    this.verifieLe,
    this.prochaineRevision,
  });

  final String id;

  /// Les champs éditables, sous la forme exacte d'un brouillon.
  final Map<String, dynamic> contenu;
  final bool publiee;
  final int version;
  final String? sourceUrl;
  final String? sourcePublisher;
  final DateTime? verifieLe;
  final DateTime? prochaineRevision;

  String get titre => contenu['titre'] as String? ?? id;
  String get rubrique => contenu['rubrique'] as String? ?? '';

  /// Une révision datée et dépassée ; l'absence de date n'est pas un retard,
  /// c'est une révision à planifier.
  bool get revisionEnRetard =>
      prochaineRevision != null && prochaineRevision!.isBefore(DateTime.now());

  factory DemarcheAdmin.fromRow(Map<String, dynamic> r) => DemarcheAdmin(
        id: r['id'] as String,
        contenu: {
          for (final k in champsEditables)
            if (r.containsKey(k)) k: r[k],
        },
        publiee: r['publication_status'] == 'published',
        version: r['version'] as int? ?? 1,
        sourceUrl: r['source_url'] as String?,
        sourcePublisher: r['source_publisher'] as String?,
        verifieLe: _date(r['verified_at']),
        prochaineRevision: _date(r['next_review_at']),
      );
}

/// Les champs qu'un brouillon peut porter (liste blanche du serveur).
const champsEditables = [
  'titre',
  'titre_source',
  'rubrique',
  'request_type',
  'lieu',
  'exige_carte_consulaire',
  'est_prerequis_de_tout_le_reste',
  'resume',
  'pieces',
  'pieces_conditionnelles',
  'cout',
  'delai',
  'juridiction_competente',
  'avertissements',
  'ordre',
];

class BrouillonDemarche {
  const BrouillonDemarche({
    required this.id,
    required this.demarcheId,
    required this.contenu,
    required this.statut,
    required this.auteur,
    this.sourceUrl,
    this.sourcePublisher,
    this.verifieLe,
    this.prochaineRevision,
    this.motif,
    this.noteRelecture,
  });

  final String id;
  final String demarcheId;
  final Map<String, dynamic> contenu;
  final String statut; // draft | pending | approved
  final String auteur;
  final String? sourceUrl;
  final String? sourcePublisher;
  final DateTime? verifieLe;
  final DateTime? prochaineRevision;
  final String? motif;
  final String? noteRelecture;

  String get titre => contenu['titre'] as String? ?? demarcheId;

  factory BrouillonDemarche.fromRow(Map<String, dynamic> r) => BrouillonDemarche(
        id: r['id'] as String,
        demarcheId: r['demarche_id'] as String,
        contenu: Map<String, dynamic>.from(r['payload'] as Map),
        statut: r['status'] as String,
        auteur: r['author_id'] as String,
        sourceUrl: r['source_url'] as String?,
        sourcePublisher: r['source_publisher'] as String?,
        verifieLe: _date(r['verified_at']),
        prochaineRevision: _date(r['next_review_at']),
        motif: r['change_reason'] as String?,
        noteRelecture: r['review_note'] as String?,
      );
}

class RubriqueDemarche {
  const RubriqueDemarche(this.id, this.titre);
  final String id;
  final String titre;
}

class VersionDemarche {
  const VersionDemarche({
    required this.version,
    required this.evenement,
    required this.date,
    this.motif,
  });
  final int version;
  final String evenement; // published | unpublished
  final DateTime? date;
  final String? motif;
}

/// Une ligne de la file : la démarche publiée (si elle existe) et son
/// brouillon vivant (s'il existe).
class LigneDemarche {
  const LigneDemarche({this.live, this.brouillon});
  final DemarcheAdmin? live;
  final BrouillonDemarche? brouillon;

  String get id => live?.id ?? brouillon!.demarcheId;
  String get titre => brouillon?.titre ?? live?.titre ?? id;
}

/// Tout, lu d'un coup : une erreur de lecture reste une erreur, jamais une
/// liste vide qui ressemblerait à un catalogue vide.
final lignesDemarchesProvider =
    FutureProvider.autoDispose<List<LigneDemarche>>((ref) async {
  final results = await Future.wait([
    _supabase.from('demarches_consulaires').select().order('ordre'),
    _supabase
        .from('demarches_brouillons')
        .select()
        .inFilter('status', ['draft', 'pending', 'approved'])
        .order('updated_at', ascending: false),
  ]);
  final lives = {
    for (final r in results[0])
      (r['id'] as String): DemarcheAdmin.fromRow(Map<String, dynamic>.from(r)),
  };
  final brouillons = {
    for (final r in results[1])
      (r['demarche_id'] as String):
          BrouillonDemarche.fromRow(Map<String, dynamic>.from(r)),
  };
  return [
    for (final e in lives.entries)
      LigneDemarche(live: e.value, brouillon: brouillons[e.key]),
    for (final e in brouillons.entries)
      if (!lives.containsKey(e.key)) LigneDemarche(brouillon: e.value),
  ];
});

final rubriquesDemarchesProvider =
    FutureProvider.autoDispose<List<RubriqueDemarche>>((ref) async {
  final rows =
      await _supabase.from('demarches_rubriques').select().order('ordre');
  return [
    for (final r in rows) RubriqueDemarche(r['id'] as String, r['titre'] as String),
  ];
});

final versionsDemarcheProvider = FutureProvider.autoDispose
    .family<List<VersionDemarche>, String>((ref, id) async {
  final rows = await _supabase
      .from('demarches_versions')
      .select('version, event, reason, occurred_at')
      .eq('demarche_id', id)
      .order('occurred_at', ascending: false);
  return [
    for (final r in rows)
      VersionDemarche(
        version: r['version'] as int,
        evenement: r['event'] as String,
        date: _date(r['occurred_at']),
        motif: r['reason'] as String?,
      ),
  ];
});

/// Les écritures. Chacune lève [PostgrestException] en cas de refus.
class DemarchesAdminActions {
  const DemarchesAdminActions();

  Future<void> enregistrer({
    required String demarcheId,
    required Map<String, dynamic> contenu,
    required String? sourceUrl,
    required String? sourcePublisher,
    required DateTime? verifieLe,
    required DateTime? prochaineRevision,
    required String? motif,
  }) async {
    await _supabase.rpc('demarche_draft_save', params: {
      'p_demarche_id': demarcheId,
      'p_payload': contenu,
      'p_source_url': sourceUrl,
      'p_source_publisher': sourcePublisher,
      'p_verified_at': verifieLe?.toUtc().toIso8601String(),
      'p_next_review_at': prochaineRevision?.toUtc().toIso8601String(),
      'p_change_reason': motif,
    });
  }

  Future<void> soumettre(String brouillonId) =>
      _supabase.rpc('demarche_submit', params: {'p_draft_id': brouillonId});

  Future<void> retirer(String brouillonId) =>
      _supabase.rpc('demarche_withdraw', params: {'p_draft_id': brouillonId});

  Future<void> relire(String brouillonId, {required bool approuver, String? note}) =>
      _supabase.rpc('demarche_review', params: {
        'p_draft_id': brouillonId,
        'p_decision': approuver ? 'approve' : 'reject',
        'p_note': note,
      });

  /// Rend le numéro de version publiée.
  Future<int> publier(String brouillonId) async {
    final v = await _supabase.rpc('demarche_publish', params: {'p_draft_id': brouillonId});
    return v is int ? v : int.tryParse('$v') ?? 0;
  }

  Future<void> depublier(String demarcheId, String motif) =>
      _supabase.rpc('demarche_unpublish',
          params: {'p_demarche_id': demarcheId, 'p_reason': motif});
}

final demarchesAdminActionsProvider =
    Provider((ref) => const DemarchesAdminActions());
