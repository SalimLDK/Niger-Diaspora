import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';

/// Deux défauts trouvés le 2026-09-15 sur Pixel 10 Pro XL, en regardant la
/// liste des discussions pendant qu'un autre compte envoyait des messages.
///
/// **1. « Message chiffré », pour toujours.** Un message reçu sans que la
/// discussion soit ouverte n'est jamais déchiffré : le fil est le seul à le
/// faire. Un message de 21:23 était encore illisible à 21:33, app ouverte et
/// liste à l'écran. Le clair existait pourtant sur l'appareil — l'isolate de
/// notification l'avait déchiffré à l'arrivée du push, sur une copie jetable
/// côté Rust qui n'avance pas le cliquet.
///
/// **2. L'accusé de lecture mensonger.** Mesuré dans la base : `read_at` posé
/// une seconde après `delivered_at`, en lot, sur des messages dont la
/// discussion n'était pas affichée. Côté expéditeur « Lu » sur des messages
/// jamais lus ; côté destinataire, plus aucune pastille de non-lus.
///
/// ```
///   message    delivered_at   read_at
///   01:23:11   01:31:52       01:31:53
///   01:29:46   01:31:52       01:31:53
///   01:29:58   01:31:52       01:31:53
/// ```
ConversationEntity _conv({
  String? apercu,
  DateTime? quand,
  bool supprime = false,
  bool expire = false,
}) =>
    ConversationEntity(
      id: 'c1',
      type: ConversationType.individual,
      participantIds: const ['moi', 'autre'],
      createdBy: 'moi',
      createdAt: DateTime.utc(2026, 9, 1),
      lastMessage: apercu,
      lastMessageAt: quand,
      lastMessageDeleted: supprime,
      lastMessageExpired: expire,
    );

final _quand = DateTime.utc(2026, 9, 15, 21, 23);

void main() {
  group("l'aperçu déchiffré par la notification complète la liste", () {
    test('aperçu vide : le texte de la notification est repris', () {
      final sortie = MessageRepositoryImpl.apercuDepuisNotification(
        _conv(apercu: '', quand: _quand),
        'On se voit demain ?',
      );

      expect(sortie.lastMessage, 'On se voit demain ?');
    });

    test('aperçu déjà connu : le cache du fil reste prioritaire', () {
      // Le cache du fil connaît les éditions ; l'aperçu de notification est
      // figé à la réception.
      final sortie = MessageRepositoryImpl.apercuDepuisNotification(
        _conv(apercu: 'texte du cache', quand: _quand),
        'texte de la notification',
      );

      expect(sortie.lastMessage, 'texte du cache');
    });

    test('rien à reprendre : la conversation ressort telle quelle', () {
      final entree = _conv(apercu: '', quand: _quand);

      expect(
        MessageRepositoryImpl.apercuDepuisNotification(entree, null).lastMessage,
        isEmpty,
      );
      expect(
        MessageRepositoryImpl.apercuDepuisNotification(entree, '').lastMessage,
        isEmpty,
      );
    });

    test('jamais rien envoyé : pas de dernier message à résumer', () {
      final sortie = MessageRepositoryImpl.apercuDepuisNotification(
        _conv(apercu: '', quand: null),
        'du texte',
      );

      expect(sortie.lastMessage, isEmpty);
    });

    // C'est le cas qui compte le plus : l'aperçu de notification a été posé
    // à la RÉCEPTION, donc avant la suppression. Le reprendre rendrait à la
    // liste le texte que « supprimer pour tout le monde » venait d'en
    // retirer — la fuite refermée en base, rouverte depuis l'appareil.
    test('message supprimé : le texte ne revient pas par cette porte', () {
      final sortie = MessageRepositoryImpl.apercuDepuisNotification(
        _conv(apercu: '', quand: _quand, supprime: true),
        'le texte supprimé',
      );

      expect(sortie.lastMessage, isEmpty);
      expect(sortie.apercuEfface, ApercuEfface.supprime);
    });

    test('message expiré : même refus', () {
      final sortie = MessageRepositoryImpl.apercuDepuisNotification(
        _conv(apercu: '', quand: _quand, expire: true),
        'le texte expiré',
      );

      expect(sortie.lastMessage, isEmpty);
      expect(sortie.apercuEfface, ApercuEfface.expire);
    });
  });

  group('« lu » survit à la course avec « livré »', () {
    // `ConversationScreen.initState` lance `markAsDelivered` **et**
    // `markAsRead` coup sur coup, sans `await`. Les deux lisent « aucun
    // reçu », le premier insère, le second heurte la clé primaire
    // `(message_id, user_id)`. L'exception remontait au `catch` de
    // `markAsRead`, qui rend un `Left` que l'appelant ignore.
    //
    // Mesuré le 2026-09-15 sur Pixel 10 Pro XL : cinq messages avec
    // `delivered_at` posé et `read_at` nul, même après avoir ouvert la
    // discussion, et pas une ligne de journal. C'est une course : une heure
    // plus tôt, les mêmes reçus étaient corrects.
    //
    // Limite assumée : `marquer()` parle au réseau, ces tests lisent la
    // source. Le comportement, lui, se vérifie sur appareil.
    late String source;

    setUpAll(() {
      final fichier = File('lib/core/crypto/mls/mls_metadonnees.dart');
      expect(fichier.existsSync(), isTrue, reason: 'fichier introuvable');
      source = fichier.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('la collision de clé primaire ne fait plus échouer « lu »', () {
      expect(
        source,
        contains("if (e.code != '23505') rethrow;"),
        reason: 'une insertion concurrente reperdrait « lu »',
      );
    });

    test('« lu » est posé sur tout le lot, pas sur les seuls reçus vus', () {
      // C'est la moitié qui referme vraiment la course : entre le SELECT et
      // l'UPDATE, l'autre appel a pu créer les reçus manquants.
      final debut = source.indexOf('if (!lu) continue;');
      expect(debut, isNot(-1));

      final bloc = source.substring(debut, debut + 600);
      expect(bloc, contains(".inFilter('message_id', lot)"));
      expect(bloc, isNot(contains('aAvancer')));
    });

    test("l'heure du premier coup d'œil n'est pas réécrite", () {
      // La règle d'origine : « lu à 14 h 03 » ne doit pas devenir « lu à
      // l'instant » à chaque ouverture. Elle tient désormais par un filtre
      // SQL au lieu d'une lecture préalable.
      final debut = source.indexOf('if (!lu) continue;');
      final bloc = source.substring(debut, debut + 600);
      expect(bloc, contains(".isFilter('read_at', null)"));
    });
  });

  group('« lu » exige que la discussion soit affichée', () {
    // Limite assumée, comme `etat_vide_filtre_test.dart` : ces tests lisent la
    // source. Monter `ConversationScreen` demande GoRouter, une session
    // Supabase et une dizaine de providers, et le garde est privé.
    late String source;

    setUpAll(() {
      final fichier = File(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      );
      expect(fichier.existsSync(), isTrue, reason: 'écran introuvable');
      source = fichier.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('le garde de visibilité existe et interroge le routeur', () {
      expect(source, contains('bool get _estAffichee'));
      // L'emplacement GLOBAL, pas `ModalRoute.isCurrent` : ce dernier est vrai
      // aussi dans une branche d'onglet inactive.
      expect(source, contains('currentConfiguration'));
      expect(source, isNot(contains('ModalRoute.of(context)?.isCurrent')));
    });

    test('le retour au premier plan ne marque plus lu à lui seul', () {
      final debut = source.indexOf('if (state == AppLifecycleState.resumed) {');
      expect(debut, isNot(-1), reason: 'la garde de cycle de vie a disparu');

      final bloc = source.substring(debut, debut + 700);
      final marqueLu = bloc.indexOf('markAsReadProvider');
      expect(marqueLu, isNot(-1));

      final garde = bloc.indexOf('if (_estAffichee) {');
      expect(garde, isNot(-1), reason: 'le garde de visibilité a sauté');
      expect(
        garde,
        lessThan(marqueLu),
        reason: '« lu » serait de nouveau posé sans que personne ne regarde',
      );
    });

    test("l'arrivée d'un message exige les deux conditions", () {
      expect(
        source,
        contains('_isAppInForeground &&\n          _estAffichee'),
        reason: 'premier plan seul ne suffit pas : il faut être à l\'écran',
      );
    });

    test('« livré » reste posé sans condition de visibilité', () {
      // Livré vaut dès que l'appareil a le message. N'exiger la visibilité que
      // pour « lu » est tout l'intérêt de la distinction.
      final debut = source.indexOf('if (state == AppLifecycleState.resumed) {');
      final bloc = source.substring(debut, debut + 700);
      final livre = bloc.indexOf('markAsDeliveredProvider');
      final garde = bloc.indexOf('if (_estAffichee) {');

      expect(livre, isNot(-1));
      expect(livre, lessThan(garde), reason: '« livré » ne doit pas être gardé');
    });
  });
}
