import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
