import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Demandes relatives aux données et incidents de sécurité, côté administration.
///
/// Lecture : les tables (permissions `privacy.requests.manage` /
/// `security.incidents.manage`, superAdmin seul). Écriture : uniquement les
/// sept RPC de la migration 20261018230000.

SupabaseClient get _supabase => Supabase.instance.client;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

// ═══ Demandes de données ═══════════════════════════════════════════════════

class DemandeDonnees {
  const DemandeDonnees({
    required this.id,
    required this.nature,
    required this.statut,
    required this.echeance,
    this.compte,
    this.contact,
    this.perimetre,
    this.methodeIdentite,
    this.resultat,
    this.nonAttribuee = false,
    this.depuisApp = false,
  });

  final String id;
  final String nature; // access | rectification | erasure | portability | objection
  final String statut; // received | identity_verified | in_progress | completed | refused | cancelled
  final DateTime? echeance;
  final String? compte;
  final String? contact;
  final String? perimetre;
  final String? methodeIdentite;
  final String? resultat;

  /// Une demande de l'application attend dans la file tant que personne ne
  /// l'a prise : le serveur refuse de la traiter avant.
  final bool nonAttribuee;
  final bool depuisApp;

  bool get ouverte =>
      statut == 'received' || statut == 'identity_verified' || statut == 'in_progress';
  bool get enRetard => ouverte && echeance != null && echeance!.isBefore(DateTime.now());

  factory DemandeDonnees.fromRow(Map<String, dynamic> r) => DemandeDonnees(
        id: r['id'] as String,
        nature: r['kind'] as String,
        statut: r['status'] as String,
        echeance: _date(r['due_at']),
        compte: r['requester_id'] as String?,
        contact: r['requester_contact'] as String?,
        perimetre: r['scope'] as String?,
        methodeIdentite: r['identity_method'] as String?,
        resultat: r['result_note'] as String?,
        nonAttribuee: r['assigned_to'] == null,
        depuisApp: r['source'] == 'app',
      );
}

/// Où en est la suppression du compte visé par une demande d'effacement.
class EtatSuppression {
  const EtatSuppression({required this.lie, this.comptePresent, this.statut});
  final bool lie;
  final bool? comptePresent;
  final String? statut;
}

final etatSuppressionProvider =
    FutureProvider.autoDispose.family<EtatSuppression, String>((ref, id) async {
  final r = await _supabase.rpc('privacy_request_erasure_status', params: {'p_id': id});
  final m = Map<String, dynamic>.from(r as Map);
  return EtatSuppression(
    lie: m['linked'] == true,
    comptePresent: m['account_exists'] as bool?,
    statut: m['deletion_status'] as String?,
  );
});

/// L'état des lieux d'une demande : des nombres par catégorie, jamais de contenu.
final etatDesLieuxProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await _supabase.rpc('privacy_request_data_summary', params: {'p_id': id});
  return Map<String, dynamic>.from(r as Map);
});

enum VueSecurite { enCours, closes, toutes }

final vueDemandesProvider =
    StateProvider.autoDispose<VueSecurite>((ref) => VueSecurite.enCours);

final demandesDonneesProvider =
    FutureProvider.autoDispose<List<DemandeDonnees>>((ref) async {
  final vue = ref.watch(vueDemandesProvider);
  var q = _supabase.from('privacy_requests').select();
  switch (vue) {
    case VueSecurite.enCours:
      q = q.inFilter('status', ['received', 'identity_verified', 'in_progress']);
    case VueSecurite.closes:
      q = q.inFilter('status', ['completed', 'refused', 'cancelled']);
    case VueSecurite.toutes:
      break;
  }
  final rows = await q.order('due_at').limit(200);
  return [
    for (final r in rows) DemandeDonnees.fromRow(Map<String, dynamic>.from(r)),
  ];
});

// ═══ Incidents ═════════════════════════════════════════════════════════════

class IncidentSecurite {
  const IncidentSecurite({
    required this.id,
    required this.titre,
    required this.gravite,
    required this.statut,
    required this.resume,
    this.impact,
    this.detecteLe,
    this.cause,
    this.mesures,
    this.enseignements,
  });

  final String id;
  final String titre;
  final String gravite; // low | medium | high | critical
  final String statut; // open | contained | resolved | closed
  final String resume;
  final String? impact;
  final DateTime? detecteLe;
  final String? cause;
  final String? mesures;
  final String? enseignements;

  bool get clos => statut == 'closed';

  factory IncidentSecurite.fromRow(Map<String, dynamic> r) => IncidentSecurite(
        id: r['id'] as String,
        titre: r['title'] as String,
        gravite: r['severity'] as String,
        statut: r['status'] as String,
        resume: r['summary'] as String,
        impact: r['impact'] as String?,
        detecteLe: _date(r['detected_at']),
        cause: r['cause'] as String?,
        mesures: r['corrective_actions'] as String?,
        enseignements: r['lessons'] as String?,
      );
}

class EvenementIncident {
  const EvenementIncident(this.nature, this.texte, this.date);
  final String nature; // opened | note | status | severity
  final String texte;
  final DateTime? date;
}

final vueIncidentsProvider =
    StateProvider.autoDispose<VueSecurite>((ref) => VueSecurite.enCours);

final incidentsProvider = FutureProvider.autoDispose<List<IncidentSecurite>>((ref) async {
  final vue = ref.watch(vueIncidentsProvider);
  var q = _supabase.from('security_incidents').select();
  switch (vue) {
    case VueSecurite.enCours:
      q = q.neq('status', 'closed');
    case VueSecurite.closes:
      q = q.eq('status', 'closed');
    case VueSecurite.toutes:
      break;
  }
  final rows = await q.order('detected_at', ascending: false).limit(200);
  return [
    for (final r in rows) IncidentSecurite.fromRow(Map<String, dynamic>.from(r)),
  ];
});

final chronologieIncidentProvider = FutureProvider.autoDispose
    .family<List<EvenementIncident>, String>((ref, id) async {
  final rows = await _supabase
      .from('security_incident_events')
      .select('kind, body, occurred_at')
      .eq('incident_id', id)
      .order('occurred_at');
  return [
    for (final r in rows)
      EvenementIncident(r['kind'] as String, r['body'] as String? ?? '', _date(r['occurred_at'])),
  ];
});

final permissionSecuriteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, cle) async {
  final ok = await _supabase.rpc('admin_has_permission', params: {'perm': cle});
  return ok == true;
});

/// Les écritures. Chacune lève [PostgrestException] en cas de refus.
class SecuriteAdminActions {
  const SecuriteAdminActions();

  Future<void> creerDemande({
    required String nature,
    String? compte,
    String? contact,
    String? perimetre,
    required DateTime echeance,
  }) async {
    await _supabase.rpc('privacy_request_create', params: {
      'p_kind': nature,
      'p_requester_id': compte,
      'p_contact': contact,
      'p_ticket_id': null,
      'p_scope': perimetre,
      'p_due_at': echeance.toUtc().toIso8601String(),
    });
  }

  Future<void> prendreDemande(String id) =>
      _supabase.rpc('privacy_request_take', params: {'p_id': id});

  Future<void> verifierIdentite(String id, String methode) =>
      _supabase.rpc('privacy_request_verify_identity',
          params: {'p_id': id, 'p_method': methode});

  /// [reponse] : le texte que le demandeur lira ; requis par le serveur pour
  /// terminer ou refuser la demande d'une personne qui a un compte.
  Future<void> transitionnerDemande(String id, String vers,
          {String? note, String? reponse}) =>
      _supabase.rpc('privacy_request_transition',
          params: {'p_id': id, 'p_to': vers, 'p_note': note, 'p_answer': reponse});

  Future<void> ouvrirIncident({
    required String titre,
    required String gravite,
    required String resume,
    String? impact,
  }) async {
    await _supabase.rpc('security_incident_open', params: {
      'p_title': titre,
      'p_severity': gravite,
      'p_summary': resume,
      'p_impact': impact,
    });
  }

  Future<void> noter(String id, String texte) =>
      _supabase.rpc('security_incident_note', params: {'p_id': id, 'p_body': texte});

  Future<void> changerGravite(String id, String gravite, String motif) =>
      _supabase.rpc('security_incident_set_severity',
          params: {'p_id': id, 'p_severity': gravite, 'p_reason': motif});

  Future<void> transitionnerIncident(
    String id,
    String vers,
    String note, {
    String? cause,
    String? mesures,
    String? enseignements,
  }) =>
      _supabase.rpc('security_incident_transition', params: {
        'p_id': id,
        'p_to': vers,
        'p_note': note,
        'p_cause': cause,
        'p_actions': mesures,
        'p_lessons': enseignements,
      });
}

final securiteAdminActionsProvider = Provider((ref) => const SecuriteAdminActions());

enum RefusSecurite { permission, conflit, saisie, introuvable, autre }

RefusSecurite classerRefusSecurite(Object e) {
  if (e is! PostgrestException) return RefusSecurite.autre;
  return switch (e.code) {
    '42501' => RefusSecurite.permission,
    '55000' => RefusSecurite.conflit,
    '22023' || '22001' => RefusSecurite.saisie,
    'P0002' => RefusSecurite.introuvable,
    _ => RefusSecurite.autre,
  };
}

String detailSecurite(Object e) => e is PostgrestException ? e.message : e.toString();
