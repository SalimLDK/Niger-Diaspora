import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/polls/data/datasources/poll_remote_datasource.dart';
import 'package:diaspo_niger/features/polls/data/models/poll_model.dart';
import 'package:diaspo_niger/features/polls/data/repositories/poll_repository_impl.dart';
import 'package:diaspo_niger/features/polls/domain/entities/poll_entity.dart';
import 'package:diaspo_niger/features/polls/presentation/providers/poll_provider.dart';
import 'package:diaspo_niger/features/polls/presentation/widgets/poll_card.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Le flux du sondage (`.stream()`) ne sait ni joindre ni lire une autre
/// table. Il rendait donc un sondage « jamais vote » a tout le monde : la
/// bulle d'une discussion restait en mode vote apres le vote, sans
/// pourcentages, et le badge « Votre choix » de l'ecran de resultats ne
/// s'affichait jamais. D'ou ces tests : le lecteur doit arriver jusqu'au
/// flux, et la carte doit basculer des qu'il a vote.
void main() {
  group('le lecteur descend jusqu au flux', () {
    test('getPollStream transmet currentUserId a la source', () {
      final source = _SourceEspion();
      PollRepositoryImpl(remoteDataSource: source)
          .getPollStream('p1', currentUserId: 'u1');

      expect(source.dernierUtilisateurDuFlux, 'u1');
    });

    test('une panne de lecture est publiee, pas avalee', () async {
      final source = _SourceEspion(fluxEnErreur: true);
      final emissions = await PollRepositoryImpl(remoteDataSource: source)
          .getPollStream('p1')
          .take(1)
          .toList();

      // `handleError` qui retournait une valeur ne publiait rien : l'ecran de
      // resultats tournait indefiniment sur son indicateur de chargement.
      expect(emissions.single.isLeft(), isTrue);
    });

    test('les votants sont rendus par option', () async {
      final source = _SourceEspion();
      final result = await PollRepositoryImpl(remoteDataSource: source)
          .getPollVoters('p1');

      final parOption = result.getOrElse(() => {});
      expect(parOption['o1']!.single.userId, 'u2');
      expect(parOption['o1']!.single.name, 'Aïcha');
      expect(parOption['o2'], isNull);
    });
  });

  group('carte de sondage', () {
    testWidgets('deja vote : resultats, et une porte pour se corriger',
        (tester) async {
      await _pump(tester, _sondage(votedOptionIds: ['o1']));

      expect(find.text('67%'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      expect(find.text('Modifier mon vote'), findsOneWidget);
    });

    testWidgets('pas encore vote : des cases, pas de pourcentages',
        (tester) async {
      await _pump(tester, _sondage());

      expect(find.text('67%'), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
      expect(find.text('Modifier mon vote'), findsNothing);
    });

    testWidgets('termine : ni vote ni correction possibles', (tester) async {
      await _pump(
        tester,
        _sondage(
          votedOptionIds: ['o1'],
          endsAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      expect(find.textContaining('Sondage terminé'), findsOneWidget);
      expect(find.text('Modifier mon vote'), findsNothing);
    });

    testWidgets('se corriger rouvre la selection sur son propre vote',
        (tester) async {
      final actions = await _pump(tester, _sondage(votedOptionIds: ['o1']));

      await tester.tap(find.text('Modifier mon vote'));
      await tester.pumpAndSettle();

      // Le choix en cours est repris : on voit ce qu'on change.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.text('Voter'), findsOneWidget);

      await tester.tap(find.text('Oui'));
      await tester.pumpAndSettle();

      // Tout deselectionner = retirer son vote, seul chemin vers la policy
      // « Users can retract their own vote ».
      expect(find.text('Retirer mon vote'), findsOneWidget);

      await tester.tap(find.text('Retirer mon vote'));
      await tester.pumpAndSettle();
      expect(actions.votes.single, isEmpty);
    });

    testWidgets('la regle de confidentialite se lit avant de voter',
        (tester) async {
      // Le choix est fait une fois pour toutes a la creation ; le votant doit
      // le savoir sous la question, pas sur l'ecran de resultats.
      await _pump(tester, _sondage());
      expect(find.text('Vote public : votre nom sera visible'), findsOneWidget);

      await _pump(tester, _sondage(isAnonymous: true));
      expect(find.text('Vote anonyme'), findsOneWidget);
      expect(find.text('Vote public : votre nom sera visible'), findsNothing);
    });

    testWidgets('deux actions : le compte garde sa ligne, elles prennent la leur',
        (tester) async {
      // Sur une bulle RECUE (320 dp, plus etroite qu'une bulle envoyee), les
      // deux boutons ne tiennent pas a cote du compte. Un `Wrap` unique les
      // empilait en laissant « N votes » centre entre les deux — vu sur
      // SM A515F le 2026-09-14.
      await _pump(tester, _sondage(votedOptionIds: ['o1']), largeur: 320);

      final compte = tester.getRect(find.text('3 votes'));
      final modifier = tester.getRect(find.text('Modifier mon vote'));
      final resultats = tester.getRect(find.text('Voir les résultats'));

      expect(compte.bottom, lessThanOrEqualTo(modifier.top));
      expect(compte.bottom, lessThanOrEqualTo(resultats.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('une seule action reste sur la ligne du compte', (tester) async {
      await _pump(tester, _sondage(), largeur: 320);

      final compte = tester.getRect(find.text('3 votes'));
      final action = tester.getRect(find.text('Voir les résultats'));
      expect(compte.top, lessThan(action.bottom));
      expect(action.top, lessThan(compte.bottom));
    });

    testWidgets('bulle etroite a grande echelle de police : rien ne deborde',
        (tester) async {
      await _pump(
        tester,
        _sondage(votedOptionIds: ['o1']),
        largeur: 320,
        echellePolice: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('la carte epouse les rayons que la bulle lui donne',
        (tester) async {
      // Sans ca, le coin de queue de la bulle (arrondi a 6) depassait de la
      // carte (arrondie a 16) : sur une bulle envoyee, un triangle vert.
      const rayon = BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(6),
      );
      await _pump(tester, _sondage(), rayon: rayon);

      final conteneur = tester.widget<Container>(
        find
            .descendant(of: find.byType(PollCard), matching: find.byType(Container))
            .first,
      );
      expect((conteneur.decoration as BoxDecoration).borderRadius, rayon);
    });

    testWidgets('changer d avis envoie la nouvelle option', (tester) async {
      final actions = await _pump(tester, _sondage(votedOptionIds: ['o1']));

      await tester.tap(find.text('Modifier mon vote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voter'));
      await tester.pumpAndSettle();

      expect(actions.votes.single, ['o2']);
    });
  });

  /// L'en-tete « auteur · il y a X ». Le libelle de temps y etait pose sans
  /// contrainte a cote d'un `Expanded` : il prenait sa largeur intrinseque,
  /// l'`Expanded` tombait a zero, et la rangee debordait. Aucun test ne
  /// couvrait ce coin — `_sondage()` ne portait pas de `createdAt`, donc le
  /// libelle ne s'affichait jamais ici ; l'echec est apparu ailleurs, dans
  /// `mode_selection_gestes_test.dart`.
  group('en-tete : anciennete', () {
    // 26 h : la forme longue est « il y a environ un jour », la plus longue
    // que `timeago` produise a cette echelle.
    final creeIlYA26h = DateTime.now().subtract(const Duration(hours: 26));

    /// ⚠ Ces bancs montent la carte en mode RESULTATS (`votedOptionIds`), et
    /// ce n'est pas un detail de confort : en mode vote, `_pied` n'a qu'une
    /// action et la pose sans contrainte a cote d'un `Expanded`, exactement
    /// le motif corrige ici dans l'en-tete. A 288 dp, « Voir les résultats »
    /// deborde alors de 22 px — defaut PREEXISTANT et independant, visible
    /// avec `createdAt` a null, donc sans le moindre libelle de temps.
    /// Consigne dans `TESTS_APPAREIL_A_FAIRE.md`. En mode resultats, `_pied`
    /// a deux actions et passe par sa branche `Column` + `Wrap`, qui elle
    /// est correcte : l'en-tete est donc seule en cause dans ce qui suit.
    PollEntity sondageDate() =>
        _sondage(votedOptionIds: ['o1'], createdAt: creeIlYA26h);

    testWidgets('bulle etroite : la forme compacte prend le relais',
        (tester) async {
      await _pump(tester, sondageDate(), largeur: 288);

      // « il y a environ un jour » mesure a lui seul 269,5 px dans la police
      // de test, contre 262 px laisses par l'icone et son espace : la rangee
      // debordait de 7,5 px.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('il y a'), findsNothing);
      expect(find.text('1 j'), findsOneWidget);
    });

    testWidgets('carte large : la forme longue est gardee', (tester) async {
      // Raccourcir partout serait une regression : la ou il y a la place, le
      // libelle en toutes lettres reste celui de la maquette.
      await _pump(tester, sondageDate());

      expect(find.textContaining('il y a environ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('le nom prend tout ce que le temps laisse', (tester) async {
      await _pump(tester, sondageDate(), largeur: 288);

      final nom = tester.getRect(find.text('Sim A'));
      final temps = tester.getRect(find.text('1 j'));

      // Le temps reste colle au bord interieur de la carte (padding 16)...
      expect(temps.right, moreOrLessEquals(288 - 16, epsilon: 0.5));
      // ...et le nom occupe tout l'espace jusqu'a lui, sans blanc entre les
      // deux.
      //
      // ⚠ C'est precisement ce que le correctif « evident » casserait :
      // passer le libelle de temps en `Flexible` a cote de l'`Expanded` du
      // nom supprime bien le debordement, mais `RenderFlex` cesse alors de
      // donner leur largeur intrinseque aux deux enfants — il partage
      // l'espace libre au prorata des flex. Le nom serait fige a la moitie
      // de la rangee et le temps flotterait au milieu, decolle du bord.
      expect(nom.right, moreOrLessEquals(temps.left, epsilon: 0.5));
    });

    testWidgets('la mesure tient compte du style herite', (tester) async {
      // ⚠ Banc de non-regression d'un defaut TROUVE SUR APPAREIL le
      // 2026-09-15 (SM A515F, `font_scale` 1.6) : la carte affichait
      // « il y a 11 heur... », tronque par le filet, au lieu de basculer sur
      // la forme compacte.
      //
      // Un `Text` fusionne le `DefaultTextStyle` ambiant avant de rendre.
      // Mesurer le libelle avec le seul `TextStyle(fontSize: 12)` revient
      // donc a le mesurer dans une AUTRE police que celle affichee — sur
      // l'appareil, la police par defaut de la plateforme au lieu d'Inter,
      // plus etroite : la mesure conclut que la forme longue tient, et le
      // rendu deborde.
      //
      // La police du banc etant unique, c'est l'INTERLETTRAGE qui joue ici le
      // role d'Inter : +3 px par glyphe, invisibles pour une mesure qui
      // ignore le style herite. Sans le `merge`, ce cas rend la forme longue
      // tronquee et « 11 h » est introuvable.
      await _pump(
        tester,
        _sondage(
          votedOptionIds: ['o1'],
          createdAt: DateTime.now().subtract(const Duration(hours: 11)),
        ),
        largeur: 500,
        interlettrage: 3,
      );

      expect(find.text('11 h'), findsOneWidget);
      expect(find.textContaining('il y a'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans interlettrage, la meme carte garde la forme longue',
        (tester) async {
      // Le temoin du cas precedent : a 500 dp, « il y a 11 heures » tient
      // largement. C'est bien le style herite qui fait basculer, pas la
      // largeur.
      await _pump(
        tester,
        _sondage(
          votedOptionIds: ['o1'],
          createdAt: DateTime.now().subtract(const Duration(hours: 11)),
        ),
        largeur: 500,
      );

      expect(find.text('il y a 11 heures'), findsOneWidget);
    });

    testWidgets('echelle de police 1.3 : rien ne deborde non plus',
        (tester) async {
      // Le facteur d'echelle vient des reglages de l'appareil : la meme
      // rangee deborde sur une carte plus large des que le texte grossit.
      // D'ou une mesure du libelle plutot qu'un simple seuil de largeur.
      await _pump(
        tester,
        sondageDate(),
        largeur: 320,
        echellePolice: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('1 j'), findsOneWidget);
    });
  });

}

PollEntity _sondage({
  List<String> votedOptionIds = const [],
  DateTime? endsAt,
  bool isAnonymous = false,
  DateTime? createdAt,
}) {
  return PollEntity(
    id: 'p1',
    contextType: PollContextType.conversation,
    contextId: 'c1',
    question: 'Qui vient samedi ?',
    options: const [
      PollOptionEntity(id: 'o1', label: 'Oui', voteCount: 2),
      PollOptionEntity(id: 'o2', label: 'Non', voteCount: 1),
    ],
    totalVotes: 3,
    isAnonymous: isAnonymous,
    createdBy: 'u1',
    createdByName: 'Sim A',
    createdAt: createdAt,
    endsAt: endsAt,
    votedOptionIds: votedOptionIds,
  );
}

Future<_ActionsEspion> _pump(
  WidgetTester tester,
  PollEntity poll, {
  double? largeur,
  double echellePolice = 1.0,
  BorderRadiusGeometry? rayon,
  double? interlettrage,
}) async {
  final actions = _ActionsEspion();
  Widget carte = PollCard(poll: poll, borderRadius: rayon);
  if (interlettrage != null) {
    // Tient lieu de la police du theme : un style ambiant que le `Text` du
    // libelle fusionne, et qu'une mesure naive ne verrait pas.
    carte = DefaultTextStyle.merge(
      style: TextStyle(letterSpacing: interlettrage),
      child: carte,
    );
  }
  if (largeur != null) {
    // La bulle de discussion contraint la carte a 320 dp.
    carte = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: largeur, child: carte),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pollActionsNotifierProvider.overrideWith(() => actions),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(echellePolice)),
          child: Scaffold(body: carte),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return actions;
}

class _ActionsEspion extends PollActionsNotifier {
  final List<List<String>> votes = [];

  @override
  Future<bool> vote(
    String pollId,
    List<String> optionIds, {
    String? groupId,
    String? postId,
  }) async {
    votes.add(optionIds);
    return true;
  }
}

class _SourceEspion implements PollRemoteDataSource {
  final bool fluxEnErreur;
  String? dernierUtilisateurDuFlux;

  _SourceEspion({this.fluxEnErreur = false});

  @override
  Stream<PollModel?> getPollStream(String pollId, {String? currentUserId}) {
    dernierUtilisateurDuFlux = currentUserId;
    if (fluxEnErreur) {
      return Stream<PollModel?>.error(Exception('lecture refusée'));
    }
    return const Stream<PollModel?>.empty();
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> getPollVoters(
    String pollId,
  ) async {
    return {
      'o1': [
        {'user_id': 'u2', 'display_name': 'Aïcha', 'avatar_url': null},
      ],
    };
  }

  @override
  Future<PollModel> createPoll({
    required String contextType,
    required String contextId,
    required String question,
    required List<String> optionLabels,
    required bool allowMultiple,
    required bool isAnonymous,
    DateTime? endsAt,
    String? userId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deletePoll(String pollId) => throw UnimplementedError();

  @override
  Future<PollModel> getPoll(String pollId, {String? currentUserId}) =>
      throw UnimplementedError();

  @override
  Future<List<PollModel>> getPollsByContext(
    String contextType,
    String contextId, {
    String? currentUserId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> vote(String pollId, List<String> optionIds, {String? userId}) =>
      throw UnimplementedError();
}
