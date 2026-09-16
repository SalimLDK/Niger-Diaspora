import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../domain/entities/gif_entity.dart';
import 'gif_remote_datasource.dart';

/// Unique porte d'entrée vers les GIFs distants : l'Edge Function `gif-proxy`.
///
/// Les clés Giphy/Tenor vivent sur le serveur — le `.env` est déclaré comme
/// asset, donc tout ce qu'il contient part dans l'APK et s'en extrait par
/// simple dézippage. L'app envoie une requête métier, jamais une clé.
///
/// Le **fournisseur est choisi par la fonction** (`provider: 'auto'`) : elle
/// seule sait quelles clés sont posées. Un client qui tentait Tenor puis Giphy
/// payait un aller-retour perdu à chaque requête dès qu'une des deux clés
/// manquait — il ne pouvait pas le savoir. La réponse nomme le fournisseur qui
/// a servi, car la forme de la charge utile en dépend.
class GifProxyDataSource implements GifRemoteDataSource {
  static const _functionName = 'gif-proxy';

  final SupabaseClient _supabase;
  final Future<bool> Function() _ensureSession;

  GifProxyDataSource({
    SupabaseClient? supabase,
    Future<bool> Function()? ensureSession,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _ensureSession =
           ensureSession ?? SupabaseAuthBridge.instance.ensureReadableSession;

  @override
  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    return _fetch('trending', type: type, limit: limit);
  }

  @override
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    return _fetch('search', type: type, limit: limit, query: query);
  }

  Future<List<GifEntity>> _fetch(
    String endpoint, {
    required GifContentType type,
    required int limit,
    String? query,
  }) async {
    // `gif-proxy` refuse les appels anonymes — les clés portent un quota
    // facturable. Sans session Supabase, l'invoke partirait avec la seule clé
    // anon et reviendrait en 401 ; la version bornée évite en plus de figer le
    // picker sur un pont lent (voir SupabaseAuthBridge.ensureReadableSession).
    if (!await _ensureSession()) {
      // Le texte d'une exception finit régulièrement dans un bandeau ou un
      // `SnackBar` : il ne nomme pas notre pile technique. Le détail reste au
      // journal, qui ne s'affiche nulle part. Règle vérifiée par
      // `test/core/architecture/noms_internes_hors_ecran_test.dart`, née d'un
      // « Session Supabase non établie » vu en plein écran le 2026-09-14.
      debugPrint('GifProxyDataSource: session absente, invoke non tenté');
      throw ServerException('GIFs indisponibles pour le moment');
    }

    try {
      final response = await _supabase.functions.invoke(
        _functionName,
        body: {
          'provider': 'auto',
          'endpoint': endpoint,
          'type': type == GifContentType.sticker ? 'sticker' : 'gif',
          'limit': limit,
          if (query != null) 'q': query,
        },
      );

      return gifsDepuisReponseProxy(response.data);
    } on FunctionException catch (e) {
      if (_codeOf(e) == 'no_provider') {
        throw GifProvidersUnavailableException(
          'Aucune clé de fournisseur de GIFs posée sur le projet',
        );
      }
      throw ServerException(
        'GIFs indisponibles : ${e.reasonPhrase ?? e.status}',
      );
    }
  }

  /// `details` porte le corps JSON décodé de la réponse d'erreur.
  String? _codeOf(FunctionException e) {
    final details = e.details;
    return details is Map ? details['code'] as String? : null;
  }
}

/// Traduit la réponse de `gif-proxy` en entités.
///
/// Isolée du transport pour être vérifiable sans client Supabase : c'est ici
/// que vit la seule dépendance à la forme exacte de chaque fournisseur —
/// `results[]` chez Tenor, `data[]` chez Giphy — et c'est donc ici que la
/// moindre dérive d'API casserait l'onglet.
@visibleForTesting
List<GifEntity> gifsDepuisReponseProxy(Object? body) {
  final enveloppe = body is Map ? body : null;
  final provider = _providerNomme(enveloppe?['provider']);
  final payload = enveloppe?['payload'];
  if (provider == null || payload is! Map) {
    throw ServerException('Réponse inattendue de gif-proxy');
  }

  return switch (provider) {
    GifProvider.tenor => _parse(payload['results'], _fromTenor),
    GifProvider.giphy => _parse(payload['data'], _fromGiphy),
  };
}

GifProvider? _providerNomme(Object? name) {
  for (final provider in GifProvider.values) {
    if (provider.name == name) return provider;
  }
  return null;
}

List<GifEntity> _parse(
  Object? items,
  GifEntity? Function(Map<String, dynamic>) mapper,
) {
  if (items is! List) return const [];
  return items
      .whereType<Map<String, dynamic>>()
      .map(mapper)
      .whereType<GifEntity>()
      .toList();
}

GifEntity? _fromTenor(Map<String, dynamic> json) {
  final formats = json['media_formats'] as Map<String, dynamic>?;
  if (formats == null) return null;

  // `mediumgif` d'abord : le `gif` d'origine monte à plusieurs Mo, payés sur
  // la data de chaque destinataire. Repli sur `gif` si Tenor ne l'a pas.
  final full = (formats['mediumgif'] ?? formats['gif']) as Map<String, dynamic>?;
  final preview = (formats['tinygif'] ?? formats['gif']) as Map<String, dynamic>?;
  final fullUrl = full?['url'] as String?;
  final previewUrl = preview?['url'] as String?;
  if (fullUrl == null || previewUrl == null) return null;

  final dims = full?['dims'];
  final ratio =
      dims is List && dims.length >= 2
          ? _ratio(dims[0]?.toString(), dims[1]?.toString())
          : 1.0;

  return GifEntity(
    id: json['id'].toString(),
    url: fullUrl,
    previewUrl: previewUrl,
    provider: GifProvider.tenor,
    aspectRatio: ratio,
    description: json['content_description'] as String?,
  );
}

GifEntity? _fromGiphy(Map<String, dynamic> json) {
  final images = json['images'] as Map<String, dynamic>?;
  if (images == null) return null;

  // `downsized_medium` est la version plafonnée à 5 Mo du média d'origine :
  // même raison que `mediumgif` côté Tenor.
  final full =
      (images['downsized_medium'] ?? images['original'])
          as Map<String, dynamic>?;
  final original = images['original'] as Map<String, dynamic>?;
  final preview =
      (images['fixed_width_small'] ?? images['original'])
          as Map<String, dynamic>?;
  final fullUrl = full?['url'] as String?;
  final previewUrl = preview?['url'] as String?;
  if (fullUrl == null || previewUrl == null) return null;

  // Giphy renvoie les dimensions sous forme de chaînes.
  final dimensions = original ?? full;
  final ratio = _ratio(
    dimensions?['width']?.toString(),
    dimensions?['height']?.toString(),
  );

  return GifEntity(
    id: json['id'].toString(),
    url: fullUrl,
    previewUrl: previewUrl,
    provider: GifProvider.giphy,
    aspectRatio: ratio,
    description: json['title'] as String?,
  );
}

double _ratio(String? width, String? height) {
  final w = double.tryParse(width ?? '');
  final h = double.tryParse(height ?? '');
  if (w == null || h == null || h == 0) return 1.0;
  return w / h;
}
