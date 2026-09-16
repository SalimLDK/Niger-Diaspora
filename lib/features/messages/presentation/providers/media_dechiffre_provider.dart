import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/uid_firebase_provider.dart';
import '../../../../core/services/e2ee/media_dechiffre_cache.dart';
import '../../../admin/presentation/providers/app_settings_provider.dart';
import '../../domain/entities/media_chiffre.dart';

/// Interrupteur serveur du chiffrement des pièces jointes (C4, tranche 1).
///
/// Lu depuis les réglages administrateur (`featureFlags.mediasChiffres`),
/// comme les autres drapeaux — pas de codegen, pas de redéploiement d'Edge
/// Function. Fermé par défaut : tant que la mise à jour minimale (décision B
/// du plan MLS) n'est pas imposée, un média chiffré casse l'affichage des
/// anciens builds.
///
/// Ne gouverne que l'**envoi**. La lecture d'un média chiffré marche toujours,
/// drapeau ouvert ou fermé : refermer le drapeau ne doit pas rendre illisible
/// ce qui a déjà été envoyé.
final mediasChiffresActifsProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagsProvider).mediasChiffres;
});

/// Interrupteur serveur de la messagerie MLS (plan MLS, phase 5).
///
/// Fermé par défaut, et pour longtemps : l'ouvrir fait **basculer** une
/// conversation sans retour — `conversations.mls_since` ne se remet jamais à
/// NULL, et le legacy refuse ensuite d'y écrire.
///
/// **Deux interrupteurs, pas un.** `mlsMessages` vaut pour tout le monde ;
/// `mlsMessagesComptes` ne vaut que pour les uid qu'il nomme. Le second
/// existe parce que le premier rendait toute vérification impossible : essayer
/// MLS sur un seul téléphone demandait de basculer la production entière, sans
/// retour. Vérifier ne doit pas être un point de non-retour.
///
/// La lecture d'une conversation déjà basculée ne dépend d'aucun des deux —
/// c'est `MlsGateway.enMls`, qui regarde `mls_since`. Refermer ne rend jamais
/// illisible ce qui a déjà été envoyé.
final mlsMessagesActifsProvider = Provider<bool>((ref) {
  final drapeaux = ref.watch(featureFlagsProvider);
  if (drapeaux.mlsMessages) return true;
  final comptes = drapeaux.mlsMessagesComptes;
  if (comptes.isEmpty) return false;
  // Observé, pas lu : lu à la construction, l'uid valait `null` au démarrage
  // à froid et le drapeau restait fermé pour tout le processus.
  final uid = ref.watch(uidFirebaseProvider);
  return uid != null && comptes.contains(uid);
});

/// Ce compte peut-il tenir **plusieurs sessions à la fois** (plan MLS,
/// phase 7) ?
///
/// Par compte, jamais globalement : lever « une seule session » change une
/// posture de sécurité pour tout le monde, et cette règle protège peut-être
/// contre le partage de comptes. Une liste permet de l'ouvrir aux comptes de
/// test — qui sont justement ceux dont on a besoin pour éprouver le
/// multi-appareil.
///
/// Vide = comportement d'avant, pour tout le monde.
final multiAppareilAutoriseProvider = Provider<bool>((ref) {
  final comptes = ref.watch(featureFlagsProvider).multiAppareilComptes;
  if (comptes.isEmpty) return false;
  final uid = ref.watch(uidFirebaseProvider);
  return uid != null && comptes.contains(uid);
});

/// Clé d'une demande de déchiffrement : l'id du message suffit à identifier
/// le fichier, les métadonnées servent à le produire la première fois.
class DemandeMediaDechiffre extends Equatable {
  final String messageId;
  final MediaChiffre media;

  const DemandeMediaDechiffre(this.messageId, this.media);

  @override
  List<Object?> get props => [messageId, media];
}

/// Chemin local du média déchiffré d'un message.
///
/// Volontairement **sans** `autoDispose` : le résultat est un chemin de
/// fichier stable, et le re-calculer à chaque recyclage de la liste
/// relancerait un téléchargement. Voir aussi le piège du « bouton mort »
/// des providers `autoDispose` lus au premier tap.
final mediaDechiffreProvider =
    FutureProvider.family<String, DemandeMediaDechiffre>((ref, demande) {
  return ref
      .watch(mediaDechiffreCacheProvider)
      .cheminLocal(demande.messageId, demande.media);
});
