import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Échec d'export porteur d'un message affichable à l'utilisateur.
class DataExportException implements Exception {
  const DataExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Export des données personnelles (RGPD art. 20 — droit à la portabilité).
///
/// Tout le travail de lecture est fait par l'Edge Function `export-my-data`,
/// qui seule détient la service_role key : le client se contente d'envoyer son
/// Firebase ID token, d'écrire le JSON reçu dans un fichier temporaire et de
/// le passer à la feuille de partage du système.
class DataExportService {
  DataExportService._();

  static final DataExportService instance = DataExportService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Demande l'export, écrit le JSON sur disque et ouvre le partage système.
  ///
  /// Renvoie le chemin du fichier généré. Lève [DataExportException] avec un
  /// message affichable si quoi que ce soit échoue.
  Future<String> exportAndShare() async {
    final json = await fetchExport();

    final pretty = const JsonEncoder.withIndent('  ').convert(json);
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/diaspo-niger-mes-donnees-$stamp.json');
    await file.writeAsString(pretty);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Export de mes données Diaspo Niger',
      ),
    );

    return file.path;
  }

  /// Récupère l'export brut, sans l'écrire ni le partager.
  Future<Map<String, dynamic>> fetchExport() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const DataExportException(
        'Vous devez être connecté pour exporter vos données.',
      );
    }

    String? idToken;
    try {
      // Force le rafraîchissement : un token expiré est rejeté par la fonction.
      idToken = await user.getIdToken(true);
    } catch (e) {
      debugPrint('DataExportService: getIdToken a échoué ($e)');
    }
    if (idToken == null || idToken.isEmpty) {
      throw const DataExportException(
        'Session expirée. Reconnectez-vous puis réessayez.',
      );
    }

    final FunctionResponse response;
    try {
      response = await _supabase.functions.invoke(
        'export-my-data',
        body: {'firebase_token': idToken},
      );
    } catch (e) {
      debugPrint('DataExportService: invoke a échoué ($e)');
      throw const DataExportException(
        'Export indisponible pour le moment. Réessayez plus tard.',
      );
    }

    if (response.status != 200) {
      debugPrint('DataExportService: statut ${response.status}');
      throw const DataExportException(
        "L'export a échoué. Réessayez plus tard.",
      );
    }

    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw const DataExportException("Réponse d'export illisible.");
  }
}
