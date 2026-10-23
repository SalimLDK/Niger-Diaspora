import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Le bloc « À traiter » du tableau de bord (migration 20261019130000).
///
/// Calculé côté serveur, élément par élément selon les droits de l'appelant :
/// un rôle sans droit sur un module ne reçoit pas la ligne. Une erreur de
/// calcul reste une erreur — jamais une liste vide qui se lirait « tout est
/// calme ».

class ElementATraiter {
  const ElementATraiter({
    required this.cle,
    required this.nombre,
    this.urgent,
    this.leMoinsRecent,
  });

  final String cle; // reports | support | demarches | campaigns | privacy | incidents | listings
  final int nombre;

  /// Un sous-ensemble défini par l'élément (non pris en charge, en retard…).
  final int? urgent;
  final DateTime? leMoinsRecent;

  /// La rubrique du menu où se traite cet élément.
  String get destination => switch (cle) {
        'reports' => 'reports',
        'support' => 'support',
        'demarches' => 'demarches',
        'campaigns' => 'notifications',
        'privacy' || 'incidents' => 'securite',
        'listings' => 'businesses',
        _ => '',
      };

  factory ElementATraiter.fromJson(Map<String, dynamic> j) => ElementATraiter(
        cle: j['key'] as String,
        nombre: (j['count'] as num).toInt(),
        urgent: (j['urgent'] as num?)?.toInt(),
        leMoinsRecent: DateTime.tryParse(j['oldest_at'] as String? ?? '')?.toLocal(),
      );
}

class ListeATraiter {
  const ListeATraiter(this.calculeLe, this.elements);
  final DateTime? calculeLe;
  final List<ElementATraiter> elements;
}

final aTraiterProvider = FutureProvider.autoDispose<ListeATraiter>((ref) async {
  final r = await Supabase.instance.client.rpc('admin_dashboard_tasks');
  final m = Map<String, dynamic>.from(r as Map);
  return ListeATraiter(
    DateTime.tryParse(m['computed_at'] as String? ?? '')?.toLocal(),
    [
      for (final e in (m['items'] as List))
        ElementATraiter.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
  );
});

String detailATraiter(Object e) => e is PostgrestException ? e.message : e.toString();
