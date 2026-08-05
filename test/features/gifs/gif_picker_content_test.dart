import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/gifs/data/datasources/gif_remote_datasource.dart';
import 'package:diaspo_niger/features/gifs/data/repositories/gif_repository.dart';
import 'package:diaspo_niger/features/gifs/domain/entities/gif_entity.dart';
import 'package:diaspo_niger/features/gifs/presentation/providers/gif_provider.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/emoji_sticker_picker.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/gif_picker_content.dart';
import 'package:diaspo_niger/features/stickers/domain/entities/sticker_pack_entity.dart';
import 'package:diaspo_niger/features/stickers/presentation/providers/sticker_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Repository de test : sans réseau, enregistre la dernière requête reçue.
class _FakeGifRepository implements GifRepository {
  final List<GifEntity> results;
  final bool configured;
  final Object? error;

  String? lastQuery;
  GifContentType? lastType;

  _FakeGifRepository({
    this.results = const [],
    this.configured = true,
    this.error,
  });

  @override
  bool get isConfigured => configured;

  @override
  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) =>
      search('', type: type, limit: limit);

  @override
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) async {
    lastQuery = query;
    lastType = type;
    if (error != null) throw error!;
    return results;
  }
}

GifEntity _gif(String id) => GifEntity(
      id: id,
      url: 'https://example.test/$id.gif',
      previewUrl: 'https://example.test/$id-small.gif',
      provider: GifProvider.giphy,
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeGifRepository repo, {
  void Function(GifEntity)? onSelected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gifRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: GifPickerContent(onGifSelected: onSelected ?? (_) {}),
        ),
      ),
    ),
  );
}

/// Monte la coque complète du picker sur l'onglet GIF : c'est elle qui porte la
/// loupe et le champ de recherche. Les packs de stickers sont neutralisés pour
/// ne pas partir en réseau (l'onglet Stickers reste alors masqué).
Future<void> _pumpShell(WidgetTester tester, _FakeGifRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gifRepositoryProvider.overrideWithValue(repo),
        allUserPacksProvider.overrideWithValue(
          const AsyncValue<List<StickerPackEntity>>.data([]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: EmojiStickerPicker(
            onEmojiSelected: (_, __) {},
            onGifSelected: (_) {},
            initialTab: MessagePickerTab.gif,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('GifPickerContent', () {
    testWidgets('affiche la grille des résultats', (tester) async {
      final repo = _FakeGifRepository(results: [_gif('a'), _gif('b')]);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(repo.lastQuery, '');
      expect(repo.lastType, GifContentType.gif);
    });

    testWidgets('sans clé API, informe au lieu de tenter le réseau',
        (tester) async {
      final repo = _FakeGifRepository(configured: false);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(
          find.text('Les GIFs ne sont pas encore configurés.'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(repo.lastQuery, isNull);
    });

    testWidgets('résultats vides -> message dédié', (tester) async {
      final repo = _FakeGifRepository(results: const []);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Aucun résultat.'), findsOneWidget);
    });

    testWidgets('erreur réseau -> message d\'erreur, pas de crash',
        (tester) async {
      final repo = _FakeGifRepository(error: Exception('boom'));
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('Impossible de charger les GIFs.'), findsOneWidget);
    });

    testWidgets('bascule Stickers -> demande le type sticker', (tester) async {
      final repo = _FakeGifRepository(results: [_gif('a')]);
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stickers'));
      await tester.pumpAndSettle();

      expect(repo.lastType, GifContentType.sticker);
    });

    testWidgets('taper un GIF le renvoie via onGifSelected', (tester) async {
      final repo = _FakeGifRepository(results: [_gif('a')]);
      GifEntity? selected;
      await _pump(tester, repo, onSelected: (g) => selected = g);
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(selected?.id, 'a');
    });
  });

  // La recherche n'est plus dans `GifPickerContent` : la fiche 26b l'a déplacée
  // dans la loupe de la coque (`EmojiStickerPicker`), qui publie la requête dans
  // `gifSearchQueryProvider`. On monte donc la coque pour couvrir le chemin
  // complet loupe -> champ -> provider -> repository.
  group('Recherche de GIFs depuis la coque', () {
    testWidgets('taper une recherche la transmet au repository',
        (tester) async {
      final repo = _FakeGifRepository(results: [_gif('a')]);
      await _pumpShell(tester, repo);
      await tester.pumpAndSettle();

      // Avant ouverture, la seule loupe de l'écran est celle de l'en-tête.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bonjour');
      // Le provider laisse la frappe se poser 350 ms avant de partir au réseau.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(repo.lastQuery, 'bonjour');
    });

    testWidgets('fermer la recherche revient aux tendances', (tester) async {
      final repo = _FakeGifRepository(results: [_gif('a')]);
      await _pumpShell(tester, repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bonjour');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(repo.lastQuery, '');
    });
  });
}
