import 'package:equatable/equatable.dart';

/// Ce qu'il faut pour relire un média chiffré : où est le blob, et la clé.
///
/// Voyage **uniquement** sous forme chiffrée dans `messages.data.encMedia`
/// (clé dérivée de la conversation, même mécanisme que `encAnnexes`), et
/// n'apparaît en clair que dans le modèle local une fois déchiffré. Le
/// serveur voit un blob `application/octet-stream` et un `fileUrl` qui ne
/// sert à rien sans cette clé.
///
/// `fileName` vit ici et non à côté : le nom d'origine d'une pièce jointe est
/// une donnée utilisateur au même titre que sa légende.
class MediaChiffre extends Equatable {
  /// Version du format, pour pouvoir changer d'algorithme sans casser les
  /// messages déjà envoyés.
  final int version;

  /// Chemin dans Firebase Storage (`encrypted_media/<conv>/<sender>/…`).
  final String storagePath;

  /// URL de téléchargement du blob chiffré — utile pour la progression, mais
  /// inutile sans [fileKeyBase64].
  final String encryptedUrl;

  /// Clé AES-256 propre à ce fichier.
  final String fileKeyBase64;

  /// IV/nonce GCM (96 bits).
  final String ivBase64;

  /// Nom d'origine, type MIME et taille **en clair** du fichier.
  final String fileName;
  final String mimeType;
  final int size;

  const MediaChiffre({
    this.version = 1,
    required this.storagePath,
    required this.encryptedUrl,
    required this.fileKeyBase64,
    required this.ivBase64,
    required this.fileName,
    required this.mimeType,
    required this.size,
  });

  factory MediaChiffre.fromJson(Map<String, dynamic> json) => MediaChiffre(
    version: (json['v'] as num?)?.toInt() ?? 1,
    storagePath: json['storagePath'] as String? ?? '',
    encryptedUrl: json['encryptedUrl'] as String? ?? '',
    fileKeyBase64: json['fileKey'] as String? ?? '',
    ivBase64: json['iv'] as String? ?? '',
    fileName: json['fileName'] as String? ?? '',
    mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    size: (json['size'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'v': version,
    'storagePath': storagePath,
    'encryptedUrl': encryptedUrl,
    'fileKey': fileKeyBase64,
    'iv': ivBase64,
    'fileName': fileName,
    'mimeType': mimeType,
    'size': size,
  };

  /// Vrai quand il manque de quoi déchiffrer : on affiche alors un état
  /// d'erreur, jamais le blob brut.
  bool get estComplet =>
      storagePath.isNotEmpty && fileKeyBase64.isNotEmpty && ivBase64.isNotEmpty;

  @override
  List<Object?> get props => [
    version,
    storagePath,
    encryptedUrl,
    fileKeyBase64,
    ivBase64,
    fileName,
    mimeType,
    size,
  ];
}
