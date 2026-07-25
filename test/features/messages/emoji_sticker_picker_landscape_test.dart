import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/gifs/data/datasources/gif_remote_datasource.dart';
import 'package:diaspo_niger/features/gifs/data/repositories/gif_repository.dart';
import 'package:diaspo_niger/features/gifs/domain/entities/gif_entity.dart';
import 'package:diaspo_niger/features/gifs/presentation/providers/gif_provider.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/emoji_sticker_picker.dart';
import 'package:diaspo_niger/features/stickers/domain/entities/sticker_pack_entity.dart';
import 'package:diaspo_niger/features/stickers/presentation/providers/sticker_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

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

void main() {
  for (final height in [160.0, 200.0, 260.0]) {
    testWidgets('EmojiStickerPicker ne déborde pas en paysage (h=$height)',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gifRepositoryProvider.overrideWithValue(_FakeGifRepository()),
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
              body: Align(
                alignment: Alignment.bottomCenter,
                child: EmojiStickerPicker(
                  height: height,
                  onEmojiSelected: (_, __) {},
                  onGifSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull, reason: 'overflow onglet Emojis');

      await tester.tap(find.byIcon(Icons.gif_box_outlined));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'overflow onglet GIFs');
    });
  }
}
