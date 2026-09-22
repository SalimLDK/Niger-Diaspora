import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/messages/presentation/providers/media_dechiffre_provider.dart';
import '../../providers/uid_firebase_provider.dart';
import '../../services/oubli_medias_locaux.dart';
import 'mls_conversation_service.dart';
import 'mls_delivery.dart';
import 'mls_device_registry.dart';
import 'mls_engine_provider.dart';
import 'mls_gateway.dart';

/// Le transport MLS : les tables, aucune cryptographie.
final mlsDeliveryProvider = Provider<MlsDelivery>((ref) => MlsDelivery());

/// La passerelle que la couche messages utilise — et la seule chose qu'elle
/// connaisse de MLS.
///
/// Nulle tant qu'aucun compte n'est connecté : le repository se comporte
/// alors exactement comme avant, sans un appel réseau de plus.
///
/// **Ne dépend que de l'identifiant utilisateur**, comme le moteur : c'est la
/// règle tirée de la panne Signal, où un service reconstruit par
/// l'invalidation d'un autre repartait « non initialisé » sans que personne
/// ne le rejoue. Le drapeau, lui, est lu à chaque appel par une fermeture,
/// pas observé — l'ouvrir prend effet sans reconstruire quoi que ce soit.
///
/// Mais cet identifiant, il faut l'**observer** : lu une fois à la
/// construction, il valait `null` au démarrage à froid, et la passerelle
/// restait nulle pour tout le processus — messages chiffrés invisibles,
/// envois refusés. Voir [uidFirebaseProvider].
final mlsGatewayProvider = Provider<MlsGateway?>((ref) {
  final userId = ref.watch(uidFirebaseProvider);
  if (userId == null) return null;

  final delivery = ref.read(mlsDeliveryProvider);
  final registry = ref.read(mlsDeviceRegistryProvider);

  // `fiche ??= await …` ne mémorisait qu'une inscription TERMINÉE : trois
  // appels arrivés pendant la première en lançaient trois. Le 2026-09-16 ils
  // ont donné trois lignes `mls_devices` en 190 ms.
  final appareil = volUnique(() => registry.ensureRegistered(userId));

  final service = MlsConversationService(
    userId: userId,
    moteur: () => ref.read(mlsEngineProvider(userId).future),
    delivery: delivery,
    appareil: appareil,
  );

  return MlsGateway(
    userId: userId,
    actif: () => ref.read(mlsMessagesActifsProvider),
    service: service,
    delivery: delivery,
    nomDe: (id) async {
      final row = await Supabase.instance.client
          .from('users')
          .select('display_name')
          .eq('id', id)
          .maybeSingle();
      return row?['display_name'] as String?;
    },
    // `read` dans une fermeture, comme `actif` : la passerelle ne dépend que
    // de l'uid, rien d'autre ne doit la reconstruire.
    surSuppression: (ids) => ref.read(oubliMediasLocauxProvider).oublier(ids),
  );
});

/// Une opération asynchrone qu'on n'exécute qu'une fois à la fois : les
/// appelants simultanés partagent l'appel en cours, un succès est gardé, un
/// échec est oublié — l'appel suivant réessaie.
@visibleForTesting
Future<T> Function() volUnique<T>(Future<T> Function() operation) {
  Future<T>? enCours;
  return () {
    final existant = enCours;
    if (existant != null) return existant;
    final appel = operation();
    enCours = appel;
    unawaited(appel.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(enCours, appel)) enCours = null;
      },
    ));
    return appel;
  };
}
