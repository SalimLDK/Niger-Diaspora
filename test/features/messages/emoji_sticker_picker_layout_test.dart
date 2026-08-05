import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/gifs/data/datasources/gif_remote_datasource.dart';
import 'package:diaspo_niger/features/gifs/data/repositories/gif_repository.dart';
import 'package:diaspo_niger/features/gifs/domain/entities/gif_entity.dart';
import 'package:diaspo_niger/features/gifs/presentation/providers/gif_provider.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/emoji_sticker_picker.dart';
import 'package:diaspo_niger/features/stickers/domain/entities/sticker_entity.dart';
import 'package:diaspo_niger/features/stickers/domain/entities/sticker_pack_entity.dart';
import 'package:diaspo_niger/features/stickers/presentation/providers/sticker_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Fiche 26b : onglets en pilules **Stickers · GIF · Émojis** suivis d'une
/// loupe, sections à en-tête au lieu de sous-onglets iconiques, grille de
/// vignettes, et la note « téléchargés une fois » en pied.

class _FakeGifRepository implements GifRepository {
  @override
  bool get isConfigured => true;
  @override
  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) async =>
      const [];
  @override
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) async =>
      const [];
}

/// Des URL vides : `CachedNetworkImage` n'atteint jamais le réseau et tombe
/// sur son `errorWidget`. C'est la géométrie des tuiles qu'on mesure, pas les
/// images.
StickerEntity _sticker(String id, {String pack = 'pack-sahel'}) =>
    StickerEntity(id: id, packId: pack, url: '', emoji: '🙂');

final _pack = StickerPackEntity(
  id: 'pack-sahel',
  name: 'Pack Sahel',
  thumbnailUrl: '',
  creatorId: 'salim',
  stickers: List.generate(6, (i) => _sticker('s$i')),
  createdAt: DateTime(2026, 8, 5),
);

Future<void> _pump(
  WidgetTester tester, {
  double height = 300,
  List<StickerPackEntity> packs = const [],
  List<StickerEntity> recents = const [],
  List<StickerEntity> favoris = const [],
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gifRepositoryProvider.overrideWithValue(_FakeGifRepository()),
        allUserPacksProvider.overrideWithValue(
          AsyncValue<List<StickerPackEntity>>.data(packs),
        ),
        recentStickersProvider.overrideWith((ref) => Stream.value(recents)),
        favoriteStickersProvider.overrideWith((ref) => Stream.value(favoris)),
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
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: EmojiStickerPicker(
              height: height,
              onEmojiSelected: (_, __) {},
              onGifSelected: (_) {},
              onStickerSelected: (_) {},
              initialTab: MessagePickerTab.stickers,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('les onglets suivent l\'ordre de la fiche, loupe à droite', (
    tester,
  ) async {
    await _pump(tester, packs: [_pack]);

    final stickers = tester.getCenter(find.text('Stickers')).dx;
    final gif = tester.getCenter(find.text('GIF')).dx;
    final emojis = tester.getCenter(find.text('Émojis')).dx;
    final loupe = tester.getCenter(find.byIcon(Icons.search)).dx;

    expect(stickers, lessThan(gif));
    expect(gif, lessThan(emojis));
    expect(loupe, greaterThan(emojis));
  });

  testWidgets('sans pack, l\'onglet Stickers n\'est pas proposé', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Stickers'), findsNothing);
    expect(find.text('GIF'), findsOneWidget);
    expect(find.text('Émojis'), findsOneWidget);
  });

  testWidgets('les sections remplacent les sous-onglets iconiques', (
    tester,
  ) async {
    await _pump(
      tester,
      packs: [_pack],
      recents: [_sticker('r0'), _sticker('r1')],
      favoris: [_sticker('f0')],
    );

    // DesignSectionLabel met en capitales.
    final recents = tester.getRect(find.text('RÉCEMMENT UTILISÉS'));
    final favoris = tester.getRect(find.text('FAVORIS'));
    expect(recents.top, lessThan(favoris.top));

    // Le pack vient après, hors du premier écran : c'est un défilement unique,
    // plus trois barres d'onglets superposées.
    await tester.scrollUntilVisible(
      find.text('PACK SAHEL'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('PACK SAHEL'), findsOneWidget);
  });

  testWidgets('la grille tient 4 colonnes à la largeur de référence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester, packs: [_pack]);

    // 6 stickers dans le pack : les 4 premiers sur une ligne, le 5e dessous.
    final tuiles = find.byType(CachedNetworkImage);
    expect(tuiles, findsNWidgets(6));

    final r0 = tester.getRect(tuiles.at(0));
    final r3 = tester.getRect(tuiles.at(3));
    final r4 = tester.getRect(tuiles.at(4));

    expect(r0.top, equals(r3.top), reason: '4 tuiles sur la première ligne');
    expect(r4.top, greaterThan(r0.top), reason: 'la 5e passe à la ligne');
  });

  testWidgets('la note « données réduites » est en pied, hors onglet Émojis', (
    tester,
  ) async {
    await _pump(tester, packs: [_pack]);

    final note = find.textContaining('téléchargés une fois');
    expect(note, findsOneWidget);

    // Elle est bien SOUS la grille, pas en tête comme avant.
    final onglets = tester.getRect(find.text('Stickers'));
    expect(tester.getRect(note).top, greaterThan(onglets.bottom));

    await tester.tap(find.text('Émojis'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('téléchargés une fois'), findsNothing);
  });

  testWidgets('en chrome resserré, la note disparaît partout', (tester) async {
    await _pump(tester, height: 160, packs: [_pack]);

    expect(find.textContaining('téléchargés une fois'), findsNothing);
  });

  testWidgets('la loupe filtre les stickers sur place', (tester) async {
    await _pump(tester, packs: [_pack]);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PACK SAHEL'), findsNothing);
    expect(find.textContaining('Aucun résultat'), findsOneWidget);
  });

  testWidgets('le panneau se construit en nocturne', (tester) async {
    await _pump(tester, packs: [_pack], theme: ThemeData.dark());

    expect(tester.takeException(), isNull);
    expect(find.text('Stickers'), findsOneWidget);
  });
}
