import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Le référentiel géographique côté administration (villes, pays, doublons).
///
/// Lecture : les tables, publiques. Écriture : uniquement les cinq fonctions de
/// la migration 20261019130000 — permission `geography.reference.manage`
/// (superAdmin), motif obligatoire, contrôle des dépendances, historique.

SupabaseClient get _supabase => Supabase.instance.client;

class VilleRef {
  const VilleRef({
    required this.id,
    required this.nom,
    required this.pays,
    required this.latitude,
    required this.longitude,
    required this.population,
    this.region,
    this.alias = const [],
  });

  final int id;
  final String nom;
  final String pays;
  final String? region;
  final double latitude;
  final double longitude;
  final int population;
  final List<String> alias;

  factory VilleRef.fromRow(Map<String, dynamic> r) => VilleRef(
        id: r['id'] as int,
        nom: r['nom'] as String,
        pays: r['pays'] as String,
        region: r['region'] as String?,
        latitude: (r['latitude'] as num).toDouble(),
        longitude: (r['longitude'] as num).toDouble(),
        population: (r['population'] as num).toInt(),
        alias: [for (final a in (r['alias_plies'] as List? ?? const [])) '$a'],
      );
}

class DoublonVille {
  const DoublonVille({
    required this.idA,
    required this.idB,
    required this.nomA,
    required this.nomB,
    required this.pays,
    required this.distanceKm,
    required this.profilsA,
    required this.profilsB,
    required this.groupesA,
    required this.groupesB,
  });

  final int idA;
  final int idB;
  final String nomA;
  final String nomB;
  final String pays;
  final double distanceKm;
  final int profilsA;
  final int profilsB;
  final int groupesA;
  final int groupesB;

  factory DoublonVille.fromRow(Map<String, dynamic> r) {
    int n(Object? m, String k) => ((m as Map?)?[k] as num?)?.toInt() ?? 0;
    return DoublonVille(
      idA: r['id_a'] as int,
      idB: r['id_b'] as int,
      nomA: r['nom_a'] as String,
      nomB: r['nom_b'] as String,
      pays: r['pays'] as String,
      distanceKm: (r['distance_km'] as num).toDouble(),
      profilsA: n(r['usage_a'], 'profils'),
      profilsB: n(r['usage_b'], 'profils'),
      groupesA: n(r['usage_a'], 'groupes'),
      groupesB: n(r['usage_b'], 'groupes'),
    );
  }
}

/// La recherche et le pays filtré : deux caractères au moins, sinon rien
/// (33 880 lignes ne se listent pas).
final rechercheVilleProvider = StateProvider.autoDispose<String>((ref) => '');
final paysFiltreProvider = StateProvider.autoDispose<String?>((ref) => null);

final paysRefProvider = FutureProvider.autoDispose<List<({String nom, String code})>>((ref) async {
  final rows = await _supabase.from('pays').select().order('nom');
  return [
    for (final r in rows) (nom: r['nom'] as String, code: r['code_iso_herite'] as String),
  ];
});

/// Les 60 villes les plus peuplées correspondant. Une erreur de lecture reste
/// une erreur — jamais « aucune ville ».
final villesRefProvider = FutureProvider.autoDispose<List<VilleRef>>((ref) async {
  final terme = ref.watch(rechercheVilleProvider).trim();
  final pays = ref.watch(paysFiltreProvider);
  if (terme.length < 2 && pays == null) return const [];
  var q = _supabase.from('villes').select();
  if (terme.length >= 2) {
    // % et _ saisis par l'utilisateur ne sont pas des jokers.
    final sur = terme.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
    q = q.ilike('nom', '%$sur%');
  }
  if (pays != null) q = q.eq('pays', pays);
  final rows = await q.order('population', ascending: false).limit(60);
  return [
    for (final r in rows) VilleRef.fromRow(Map<String, dynamic>.from(r)),
  ];
});

final doublonsVillesProvider = FutureProvider.autoDispose<List<DoublonVille>>((ref) async {
  final rows = await _supabase.rpc('villes_doublons_possibles', params: {'p_limit': 100}) as List;
  return [
    for (final r in rows) DoublonVille.fromRow(Map<String, dynamic>.from(r as Map)),
  ];
});

final permissionReferentielProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, cle) async {
  final ok = await _supabase.rpc('admin_has_permission', params: {'perm': cle});
  return ok == true;
});

/// Les écritures. Chacune lève [PostgrestException] en cas de refus.
class ReferentielAdminActions {
  const ReferentielAdminActions();

  Future<void> enregistrerVille({
    int? id,
    required String nom,
    required String pays,
    String? region,
    required double latitude,
    required double longitude,
    required int population,
    required List<String> alias,
    required String motif,
  }) async {
    await _supabase.rpc('ville_admin_save', params: {
      'p_id': id,
      'p_nom': nom,
      'p_pays': pays,
      'p_region': region,
      'p_lat': latitude,
      'p_lon': longitude,
      'p_population': population,
      'p_aliases': alias,
      'p_reason': motif,
    });
  }

  Future<void> fusionner(int garder, int retirer, String motif) =>
      _supabase.rpc('ville_admin_merge',
          params: {'p_keep': garder, 'p_drop': retirer, 'p_reason': motif});

  Future<void> supprimer(int id, String motif) =>
      _supabase.rpc('ville_admin_delete', params: {'p_id': id, 'p_reason': motif});

  Future<void> ajouterPays(String nom, String code, String motif) =>
      _supabase.rpc('pays_admin_add',
          params: {'p_nom': nom, 'p_code': code, 'p_reason': motif});
}

final referentielAdminActionsProvider = Provider((ref) => const ReferentielAdminActions());

enum RefusReferentiel { permission, conflit, saisie, introuvable, autre }

RefusReferentiel classerRefusReferentiel(Object e) {
  if (e is! PostgrestException) return RefusReferentiel.autre;
  return switch (e.code) {
    '42501' => RefusReferentiel.permission,
    '55000' => RefusReferentiel.conflit,
    '22023' || '22001' => RefusReferentiel.saisie,
    'P0002' => RefusReferentiel.introuvable,
    _ => RefusReferentiel.autre,
  };
}

String detailReferentiel(Object e) => e is PostgrestException ? e.message : e.toString();
