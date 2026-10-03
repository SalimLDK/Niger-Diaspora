/// Noms de fichier venus d'ailleurs — d'un message, donc de son expéditeur.
///
/// `message.fileName` est écrit par l'expéditeur, et
/// `FileDownloadService.downloadToAppDirectory` le collait tel quel derrière
/// le répertoire documents : `'${documents.path}/$fileName'`. Le
/// téléchargement automatique (`AutoDownloadService`) l'appelle dès
/// l'affichage de la bulle, sans geste de l'utilisateur. D'où deux portes :
///
///  * `../../…` sortait du répertoire : écriture où l'app a le droit d'écrire ;
///  * sans même un `/`, un nom comme celui d'une boîte Hive écrasait le
///    fichier du même nom — `Hive.initFlutter()` range ses boîtes dans ce
///    même répertoire documents.
///
/// [nomDeFichierSur] ferme la première ; le sous-dossier par message de
/// `FileDownloadService` ferme la seconde.
library;

/// Longueur maximale gardée, extension comprise. Bien sous la limite de 255
/// octets des systèmes de fichiers, même en UTF-8 multi-octets.
const int longueurMaxNomDeFichier = 120;

final RegExp _separateurs = RegExp(r'[/\\]');
final RegExp _interdits = RegExp(r'[\x00-\x1F\x7F:*?"<>|]');

/// Réduit [brut] à un nom de fichier simple, sans aucun composant de chemin.
///
/// Garde le dernier segment après `/` ou `\`, retire les caractères de
/// contrôle et ceux que les systèmes de fichiers refusent, et les points de
/// tête (ni `..`, ni fichier caché). Tronque à [longueurMaxNomDeFichier] en
/// préservant l'extension. Rend [repli] si rien d'utilisable ne reste —
/// [repli] est lui-même nettoyé, et `fichier` le remplace s'il est vide.
String nomDeFichierSur(String? brut, {String repli = 'fichier'}) {
  final nom = _nettoyer(brut);
  if (nom.isNotEmpty) return nom;
  final secours = _nettoyer(repli);
  return secours.isNotEmpty ? secours : 'fichier';
}

String _nettoyer(String? brut) {
  if (brut == null) return '';
  final segments = brut.split(_separateurs);
  var nom = segments.isEmpty ? '' : segments.last;
  nom = nom.replaceAll(_interdits, '').trim();
  nom = nom.replaceFirst(RegExp(r'^\.+'), '').trim();
  // Par points de code, pas par unités UTF-16 : une coupe au milieu d'une
  // paire de substitution laisserait un nom invalide.
  final runes = nom.runes.toList();
  if (runes.length > longueurMaxNomDeFichier) {
    final point = nom.lastIndexOf('.');
    final ext = point > 0 && nom.length - point <= 16 ? nom.substring(point) : '';
    final garde = longueurMaxNomDeFichier - ext.runes.length;
    nom = String.fromCharCodes(runes.take(garde)) + ext;
  }
  return nom;
}
