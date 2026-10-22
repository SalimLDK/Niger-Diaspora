import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Demandes d'informations et recours d'un dossier de modération.
///
/// Les écritures passent TOUTES par les six RPC de la migration
/// 20261018090000 : le serveur contrôle la permission, le statut et la
/// séparation des tâches, et écrit l'audit. Ce fichier ne contourne rien ; il
/// lit les deux tables (RLS : `moderation.reports.view` /
/// `moderation.appeals.view`) et traduit les refus en messages lisibles.

SupabaseClient get _supabase => Supabase.instance.client;

/// Une demande d'informations (`moderation_info_requests`).
class DemandeInformations {
  const DemandeInformations({
    required this.id,
    required this.recipientKind,
    required this.questions,
    required this.dueAt,
    required this.status,
    this.response,
    this.sentAt,
  });

  final String id;
  final String recipientKind; // reporter | reported
  final String questions;
  final DateTime dueAt;
  final String status; // draft | sent | answered | cancelled
  final String? response;
  final DateTime? sentAt;

  /// « En retard » se déduit : le statut stocké ne ment jamais.
  bool get enRetard => status == 'sent' && dueAt.isBefore(DateTime.now());

  factory DemandeInformations.fromRow(Map<String, dynamic> r) =>
      DemandeInformations(
        id: r['id'] as String,
        recipientKind: r['recipient_kind'] as String,
        questions: r['questions'] as String,
        dueAt: DateTime.parse(r['due_at'] as String).toLocal(),
        status: r['status'] as String,
        response: r['response'] as String?,
        sentAt: r['sent_at'] == null
            ? null
            : DateTime.parse(r['sent_at'] as String).toLocal(),
      );
}

/// Un recours (`moderation_appeals`).
class RecoursModeration {
  const RecoursModeration({
    required this.id,
    required this.argument,
    required this.status,
    required this.contestedDecider,
    this.contestedAction,
    this.contestedReason,
    this.reviewerId,
    this.decisionNote,
  });

  final String id;
  final String argument;
  final String status; // received | under_review | upheld | reduced | annulled | sent_back
  final String contestedDecider;
  final String? contestedAction;
  final String? contestedReason;
  final String? reviewerId;
  final String? decisionNote;

  bool get ouvert => status == 'received' || status == 'under_review';

  factory RecoursModeration.fromRow(Map<String, dynamic> r) => RecoursModeration(
        id: r['id'] as String,
        argument: r['argument'] as String,
        status: r['status'] as String,
        contestedDecider: r['contested_decider'] as String,
        contestedAction: r['contested_action'] as String?,
        contestedReason: r['contested_reason'] as String?,
        reviewerId: r['reviewer_id'] as String?,
        decisionNote: r['decision_note'] as String?,
      );
}

/// Les demandes d'un dossier, de la plus récente à la plus ancienne. Une
/// erreur de lecture reste une erreur : jamais une liste vide.
final demandesInformationsProvider = FutureProvider.autoDispose
    .family<List<DemandeInformations>, String>((ref, reportId) async {
  final rows = await _supabase
      .from('moderation_info_requests')
      .select()
      .eq('report_id', reportId)
      .order('created_at', ascending: false);
  return [
    for (final r in rows) DemandeInformations.fromRow(Map<String, dynamic>.from(r)),
  ];
});

final recoursDuDossierProvider = FutureProvider.autoDispose
    .family<List<RecoursModeration>, String>((ref, reportId) async {
  final rows = await _supabase
      .from('moderation_appeals')
      .select()
      .eq('report_id', reportId)
      .order('received_at', ascending: false);
  return [
    for (final r in rows) RecoursModeration.fromRow(Map<String, dynamic>.from(r)),
  ];
});

/// La permission, lue côté serveur : le client ne porte pas le catalogue
/// (il ne connaît que les anciennes clés). Indicatif — le serveur reste
/// l'autorité finale.
final adminAPermissionProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, cle) async {
  final ok = await _supabase.rpc('admin_has_permission', params: {'perm': cle});
  return ok == true;
});

/// Nature d'un refus du serveur, pour choisir le message affiché.
enum RefusModeration { permission, conflit, saisie, introuvable, autre }

RefusModeration classerRefus(Object erreur) {
  if (erreur is! PostgrestException) return RefusModeration.autre;
  return switch (erreur.code) {
    '42501' => RefusModeration.permission,
    '55000' => RefusModeration.conflit,
    '22023' || '22001' => RefusModeration.saisie,
    'P0002' => RefusModeration.introuvable,
    _ => RefusModeration.autre,
  };
}

/// Le texte du serveur (déjà en français, sans donnée privée).
String detailRefus(Object erreur) =>
    erreur is PostgrestException ? erreur.message : erreur.toString();

/// Les six écritures. Chacune lève [PostgrestException] en cas de refus.
class DossierModerationActions {
  const DossierModerationActions();

  Future<void> redigerDemande({
    required String reportId,
    required String destinataire,
    required String questions,
    required DateTime echeance,
  }) async {
    await _supabase.rpc('moderation_info_request_create', params: {
      'p_report_id': reportId,
      'p_recipient_kind': destinataire,
      'p_questions': questions,
      'p_due_at': echeance.toUtc().toIso8601String(),
    });
  }

  Future<void> envoyerDemande(String id) =>
      _supabase.rpc('moderation_info_request_send', params: {'p_id': id});

  Future<void> consignerReponse(String id, String reponse) =>
      _supabase.rpc('moderation_info_request_record_response',
          params: {'p_id': id, 'p_response': reponse});

  Future<void> enregistrerRecours(String reportId, String arguments) =>
      _supabase.rpc('moderation_appeal_register',
          params: {'p_report_id': reportId, 'p_argument': arguments});

  Future<void> prendreRecours(String id) =>
      _supabase.rpc('moderation_appeal_take', params: {'p_id': id});

  Future<void> trancherRecours(String id, String issue, String motif) =>
      _supabase.rpc('moderation_appeal_decide',
          params: {'p_id': id, 'p_outcome': issue, 'p_note': motif});
}

final dossierModerationActionsProvider =
    Provider((ref) => const DossierModerationActions());
