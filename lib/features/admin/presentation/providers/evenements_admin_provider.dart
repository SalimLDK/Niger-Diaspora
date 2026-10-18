import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Événements côté administration : calendrier, inscrits, statistiques.
///
/// Lecture seulement, par les trois fonctions de la migration 20261019190000.
/// Les écritures (annuler, supprimer) restent celles de l'écran de modération.

SupabaseClient get _supabase => Supabase.instance.client;

class EvenementCal {
  const EvenementCal({
    required this.id,
    required this.titre,
    required this.debut,
    required this.statut,
    required this.inscrits,
    this.fin,
    this.ville,
    this.pays,
    this.enLigne = false,
    this.capacite,
    this.organisateur,
  });

  final String id;
  final String titre;
  final DateTime debut; // heure locale de l'appareil
  final DateTime? fin;
  final String statut; // draft | upcoming | ongoing | ended | cancelled
  final String? ville;
  final String? pays;
  final bool enLigne;
  final int inscrits;
  final int? capacite;
  final String? organisateur;

  factory EvenementCal.fromJson(Map<String, dynamic> j) => EvenementCal(
        id: j['id'] as String,
        titre: j['title'] as String? ?? '',
        debut: DateTime.parse(j['starts_at'] as String).toLocal(),
        fin: j['ends_at'] == null ? null : DateTime.parse(j['ends_at'] as String).toLocal(),
        statut: j['status'] as String? ?? 'upcoming',
        ville: j['city'] as String?,
        pays: j['country_code'] as String?,
        enLigne: j['is_online'] as bool? ?? false,
        inscrits: (j['attendee_count'] as num?)?.toInt() ?? 0,
        capacite: (j['max_attendees'] as num?)?.toInt(),
        organisateur: j['organizer_name'] as String?,
      );
}

class MoisCalendrier {
  const MoisCalendrier(this.evenements, this.prives);
  final List<EvenementCal> evenements;

  /// Événements non publics ou brouillons de la période : comptés, jamais listés.
  final int prives;
}

/// Un mois, du 1er (minuit local) au 1er du suivant. Une erreur de lecture
/// reste une erreur — jamais « aucun événement ».
final calendrierMoisProvider =
    FutureProvider.autoDispose.family<MoisCalendrier, DateTime>((ref, mois) async {
  final du = DateTime(mois.year, mois.month);
  final au = DateTime(mois.year, mois.month + 1);
  final r = await _supabase.rpc('event_admin_calendar', params: {
    'p_from': du.toUtc().toIso8601String(),
    'p_to': au.toUtc().toIso8601String(),
  });
  final m = Map<String, dynamic>.from(r as Map);
  return MoisCalendrier(
    [
      for (final e in (m['events'] as List))
        EvenementCal.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
    (m['hidden_private'] as num?)?.toInt() ?? 0,
  );
});

class Inscrit {
  const Inscrit(this.userId, this.nom, this.date);
  final String userId;
  final String nom;
  final DateTime? date;
}

/// La liste des inscrits d'un événement : appelée au geste, jamais en
/// arrière-plan — chaque lecture est journalisée côté serveur.
Future<List<Inscrit>> lireInscrits(String eventId) async {
  final rows = await _supabase.rpc('event_admin_attendees', params: {'p_id': eventId}) as List;
  return [
    for (final r in rows)
      Inscrit(
        r['user_id'] as String,
        r['display_name'] as String? ?? '',
        DateTime.tryParse(r['joined_at'] as String? ?? '')?.toLocal(),
      ),
  ];
}

class StatsEvenements {
  const StatsEvenements({
    required this.jours,
    required this.crees,
    required this.aVenir,
    required this.inscriptions,
    required this.annules,
    required this.parStatut,
    required this.definitions,
    required this.nonMesure,
    this.tauxRemplissage,
  });
  final int jours;
  final int crees;
  final int aVenir;
  final int inscriptions;
  final int annules;
  final double? tauxRemplissage;
  final Map<String, int> parStatut;
  final Map<String, String> definitions;
  final List<String> nonMesure;
}

final fenetreStatsProvider = StateProvider.autoDispose<int>((ref) => 30);

final statsEvenementsProvider = FutureProvider.autoDispose<StatsEvenements>((ref) async {
  final jours = ref.watch(fenetreStatsProvider);
  final r = await _supabase.rpc('event_admin_stats', params: {'p_days': jours});
  final m = Map<String, dynamic>.from(r as Map);
  return StatsEvenements(
    jours: (m['window_days'] as num).toInt(),
    crees: (m['events_created'] as num).toInt(),
    aVenir: (m['events_upcoming'] as num).toInt(),
    inscriptions: (m['registrations'] as num).toInt(),
    annules: (m['events_cancelled'] as num).toInt(),
    tauxRemplissage: (m['fill_rate_upcoming'] as num?)?.toDouble(),
    parStatut: {
      for (final e in (m['by_status_now'] as Map).entries) '${e.key}': (e.value as num).toInt(),
    },
    definitions: {
      for (final e in (m['definitions'] as Map).entries) '${e.key}': '${e.value}',
    },
    nonMesure: [for (final x in (m['not_measured'] as List)) '$x'],
  );
});

final permissionEvenementsProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, cle) async {
  final ok = await _supabase.rpc('admin_has_permission', params: {'perm': cle});
  return ok == true;
});

String detailEvenements(Object e) => e is PostgrestException ? e.message : e.toString();
