import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Les campagnes de communication, côté administration.
///
/// Lecture : les tables (policy `communications.view`). Écriture : uniquement
/// les cinq RPC de la migration 20261018210000 — le serveur contrôle
/// permission, séparation auteur / approbateur, statut, résout l'audience
/// lui-même et écrit l'audit.

SupabaseClient get _supabase => Supabase.instance.client;

class Campagne {
  const Campagne({
    required this.id,
    required this.type,
    required this.titre,
    required this.texte,
    required this.audience,
    required this.statut,
    required this.auteur,
    this.noteRelecture,
    this.motifAnnulation,
    this.misAJourLe,
  });

  final String id;
  final String type; // transactional | security | official_info | promotional
  final String titre;
  final String texte;
  final Map<String, dynamic> audience;
  final String statut; // draft | pending_approval | approved | sending | sent | rejected | cancelled
  final String auteur;
  final String? noteRelecture;
  final String? motifAnnulation;
  final DateTime? misAJourLe;

  String get audienceKind => audience['kind'] as String? ?? '';

  factory Campagne.fromRow(Map<String, dynamic> r) => Campagne(
        id: r['id'] as String,
        type: r['type'] as String,
        titre: r['title'] as String,
        texte: r['body'] as String,
        audience: Map<String, dynamic>.from(r['audience'] as Map),
        statut: r['status'] as String,
        auteur: r['author_id'] as String,
        noteRelecture: r['review_note'] as String?,
        motifAnnulation: r['cancel_reason'] as String?,
        misAJourLe: DateTime.tryParse(r['updated_at'] as String? ?? '')?.toLocal(),
      );
}

/// Le filtre de la file : `null` = toutes.
enum VueCampagnes { atraiter, envoyees, closes, toutes }

final vueCampagnesProvider =
    StateProvider.autoDispose<VueCampagnes>((ref) => VueCampagnes.atraiter);

/// Une erreur de lecture reste une erreur — jamais une liste vide.
final campagnesProvider = FutureProvider.autoDispose<List<Campagne>>((ref) async {
  final vue = ref.watch(vueCampagnesProvider);
  var q = _supabase.from('campaigns').select();
  switch (vue) {
    case VueCampagnes.atraiter:
      q = q.inFilter('status', ['draft', 'pending_approval', 'approved', 'sending']);
    case VueCampagnes.envoyees:
      q = q.eq('status', 'sent');
    case VueCampagnes.closes:
      q = q.inFilter('status', ['rejected', 'cancelled']);
    case VueCampagnes.toutes:
      break;
  }
  final rows = await q.order('updated_at', ascending: false).limit(100);
  return [
    for (final r in rows) Campagne.fromRow(Map<String, dynamic>.from(r)),
  ];
});

/// Combien de comptes, selon les règles de l'envoi (prefs comprises).
class DecompteAudience {
  const DecompteAudience(this.total, this.ignores, this.notifies);
  final int total;
  final int ignores;
  final int notifies;
}

final decompteAudienceProvider =
    FutureProvider.autoDispose.family<DecompteAudience, String>((ref, id) async {
  final r = await _supabase.rpc('campaign_audience_count', params: {'p_id': id});
  final m = Map<String, dynamic>.from(r as Map);
  return DecompteAudience(
    m['total'] as int,
    m['skipped_pref'] as int,
    m['will_notify'] as int,
  );
});

/// Ce qui est vraiment parti : notifications créées / comptes ignorés.
final bilanEnvoiProvider = FutureProvider.autoDispose
    .family<({int creees, int ignorees}), String>((ref, id) async {
  final rows = await _supabase
      .from('campaign_recipients')
      .select('status')
      .eq('campaign_id', id);
  var c = 0;
  var i = 0;
  for (final r in rows) {
    if (r['status'] == 'created') {
      c++;
    } else {
      i++;
    }
  }
  return (creees: c, ignorees: i);
});

final permissionCampagneProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, cle) async {
  final ok = await _supabase.rpc('admin_has_permission', params: {'perm': cle});
  return ok == true;
});

/// Le résultat d'un lot d'envoi.
class LotEnvoye {
  const LotEnvoye({
    required this.traites,
    required this.creees,
    required this.restants,
    required this.termine,
  });
  final int traites;
  final int creees;
  final int restants;
  final bool termine;
}

/// Les écritures. Chacune lève [PostgrestException] en cas de refus.
class CampagnesAdminActions {
  const CampagnesAdminActions();

  Future<void> enregistrer({
    String? id,
    required String type,
    required String titre,
    required String texte,
    required Map<String, dynamic> audience,
  }) async {
    await _supabase.rpc('campaign_save', params: {
      'p_id': id,
      'p_type': type,
      'p_title': titre,
      'p_body': texte,
      'p_audience': audience,
    });
  }

  Future<void> soumettre(String id) =>
      _supabase.rpc('campaign_submit', params: {'p_id': id});

  Future<void> relire(String id, {required bool approuver, String? note}) =>
      _supabase.rpc('campaign_review', params: {
        'p_id': id,
        'p_decision': approuver ? 'approve' : 'reject',
        'p_note': note,
      });

  Future<void> annuler(String id, String motif) =>
      _supabase.rpc('campaign_cancel', params: {'p_id': id, 'p_reason': motif});

  /// Un lot d'au plus [taille] comptes ; le serveur dit ce qu'il reste.
  Future<LotEnvoye> envoyerUnLot(String id, {int taille = 200}) async {
    final r = await _supabase
        .rpc('campaign_send_batch', params: {'p_id': id, 'p_limit': taille});
    final m = Map<String, dynamic>.from(r as Map);
    return LotEnvoye(
      traites: m['processed'] as int,
      creees: m['created'] as int,
      restants: m['remaining'] as int,
      termine: m['status'] == 'sent',
    );
  }
}

final campagnesAdminActionsProvider = Provider((ref) => const CampagnesAdminActions());

enum RefusCampagne { permission, conflit, saisie, introuvable, autre }

RefusCampagne classerRefusCampagne(Object e) {
  if (e is! PostgrestException) return RefusCampagne.autre;
  return switch (e.code) {
    '42501' => RefusCampagne.permission,
    '55000' => RefusCampagne.conflit,
    '22023' || '22001' => RefusCampagne.saisie,
    'P0002' => RefusCampagne.introuvable,
    _ => RefusCampagne.autre,
  };
}

String detailCampagne(Object e) => e is PostgrestException ? e.message : e.toString();
