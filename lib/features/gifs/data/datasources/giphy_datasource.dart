import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/gif_entity.dart';
import 'gif_remote_datasource.dart';

/// Fournisseur Giphy — API v1. Utilisé en repli de [TenorDataSource].
///
/// L'appel passe par l'Edge Function `gif-proxy`, seule détentrice de la clé.
/// Elle vivait auparavant dans le `.env` embarqué comme asset dans l'APK, donc
/// extractible par quiconque décompresse l'application — quota et facturation
/// compris.
///
/// Docs : https://developers.giphy.com/docs/api/endpoint
class GiphyDataSource implements GifRemoteDataSource {
  static const String _functionName = 'gif-proxy';

  final SupabaseClient _supabase;

  GiphyDataSource({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  GifProvider get provider => GifProvider.giphy;

  /// La clé vit côté serveur : le client ne peut plus savoir si elle est
  /// renseignée. `gif-proxy` répond 503 quand elle manque, ce qui fait basculer
  /// [GifRepository] sur le fournisseur suivant — même comportement qu'avant,
  /// décidé au bon endroit.
  @override
  bool get isConfigured => true;

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
    try {
      final response = await _supabase.functions.invoke(
        _functionName,
        body: {
          'provider': 'giphy',
          'endpoint': endpoint,
          'type': type == GifContentType.sticker ? 'sticker' : 'gif',
          'limit': limit,
          if (query != null) 'q': query,
        },
      );

      if (response.status != 200) {
        throw ServerException('Giphy indisponible : HTTP ${response.status}');
      }

      // `gif-proxy` relaie la charge utile Giphy verbatim : la forme `data[]`
      // est celle de l'API, le parsing ci-dessous est inchangé.
      final payload = response.data as Map<String, dynamic>?;
      final results = payload?['data'] as List? ?? const [];
      return results
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .whereType<GifEntity>()
          .toList();
    } on FunctionException catch (e) {
      throw ServerException('Giphy indisponible : ${e.reasonPhrase ?? e.status}');
    }
  }

  GifEntity? _fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    if (images == null) return null;

    final full = images['original'] as Map<String, dynamic>?;
    final preview =
        (images['fixed_width_small'] ?? images['original']) as Map<String, dynamic>?;
    final fullUrl = full?['url'] as String?;
    final previewUrl = preview?['url'] as String?;
    if (fullUrl == null || previewUrl == null) return null;

    // Giphy renvoie les dimensions sous forme de chaînes.
    final width = double.tryParse(full?['width']?.toString() ?? '');
    final height = double.tryParse(full?['height']?.toString() ?? '');
    final aspectRatio =
        (width != null && height != null && height != 0) ? width / height : 1.0;

    return GifEntity(
      id: json['id'].toString(),
      url: fullUrl,
      previewUrl: previewUrl,
      provider: GifProvider.giphy,
      aspectRatio: aspectRatio,
      description: json['title'] as String?,
    );
  }
}
