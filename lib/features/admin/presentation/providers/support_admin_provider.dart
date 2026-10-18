import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Les tickets du support, côté administration.
///
/// Lecture : la table (policy `support.tickets.view`). Écriture : uniquement
/// les cinq RPC de la migration 20261018130000 — le serveur contrôle la
/// permission, le responsable, le statut, et écrit l'audit.

SupabaseClient get _supabase => Supabase.instance.client;

/// Un message du fil visible par le membre.
class MessageTicket {
  const MessageTicket({
    required this.id,
    required this.deSupport,
    required this.auteur,
    required this.contenu,
    required this.date,
  });

  final String id;
  final bool deSupport;
  final String auteur;
  final String contenu;
  final DateTime? date;

  factory MessageTicket.fromJson(Map<String, dynamic> m) => MessageTicket(
        id: m['id'] as String? ?? '',
        deSupport: m['isFromSupport'] as bool? ?? false,
        auteur: m['senderName'] as String? ?? '',
        contenu: m['content'] as String? ?? '',
        date: DateTime.tryParse(m['createdAt'] as String? ?? '')?.toLocal(),
      );
}

class TicketAdmin {
  const TicketAdmin({
    required this.id,
    required this.userId,
    required this.userName,
    required this.sujet,
    required this.categorie,
    required this.statut,
    required this.priorite,
    required this.messages,
    required this.creeLe,
    required this.misAJourLe,
    required this.nonLuDuMembre,
    this.responsable,
    this.resolution,
    this.escaladeLe,
    this.escaladeMotif,
  });

  final String id;
  final String userId;
  final String userName;
  final String sujet;
  final String categorie;
  final String statut; // open | in_progress | resolved | closed
  final String priorite; // low | normal | high | urgent
  final String? responsable;
  final String? resolution;
  final DateTime? escaladeLe;
  final String? escaladeMotif;
  final List<MessageTicket> messages;
  final DateTime? creeLe;
  final DateTime? misAJourLe;
  final bool nonLuDuMembre;

  bool get escalade => escaladeLe != null;

  /// Peut-on encore répondre ? Le serveur l'exige « en cours ».
  bool get enCours => statut == 'in_progress';

  factory TicketAdmin.fromRow(Map<String, dynamic> r) => TicketAdmin(
        id: r['id'].toString(),
        userId: r['user_id'] as String? ?? '',
        userName: r['user_name'] as String? ?? '',
        sujet: r['subject'] as String? ?? '',
        categorie: r['category'] as String? ?? 'other',
        statut: r['status'] as String? ?? 'open',
        priorite: r['priority'] as String? ?? 'normal',
        responsable: r['assigned_to'] as String?,
        resolution: r['resolution_note'] as String?,
        escaladeLe: DateTime.tryParse(r['escalated_at'] as String? ?? '')?.toLocal(),
        escaladeMotif: r['escalation_reason'] as String?,
        messages: [
          for (final m in (r['messages'] as List<dynamic>? ?? const []))
            MessageTicket.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        creeLe: DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal(),
        misAJourLe: DateTime.tryParse(r['updated_at'] as String? ?? '')?.toLocal(),
        nonLuDuMembre: r['has_unread_user_messages'] as bool? ?? false,
      );
}

class NoteTicket {
  const NoteTicket({required this.id, required this.auteurId, required this.texte, this.date});
  final String id;
  final String auteurId;
  final String texte;
  final DateTime? date;
}

/// Le filtre de la file : un statut, ou `null` pour tous.
final filtreTicketsProvider = StateProvider.autoDispose<String?>((ref) => 'open');

/// La file. Une erreur de lecture reste une erreur — jamais une liste vide.
final ticketsAdminProvider = FutureProvider.autoDispose<List<TicketAdmin>>((ref) async {
  final filtre = ref.watch(filtreTicketsProvider);
  var q = _supabase.from('support_tickets').select();
  // « escalated » n'est pas un statut : c'est la file du superAdmin.
  if (filtre == 'escalated') {
    q = q.not('escalated_at', 'is', null);
  } else if (filtre != null) {
    q = q.eq('status', filtre);
  }
  final rows = await q.order('updated_at', ascending: false).limit(200);
  return [
    for (final r in rows) TicketAdmin.fromRow(Map<String, dynamic>.from(r)),
  ];
});

final notesTicketProvider =
    FutureProvider.autoDispose.family<List<NoteTicket>, String>((ref, ticketId) async {
  final rows = await _supabase
      .from('support_ticket_notes')
      .select()
      .eq('ticket_id', ticketId)
      .order('created_at');
  return [
    for (final r in rows)
      NoteTicket(
        id: r['id'] as String,
        auteurId: r['author_id'] as String,
        texte: r['body'] as String,
        date: DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal(),
      ),
  ];
});

/// La permission, lue côté serveur (indicative ; le serveur décide).
final permissionSupportProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, cle) async {
  final ok = await _supabase.rpc('admin_has_permission', params: {'perm': cle});
  return ok == true;
});

/// Un modèle de réponse : un texte que l'agent insère puis relit.
class ModeleReponse {
  const ModeleReponse(this.id, this.titre, this.texte, this.categorie);
  final String id;
  final String titre;
  final String texte;
  final String? categorie;
}

final modelesReponseProvider = FutureProvider.autoDispose<List<ModeleReponse>>((ref) async {
  final rows = await _supabase.from('support_reply_templates').select().order('title');
  return [
    for (final r in rows)
      ModeleReponse(r['id'] as String, r['title'] as String, r['body'] as String,
          r['category'] as String?),
  ];
});

/// Un délai cible, en heures d'horloge.
class DelaiCible {
  const DelaiCible(this.categorie, this.priorite, this.premiere, this.resolution);
  final String categorie;
  final String priorite;
  final int? premiere;
  final int? resolution;
}

final delaisCiblesProvider = FutureProvider.autoDispose<List<DelaiCible>>((ref) async {
  final rows = await _supabase.from('support_sla_targets').select().order('category');
  return [
    for (final r in rows)
      DelaiCible(r['category'] as String, r['priority'] as String,
          (r['first_response_hours'] as num?)?.toInt(),
          (r['resolution_hours'] as num?)?.toInt()),
  ];
});

/// Les échéances d'un ticket qui a une cible.
class EcheanceTicket {
  const EcheanceTicket({this.premiereAvant, this.resolutionAvant,
      this.premiereEnRetard = false, this.resolutionEnRetard = false});
  final DateTime? premiereAvant;
  final DateTime? resolutionAvant;
  final bool premiereEnRetard;
  final bool resolutionEnRetard;
  bool get enRetard => premiereEnRetard || resolutionEnRetard;
}

/// Par identifiant de ticket. Une erreur reste une erreur : pas d'« à l'heure »
/// par défaut.
final echeancesProvider = FutureProvider.autoDispose<Map<String, EcheanceTicket>>((ref) async {
  final rows = await _supabase.rpc('support_sla_status') as List;
  return {
    for (final r in rows)
      r['ticket_id'] as String: EcheanceTicket(
        premiereAvant: DateTime.tryParse('${r['first_response_due'] ?? ''}')?.toLocal(),
        resolutionAvant: DateTime.tryParse('${r['resolution_due'] ?? ''}')?.toLocal(),
        premiereEnRetard: r['first_response_late'] == true,
        resolutionEnRetard: r['resolution_late'] == true,
      ),
  };
});

/// Les écritures. Chacune lève [PostgrestException] en cas de refus.
class SupportAdminActions {
  const SupportAdminActions();

  Future<void> transitionner(String id, String vers, {String? note}) =>
      _supabase.rpc('support_ticket_transition',
          params: {'p_id': id, 'p_to': vers, 'p_note': note});

  Future<void> repondre(String id, String texte) =>
      _supabase.rpc('support_ticket_reply', params: {'p_id': id, 'p_body': texte});

  Future<void> noter(String id, String texte) =>
      _supabase.rpc('support_ticket_note', params: {'p_id': id, 'p_body': texte});

  Future<void> prioriser(String id, String priorite) =>
      _supabase.rpc('support_ticket_set_priority',
          params: {'p_id': id, 'p_priority': priorite});

  Future<void> marquerLu(String id) =>
      _supabase.rpc('support_ticket_mark_read', params: {'p_id': id});

  Future<void> escalader(String id, String motif) =>
      _supabase.rpc('support_ticket_escalate', params: {'p_id': id, 'p_reason': motif});

  Future<void> leverEscalade(String id) =>
      _supabase.rpc('support_ticket_escalation_resolve', params: {'p_id': id});

  /// Les deux durées à `null` retirent la cible.
  Future<void> arreterDelai(String categorie, String priorite, int? premiere, int? resolution) =>
      _supabase.rpc('support_sla_set', params: {
        'p_category': categorie,
        'p_priority': priorite,
        'p_first_hours': premiere,
        'p_resolution_hours': resolution,
      });

  Future<void> enregistrerModele(String? id, String titre, String texte, String? categorie) =>
      _supabase.rpc('support_template_save', params: {
        'p_id': id,
        'p_title': titre,
        'p_body': texte,
        'p_category': categorie,
      });

  Future<void> supprimerModele(String id) =>
      _supabase.rpc('support_template_delete', params: {'p_id': id});
}

final supportAdminActionsProvider = Provider((ref) => const SupportAdminActions());

/// Lecture d'un refus du serveur, pour choisir le message.
enum RefusSupport { permission, conflit, saisie, introuvable, autre }

RefusSupport classerRefusSupport(Object e) {
  if (e is! PostgrestException) return RefusSupport.autre;
  return switch (e.code) {
    '42501' => RefusSupport.permission,
    '55000' => RefusSupport.conflit,
    '22023' || '22001' => RefusSupport.saisie,
    'P0002' => RefusSupport.introuvable,
    _ => RefusSupport.autre,
  };
}

String detailSupport(Object e) => e is PostgrestException ? e.message : e.toString();
