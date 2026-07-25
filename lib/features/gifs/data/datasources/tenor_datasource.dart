import 'package:dio/dio.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/gif_entity.dart';
import 'gif_remote_datasource.dart';

/// Fournisseur Tenor (Google) ÔÇö API v2.
///
/// Docs : https://developers.google.com/tenor/guides/endpoints
class TenorDataSource implements GifRemoteDataSource {
  static const String _baseUrl = 'https://tenor.googleapis.com/v2';

  /// Filtre de contenu Tenor : `high` = le plus strict.
  static const String _contentFilter = 'high';

  final Dio _dio;

  TenorDataSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  @override
  GifProvider get provider => GifProvider.tenor;

  @override
  bool get isConfigured => AppConfig.isTenorConfigured;

  @override
  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    return _fetch('$_baseUrl/featured', type: type, limit: limit);
  }

  @override
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    return _fetch(
      '$_baseUrl/search',
      type: type,
      limit: limit,
      extraQuery: {'q': query},
    );
  }

  Future<List<GifEntity>> _fetch(
    String url, {
    required GifContentType type,
    required int limit,
    Map<String, dynamic> extraQuery = const {},
  }) async {
    if (!isConfigured) {
      throw ServerException('Cl├® API Tenor absente (TENOR_API_KEY)');
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {
          'key': AppConfig.tenorApiKey,
          'limit': limit,
          'contentfilter': _contentFilter,
          'media_filter': 'gif,tinygif',
          if (type == GifContentType.sticker) 'searchfilter': 'sticker',
          ...extraQuery,
        },
      );

      final results = response.data?['results'] as List? ?? const [];
      return results
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .whereType<GifEntity>()
          .toList();
    } on DioException catch (e) {
      throw ServerException('Tenor indisponible : ${e.message}');
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
