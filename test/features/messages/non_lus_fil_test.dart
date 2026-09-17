import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/screens/conversation_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Le bandeau « 1 message non lu » d'une conversation basculée ne s'effaçait
/// plus. Vu le 2026-09-15 sur SM A515F, dans la première conversation passée
/// en MLS : le séparateur de bascule (dont le libellé est désormais résolu
/// à l'affichage, voir `separateur_bascule_libelle_test.dart`) est un
/// message **système synthétique** — `senderId: 'system'`, `readBy`
/// vide — donc éternellement non lu. Rien ne viendra jamais le marquer, il
/// n'existe pas côté serveur.
///
/// Et le serveur ne le comptait pas : la vue `mls_unread_counts` ne retient
/// que `kind = 'content'` et exclut l'expéditeur. L'écran disait un, la base
/// disait zéro.
///
/// Ce que ces tests empêchent : qu'un message système redevienne du courrier,
/// que mes propres messages comptent, et que le rang du premier non-lu
/// désigne un séparateur — l'écran s'y déroule.

MessageEntity _m(
  String id,
  String expediteur, {
  List<String> lu = const [],
  MessageType type = MessageType.text,
  DateTime? quand,
}) =>
    MessageEntity(
      id: id,
      senderId: expediteur,
      senderName: expediteur,
      content: id,
      type: type,
      status: MessageStatus.sent,
      createdAt: quand ?? DateTime.utc(2026, 9, 15),
      readBy: lu,
    );

void main() {
  group('compterDepuis', () {
    // Le seul repère fiable pour le séparateur. Les deux autres mentent :
    // l'état de lecture est déjà faussé quand le fil arrive (`markAsRead` part
    // au premier rendu), et le compteur de la liste met quelques secondes à
    // retomber à zéro — s'y fier faisait réapparaître « N non lus » en
    // rouvrant une discussion qu'on venait de lire.
    final visite = DateTime.utc(2026, 9, 15, 12);

    test('compte ce qui est arrivé après, et donne son rang', () {
      final fil = [
        _m('vieux', 'autre', quand: DateTime.utc(2026, 9, 15, 11)),
        _m('a', 'autre', quand: DateTime.utc(2026, 9, 15, 13)),
        _m('b', 'autre', quand: DateTime.utc(2026, 9, 15, 14)),
      ];

      final vus = compterDepuis(fil, 'moi', visite);
      expect(vus.nombre, 2);
      expect(vus.premier, 1);
    });

    test('rien depuis la visite : aucun séparateur', () {
      final fil = [
        _m('vieux', 'autre', quand: DateTime.utc(2026, 9, 15, 11)),
      ];

      final vus = compterDepuis(fil, 'moi', visite);
      expect(vus.nombre, 0);
      expect(vus.premier, isNull);
    });

    test('mes propres messages ne comptent pas', () {
      final fil = [
        _m('a', 'moi', quand: DateTime.utc(2026, 9, 15, 13)),
        _m('b', 'autre', quand: DateTime.utc(2026, 9, 15, 14)),
      ];

      final vus = compterDepuis(fil, 'moi', visite);
      expect(vus.nombre, 1);
      expect(vus.premier, 1);
    });

    test('un message système ne compte pas', () {
      final fil = [
        MlsMessageMapper.separateur(DateTime.utc(2026, 9, 15, 13)),
        _m('a', 'autre', quand: DateTime.utc(2026, 9, 15, 14)),
      ];

      final vus = compterDepuis(fil, 'moi', visite);
      expect(vus.nombre, 1);
      expect(vus.premier, 1);
    });

    test('la borne est stricte : un message à l\'instant pile ne compte pas', () {
      // La visite est écrite en quittant l'écran ; ce qui porte exactement
      // cette date a été vu.
      final fil = [_m('a', 'autre', quand: visite)];

      expect(compterDepuis(fil, 'moi', visite).nombre, 0);
    });
  });

  group("le fil doit aller jusqu'au bout avant tout comptage", () {
    // Vu a l'ecran le 2026-09-16 : le separateur « 2 messages non lus » pose
    // devant deux messages du matin. Le compte etait bon, le RANG faux — il
    // avait ete calcule sur le fil du cache, qui s'arretait avant les vrais
    // non-lus. `_loadCacheSync` affiche ce cache d'abord, a dessein.
    late String source;

    setUpAll(() {
      final fichier = File(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      );
      expect(fichier.existsSync(), isTrue, reason: 'ecran introuvable');
      source = fichier.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('la garde existe et compare au dernier message annonce', () {
      expect(source, contains('bool _filVaJusquAuBout('));
      expect(source, contains('_dernierMessageAnnonce = c.lastMessageAt;'));
    });

    test('elle passe AVANT les deux chemins de comptage', () {
      final garde = source.indexOf('if (!_filVaJusquAuBout(messages)) {');
      final visite = source.indexOf('final depuis = _curseurALOuverture;');
      final repli = source.indexOf('final rang = rangDesDerniersDAutrui(');

      expect(garde, isNot(-1), reason: 'la garde a saute');
      expect(garde, lessThan(visite));
      expect(garde, lessThan(repli));
    });

    test('sans repere de comparaison, elle ne bloque pas', () {
      // Ouverture par lien profond : la liste n'a rien annonce.
      expect(source, contains('if (annonce == null) return true;'));
    });
  });

  group('le curseur de lecture', () {
    // Le séparateur est la **représentation d'un curseur**, pas une propriété
    // des messages. Trois repères ont été essayés avant, et les trois
    // mentaient :
    //
    // - l'état de lecture des messages chargés : déjà faussé à l'arrivée du
    //   fil, `markAsRead` partant au premier rendu ;
    // - le compteur de la liste : il ne dit pas **où**, et il met quelques
    //   secondes à retomber à zéro après lecture ;
    // - une date de visite locale : elle ne survit ni à la pagination ni au
    //   fuseau, et elle a posé « 4 messages non lus » devant des messages de
    //   la veille, vérifié à l'écran.
    late String source;

    setUpAll(() {
      final fichier = File(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      );
      expect(fichier.existsSync(), isTrue, reason: 'écran introuvable');
      source = fichier.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('le curseur vient du serveur, pas des préférences locales', () {
      expect(source, contains('passerelle.curseurDeLecture('));
      expect(
        source,
        isNot(contains('SharedPreferences')),
        reason: 'la date de visite locale ne doit pas revenir',
      );
    });

    test('il est figé à l\'ouverture', () {
      // Un message qui arrive pendant qu'on lit ne doit pas déplacer le
      // repère : le curseur ne se relève qu'une fois.
      expect(source, contains('DateTime? _curseurALOuverture;'));
      expect(source, contains('unawaited(_releverCurseur());'));

      final debut = source.indexOf('Future<void> _releverCurseur() async {');
      expect(debut, isNot(-1));
      final corps = source.substring(debut, debut + 2000);
      expect(corps, contains('_curseurReleve = true;'));
    });

    test('le repère vient du serveur, pas des messages chargés', () {
      // § 11 du modèle : si la page affichée commence **après** le premier
      // non-lu, le chercher dans les messages chargés désignerait le plus
      // ancien de la page. L'identifiant rendu par le serveur, lui, attend que
      // la remontée du fil l'amène à l'écran.
      expect(source, contains('passerelle.premierNonLu('));
      expect(source, contains('_repereServeur'));
    });

    test('le repère serveur passe AVANT les chemins basés sur la liste', () {
      final serveur = source.indexOf('final repere = _repereServeur;');
      final liste = source.indexOf('final depuis = _curseurALOuverture;');

      expect(serveur, isNot(-1), reason: 'le repère serveur a disparu');
      expect(liste, isNot(-1));
      expect(
        serveur,
        lessThan(liste),
        reason: 'les messages chargés ne doivent servir que de repli',
      );
    });

    test('un premier non-lu hors page ne fait pas sauter la vue', () {
      // On ne peut pas se placer sur un message absent : on reste en bas, et
      // le séparateur apparaît en remontant.
      expect(
        source,
        contains('_scrollToUnreadOrBottom(rang == -1 ? null : rang'),
      );
    });

    test('un seul point d\'entrée pour le relevé, sur les deux magasins', () {
      // `repere_de_lecture` lit `messages` ET `mls_messages` : un aiguillage
      // « MLS ou clair » par conversation manquerait les messages en clair
      // d'avant la bascule. La passerelle ne sert plus qu'en repli.
      final serveur = source.indexOf('.read(lectureServeurProvider)\n          .relever(');
      final repli = source.indexOf('await _releverCurseurMls();');
      expect(serveur, isNot(-1), reason: 'le relevé serveur a disparu');
      expect(repli, isNot(-1));
      expect(serveur, lessThan(repli));
    });

    test('le relevé se termine toujours, même en échec', () {
      // Sinon `_pousserCurseur`, qui l'attend, ne marquerait plus jamais rien.
      final debut = source.indexOf('Future<void> _releverCurseur() async {');
      final corps = source.substring(debut, source.indexOf('Future<void> _releverCurseurMls()'));
      expect(corps, contains('} finally {'));
      expect(
        corps.indexOf('if (!_releve.isCompleted) _releve.complete();'),
        greaterThan(corps.indexOf('} finally {')),
      );
    });

    test('« rien à lire » du serveur passe AVANT les replis sur la liste', () {
      // Sans ça, un fil chargé dont l'état de lecture est en retard inventait
      // un séparateur que le serveur venait de démentir.
      final debut = source.indexOf('void _calculateUnreadOnOpen()');
      final corps = source.substring(debut);
      final foi = corps.indexOf('if (_repereFaitFoi) {');
      final liste = corps.indexOf('compterNonLus(messages, currentUser.id)');
      expect(foi, isNot(-1));
      expect(liste, isNot(-1));
      expect(foi, lessThan(liste));
    });

    test('le comptage attend que le curseur soit relevé', () {
      // Sans cette attente, le premier passage compterait sans repère et
      // verrouillerait un séparateur faux.
      final attente = source.indexOf('if (!_curseurReleve) return;');
      final usage = source.indexOf('final depuis = _curseurALOuverture;');

      expect(attente, isNot(-1));
      expect(usage, isNot(-1));
      expect(attente, lessThan(usage));
    });
  });

  group("l'avancée du curseur", () {
    late String corps;

    setUpAll(() {
      final source = File(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final debut = source.indexOf('Future<void> _pousserCurseur() async {');
      expect(debut, isNot(-1), reason: '_pousserCurseur introuvable');
      corps = source.substring(debut, source.indexOf('final Completer<void> _releve', debut));
    });

    test('relever, PUIS marquer', () {
      // Dans l'autre ordre, le repère se lit sur un état déjà « lu » et le
      // séparateur n'a plus rien à désigner. Les 1,1 s de délai le
      // garantissaient presque toujours — pas sur un réseau lent.
      final attente = corps.indexOf('await _releve.future;');
      expect(attente, isNot(-1));
      expect(attente, lessThan(corps.indexOf('avancerCurseur(')));
      expect(attente, lessThan(corps.indexOf('avancerJusqua(')));
    });

    test('la borne envoyée est un identifiant', () {
      expect(corps, contains('avancerJusqua(conversationId, jusquaId)'));
    });

    test('basculée se décide sur mls_since, pas sur le drapeau du compte', () {
      // `enMls` est vrai pour TOUTE conversation dès que le drapeau est
      // ouvert : une conversation encore en clair n'avait alors jamais ses
      // messages marqués.
      expect(corps, contains('passerelle.mlsSince(conversationId) != null'));
      expect(corps, isNot(contains('enMls(')));
    });

    test('les messages en clair sont marqués même dans une conversation basculée', () {
      // L'appel n'est pas dans la branche `if (basculee)` : il vient après le
      // bloc MLS, sans condition.
      final finMls = corps.indexOf("debugPrint('ConversationScreen: curseur MLS non avancé");
      final clair = corps.indexOf('.avancerJusqua(');
      expect(finMls, isNot(-1));
      expect(clair, greaterThan(finMls));
    });

    test("l'ancien marquage global ne sert QUE si la fonction est absente", () {
      // Sur un refus ou une panne, le reprendre marquerait aussi ce qui n'a pas
      // été vu.
      final absente = corps.indexOf('on LectureServeurAbsente {');
      final ancien = corps.indexOf('.markAsRead(');
      final autres = corps.indexOf('} catch (e) {', absente);
      expect(absente, isNot(-1));
      expect(ancien, greaterThan(absente));
      expect(ancien, lessThan(autres));
      expect('.markAsRead('.allMatches(corps).length, 1);
    });
  });

  group("A2 — ouvrir, c'est lire ce qui est à l'écran", () {
    // Choix du 2026-09-16. Le mécanisme (le relevé après le saut) est éprouvé
    // contre un vrai ListView par `releve_a_l_ecran_test.dart` ; ceci tient
    // son branchement dans l'écran, qu'on ne peut pas monter.
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
    });

    String corpsDe(String debut, String fin) {
      final i = source.indexOf(debut);
      expect(i, isNot(-1), reason: '$debut introuvable');
      final j = source.indexOf(fin, i + debut.length);
      expect(j, isNot(-1), reason: '$fin introuvable après $debut');
      return source.substring(i, j);
    }

    test('chaque sortie du placement initial pose la vue', () {
      // Une sortie oubliée, et la vue n'est jamais posée : plus aucune bulle ne
      // serait lue, ni à l'ouverture ni après (le filet de 6 s mis à part).
      final corps = corpsDe('void _scrollToUnreadOrBottom(', 'void dispose()');
      expect('_apresPlacement();'.allMatches(corps).length, 4);
      // Et le saut d'abord : poser avant `jumpTo`, c'est lire la liste en bas.
      expect(
        corps.indexOf('_scrollController.jumpTo(targetPosition);'),
        lessThan(corps.lastIndexOf('_apresPlacement();')),
      );
    });

    test('aucun compte à rebours avant que la vue soit posée', () {
      final corps = corpsDe('void _signalerVisibilite(', 'void _attendreAvantDeLire(');
      final note = corps.indexOf('_aLEcran.noter(message, fraction);');
      final verrou = corps.indexOf('if (!_aLEcran.vuePosee) return;');
      final attente = corps.indexOf('_attendreAvantDeLire(message);');
      expect(note, isNot(-1), reason: 'le relevé doit être tenu même avant la pose');
      expect(verrou, greaterThan(note));
      expect(attente, greaterThan(verrou));
    });

    test('une seule écriture pour tout l\'écran, après le relevé du repère', () {
      final corps = corpsDe('void _lireCeQuiEstALEcran()', 'void _apresPlacement()');
      expect(corps, contains('plusRecentALire('));
      expect('_pousserCurseur()'.allMatches(corps).length, 1);
      // `_pousserCurseur` attend lui-même la fin du relevé (voir « relever,
      // PUIS marquer ») : pas de second chemin d'écriture ici.
      expect(corps, isNot(contains('avancerJusqua(')));
      expect(corps, isNot(contains('avancerCurseur(')));
    });

    test('gardes refusées : les comptes à rebours ordinaires, pas rien', () {
      // Refuser sans rien armer, c'était ne plus jamais lire ces bulles : leur
      // visibilité ne changera plus.
      final corps = corpsDe('void _lireCeQuiEstALEcran()', 'void _apresPlacement()');
      final garde = corps.indexOf('if (!_isAppInForeground || !_estAffichee) {');
      expect(garde, isNot(-1));
      expect(corps.indexOf('_attendreAvantDeLire(message);'), greaterThan(garde));
    });

    test('le retour au premier plan relit ce qui est à l\'écran', () {
      final corps = corpsDe('void didChangeAppLifecycleState(', 'void _onScroll()');
      expect(corps, contains('if (_aLEcran.vuePosee) _lireCeQuiEstALEcran();'));
    });

    test('un filet pose la vue si le placement n\'arrive jamais', () {
      expect(source, contains('_filetPlacement = Timer(_fenetreRecompteNonLus, _apresPlacement);'));
      expect(corpsDe('void dispose() {', 'super.dispose();'), contains('_filetPlacement?.cancel();'));
    });
  });

  group('B — le séparateur part quand tout est lu', () {
    // La règle elle-même est tenue par `suivi_des_non_lus_test.dart` (dont un
    // vrai ListView). Ceci tient son branchement dans l'écran.
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
    });

    String corpsDe(String debut, String fin) {
      final i = source.indexOf(debut);
      expect(i, isNot(-1), reason: '$debut introuvable');
      final j = source.indexOf(fin, i + debut.length);
      expect(j, isNot(-1), reason: '$fin introuvable après $debut');
      return source.substring(i, j);
    }

    test('la borne haute est notée au relevé d\'ouverture', () {
      final corps = corpsDe('Future<void> _releverCurseur() async {', 'Future<void> _releverCurseurMls()');
      expect(corps, contains('_suivi.noterOuverture(repere);'));
    });

    test('un relevé de suivi part APRÈS les écritures du curseur', () {
      final corps = corpsDe('Future<void> _pousserCurseur() async {', 'final SuiviDesNonLus _suivi');
      final suivi = corps.indexOf('await _suivreLaLecture();');
      expect(suivi, isNot(-1));
      expect(suivi, greaterThan(corps.indexOf('.avancerJusqua(')));
      expect(suivi, greaterThan(corps.indexOf('avancerCurseur(')));
    });

    test('les rapports de visibilité sont vidés AVANT de décider', () {
      // Sans ça, un séparateur entré à l'écran depuis moins de 500 ms passe
      // pour absent, et part sous les yeux.
      final corps = corpsDe('Future<void> _suivreLaLecture() async {', 'final Completer<void> _releve');
      final vidage = corps.indexOf('VisibilityDetectorController.instance.notifyNow();');
      expect(vidage, isNot(-1));
      expect(vidage, lessThan(corps.indexOf('_suivi.suivre(maintenant)')));
    });

    test('un relevé ancien arrivé en dernier est ignoré', () {
      final corps = corpsDe('Future<void> _suivreLaLecture() async {', 'final Completer<void> _releve');
      expect(corps, contains('final numero = ++_releveDeSuivi;'));
      expect(corps, contains('numero != _releveDeSuivi'));
    });

    test('le séparateur retiré ne s\'affiche plus, et sa sortie d\'écran est suivie', () {
      expect(source, contains('!_suivi.separateurRetire;'));
      expect(source, contains("key: const ValueKey('separateur-non-lus'),"));
      expect(source, contains('if (_suivi.signalerSeparateur(info.visibleFraction)) {'));
    });

    test('le badge suit les relevés, plus le compte figé d\'ouverture', () {
      expect(source, contains('if (_suivi.restants(_unreadCountOnOpen) > 0)'));
      expect(source, isNot(contains('if (_unreadCountOnOpen > 0)\n                          Positioned(')));
    });

    test('un message reçu après coup ne repose pas de séparateur', () {
      // Le repère serveur ferme le comptage dès qu'il est posé : aucune
      // émission suivante du fil ne recalcule le séparateur. Et le suivi est
      // `final`, jamais recréé — un séparateur retiré le reste.
      final calcul = corpsDe('void _calculateUnreadOnOpen() {', 'void _scrollToUnreadOrBottom(');
      // Première instruction du calcul : le verrou.
      expect(calcul.split('\n')[1].trim(), 'if (_hasCalculatedUnread) return;');
      final foi = calcul.indexOf('if (_repereFaitFoi) {');
      expect(foi, isNot(-1));
      expect(calcul.substring(foi, foi + 120), contains('_hasCalculatedUnread = true;'));
      expect(source, contains('if (!_hasCalculatedUnread &&\n          next.messages.isNotEmpty &&'));
      // Une seule affectation du suivi : sa déclaration `final`.
      expect(RegExp(r'_suivi\s*=').allMatches(source).length, 1);
      expect(source, contains('final SuiviDesNonLus _suivi = SuiviDesNonLus();'));
    });
  });

  group('rangDesDerniersDAutrui', () {
    // Quand `markAsRead` a déjà tout marqué lu — il part au premier rendu,
    // avant même que le fil chiffré ne soit récupéré — l'état de lecture ne
    // dit plus rien. On place alors le séparateur par le **rang**, à partir du
    // compteur serveur relevé avant l'ouverture.
    test('trouve le rang du N-ième message d\'autrui en remontant', () {
      final fil = [
        _m('a', 'autre'),   // 0
        _m('b', 'moi'),     // 1
        _m('c', 'autre'),   // 2
        _m('d', 'autre'),   // 3
      ];

      expect(rangDesDerniersDAutrui(fil, 'moi', 1), 3);
      expect(rangDesDerniersDAutrui(fil, 'moi', 2), 2);
      expect(rangDesDerniersDAutrui(fil, 'moi', 3), 0);
    });

    test('mes propres messages ne comptent pas dans le rang', () {
      final fil = [
        _m('a', 'autre'),
        _m('b', 'moi'),
        _m('c', 'moi'),
      ];

      // Un seul message d'autrui, tout au début.
      expect(rangDesDerniersDAutrui(fil, 'moi', 1), 0);
    });

    test('un message système est sauté', () {
      final fil = [
        _m('a', 'autre'),
        MlsMessageMapper.separateur(DateTime.utc(2026, 9, 15)),
        _m('c', 'autre'),
      ];

      expect(rangDesDerniersDAutrui(fil, 'moi', 2), 0);
    });

    test('fil incomplet : on ne place rien plutôt que de se tromper', () {
      // Le serveur annonce 5 non-lus, le fil n'en porte que deux : il n'est
      // pas encore complet. Placer un séparateur au début serait faux.
      final fil = [_m('a', 'autre'), _m('b', 'autre')];

      expect(rangDesDerniersDAutrui(fil, 'moi', 5), isNull);
    });

    test('zéro ou négatif : rien à placer', () {
      final fil = [_m('a', 'autre')];

      expect(rangDesDerniersDAutrui(fil, 'moi', 0), isNull);
      expect(rangDesDerniersDAutrui(fil, 'moi', -1), isNull);
    });
  });

  group('le rattrapage MLS ne tourne pas deux fois à la fois', () {
    // `catchUp` fait avancer le cliquet MLS. Depuis que la liste déclenche un
    // rattrapage de fond, l'écran peut ouvrir le même fil au même moment :
    // sans partage du futur, le cliquet avancerait deux fois en parallèle, et
    // un cliquet abîmé rend des messages illisibles pour de bon.
    late String source;

    setUpAll(() {
      final fichier = File('lib/core/crypto/mls/mls_gateway.dart');
      expect(fichier.existsSync(), isTrue, reason: 'passerelle introuvable');
      source = fichier.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('les appelants concurrents partagent le même futur', () {
      expect(source, contains('final enCours = _rattrapages[conversationId];'));
      expect(source, contains('if (enCours != null) return enCours;'));
    });

    test('le futur est retiré une fois terminé', () {
      // Sinon un échec figerait la conversation : tout appelant suivant
      // recevrait le même futur déjà en erreur.
      expect(source, contains('_rattrapages.remove(conversationId);'));
    });

    test('le rattrapage de fond est borné', () {
      // Il ne s'agit pas de déchiffrer toute la messagerie au démarrage.
      expect(source, contains('int maximum = 3'));
      expect(source, contains('if (sortie.length >= maximum) break;'));
    });
  });

  group('le séparateur né après la lecture réseau', () {
    // `_loadCacheSync` affiche le cache local immédiatement et pose
    // `isLoadingInitial: false`. Les messages neufs, eux, ne sont PAS dans ce
    // cache : sur une conversation chiffrée ils n'ont jamais été déchiffrés
    // et n'arrivent qu'après le réseau. Le comptage tombait donc sur zéro,
    // `_hasCalculatedUnread` se fermait pour de bon, et le séparateur
    // « nouveaux messages » ne s'affichait jamais.
    //
    // Signalé à l'usage le 2026-09-15, en même temps que le délai avant que
    // le message neuf lui-même apparaisse — c'est la même cause.
    //
    // Limite assumée, comme le reste de ce fichier : ces tests lisent la
    // source. Monter `ConversationScreen` demande GoRouter, une session
    // Supabase et une dizaine de providers.
    late String source;

    setUpAll(() {
      final fichier = File(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      );
      expect(fichier.existsSync(), isTrue, reason: 'écran introuvable');
      source = fichier.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('zéro non-lu ne ferme plus le verrou immédiatement', () {
      // Le verrou ne se ferme qu'une fois la fenêtre d'ouverture passée.
      expect(
        source,
        contains(
          "if (DateTime.now().difference(_ouvertA) >= _fenetreRecompteNonLus) {",
        ),
        reason: 'le comptage se refermerait sur le cache seul',
      );
    });

    test('la fenêtre de recompte est bornée', () {
      // Sans borne, un message reçu en direct se rangerait sous un séparateur
      // « nouveaux messages » sous les yeux de qui regarde la discussion.
      expect(source, contains('_fenetreRecompteNonLus = Duration(seconds:'));
    });

    test('le placement initial ne se rejoue pas à chaque recompte', () {
      // Sinon la vue sauterait à chaque émission pendant la fenêtre.
      expect(source, contains('bool _aFaitLePlacementInitial = false;'));
      final debut = source.indexOf('void _calculateUnreadOnOpen()');
      final corps = source.substring(debut, debut + 2200);
      expect(
        '_aFaitLePlacementInitial'.allMatches(corps).length,
        greaterThanOrEqualTo(4),
        reason: 'les deux branches doivent garder le placement',
      );
    });
  });

  const moi = 'uid-moi';

  group('compterNonLus', () {
    test('le séparateur de bascule MLS ne compte pas', () {
      // Le cas exact rencontré sur l'appareil : une conversation avec
      // soi-même, un seul message, et un bandeau qui annonçait un non-lu.
      final fil = [
        _m('vieux', moi, lu: [moi]),
        MlsMessageMapper.separateur(DateTime.utc(2026, 9, 15)),
        _m('mien', moi, lu: [moi]),
      ];

      final r = compterNonLus(fil, moi);
      expect(r.nombre, 0);
      expect(r.premier, isNull);
    });

    test('aucun message système ne compte, quel qu\'il soit', () {
      final fil = [
        _m('arrivee', 'system', type: MessageType.system),
        _m('depart', 'system', type: MessageType.system),
      ];
      expect(compterNonLus(fil, moi).nombre, 0);
    });

    test('mes propres messages ne comptent pas, lus ou non', () {
      final fil = [_m('a', moi), _m('b', moi, lu: [moi])];
      expect(compterNonLus(fil, moi).nombre, 0);
    });

    test('un message d\'autrui non lu compte, et donne son rang', () {
      final fil = [
        _m('a', moi, lu: [moi]),
        _m('b', 'autre', lu: [moi]),
        _m('c', 'autre'),
        _m('d', 'autre'),
      ];
      final r = compterNonLus(fil, moi);
      expect(r.nombre, 2);
      expect(r.premier, 2);
    });

    test('le rang du premier non-lu saute le séparateur', () {
      // Sans ça, le bandeau se posait SUR le séparateur, et l'écran s'y
      // déroulait — au mauvais endroit du fil.
      final fil = [
        _m('vieux', 'autre', lu: [moi]),
        MlsMessageMapper.separateur(DateTime.utc(2026, 9, 15)),
        _m('neuf', 'autre'),
      ];
      final r = compterNonLus(fil, moi);
      expect(r.nombre, 1);
      expect(r.premier, 2);
    });

    test('fil vide', () {
      final r = compterNonLus(const [], moi);
      expect(r.nombre, 0);
      expect(r.premier, isNull);
    });
  });
}
