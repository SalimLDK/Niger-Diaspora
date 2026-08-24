import '../../domain/entities/message_entity.dart';
import '../widgets/message_bubble.dart' show MessageGroupPosition;

/// Écart au-delà duquel deux messages du même expéditeur ne forment plus une
/// seule rafale.
///
/// Sans ce seuil, une rafale se définissait par « même expéditeur, même jour » :
/// deux messages envoyés à 09:00 et à 18:00 n'en faisaient qu'une, et comme
/// seul le dernier message d'une rafale porte son heure
/// (`_isLastInGroup` dans [MessageBubble]), celle de 09:00 disparaissait de la
/// discussion. La coupure rend son heure au message du matin, et casse aussi
/// le regroupement visuel (queue de bulle, nom de l'expéditeur en groupe) —
/// c'est voulu : deux moments distincts se lisent comme deux blocs distincts.
const Duration kDureeRafale = Duration(minutes: 15);

/// Deux messages appartiennent à la même rafale : même expéditeur **et** moins
/// de [kDureeRafale] d'écart.
bool memeRafale(MessageEntity a, MessageEntity b) {
  if (a.senderId != b.senderId) return false;
  return a.createdAt.difference(b.createdAt).abs() <= kDureeRafale;
}

/// Position d'un message dans sa rafale, pour une liste **inversée**
/// (index 0 = message le plus récent), telle que la construit l'écran de
/// discussion.
///
/// [hasDateBreak] : un séparateur de date s'affiche au-dessus de ce message.
/// [hasNextDateBreak] : un séparateur s'affiche au-dessus du message plus
/// récent (index - 1).
MessageGroupPosition positionDansRafale(
  List<MessageEntity> messages,
  int index, {
  required bool hasDateBreak,
  required bool hasNextDateBreak,
}) {
  final message = messages[index];

  // In reversed list: lower index = newer, higher index = older
  // "Previous" visually (below) = index - 1 (newer)
  // "Next" visually (above) = index + 1 (older)
  final hasNewerSameSender =
      index > 0 && memeRafale(messages[index - 1], message);
  final hasOlderSameSender =
      index < messages.length - 1 && memeRafale(messages[index + 1], message);

  if (hasDateBreak) {
    // After date separator (visually), treat as first message of group
    if (hasNewerSameSender && !hasNextDateBreak) {
      return MessageGroupPosition.first;
    }
    return MessageGroupPosition.single;
  }

  // hasNewerSameSender/hasOlderSameSender sont exprimés en index de la
  // liste inversée (index 0 = message le plus récent). "first"/"last"
  // doivent rester alignés sur l'ordre chronologique réel — c'est la
  // convention qu'utilisent déjà _getBorderRadius() (queue de bulle sur
  // "last") et showSenderInfo (nom affiché sur "first") : sans quoi le
  // message le plus ANCIEN du groupe hérite de "last", donc de l'heure et de
  // l'accusé « Envoyé » portés par _isLastInGroup, à la place du plus récent.
  if (!hasNewerSameSender && !hasOlderSameSender) {
    return MessageGroupPosition.single;
  } else if (!hasNewerSameSender && hasOlderSameSender) {
    return MessageGroupPosition.last;
  } else if (hasNewerSameSender && hasOlderSameSender) {
    return MessageGroupPosition.middle;
  } else {
    return MessageGroupPosition.first;
  }
}
