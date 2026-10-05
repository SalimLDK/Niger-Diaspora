import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chaque après-envoi nomme le message qu'il annonce.
///
/// « Supprimer pour tout le monde » et la purge des éphémères reconnaissent le
/// dernier message à l'égalité `last_message_at = created_at`. Depuis que les
/// deux dates sont posées par le serveur dans deux requêtes distinctes, elles
/// ne sont plus jamais égales — sauf si `apres_envoi_message` recopie la date
/// du message lui-même (20261005090000). Sans `p_message_id`, l'appel échoue
/// (la fonction à deux arguments n'existe plus), et l'aperçu en clair d'un
/// message supprimé restait lisible dans la liste des discussions.
///
/// Le sens côté serveur est tenu par tools/rls_tests/apercu_date_du_message.sql.
/// Ici : qu'aucun des trois chemins d'envoi n'oublie l'identifiant.
void main() {
  const chemins = [
    'lib/features/messages/data/datasources/message_supabase_datasource.dart',
    'lib/core/services/background_reply_service.dart',
    'lib/core/services/call_message_service.dart',
  ];

  test('les trois chemins d\'envoi appellent apres_envoi_message', () {
    final appelants = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) =>
            f.readAsStringSync().contains("rpc('apres_envoi_message'"))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(appelants, chemins.toSet(),
        reason: 'un nouvel appelant doit être ajouté à ce banc');
  });

  for (final chemin in chemins) {
    test('$chemin : l\'appel porte p_message_id', () {
      final source = File(chemin).readAsStringSync();
      final debut = source.indexOf("rpc('apres_envoi_message'");
      expect(debut, isNot(-1));
      // Les paramètres de l'appel, jusqu'à la fermeture de la map.
      final fin = source.indexOf('});', debut);
      final params = source.substring(debut, fin);
      expect(params, contains("'p_message_id': messageId"));
    });
  }
}
