import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/embassies/domain/entities/embassy_entity.dart';
import 'package:diaspo_niger/features/embassies/domain/repositories/embassies_repository.dart';
import 'package:diaspo_niger/features/embassies/presentation/providers/embassies_provider.dart';
import 'package:diaspo_niger/features/embassies/presentation/screens/embassy_detail_route.dart';
import 'package:diaspo_niger/features/embassies/presentation/screens/embassy_detail_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// La fiche d'un poste atteinte **sans** l'entité en main.
///
/// `state.extra` est nul par construction sur un lien profond
/// (`diasponiger:///embassies/<id>`) et sur une notification — et il l'était
/// aussi depuis la carte, dont le bouton poussait la route sans objet. La
/// route terminait par `EmbassyDetailScreen(embassy: embassy!)`, un `!` sur
/// la valeur qu'elle venait de tester nulle : écran rouge « Null check
/// operator used on a null value », reproduit sur SM A515F le 2026-09-08.
///
/// Ce que les trois cas ci-dessous tiennent :
/// - l'identifiant seul suffit à afficher la fiche ;
/// - une fiche hors de la juridiction de l'usager s'affiche quand même par
///   lien direct (un consulat partagé n'est pas forcément le sien) ;
/// - une fiche absente donne un état nommé **avec une sortie**, jamais une
///   exception.
void main() {
  const embassy = EmbassyEntity(
    id: 'aa643d7b-373a-47a5-bc94-c33545a43cad',
    name: 'Ambassade du Niger',
    country: 'France',
    city: 'Paris',
    address: '154 rue de Longchamp',
    isVerified: true,
  );

  Widget boot({
    required List<EmbassyEntity> visibles,
    required EmbassiesRepository depot,
  }) {
    final router = GoRouter(
      initialLocation: '/embassies/${embassy.id}',
      routes: [
        GoRoute(
          path: '/embassies',
          builder: (_, __) => const Scaffold(body: Text('annuaire')),
        ),
        GoRoute(
          path: '/embassies/:id',
          builder:
              (context, state) =>
                  EmbassyDetailRoute(embassyId: state.pathParameters['id']!),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        embassiesListProvider.overrideWith((ref) async => visibles),
        embassiesRepositoryProvider.overrideWithValue(depot),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        routerConfig: router,
      ),
    );
  }

  testWidgets('Lien profond : l\'identifiant seul affiche la fiche', (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(visibles: const [embassy], depot: _DepotVide()),
    );
    await tester.pumpAndSettle();

    // Le test de fond : plus aucune exception là où le `!` en levait une.
    expect(tester.takeException(), isNull);
    expect(find.byType(EmbassyDetailScreen), findsOneWidget);
    expect(find.text('Ambassade du Niger'), findsWidgets);
  });

  testWidgets('Hors juridiction : la fiche reste ouvrable par lien direct', (
    tester,
  ) async {
    // La liste est vide pour cet usager — le filtre de juridiction l'a
    // écartée — mais le dépôt, lui, ne filtre pas. Un consulat partagé à
    // quelqu'un qui vit ailleurs doit s'ouvrir.
    await tester.pumpWidget(
      boot(visibles: const [], depot: _DepotAvec(embassy)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(EmbassyDetailScreen), findsOneWidget);
  });

  testWidgets(
    'Reseau muet : « chargement impossible », jamais « introuvable »',
    (tester) async {
      // Hors ligne derriere un VPN, `networkInfo` se croit connecte et
      // l'appel Supabase n'a pas de delai de garde a lui : sans la borne du
      // provider, le rond de chargement tourne indefiniment. Observe sur
      // SM A515F le 2026-09-08.
      //
      // Ce qui compte ici n'est pas seulement de sortir de l'attente, c'est
      // d'en sortir en disant la verite : on ignore si la fiche existe, donc
      // « Fiche introuvable » serait une affirmation fausse.
      await tester.pumpWidget(
        boot(visibles: const [], depot: _DepotMuet()),
      );
      await tester.pump();

      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(find.text('Fiche introuvable'), findsNothing);
      expect(find.text("Retour à l'annuaire"), findsOneWidget);
    },
  );

  testWidgets('Fiche absente : un état nommé, et une sortie', (tester) async {
    await tester.pumpWidget(boot(visibles: const [], depot: _DepotVide()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(EmbassyDetailScreen), findsNothing);
    expect(find.text('Fiche introuvable'), findsOneWidget);

    // La sortie doit exister ET marcher : par lien profond il n'y a rien à
    // dépiler, donc la flèche implicite de Flutter ne s'affiche pas.
    final retour = find.text('Retour à l\'annuaire');
    expect(retour, findsOneWidget);
    await tester.tap(retour);
    await tester.pumpAndSettle();
    expect(find.text('annuaire'), findsOneWidget);
  });
}

/// Le reseau qui ne repond jamais : ni reponse, ni erreur.
class _DepotMuet extends _DepotBase {
  @override
  Future<EmbassyEntity?> getEmbassyById(String id) => Completer<EmbassyEntity?>().future;
}

class _DepotVide extends _DepotBase {
  @override
  Future<EmbassyEntity?> getEmbassyById(String id) async => null;
}

class _DepotAvec extends _DepotBase {
  _DepotAvec(this.fiche);
  final EmbassyEntity fiche;

  @override
  Future<EmbassyEntity?> getEmbassyById(String id) async =>
      fiche.id == id ? fiche : null;
}

/// Seul `getEmbassyById` est exercé ici ; le reste du contrat lève, pour que
/// tout appel imprévu se voie au lieu de passer pour un résultat vide.
abstract class _DepotBase implements EmbassiesRepository {
  @override
  Future<List<EmbassyEntity>> getEmbassies() => throw UnimplementedError();

  @override
  Future<List<EmbassyEntity>> searchEmbassies(String query) =>
      throw UnimplementedError();

  @override
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  }) => throw UnimplementedError();

  @override
  Future<String> createEmbassy(EmbassyEntity embassy) =>
      throw UnimplementedError();

  @override
  Future<DateTime?> cachedAt() => throw UnimplementedError();
}
