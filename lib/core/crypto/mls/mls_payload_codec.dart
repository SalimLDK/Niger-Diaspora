import 'dart:convert';
import 'dart:typed_data';

/// Données authentifiées associées (AAD), plan MLS § 6.1.
///
/// Recomposées par le récepteur depuis les **colonnes** de la ligne, jamais
/// depuis le payload : un ciphertext déplacé vers une autre conversation, un
/// autre id ou un autre expéditeur échoue à l'authentification.
///
/// Les commits ont le leur : OpenMLS remet l'AAD à vide après chaque message
/// sortant (piège relevé au spike), donc le moteur le pose explicitement à
/// chaque commit, et le récepteur le recompose depuis `mls_commits`.
class MlsAad {
  MlsAad._();

  static const version = 'dn-mls/1';

  static Uint8List message({
    required String conversationId,
    required String messageId,
    required String senderDeviceId,
    required String kind,
  }) =>
      Uint8List.fromList(
        utf8.encode('$version|$conversationId|$messageId|$senderDeviceId|$kind'),
      );

  static Uint8List commit({required String conversationId, required int epoch}) =>
      Uint8List.fromList(utf8.encode('$version|$conversationId|commit|$epoch'));
}

/// Le contenu d'un message, avant chiffrement (plan MLS § 6.2).
///
/// Tout ce qui fuyait à côté d'un `content` chiffré dans le legacy —
/// légende, nom de fichier, position, citation — vit ici, dans le clair que
/// seul le groupe lit. Le serveur ne voit que `kind` et `content_type`.
class MlsPayload {
  static const versionCourante = 1;

  final int v;

  /// Égal à `mls_messages.id` : recopié dans le payload pour qu'un
  /// ciphertext ne puisse pas être présenté sous un autre identifiant même
  /// si l'AAD venait à être contourné.
  final String id;

  /// `text | image | video | file | voiceNote | location | poll | sticker |
  /// call | system` — ou, pour un message de contrôle, `reaction | edit |
  /// delete`.
  final String type;

  /// Horodatage client (ms depuis l'epoch Unix), informatif : l'ordre qui
  /// fait foi est `created_at` du serveur.
  final int sentAt;
  final Map<String, dynamic> body;
  final Map<String, dynamic>? replyTo;
  final List<String> mentions;
  final bool forwarded;

  /// Durée de vie en secondes, quand la conversation a un minuteur.
  ///
  /// **Elle voyage ici, dans le clair que seul le groupe lit, et pas
  /// seulement dans la colonne `mls_messages.expires_at`.** Le service de
  /// livraison est considéré comme hostile (§ « ce que le serveur est ») :
  /// il peut repousser l'échéance de la colonne, ou l'effacer. Le récepteur
  /// recalcule donc la sienne depuis cette valeur-ci, que le serveur ne peut
  /// ni lire ni réécrire — la colonne ne lui sert qu'à balayer.
  ///
  /// `null` = pas de minuteur. L'échéance se compte depuis le `created_at`
  /// de la ligne et non depuis [sentAt] : l'horloge de l'expéditeur n'est
  /// pas une autorité, un `sentAt` antidaté ferait expirer le message à
  /// l'arrivée.
  final int? ttl;

  const MlsPayload({
    this.v = versionCourante,
    required this.id,
    required this.type,
    required this.sentAt,
    required this.body,
    this.replyTo,
    this.mentions = const [],
    this.forwarded = false,
    this.ttl,
  });

  factory MlsPayload.texte(String id, String texte, {DateTime? quand}) => MlsPayload(
        id: id,
        type: 'text',
        sentAt: (quand ?? DateTime.now()).millisecondsSinceEpoch,
        body: {'content': texte},
      );

  String get texte => body['content'] as String? ?? '';

  /// L'échéance du message, à partir de l'horodatage **serveur** de sa ligne.
  /// `null` quand le message n'a pas de minuteur.
  DateTime? echeance(DateTime createdAt) =>
      ttl == null || ttl! <= 0 ? null : createdAt.add(Duration(seconds: ttl!));

  Map<String, dynamic> toJson() => {
        'v': v,
        'id': id,
        'type': type,
        'sentAt': sentAt,
        'body': body,
        if (replyTo != null) 'replyTo': replyTo,
        if (mentions.isNotEmpty) 'mentions': mentions,
        if (forwarded) 'forwarded': true,
        if (ttl != null) 'ttl': ttl,
      };

  factory MlsPayload.fromJson(Map<String, dynamic> json) => MlsPayload(
        v: (json['v'] as num?)?.toInt() ?? 1,
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'text',
        sentAt: (json['sentAt'] as num?)?.toInt() ?? 0,
        body: Map<String, dynamic>.from(json['body'] as Map? ?? const {}),
        replyTo: json['replyTo'] is Map
            ? Map<String, dynamic>.from(json['replyTo'] as Map)
            : null,
        mentions: (json['mentions'] as List?)?.cast<String>() ?? const [],
        forwarded: json['forwarded'] == true,
        ttl: (json['ttl'] as num?)?.toInt(),
      );

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  static MlsPayload decode(Uint8List clair) {
    final decode = jsonDecode(utf8.decode(clair));
    if (decode is! Map) throw const FormatException('payload MLS : pas un objet');
    return MlsPayload.fromJson(Map<String, dynamic>.from(decode));
  }
}
