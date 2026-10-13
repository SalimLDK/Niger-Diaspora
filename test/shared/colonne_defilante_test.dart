import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/businesses/domain/entities/business_entity.dart';
import 'package:diaspo_niger/features/businesses/presentation/providers/business_provider.dart';
import 'package:diaspo_niger/features/businesses/presentation/screens/create_business_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/colonne_defilante.dart';

/// Ce que le dépôt laisse passer : il n'attrape que `ServerException`, et
/// une `PostgrestException` (contrainte 23514 ici) remonte telle quelle
/// jusqu'à l'écran.
class _NotifierQuiLeve extends MyBusinessNotifier {
  @override
  AsyncValue<BusinessEntity?> build() => const AsyncValue.data(null);

  @override
  Future<bool> createBusiness(BusinessEntity business) async {
    throw const PostgrestException(
      message: 'new row for relation "businesses" violates check constraint '
          '"businesses_description_non_vide"',
      code: '23514',
    );
  }
}

/// Un champ obligatoire défilé hors écran ne doit pas échapper à `validate()`.
///
/// Le 2026-10-11, deux usagers ont envoyé onze fois une entreprise sans
/// description (contrainte `businesses_description_non_vide`, fiche
/// Crashlytics « PostgrestBuilder._parseResponse »), alors que le champ porte
/// un validateur depuis le 2026-07-20. Le `Form` avait pour enfant un
/// `ListView` : un `TextFormField` défilé au-delà de la fenêtre et de
/// `cacheExtent` est démonté, se désinscrit du `Form`, et `validate()` ne le
/// regarde plus — le `TextEditingController`, lui, garde le texte vide qui
/// part à la base. Treize écrans partageaient cette structure.
///
/// Trois niveaux :
/// 1. le mécanisme, avec un témoin qui reproduit le défaut sous `ListView` —
///    si ce témoin échoue un jour, c'est que Flutter a changé et que
///    `ColonneDefilante` n'a plus de raison d'être ;
/// 2. l'écran réel « Créer une entreprise », dans une fenêtre courte ;
/// 3. la structure : aucun `Form` du projet ne repose sur une liste paresseuse.
void main() {
  /// Fenêtre de 360 × 480 logiques : bien moins que les formulaires, pour que
  /// le bas de page soit à plus de `cacheExtent` (250 px) du champ visé.
  void fenetreCourte(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1440);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('mécanisme', () {
    const messageRequis = 'Champ requis';

    /// Un formulaire dont le seul champ est à 3 000 px du haut.
    Widget formulaire(
      GlobalKey<FormState> cle,
      Widget Function(List<Widget> enfants) corps,
    ) {
      return MaterialApp(
        home: Scaffold(
          body: Form(
            key: cle,
            child: corps([
              const SizedBox(height: 3000),
              TextFormField(
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? messageRequis : null,
              ),
            ]),
          ),
        ),
      );
    }

    testWidgets('témoin : sous ListView, validate() ignore le champ hors écran',
        (tester) async {
      fenetreCourte(tester);
      final cle = GlobalKey<FormState>();
      await tester.pumpWidget(
        formulaire(cle, (enfants) => ListView(children: enfants)),
      );

      // Le champ n'est même pas construit : rien à valider.
      expect(find.byType(TextFormField), findsNothing);
      expect(
        cle.currentState!.validate(),
        isTrue,
        reason: 'Le défaut reproduit ici est la raison d\'être de '
            'ColonneDefilante. S\'il ne se reproduit plus, Flutter a changé : '
            'relire colonne_defilante.dart avant de toucher à ce témoin.',
      );
    });

    testWidgets('sous ColonneDefilante, validate() refuse le champ vide hors écran',
        (tester) async {
      fenetreCourte(tester);
      final cle = GlobalKey<FormState>();
      await tester.pumpWidget(
        formulaire(cle, (enfants) => ColonneDefilante(children: enfants)),
      );

      expect(find.byType(TextFormField, skipOffstage: false), findsOneWidget);
      expect(cle.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text(messageRequis, skipOffstage: false), findsOneWidget);
    });

    testWidgets('les enfants gardent toute la largeur, comme sous ListView',
        (tester) async {
      // Un `ListView` serre ses enfants en largeur ; une `Column` nue les
      // centrerait, et un bouton pleine largeur rétrécirait à son libellé.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColonneDefilante(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('OK')),
              ],
            ),
          ),
        ),
      );
      final fenetre = tester.getSize(find.byType(Scaffold)).width;
      expect(tester.getSize(find.byType(ElevatedButton)).width, fenetre - 32);
    });
  });

  group('Créer une entreprise', () {
    Future<void> monter(WidgetTester tester, List<Override> overrides) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fr'),
            home: const CreateBusinessScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    final bouton = find.widgetWithText(ElevatedButton, 'Créer l\'entreprise');

    testWidgets('refuse la soumission quand la description, hors écran, est vide',
        (tester) async {
      fenetreCourte(tester);
      await monter(tester, [
        // Lu par `_submit` seulement si la validation passe — c'est-à-dire
        // sur l'ancienne structure. Un usager nul le fait sortir proprement :
        // le test échoue alors sur le message absent, pas sur `[core/no-app]`.
        currentUserAsyncProvider.overrideWith((ref) => Stream.value(null)),
      ]);

      // Le nom, obligatoire lui aussi, est rempli : seule la description
      // manque. Même parcours que l'usager du 11/10, nom tapé puis défilement
      // jusqu'au bouton.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom de l\'entreprise *'),
        'Boulangerie du Sahel',
      );

      // Le premier Scrollable sous le Form est celui du formulaire ; la bande
      // de photos, horizontale, est plus profonde dans l'arbre.
      final defilable = find
          .descendant(of: find.byType(Form), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(bouton, 300, scrollable: defilable);

      await tester.tap(bouton);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text('La description est requise', skipOffstage: false),
        findsOneWidget,
        reason: 'La validation a laissé passer une description vide : le '
            'champ, hors écran, n\'était plus inscrit au Form. (Sur l\'ancienne '
            'structure, le champ n\'est même plus dans l\'arbre.)',
      );
      expect(find.text('Le nom est requis', skipOffstage: false), findsNothing);

      // Le cas a bien porté sur un champ hors écran, au-delà du cacheExtent
      // (250 px) : rien n'a défilé depuis le tap.
      final description = find.widgetWithText(
        TextFormField,
        'Description *',
        skipOffstage: false,
      );
      expect(tester.getRect(description).bottom, lessThan(-250));
    });

    testWidgets('dit à l\'usager quand l\'écriture lève, et rend le bouton',
        (tester) async {
      // Avant le 2026-10-13, `_submit` était un `try … finally` sans `catch` :
      // l'exception traversait, aucun message, `_isLoading` retombait et
      // l'usager retapait — six fois en 23 s pour l'un des deux du 11/10.
      await monter(tester, [
        currentUserAsyncProvider.overrideWith(
          (ref) => Stream.value(const UserEntity(id: 'u-test')),
        ),
        myBusinessNotifierProvider.overrideWith(_NotifierQuiLeve.new),
      ]);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom de l\'entreprise *'),
        'Boulangerie du Sahel',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description *'),
        'Pain frais',
      );
      await tester.ensureVisible(bouton);
      await tester.tap(bouton);
      // Deux tours : la session (Stream), puis l'écriture qui lève.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Erreur lors de la création'),
        findsOneWidget,
        reason: 'L\'écriture a levé sans que l\'écran le dise.',
      );
      expect(
        tester.widget<ElevatedButton>(bouton).onPressed,
        isNotNull,
        reason: 'Le bouton doit redevenir actif après l\'échec.',
      );
    });
  });

  test('aucun Form du projet ne pose ses champs dans une liste paresseuse', () {
    // `Form(key: …, child: ListView(` — la forme exacte des treize écrans
    // corrigés — et `SliverChildListDelegate`, le même défaut sous un
    // `CustomScrollView` (édition du profil).
    final listeSousForm = RegExp(
      r'Form\(\s*key:\s*[\w.]+,(?:\s*\w+:\s*[^,]+,)*\s*child:\s*ListView',
    );
    final coupables = <String>[];

    for (final fichier in Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = fichier.readAsStringSync();
      if (!source.contains('GlobalKey<FormState>')) continue;
      if (listeSousForm.hasMatch(source) ||
          source.contains('SliverChildListDelegate(')) {
        coupables.add(fichier.path);
      }
    }

    expect(
      coupables,
      isEmpty,
      reason: 'Ces écrans posent un Form sur une liste paresseuse : un champ '
          'obligatoire défilé hors écran est démonté et validate() ne le voit '
          'plus. Utilisez ColonneDefilante (lib/shared/widgets), ou '
          'SliverToBoxAdapter + Column sous un CustomScrollView.',
    );
  });
}
