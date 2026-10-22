import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/groups/domain/entities/group_entity.dart';
import 'package:diaspo_niger/features/groups/domain/repositories/group_repository.dart';
import 'package:diaspo_niger/features/groups/presentation/providers/group_provider.dart';
import 'package:diaspo_niger/features/groups/presentation/screens/create_group_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Crashlytics 1.2.2 (31) : « Bad state: Cannot use "ref" after the widget was
/// disposed » dans `_createGroup`. Quitter l'écran pendant l'envoi de la photo
/// du groupe tuait l'app : `ref.read(...)` venait après l'`await` de l'envoi.
class _FauxDepot implements GroupRepository {
  final List<GroupEntity> crees = [];

  @override
  Future<Either<Failure, List<GroupEntity>>> getMyGroups(String userId) async =>
      const Right([]);

  @override
  Stream<void> watchMyMemberships(String userId) => const Stream.empty();

  @override
  Future<Either<Failure, GroupEntity>> createGroup(GroupEntity group) async {
    crees.add(group);
    return Right(group);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} hors du banc');
}

void main() {
  const moi = UserEntity(id: 'alice', email: 'alice@example.com');

  testWidgets(
    "quitter l'écran pendant l'envoi de la photo ne plante pas, et le groupe "
    'est créé quand même',
    (tester) async {
      final depot = _FauxDepot();
      final envoi = Completer<String?>();
      // PNG 1×1 : l'écran affiche la photo choisie.
      final photo = File('${Directory.systemTemp.path}/photo_groupe_test.png')
        ..writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        ));
      addTearDown(() {
        try {
          photo.deleteSync();
        } on FileSystemException {
          // Encore tenue par le décodeur d image : le dossier temporaire la purgera.
        }
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserAsyncProvider.overrideWith((ref) => Stream.value(moi)),
            currentUserProvider.overrideWith((ref) => Stream.value(moi)),
            groupRepositoryProvider.overrideWithValue(depot),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fr'),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateGroupScreen(
                          initialName: 'Niamey Paris',
                          imageInitiale: photo,
                          envoyerImage: (_, __) => envoi.future,
                        ),
                      ),
                    ),
                    child: const Text('ouvrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.tap(find.text('ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // En production « Mes groupes » vit déjà (liste de l'onglet Groupes) :
      // on le laisse se construire et se stabiliser avant de créer.
      ProviderScope.containerOf(tester.element(find.byType(CreateGroupScreen)))
          .read(myGroupsNotifierProvider);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      // Le nom est pré-rempli ; la description est obligatoire.
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Les Nigériens de Paris',
      );
      // « Créer » : l'ElevatedButton en bas du formulaire.
      final bouton = find.byType(ElevatedButton);
      await tester.dragUntilVisible(
        bouton,
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await tester.tap(bouton);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pump();

      // L'envoi est en cours : on quitte l'écran.
      expect(find.byType(CreateGroupScreen), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CreateGroupScreen), findsNothing);

      // L'envoi se termine, écran détruit. Une erreur asynchrone non gérée
      // (le « Bad state » d'avant) ferait échouer le test d'elle-même.
      envoi.complete('https://exemple.test/photo.jpg');
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(depot.crees, hasLength(1));
      expect(depot.crees.single.imageUrl, 'https://exemple.test/photo.jpg');
    },
  );
}
