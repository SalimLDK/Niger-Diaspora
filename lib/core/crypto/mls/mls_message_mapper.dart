import '../../../features/feed/domain/entities/post_entity.dart' show MentionedUser;
import '../../../features/messages/domain/entities/message_entity.dart';
import 'mls_conversation_service.dart';
import 'mls_delivery.dart';
import 'mls_payload_codec.dart';

/// Traduit un message MLS déchiffré en [MessageEntity], la forme que
/// l'interface sait déjà afficher.
///
/// Toute la difficulté de la coexistence tient ici : les deux sources n'ont
/// pas la même forme (le legacy met tout dans un JSONB `data`, MLS met le
/// contenu dans le payload chiffré et les métadonnées en colonnes), mais
/// l'écran, lui, ne doit voir qu'une seule liste.
class MlsMessageMapper {
  MlsMessageMapper._();

  /// Identifiant du séparateur « avant le chiffrement de bout en bout ».
  /// Réservé, jamais produit par un vrai message : les identifiants de
  /// messages sont des uuid ou des identifiants Firestore.
  static const idSeparateur = '__mls_separateur__';

  /// Le repère visuel entre l'historique lisible par le serveur et ce qui
  /// suit. Sans lui, la bascule serait invisible — et l'utilisateur croirait
  /// que tout son historique est chiffré.
  static MessageEntity separateur(DateTime quand) => MessageEntity(
        id: idSeparateur,
        senderId: 'system',
        senderName: '',
        content: 'Messages d\'avant le chiffrement de bout en bout',
        type: MessageType.system,
        status: MessageStatus.sent,
        createdAt: quand,
      );

  static bool estSeparateur(MessageEntity m) => m.id == idSeparateur;

  /// Un message reçu (déchiffré ou non) vers l'entité affichable.
  ///
  /// Un message illisible n'est pas jeté : il devient une bulle avec un
  /// placeholder. Le faire disparaître laisserait un trou dans le fil, et
  /// personne ne saurait qu'il manque quelque chose.
  static MessageEntity depuisEntrant(
    MlsIncoming entrant, {
    required String senderName,
    String? senderPhotoUrl,
    required String currentUserId,
  }) {
    final row = entrant.row;
    final payload = entrant.payload;
    if (payload == null) {
      return MessageEntity(
        id: row.id,
        senderId: row.senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: placeholderIllisible,
        type: MessageType.text,
        status: MessageStatus.sent,
        createdAt: row.createdAt.toLocal(),
        deletedForEveryone: row.isDeleted,
        encryptionLevel: MessageEncryptionLevel.e2ee,
      );
    }
    return depuisPayload(
      payload,
      row: row,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      currentUserId: currentUserId,
    );
  }

  /// Ce que l'écran affiche quand le déchiffrement n'a pas abouti — message
  /// d'un epoch pas encore traité, appareil ajouté après coup, réinstallation.
  static const placeholderIllisible = '🔐 Message chiffré';

  static MessageEntity depuisPayload(
    MlsPayload payload, {
    required MlsMessageRow row,
    required String senderName,
    String? senderPhotoUrl,
    required String currentUserId,
  }) {
    final body = payload.body;
    return MessageEntity(
      id: row.id,
      senderId: row.senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      content: body['content'] as String? ?? '',
      type: _type(payload.type),
      status: MessageStatus.sent,
      fileUrl: body['storagePath'] as String?,
      fileName: body['fileName'] as String?,
      fileSize: (body['fileSize'] as num?)?.toInt(),
      mimeType: body['mimeType'] as String?,
      audioDuration: (body['duration'] as num?)?.toInt(),
      blurhash: body['blurhash'] as String?,
      createdAt: row.createdAt.toLocal(),
      deletedForEveryone: row.isDeleted,
      replyToId: payload.replyTo?['id'] as String?,
      replyToMessageData: payload.replyTo,
      latitude: (body['latitude'] as num?)?.toDouble(),
      longitude: (body['longitude'] as num?)?.toDouble(),
      locationAddress: body['address'] as String?,
      pollId: body['pollId'] as String?,
      stickerPackId: body['stickerPackId'] as String?,
      stickerId: body['stickerId'] as String?,
      isForwarded: payload.forwarded,
      mentionedUsers: [
        for (final id in payload.mentions) MentionedUser(id: id, name: ''),
      ],
      // Les reçus ne viennent pas du payload : ils vivent dans
      // `mls_message_receipts`, et l'expéditeur a forcément lu le sien.
      readBy: row.senderId == currentUserId ? [currentUserId] : const [],
      // Le texte modifié voyage dans un contrôle, qui n'est délivré qu'une
      // fois ; la colonne, elle, est toujours là. Un appareil qui a manqué le
      // contrôle affiche donc « modifié » sous le texte d'origine — dégradé,
      // jamais mensonger.
      editedAt: row.editedAt?.toLocal(),
      encryptionLevel: MessageEncryptionLevel.e2ee,
    );
  }

  /// Le type du payload vers celui de l'interface. Un type inconnu — écrit
  /// par une version plus récente — devient du texte plutôt qu'une bulle
  /// vide : dégradé, jamais cassé.
  static MessageType _type(String type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'audio':
        return MessageType.audio;
      case 'voiceNote':
        return MessageType.voiceNote;
      case 'location':
        return MessageType.location;
      case 'poll':
        return MessageType.poll;
      case 'sticker':
        return MessageType.sticker;
      case 'call':
        return MessageType.call;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  /// Le `content_type` de la colonne, à partir du type de payload : c'est la
  /// seule chose que le serveur apprend du contenu, on la garde grossière.
  static String contentType(String typePayload) {
    switch (typePayload) {
      case 'image':
      case 'video':
      case 'file':
        return 'media';
      case 'audio':
      case 'voiceNote':
        return 'voice';
      case 'location':
        return 'location';
      case 'poll':
        return 'poll';
      case 'sticker':
        return 'sticker';
      case 'call':
      case 'system':
        return 'system';
      default:
        return 'text';
    }
  }
}
