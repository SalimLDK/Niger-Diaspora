import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/e2ee/models/e2ee_models.dart';

/// Niveau de chiffrement réellement en vigueur dans une discussion de groupe.
enum GroupEncryptionLevel {
  /// Pas encore mesuré (distribution en cours, ou jamais tentée).
  unknown,

  /// Sender Key distribuée à tous : les messages partent en chiffrement de
  /// groupe.
  senderKey,

  /// Au moins un membre n'a pas la clé : les messages partent avec la clé AES
  /// partagée, pour rester lisibles par tout le monde.
  aesFallback,
}

/// État de chiffrement d'un groupe, tel qu'il sera montré à l'utilisateur.
class GroupEncryptionStatus {
  final GroupEncryptionLevel level;

  /// Identifiants des membres qui n'ont pas reçu la Sender Key. Vide sauf en
  /// [GroupEncryptionLevel.aesFallback] — et même là, vide si la cause n'est
  /// pas imputable à des membres précis (voir [localKeysUnavailable]).
  final List<String> membersWithoutKey;

  /// Le chiffrement E2EE n'est pas prêt sur CET appareil : rien n'a même pu
  /// être tenté. Le groupe tourne quand même en AES, et ça se dit autrement à
  /// l'utilisateur que « untel n'a pas de clé ».
  final bool localKeysUnavailable;

  const GroupEncryptionStatus({
    this.level = GroupEncryptionLevel.unknown,
    this.membersWithoutKey = const [],
    this.localKeysUnavailable = false,
  });

  factory GroupEncryptionStatus.fromDistribution(SenderKeyDistribution d) =>
      d.isComplete
          ? const GroupEncryptionStatus(level: GroupEncryptionLevel.senderKey)
          : GroupEncryptionStatus(
            level: GroupEncryptionLevel.aesFallback,
            membersWithoutKey: d.missingMemberIds,
          );

  /// Aucune tentative n'a été possible — clés locales absentes.
  const GroupEncryptionStatus.keysUnavailable()
    : level = GroupEncryptionLevel.aesFallback,
      membersWithoutKey = const [],
      localKeysUnavailable = true;
}

/// État de chiffrement par groupe, alimenté au chargement de la conversation.
///
/// **Pourquoi ça existe.** La distribution d'une Sender Key échoue en silence
/// pour un membre avec qui aucune session Signal n'a pu s'établir — il n'a
/// jamais publié ses clés, ou jamais rouvert l'application. Le groupe restait
/// alors en repli AES **indéfiniment, sans que rien ne le signale** : ni dans
/// l'app, ni dans un compteur. On ne pouvait le découvrir qu'en lisant
/// `encryptionLevel` en base, message par message.
///
/// ⚠️ Volontairement **pas** `autoDispose` : l'état doit survivre à la
/// reconstruction de l'écran de conversation, sinon le cadenas repasserait à
/// « inconnu » à chaque rebuild et le signalement clignoterait.
final groupEncryptionStatusProvider =
    StateProvider.family<GroupEncryptionStatus, String>(
      (ref, groupId) => const GroupEncryptionStatus(),
    );
