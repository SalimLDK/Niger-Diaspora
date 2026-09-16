import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/messages/presentation/providers/media_dechiffre_provider.dart';
import '../../providers/uid_firebase_provider.dart';
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

  MlsDeviceRecord? fiche;
  Future<MlsDeviceRecord> appareil() async =>
      fiche ??= await registry.ensureRegistered(userId);

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
  );
});
