import 'package:dio/dio.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/gif_entity.dart';
import 'gif_remote_datasource.dart';

/// Fournisseur Giphy ÔÇö API v1. Utilis├® en repli de [TenorDataSource].
///
/// Docs : https://developers.giphy.com/docs/api/endpoint
class GiphyDataSource implements GifRemoteDataSource {
  static const String _baseUrl = 'https://api.giphy.com/v1';

  /// Classification Giphy : `g` = tout public.
  static const String _rating = 'g';

  final Dio _dio;

  GiphyDataSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  @override
  GifProvider get provider => GifProvider.giphy;

  @override
  bool get isConfigured => AppConfig.isGiphyConfigured;

  @override
  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    return _fetch('${_segment(type)}/trending', limit: limit);
  }

  @override
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    return _fetch(
      '${_segment(type)}/search',
      limit: limit,
      extraQuery: {'q': query},
    );
  }

  /// Giphy expose les stickers sur un chemin distinct de celui des GIFs.
  String _segment(GifContentType type) =>
      type == GifContentType.sticker ? '$_baseUrl/stickers' : '$_baseUrl/gifs';

  Future<List<GifEntity>> _fetch(
    String url, {
    required int limit,
    Map<String, dynamic> extraQuery = const {},
  }) async {
    if (!isConfigured) {
      throw ServerException('Cl├® API Giphy absente (GIPHY_API_KEY)');
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {
          'api_key': AppConfig.giphyApiKey,
          'limit': limit,
          'rating': _rating,
          ...extraQuery,
        },
      );

      final results = response.data?['data'] as List? ?? const [];
      return results
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .whereType<GifEntity>()
          .toList();
    } on DioException catch (e) {
      throw ServerException('Giphy indisponible : ${e.message}');
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

    // Giphy renvoie les dimensions sous forme de cha├«nes.
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
