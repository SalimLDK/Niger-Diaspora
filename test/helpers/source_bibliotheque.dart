import 'dart:io';

/// Source d'une bibliothèque Dart, telle que la lisent les tests de
/// structure : le fichier [chemin] suivi de ses fichiers `part`, dans l'ordre
/// de leurs directives. Pour un fichier sans `part`, c'est le fichier seul.
///
/// `message_supabase_datasource.dart` est découpé en parties ; les tests qui
/// cherchent une méthode dans « le fichier » la cherchent dans la
/// bibliothèque entière, où qu'elle ait été rangée.
String sourceBibliotheque(String chemin) {
  final fichier = File(chemin);
  final principal = fichier.readAsStringSync();
  final parties = RegExp(r"^part '([^']+)';", multiLine: true)
      .allMatches(principal)
      .map((m) => File('${fichier.parent.path}/${m[1]}').readAsStringSync());
  return [principal, ...parties].join('\n');
}
