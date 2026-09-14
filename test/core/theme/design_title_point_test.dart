import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';

/// Le point d'accent après chaque titre d'écran (2026-09-13).
///
/// Il n'existait que dans `DesignTitle` : le grand en-tête d'onglet, les
/// `AppBar` à `Text` nu et les en-têtes faits main ne l'avaient pas. Et même
/// `DesignTitle` le perdait dans une `AppBar`, qui impose `softWrap: false` +
/// ellipse à son titre : l'ellipse tombait avant le point.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  const accent = Color(0xFFC85A3A);

  Future<void> dansUneAppBar(
    WidgetTester tester,
    String titre, {
    double largeur = 360,
  }) async {
    tester.view.physicalSize = Size(largeur, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: accent)),
        home: Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: DesignTitle(titre, size: 22),
            actions: const [Icon(Icons.search), Icon(Icons.more_vert)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dans une AppBar, un titre trop long garde son point',
      (tester) async {
    const titre = 'Ambassades, consulats et représentations du Niger';
    await dansUneAppBar(tester, titre, largeur: 320);

    final point = find.text('.');
    expect(point, findsOneWidget);
    final barre = tester.getRect(find.byType(AppBar));
    final rect = tester.getRect(point);
    expect(rect.right, lessThanOrEqualTo(barre.right));
    expect(rect.width, greaterThan(0));
    // Le titre, lui, est bien tronqué : c'est le cas qui perdait le point.
    final texte = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(titre), matching: find.byType(RichText)),
    );
    expect(texte.didExceedMaxLines, isTrue);
  });

  testWidgets('dans une AppBar, un titre court est suivi de son point',
      (tester) async {
    await dansUneAppBar(tester, 'Amis');
    expect(find.text('Amis'), findsOneWidget);
    expect(find.text('.'), findsOneWidget);
    expect(
      tester.getRect(find.text('.')).left,
      greaterThanOrEqualTo(tester.getRect(find.text('Amis')).right - 0.5),
    );
  });

  testWidgets('sur plusieurs lignes, le point suit le dernier mot',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 160, child: DesignTitle('Votre identité')),
        ),
      ),
    );
    expect(find.text('Votre identité.'), findsOneWidget);
  });

  testWidgets('pas de second signe après une ponctuation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DesignTitle('Mot de passe oublié ?')),
      ),
    );
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.textContaining('?.'), findsNothing);
  });

  testWidgets(
      "back-office : typographie de l'AppBar gardée, point terracotta",
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            titleTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 21,
              color: AdminColors.text,
            ),
          ),
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const DesignTitle.ambiant(
              'Tickets',
              accent: AdminColors.titleDot,
            ),
          ),
        ),
      ),
    );
    TextStyle rendu(String texte) => tester
        .renderObject<RenderParagraph>(find.descendant(
          of: find.text(texte),
          matching: find.byType(RichText),
        ))
        .text
        .style!;

    expect(rendu('Tickets').fontFamily, 'Inter');
    expect(rendu('Tickets').fontSize, 21);
    expect(rendu('Tickets').color, AdminColors.text);
    expect(rendu('.').fontFamily, 'Inter');
    expect(rendu('.').color, AdminColors.titleDot);
  });

  testWidgets('une autre famille garde sa police et prend la couleur du point',
      (tester) async {
    const style = TextStyle(fontSize: 18, fontFamily: 'Inter');
    const violet = Color(0xFF8E86C4);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DesignTitle('Le fil', style: style, accent: violet),
        ),
      ),
    );
    final texte = tester.widget<Text>(find.text('Le fil.'));
    expect(texte.style?.fontFamily, 'Inter');
    final point = (texte.textSpan! as TextSpan).children!.last as TextSpan;
    expect(point.text, '.');
    expect(point.style?.color, violet);
  });
}
