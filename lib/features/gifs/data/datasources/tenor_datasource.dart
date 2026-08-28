import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/gif_entity.dart';
import 'gif_remote_datasource.dart';

/// Fournisseur Tenor (Google) — API v2.
///
/// L'appel passe par l'Edge Function `gif-proxy`, seule détentrice de la clé.
/// Elle vivait auparavant dans le `.env` embarqué comme asset dans l'APK, donc
/// extractible par quiconque décompresse l'application — quota et facturation
/// compris.
///
/// Docs : https://developers.google.com/tenor/guides/endpoints
class TenorDataSource implements GifRemoteDataSource {
  static const String _functionName = 'gif-proxy';

  final SupabaseClient _supabase;

  TenorDataSource({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  GifProvider get provider => GifProvider.tenor;

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
          'provider': 'tenor',
          'endpoint': endpoint,
          'type': type == GifContentType.sticker ? 'sticker' : 'gif',
          'limit': limit,
          if (query != null) 'q': query,
        },
      );

      if (response.status != 200) {
        throw ServerException('Tenor indisponible : HTTP ${response.status}');
      }

      // `gif-proxy` relaie la charge utile Tenor verbatim : la forme
      // `results[]` est celle de l'API, le parsing ci-dessous est inchangé.
      final payload = response.data as Map<String, dynamic>?;
      final results = payload?['results'] as List? ?? const [];
      return results
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .whereType<GifEntity>()
          .toList();
    } on FunctionException catch (e) {
      throw ServerException('Tenor indisponible : ${e.reasonPhrase ?? e.status}');
    }
  }

  GifEntity? _fromJson(Map<String, dynamic> json) {
    final formats = json['media_formats'] as Map<String, dynamic>?;
    if (formats == null) return null;

    final full = formats['gif'] as Map<String, dynamic>?;
    final preview = (formats['tinygif'] ?? formats['gif']) as Map<String, dynamic>?;
    final fullUrl = full?['url'] as String?;
    final previewUrl = preview?['url'] as String?;
    if (fullUrl == null || previewUrl == null) return null;

    // dims = [largeur, hauteur]
    final dims = (full?['dims'] as List?)?.cast<num>();
    final aspectRatio = (dims != null && dims.length == 2 && dims[1] != 0)
        ? dims[0] / dims[1]
        : 1.0;

    return GifEntity(
      id: json['id'].toString(),
      url: fullUrl,
      previewUrl: previewUrl,
      provider: GifProvider.tenor,
      aspectRatio: aspectRatio,
      description: json['content_description'] as String?,
    );
  }
}
