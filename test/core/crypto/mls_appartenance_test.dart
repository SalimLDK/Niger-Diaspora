import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 5.4, phase 8)
/// ----------------------------------------------------
/// La réconciliation d'appartenance ne tournait qu'à l'envoi. Exclure
/// quelqu'un d'un groupe ne le sortait de l'arbre MLS qu'au prochain message
/// de quelqu'un d'autre, et un arrivant attendait ce même message pour
/// recevoir son Welcome. Tardif, jamais faux — mais tardif.
///
/// `appartenanceChangee` ferme cet écart en s'accrochant au flux de la
/// conversation, seul signal qui voie TOUS les chemins d'appartenance : la
/// moitié d'entre eux écrit `group_members`, et c'est un déclencheur serveur
/// qui recopie dans `participant_ids`, sans qu'aucun code Dart ne le voie.
///
/// Ce que ces tests empêchent, concrètement : qu'ouvrir une discussion lance
/// un balayage des appareils de tous ses participants (le flux émet à chaque
/// frappe d'un indicateur de saisie), et qu'un échec de réconciliation soit
/// retenu comme un succès — il serait alors avalé pour de bon, le signal
/// suivant n'ayant plus rien à signaler.

/// Le transport, sans réseau : seul `conversation()` est consulté par le
/// chemin testé, pour savoir si la conversation est basculée.
class _TransportFige extends MlsDelivery {
  _TransportFige(this.mlsSince)
      : super(ensureAuth: (() async => true));

  final String? mlsSince;

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'group',
        'participant_ids': <String>[],
        'mls_since': mlsSince,
      };
}

/// Le service, sans moteur : on compte les appels, on ne chiffre rien.
class _ServiceCompteur extends MlsConversationService {
  _ServiceCompteur({this.echoue = false})
      : super(
          userId: 'u1',
          moteur: () => throw StateError('le moteur ne doit pas être demandé'),
          delivery: _TransportFige(null),
          appareil: () => throw StateError('inutile ici'),
        );

  final bool echoue;
  int groupes = 0;
  int reconciliations = 0;

  @override
  Future<void> ensureGroup(String conversationId) async => groupes++;

  @override
  Future<void> reconcileMembership(String conversationId,
      {int tentative = 0}) async {
    reconciliations++;
    if (echoue) throw StateError('23505 pour tout le monde');
  }
}

MlsGateway _passerelle(
  _ServiceCompteur service, {
  String? mlsSince = '2026-09-15T00:00:00Z',
  bool actif = true,
}) =>
    MlsGateway(
      userId: 'u1',
      actif: () => actif,
      service: service,
      delivery: _TransportFige(mlsSince),
    );

String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('appartenanceChangee', () {
    test('la première vue enregistre et ne réconcilie pas', () async {
      final service = _ServiceCompteur();
      final passerelle = _passerelle(service);

      await passerelle.appartenanceChangee('c1', ['a', 'b']);

      // Ouvrir une discussion ne doit pas balayer les appareils de tous ses
      // participants : `catchUp` et l'envoi couvrent déjà ce moment-là.
      expect(service.reconciliations, 0);
      expect(service.groupes, 0);
    });

    test('une liste inchangée ne réconcilie pas, même répétée', () async {
      final service = _ServiceCompteur();
      final passerelle = _passerelle(service);

      await passerelle.appartenanceChangee('c1', ['a', 'b']);
      await passerelle.appartenanceChangee('c1', ['a', 'b']);
      await passerelle.appartenanceChangee('c1', ['b', 'a']); // même ensemble

      expect(service.reconciliations, 0);
    });

    test('un ajout réconcilie une fois', () async {
      final service = _ServiceCompteur();
      final passerelle = _passerelle(service);

      await passerelle.appartenanceChangee('c1', ['a', 'b']);
      await passerelle.appartenanceChangee('c1', ['a', 'b', 'c']);

      expect(service.groupes, 1);
      expect(service.reconciliations, 1);

      // Et le nouvel état est retenu : le même signal ne repasse pas.
      await passerelle.appartenanceChangee('c1', ['a', 'b', 'c']);
      expect(service.reconciliations, 1);
    });

    test('une exclusion réconcilie aussi', () async {
      final service = _ServiceCompteur();
      final passerelle = _passerelle(service);

      await passerelle.appartenanceChangee('c1', ['a', 'b', 'c']);
      await passerelle.appartenanceChangee('c1', ['a', 'b']);

      expect(service.reconciliations, 1);
    });

    test('une conversation non basculée, drapeau fermé, ne coûte rien',
        () async {
      final service = _ServiceCompteur();
      final passerelle = _passerelle(service, mlsSince: null, actif: false);

      await passerelle.appartenanceChangee('c1', ['a', 'b']);
      await passerelle.appartenanceChangee('c1', ['a', 'b', 'c']);

      expect(service.reconciliations, 0);
      expect(service.groupes, 0);
    });

    test('un échec ne se retient pas : le signal suivant rejoue', () async {
      final service = _ServiceCompteur(echoue: true);
      final passerelle = _passerelle(service);

      await passerelle.appartenanceChangee('c1', ['a', 'b']);
      await passerelle.appartenanceChangee('c1', ['a', 'b', 'c']);
      expect(service.reconciliations, 1);

      // Même liste qu'à l'échec : comme rien n'a été retenu, on retente.
      // Sans ça, un 23505 perdu une fois le serait pour de bon.
      await passerelle.appartenanceChangee('c1', ['a', 'b', 'c']);
      expect(service.reconciliations, 2);
    });

    test('deux conversations ne se marchent pas dessus', () async {
      final service = _ServiceCompteur();
      final passerelle = _passerelle(service);

      await passerelle.appartenanceChangee('c1', ['a', 'b']);
      await passerelle.appartenanceChangee('c2', ['a', 'b']);
      await passerelle.appartenanceChangee('c1', ['a', 'b', 'c']);

      expect(service.reconciliations, 1);
    });
  });

  group('câblage', () {
    test('le flux de conversation appelle appartenanceChangee', () {
      // La garde de structure : sans cet appel, tout ce qui précède est du
      // code mort, et la réconciliation retombe au prochain envoi — le
      // défaut exact que cette tranche corrige. C'est la leçon du chantier
      // Signal : des pièces justes que personne n'appelle.
      final repo = _source(
        'lib/features/messages/data/repositories/message_repository_impl.dart',
      );
      final flux = repo.substring(repo.indexOf('getConversationStream('));
      expect(
        flux.substring(0, 1400).contains('appartenanceChangee'),
        isTrue,
        reason: 'getConversationStream doit signaler l\'appartenance à MLS',
      );
      // Et sans attendre : l'écran ne doit rien devoir à un travail de fond.
      expect(flux.substring(0, 1400).contains('unawaited('), isTrue);
    });
  });
}
