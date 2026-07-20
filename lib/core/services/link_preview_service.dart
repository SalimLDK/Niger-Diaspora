import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  Map<String, dynamic> toMap() => {
    'url': url,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (siteName != null) 'siteName': siteName,
  };

  factory LinkPreviewData.fromMap(Map<String, dynamic> map) => LinkPreviewData(
    url: map['url'] as String,
    title: map['title'] as String?,
    description: map['description'] as String?,
    imageUrl: map['imageUrl'] as String?,
    siteName: map['siteName'] as String?,
  );

  bool get hasContent =>
      title != null || description != null || imageUrl != null;
}

class LinkPreviewService {
  final Map<String, LinkPreviewData?> _cache = {};

  static final _urlRegex = RegExp(
    r'(?:https?://|www\.)[^\s<>\]\)]+|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+(?:com|fr|org|net|io|co|app|dev|info|biz|edu|gov|me|tv|uk|de|nl|be|ch|ca|au|nz|ng|sn|ml|bf|ci|tg|bj|ne|gn|cm|cd|cg|ga|td|cf|rw|bi|ug|ke|tz|et|gh|za|ma|dz|tn|eg|ly|sd|mu|mg|mw|zm|zw|mz|ao|na|bw|sz|ls|so|dj|er|ss)(?:/[^\s<>\]\)]*)?',
    caseSensitive: false,
  );

  /// Extracts the first URL found in a text string
  static String? extractFirstUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  /// Extracts all URLs found in a text string
  static List<String> extractAllUrls(String text) {
    return _urlRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Fetches Open Graph metadata for a given URL
  /// Returns null if the URL is invalid, unreachable, or has no OG metadata
  Future<LinkPreviewData?> fetchLinkPreview(String url) async {
    // Normalize URL by adding https:// if no protocol
    String normalizedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      normalizedUrl = 'https://$url';
    }

    // Check cache first
    if (_cache.containsKey(normalizedUrl)) {
      return _cache[normalizedUrl];
    }

    try {
      final uri = Uri.parse(normalizedUrl);
      if (!uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return null;
      }

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; DiaspoNiger/1.0)',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        _cache[url] = null;
        return null;
      }

      final document = html_parser.parse(response.body);
      final metaTags = document.getElementsByTagName('meta');

      String? title;
      String? description;
      String? imageUrl;
      String? siteName;

      for (final meta in metaTags) {
        final property = meta.attributes['property'] ?? meta.attributes['name'];
        final content = meta.attributes['content'];

        if (property == null || content == null || content.isEmpty) continue;

        switch (property) {
          case 'og:title':
            title = content;
            break;
          case 'og:description':
            description = content;
            break;
          case 'og:image':
            imageUrl = content;
            break;
          case 'og:site_name':
            siteName = content;
            break;
          case 'twitter:title':
            title ??= content;
            break;
          case 'twitter:description':
            description ??= content;
            break;
          case 'twitter:image':
            imageUrl ??= content;
            break;
          case 'description':
            description ??= content;
            break;
        }
      }

      // Fallback: use <title> tag if no og:title
      if (title == null) {
        final titleElement = document.getElementsByTagName('title');
        if (titleElement.isNotEmpty) {
          title = titleElement.first.text.trim();
        }
      }

      // Fallback: extract site name from hostname
      siteName ??= uri.host.replaceFirst('www.', '');

      // Resolve relative image URLs
      if (imageUrl != null && !imageUrl.startsWith('http')) {
        imageUrl = '${uri.scheme}://${uri.host}$imageUrl';
      }

      final data = LinkPreviewData(
        url: normalizedUrl,
        title: title,
        description: description,
        imageUrl: imageUrl,
        siteName: siteName,
      );

      _cache[normalizedUrl] = data.hasContent ? data : null;
      return _cache[normalizedUrl];
    } catch (_) {
      _cache[normalizedUrl] = null;
      return null;
    }
  }
}

/// Provider pour le service de preview de liens (keepAlive)
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService();
});
