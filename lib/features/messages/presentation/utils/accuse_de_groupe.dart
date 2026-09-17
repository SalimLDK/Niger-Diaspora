import '../../domain/entities/message_entity.dart';

/// Les membres dont la lecture compte pour que [message] soit « Lu » en
/// groupe (étape C du plan).
///
/// - **présents aujourd'hui** ([membres]) : un membre parti ne bloque pas
///   « Lu » pour toujours ;
/// - **arrivés avant le message** ([arrivees]) : quelqu'un qui n'était pas là
///   n'en était pas destinataire — dans un groupe privé, il ne le voit même
///   pas. Une arrivée inconnue compte comme ancienne ;
/// - jamais l'expéditeur lui-même.
///
/// La borne est stricte, comme le filtre des groupes privés
/// (`sansMessagesAvantArrivee`) : arrivé à l'instant pile du message, on ne le
/// voit pas, on ne l'attend pas.
Set<String> lecteursAttendus(
  MessageEntity message, {
  required Iterable<String> membres,
  Map<String, DateTime> arrivees = const {},
}) {
  return {
    for (final membre in membres)
      if (membre != message.senderId &&
          (arrivees[membre]?.isBefore(message.createdAt) ?? true))
        membre,
  };
}

/// Tous les [attendus] figurent-ils parmi les [lecteurs] ?
///
/// `false` quand personne n'est attendu : un groupe où il ne reste que
/// l'expéditeur n'a pas « lu » son message. Des lecteurs en plus — un membre
/// parti depuis — ne changent rien.
bool tousOntLu(Iterable<String> lecteurs, Set<String>? attendus) {
  if (attendus == null || attendus.isEmpty) return false;
  final lus = lecteurs.toSet();
  return attendus.every(lus.contains);
}
