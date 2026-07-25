import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/gifs/data/datasources/gif_remote_datasource.dart';
import 'package:diaspo_niger/features/gifs/data/repositories/gif_repository.dart';
import 'package:diaspo_niger/features/gifs/domain/entities/gif_entity.dart';
import 'package:diaspo_niger/features/gifs/presentation/providers/gif_provider.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/gif_picker_content.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class _FakeGifRepository implements GifRepository {
  final List<GifEntity> results;
  _FakeGifRepository(this.results);

  @override
  bool get isConfigured => true;

  @override
  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) async =>
      results;

  @override
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) async =>
      results;
}

GifEntity _gif(String id) => GifEntity(
      id: id,
      url: 'https://example.test/$id.gif',
      previewUrl: 'https://example.test/$id-small.gif',
      provider: GifProvider.giphy,
    );

void main() {
  // Reproduit l'overflow signalé en paysage : le picker reçoit une hauteur
  // réduite et une largeur large. Aucune RenderFlex ne doit exploser.
  for (final height in [160.0, 200.0, 260.0]) {
    testWidgets('GifPickerContent ne déborde pas en paysage (h=$height)',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 720);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gifRepositoryProvider.overrideWithValue(
              _FakeGifRepository([for (var i = 0; i < 12; i++) _gif('g$i')]),
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
                child: SizedBox(
                  height: height,
                  child: GifPickerContent(onGifSelected: (_) {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
