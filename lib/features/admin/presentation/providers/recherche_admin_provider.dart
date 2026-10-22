import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Recherche globale et file « à traiter » de l'administrateur.
///
/// Les deux viennent de fonctions de la migration 20261019230000 : le serveur
/// ne rend que les sources dont l'administrateur détient le droit de lecture, et
/// dit celles qu'il a ignorées.

SupabaseClient get _supabase => Supabase.instance.client;

class ResultatRecherche {
  const ResultatRecherche(this.id, this.titre, this.sousTitre, this.statut);
  final String id;
  final String titre;
  final String sousTitre;
  final String statut;
}

class GroupeRecherche {
  const GroupeRecherche(this.genre, this.resultats);
  final String genre; // members | tickets | reports | businesses | events | procedures | embassies | campaigns
  final List<ResultatRecherche> resultats;
}

class ReponseRecherche {
  const ReponseRecherche({required this.groupes, required this.ignorees, required this.total});
  final List<GroupeRecherche> groupes;

  /// Sources non cherchées faute de droit : à dire, pour qu'« aucun résultat »
  /// ne soit pas pris pour « pas le droit de chercher là ».
  final List<String> ignorees;
  final int total;
}

/// Le mot cherché ; `null` tant que rien n'a été lancé. La recherche est
/// journalisée : elle ne part qu'à la validation, jamais à chaque frappe.
final motRechercheProvider = StateProvider.autoDispose<String?>((ref) => null);

final rechercheGlobaleProvider = FutureProvider.autoDispose<ReponseRecherche?>((ref) async {
  final mot = ref.watch(motRechercheProvider);
  if (mot == null) return null;
  final r = await _supabase.rpc('admin_global_search', params: {'p_query': mot});
  final m = Map<String, dynamic>.from(r as Map);
  return ReponseRecherche(
    groupes: [
      for (final g in (m['groups'] as List))
        GroupeRecherche(
          g['kind'] as String,
          [
            for (final i in (g['items'] as List))
              ResultatRecherche(
                '${i['id']}',
                i['title'] as String? ?? '',
                i['subtitle'] as String? ?? '',
                i['status'] as String? ?? '',
              ),
          ],
        ),
    ],
    ignorees: [for (final x in (m['skipped'] as List)) '$x'],
    total: (m['total'] as num).toInt(),
  );
});

class LigneATraiter {
  const LigneATraiter(this.cle, this.total, this.enRetard, this.plusAncien);
  final String cle;
  final int total;
  final int enRetard;
  final DateTime? plusAncien;
}

/// Ce qui attend l'administrateur, compté à l'appel. Une erreur reste une
/// erreur : une file qui n'a pas pu être lue n'est pas une file vide.
final fileATraiterProvider = FutureProvider.autoDispose<List<LigneATraiter>>((ref) async {
  final rows = await _supabase.rpc('admin_attention_queue') as List;
  return [
    for (final r in rows)
      LigneATraiter(
        r['key'] as String,
        (r['total'] as num).toInt(),
        (r['late'] as num?)?.toInt() ?? 0,
        DateTime.tryParse('${r['oldest'] ?? ''}')?.toLocal(),
      ),
  ];
});

/// La destination du tableau de bord où traiter chaque famille.
String destinationDe(String cleOuGenre) => switch (cleOuGenre) {
      'members' => 'users',
      'tickets' || 'tickets_escalated' || 'tickets_overdue' => 'support',
      'events_pending' => 'evenements',
      'reports' || 'appeals' => 'reports',
      'businesses' || 'businesses_review' => 'businesses',
      'events' => 'evenements',
      'procedures' => 'demarches',
      'embassies' => 'embassies',
      'campaigns' => 'notifications',
      'privacy' => 'securite',
      _ => 'overview',
    };

String detailRecherche(Object e) => e is PostgrestException ? e.message : e.toString();
