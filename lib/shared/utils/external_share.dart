import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lanceurs de partage vers les réseaux sociaux (WhatsApp, Facebook, X)
/// et la feuille de partage système.
///
/// Chaque lanceur retourne `true` si l'application cible a bien été ouverte —
/// c'est le signal utilisé pour le tracking des partages.
class ExternalShare {
  ExternalShare._();

  /// Ouvre WhatsApp avec le message pré-rempli.
  static Future<bool> whatsApp(String message) {
    return _launch(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
    );
  }

  /// Ouvre le partage Facebook. Facebook n'accepte qu'une URL (le texte
  /// libre est ignoré par le sharer).
  static Future<bool> facebook(String url) {
    return _launch(
      Uri.parse(
        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}',
      ),
    );
  }

  /// Ouvre X (Twitter) avec le message pré-rempli.
  static Future<bool> x(String message) {
    return _launch(
      Uri.parse('https://x.com/intent/post?text=${Uri.encodeComponent(message)}'),
    );
  }

  /// Feuille de partage système. Retourne `true` si l'utilisateur a partagé
  /// (`unavailable` compte comme succès : certaines plateformes ne remontent
  /// pas le résultat).
  static Future<bool> system({
    required String text,
    String? subject,
    List<XFile>? files,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, files: files),
    );
    return result.status == ShareResultStatus.success ||
        result.status == ShareResultStatus.unavailable;
  }

  static Future<bool> _launch(Uri url) async {
    if (await canLaunchUrl(url)) {
      return launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
