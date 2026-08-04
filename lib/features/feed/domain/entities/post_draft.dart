import 'package:flutter/foundation.dart';

/// Brouillon de publication conservé **localement** (SharedPreferences) :
/// aucun modèle serveur n'existe pour les brouillons de post, et un stockage
/// mono-appareil suffit à l'usage visé (carte « Brouillons » de Mon espace
/// §5a, cartes brouillon de Mes publications §5b).
@immutable
class PostDraft {
  const PostDraft({
    required this.id,
    required this.text,
    required this.updatedAt,
  });

  final String id;
  final String text;
  final DateTime updatedAt;

  /// Première ligne utile, pour l'aperçu des cartes.
  String preview({int maxChars = 80}) {
    final flat = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (flat.length <= maxChars) return flat;
    return '${flat.substring(0, maxChars)}…';
  }

  static PostDraft? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final text = json['text'] as String?;
    if (id == null || id.isEmpty || text == null || text.trim().isEmpty) {
      return null;
    }
    final millis = json['updatedAt'];
    return PostDraft(
      id: id,
      text: text,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        millis is int ? millis : 0,
      ),
    );
  }
}
