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
}

PollEntity _sondage({
  List<String> votedOptionIds = const [],
  DateTime? endsAt,
  bool isAnonymous = false,
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
    endsAt: endsAt,
    votedOptionIds: votedOptionIds,
  );
}

Future<_ActionsEspion> _pump(WidgetTester tester, PollEntity poll) async {
  final actions = _ActionsEspion();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pollActionsNotifierProvider.overrideWith(() => actions),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PollCard(poll: poll)),
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
