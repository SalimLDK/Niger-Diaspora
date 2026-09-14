import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/exceptions.dart';
import 'supabase_auth_bridge.dart';

/// Une ville du référentiel `public.villes`.
///
/// Le référentiel existe pour que le profil, et plus tard les groupes de
/// ville, désignent une ligne plutôt qu'un texte libre. Le champ de texte nu
/// avait déjà produit « Niamey » et « niamey » côté à côté, « Arewa » (un
/// département) et « Almoustapha » (un prénom) — de quoi ouvrir autant de
/// groupes officiels distincts.
class Ville {
  const Ville({
    required this.id,
    required this.nom,
    required this.pays,
    required this.latitude,
    required this.longitude,
    required this.population,
    this.region,
    this.poleId,
  });

  final int id;
  final String nom;
  final String pays;
  final String? region;
  final double latitude;
  final double longitude;
  final int population;

  /// Grande ville dont celle-ci est une banlieue (Laval → Montréal), quand
  /// l'import en a trouvé une. C'est elle qui portera le groupe de ville.
  final int? poleId;

  factory Ville.fromRow(Map<String, dynamic> row) {
    return Ville(
      id: (row['id'] as num).toInt(),
      nom: row['nom'] as String,
      pays: row['pays'] as String,
      region: row['region'] as String?,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      population: (row['population'] as num?)?.toInt() ?? 0,
      poleId: (row['pole_id'] as num?)?.toInt(),
    );
  }

  /// « Montréal » ou « Montréal, Québec » — la région lève l'ambiguïté entre
  /// deux homonymes d'un même pays, dont la liste en compte (deux Springfield
  /// aux États-Unis).
  String get libelle => region == null || region!.isEmpty ? nom : '$nom, $region';

  @override
  bool operator ==(Object other) => other is Ville && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Ville($id, $nom, $pays)';
}

/// Lecture du référentiel des villes.
///
/// Tout passe par des fonctions SQL, jamais par un `select` sur la table :
///
/// * la règle de pliage des noms (minuscules, accents, apostrophes) vit en
///   base, dans `plier_nom_de_pays`. La recopier ici en ferait une deuxième
///   source, qui dériverait ;
/// * le pays peut arriver sous son code ISO hérité (« CA ») depuis une
///   version de l'app déjà installée : `pays_canonique` le ramène au nom,
///   côté base, une fois pour toutes ;
/// * la ville la plus proche de coordonnées se calcule sur les 33 880 lignes,
///   ce qui n'a rien à faire dans le téléphone.
class VillesService {
  VillesService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Villes du [pays] dont le nom ou un alias commence par [texte], la plus
  /// peuplée d'abord. Un [texte] vide rend les plus peuplées du pays, ce qui
  /// donne une liste utile dès l'ouverture du champ.
  Future<List<Ville>> rechercher({
    String? pays,
    String texte = '',
    int limite = 20,
  }) async {
    // La table n'est lisible que par `authenticated` : sans session, la RLS
    // rendrait une liste vide, et le champ paraîtrait simplement ne rien
    // connaître.
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase indisponible.');
    }
    try {
      final dynamic brut = await _client.rpc(
        'rechercher_villes',
        params: {'p_pays': pays, 'p_texte': texte, 'p_limite': limite},
      );
      return _lignes(brut).map(Ville.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw ServerException('Recherche de ville refusée : ${e.message}');
    } catch (e) {
      throw ServerException('Recherche de ville impossible : $e');
    }
  }

  /// Ville de référence la plus proche de coordonnées, dans [rayonKm].
  ///
  /// C'est ce qui répond à « Vous êtes à Montréal ? ». On ne retient jamais
  /// le nom que renvoie le géocodage du téléphone : c'est lui qui écrirait
  /// « Almoustapha » dans le profil.
  Future<Ville?> laPlusProche({
    required double latitude,
    required double longitude,
    double rayonKm = 50,
  }) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase indisponible.');
    }
    try {
      final dynamic brut = await _client.rpc(
        'ville_la_plus_proche',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_rayon_km': rayonKm,
        },
      );
      final lignes = _lignes(brut);
      return lignes.isEmpty ? null : Ville.fromRow(lignes.first);
    } on PostgrestException catch (e) {
      throw ServerException('Localisation de la ville refusée : ${e.message}');
    } catch (e) {
      throw ServerException('Localisation de la ville impossible : $e');
    }
  }

  /// Une fonction `RETURNS SETOF` rend une liste ; la même fonction avec une
  /// seule ligne peut arriver comme un objet seul selon la version de
  /// PostgREST. Les deux formes sont acceptées.
  List<Map<String, dynamic>> _lignes(dynamic brut) {
    if (brut is List) {
      return brut.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (brut is Map<String, dynamic>) return [brut];
    return const [];
  }
}
