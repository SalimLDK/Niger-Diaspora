import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/features/profile/presentation/widgets/qr_scanner_control_bar.dart';

/// La barre du scanner est passée de deux à trois boutons, le troisième étant
/// « Mon QR Code » — de loin le libellé le plus long des trois.
///
/// L'ancienne forme mettait l'icône **à côté** du label, chaque bouton avec
/// 24 dp de padding de chaque côté et aucune flexibilité. Sur un écran de
/// 360 dp, la rangée disposait de 312 dp utiles et en réclamait ~425 : le
/// troisième bouton la faisait déborder à la police par défaut, avant même
/// l'échelle de police des réglages système.
///
/// Ce banc verrouille le correctif structurel — icône au-dessus du label,
/// tuiles `Expanded`, label replié sur deux lignes — aux échelles relevées sur
/// les appareils du projet (1,0 / 1,1 / 1,3).
///
/// Les largeurs de texte ne sont pas asserties en dp : la police des tests rend
/// un carré de `fontSize` par caractère, sans rapport avec la police réelle.
/// Ce qui est mesuré est ce qui échouait — le débordement lui-même.
void main() {
  Widget harness({
    required double width,
    required double textScale,
    bool flashOn = false,
  }) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: QrScannerControlBar(
                  flashOn: flashOn,
                  onToggleFlash: () {},
                  onSwitchCamera: () {},
                  onShowMyQrCode: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `FlutterError.onError` est détourné plutôt que `takeException()` : un
  /// débordement de layout est signalé pendant la passe de rendu, et un
  /// `expect` qui le laisse remonter fige le test au lieu de l'échouer.
  List<String> collectErrors(WidgetTester tester) {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    addTearDown(() => FlutterError.onError = previous);
    return errors;
  }

  group('barre de contrôles du scanner QR', () {
    for (final scale in <double>[1.0, 1.1, 1.3]) {
      testWidgets(
        'ne déborde pas sur un écran de 360 dp à une échelle de $scale',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final errors = collectErrors(tester);
          await tester.pumpWidget(
            harness(width: 360, textScale: scale),
          );
          await tester.pump();

          expect(
            errors.where((e) => e.contains('overflowed')),
            isEmpty,
            reason: 'la rangée à trois boutons déborde à une échelle de $scale',
          );
        },
      );
    }

    testWidgets('affiche les trois commandes, dont « Mon QR Code »', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(width: 360, textScale: 1.0));
      await tester.pump();

      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Changer'), findsOneWidget);
      expect(find.text('Mon QR Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_rounded), findsOneWidget);
    });

    testWidgets('« Mon QR Code » notifie son appelant', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QrScannerControlBar(
              flashOn: false,
              onToggleFlash: () {},
              onSwitchCamera: () {},
              onShowMyQrCode: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mon QR Code'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('les trois tuiles se partagent la largeur à parts égales', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(width: 360, textScale: 1.0));
      await tester.pump();

      final largeurs =
          tester
              .widgetList<InkWell>(find.byType(InkWell))
              .map((w) => tester.getSize(find.byWidget(w)).width)
              .toList();

      expect(largeurs, hasLength(3));
      // 360 − 32 de padding − 2 écarts de 10 = 308, réparti en trois.
      for (final largeur in largeurs) {
        expect(largeur, closeTo(308 / 3, 0.5));
      }
    });
  });
}
