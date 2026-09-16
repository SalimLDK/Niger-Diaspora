import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/screens/conversation_screen.dart'
    show plusRecentALire;
import 'package:diaspo_niger/features/messages/presentation/utils/releve_a_l_ecran.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Choix A2 du 2026-09-16 : **ouvrir une discussion lit ce qui est à l'écran,
/// tout de suite**, et rien de ce qui est sous le pli.
///
/// Tout repose sur une question à laquelle `VisibilityDetector` ne répond pas
/// seul : *qu'est-ce qui est affiché une fois la vue posée ?* Il ne rapporte que
/// les changements, par lots de 500 ms, et la liste s'ouvre en bas avant de
/// sauter au premier non-lu. Si les bulles du bas — vues une image, pas lues —
/// restaient dans le relevé après le saut, l'ouverture les marquerait « Lu »,
/// c'est-à-dire exactement le défaut que le curseur a corrigé.
///
/// Ces tests montent un vrai `ListView` inversé, avec l'intervalle de 500 ms
/// de production, et vérifient le relevé après le saut dans les deux ordres
/// possibles : saut **avant** le premier lot de rapports (réseau rapide), et
/// **après** (le relevé serveur a pris plus de 500 ms — les bulles du bas ont
/// déjà été rapportées visibles, il faut que leur disparition le soit aussi).
///
/// Hauteur de l'écran de test : 600 px. Bulles de 80 px : 7 entières + une à
/// moitié (sous le seuil de 60 %) sont visibles à la fois.
const _hauteur = 80.0;
const _nombre = 60;

MessageEntity _message(int rang) => MessageEntity(
      id: 'm$rang',
      senderId: 'autre',
      senderName: 'autre',
      content: 'm$rang',
      type: MessageType.text,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 9, 16).add(Duration(minutes: rang)),
    );

/// `m0` est le plus ancien, `m59` le plus récent — en bas de la liste inversée.
final _fil = [for (var i = 0; i < _nombre; i++) _message(i)];

/// Les identifiants des bulles entièrement visibles quand la liste inversée est
/// défilée de [decalage] px depuis le bas.
Set<String> _attendus(double decalage) {
  final premier = (decalage / _hauteur).ceil();
  final dernier = ((decalage + 600) / _hauteur).floor() - 1;
  return {
    for (var depuisLeBas = premier; depuisLeBas <= dernier; depuisLeBas++)
      _fil[_nombre - 1 - depuisLeBas].id,
  };
}

Future<ScrollController> _monter(WidgetTester tester, ReleveALEcran releve) async {
  final defilement = ScrollController();
  addTearDown(defilement.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: defilement,
          reverse: true,
          itemCount: _nombre,
          itemExtent: _hauteur,
          itemBuilder: (_, i) {
            final message = _fil[_nombre - 1 - i];
            return VisibilityDetector(
              key: ValueKey('vu-${message.id}'),
              onVisibilityChanged: (info) => releve.noter(message, info.visibleFraction),
              child: Text(message.content),
            );
          },
        ),
      ),
    ),
  );
  return defilement;
}

/// Ce que fait `_scrollToUnreadOrBottom` : le saut dans un rappel de fin
/// d'image, puis la vue déclarée posée.
Future<void> _sauterPuisPoser(
  WidgetTester tester,
  ScrollController defilement,
  ReleveALEcran releve,
  double decalage,
  VoidCallback lire,
) async {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    defilement.jumpTo(decalage);
    releve.poser(lire, monte: () => true);
  });
  WidgetsBinding.instance.ensureVisualUpdate();
  await tester.pump(); // l'image du rappel
  await tester.pump(); // l'image qui applique le saut
}

/// Le démontage fait disparaître toutes les bulles : `VisibilityDetector` arme
/// alors un dernier lot de 500 ms, qu'il faut laisser partir.
Future<void> _demonter(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  testWidgets('sans saut : ce qui est en bas est lu dès la vue posée, sans attendre 500 ms',
      (tester) async {
    final releve = ReleveALEcran(seuil: 0.6);
    await _monter(tester, releve);

    Set<String>? luALaPose;
    releve.poser(() => luALaPose = releve.visibles.map((m) => m.id).toSet(), monte: () => true);
    await tester.pump();

    expect(luALaPose, _attendus(0), reason: 'la lecture doit partir dans l\'image, pas au lot suivant');
    expect(releve.vuePosee, isTrue);
    await _demonter(tester);
  });

  testWidgets('saut AVANT le premier lot : les bulles du bas n\'ont jamais compté', (tester) async {
    final releve = ReleveALEcran(seuil: 0.6);
    final defilement = await _monter(tester, releve);
    expect(releve.visibles, isEmpty, reason: 'aucun lot n\'est encore parti');

    const decalage = 30 * _hauteur;
    Set<String>? lu;
    await _sauterPuisPoser(tester, defilement, releve, decalage,
        () => lu = releve.visibles.map((m) => m.id).toSet());

    expect(lu, _attendus(decalage));
    expect(lu!.intersection(_attendus(0)), isEmpty);
    await _demonter(tester);
  });

  testWidgets('saut APRÈS le premier lot : la disparition des bulles du bas est bien rapportée',
      (tester) async {
    final releve = ReleveALEcran(seuil: 0.6);
    final defilement = await _monter(tester, releve);

    // Le relevé serveur a pris plus de 500 ms : les bulles du bas ont été
    // rapportées visibles avant que la vue ne saute.
    await tester.pump(const Duration(milliseconds: 600));
    expect(releve.visibles.map((m) => m.id).toSet(), _attendus(0));

    const decalage = 30 * _hauteur;
    Set<String>? lu;
    await _sauterPuisPoser(tester, defilement, releve, decalage,
        () => lu = releve.visibles.map((m) => m.id).toSet());

    expect(lu, _attendus(decalage), reason: 'des bulles plus à l\'écran seraient marquées lues');
    await _demonter(tester);
  });

  testWidgets('la lecture ne part qu\'une fois, même si la vue est posée deux fois', (tester) async {
    // Le filet de 6 s et le vrai placement peuvent tous deux appeler `poser`.
    final releve = ReleveALEcran(seuil: 0.6);
    await _monter(tester, releve);

    var lectures = 0;
    releve.poser(() => lectures++, monte: () => true);
    releve.poser(() => lectures++, monte: () => true);
    await tester.pump();
    releve.poser(() => lectures++, monte: () => true);
    await tester.pump();

    expect(lectures, 1);
    await _demonter(tester);
  });

  testWidgets('écran fermé avant l\'image : rien n\'est lu', (tester) async {
    final releve = ReleveALEcran(seuil: 0.6);
    await _monter(tester, releve);

    var lectures = 0;
    releve.poser(() => lectures++, monte: () => false);
    await tester.pump();

    expect(lectures, 0);
    expect(releve.vuePosee, isFalse);
    await _demonter(tester);
  });

  group('plusRecentALire', () {
    final quand = DateTime.utc(2026, 9, 16, 12);
    MessageEntity m(String id, String qui, int minutes, {MessageType type = MessageType.text}) =>
        MessageEntity(
          id: id,
          senderId: qui,
          senderName: qui,
          content: id,
          type: type,
          status: MessageStatus.sent,
          createdAt: quand.add(Duration(minutes: minutes)),
        );

    test('une seule cible pour tout l\'écran : la plus récente d\'autrui', () {
      // Le serveur marque « jusqu'à » : une écriture suffit, en groupe aussi.
      final cible = plusRecentALire([m('a', 'x', 1), m('c', 'y', 3), m('b', 'x', 2)], moi: 'moi');
      expect(cible?.id, 'c');
    });

    test('mes messages et les repères système ne portent pas le curseur', () {
      final cible = plusRecentALire(
        [m('a', 'x', 1), m('mien', 'moi', 5), m('sys', 'system', 6, type: MessageType.system)],
        moi: 'moi',
      );
      expect(cible?.id, 'a');
    });

    test('le curseur ne recule pas', () {
      expect(plusRecentALire([m('a', 'x', 1)], moi: 'moi', dejaVu: quand.add(const Duration(minutes: 1))), isNull);
      expect(plusRecentALire([m('b', 'x', 2)], moi: 'moi', dejaVu: quand.add(const Duration(minutes: 1)))?.id, 'b');
    });

    test('compte inconnu : rien, plutôt que de lire jusqu\'à l\'un de mes messages', () {
      expect(plusRecentALire([m('a', 'x', 1)], moi: null), isNull);
    });

    test('rien à l\'écran : rien à lire', () {
      expect(plusRecentALire(const [], moi: 'moi'), isNull);
    });
  });
}
