// Ce que l'écran Signalements sait d'un signalement, sorti de l'écran :
// où mène « Voir le contenu » (une route fausse ouvre la fiche d'un autre
// contenu ou rien), et la couleur d'un statut. Plus un rendu des widgets
// extraits des écrans Signalements et Configuration.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/reglages/reglages_briques.dart';
import 'package:diaspo_niger/features/admin/presentation/signalement_presentation.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/apercu_contenu_signale.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/carte_stat_signalement.dart';

ReportEntity _signalement(
  String type, {
  String cible = 'c1',
  String? conversation,
  ContentSnapshotData? instantane,
}) =>
    ReportEntity(
      id: 'r',
      reporterId: 'u',
      targetType: type,
      targetId: cible,
      reason: 'x',
      conversationId: conversation,
      contentSnapshot: instantane,
    );

void main() {
  group('destinationContenuSignale', () {
    test("chaque cible mène à un écran qui existe dans le panneau", () {
      expect(destinationContenuSignale('user'), 'users');
      expect(destinationContenuSignale('business'), 'businesses');
      expect(destinationContenuSignale('business_review'), 'businesses');
      expect(destinationContenuSignale('product'), 'marketplace');
      expect(destinationContenuSignale('group'), 'content');
      expect(destinationContenuSignale('event'), 'content');
    });

    test("un message ou une conversation (chiffrés) n'ont pas d'écran", () {
      expect(destinationContenuSignale('message'), isNull);
      expect(destinationContenuSignale('conversation'), isNull);
      expect(destinationContenuSignale('inconnu'), isNull);
    });
  });

  group('routeContenuSignale', () {
    test('un type de contenu mène à sa fiche', () {
      expect(routeContenuSignale(_signalement('user')), '/profile/c1');
      expect(routeContenuSignale(_signalement('group')), '/groups/c1');
      expect(routeContenuSignale(_signalement('event')), '/events/c1');
      expect(routeContenuSignale(_signalement('business')), '/businesses/c1');
      expect(routeContenuSignale(_signalement('product')), '/marketplace/c1');
    });

    test('un message ou une conversation mène à la discussion, pas à sa cible', () {
      expect(
        routeContenuSignale(_signalement('message', conversation: 'k9')),
        '/messages/k9',
      );
      expect(routeContenuSignale(_signalement('conversation')), isNull);
    });

    test("un avis mène à la fiche du commerce lue dans l'instantané", () {
      expect(
        routeContenuSignale(_signalement(
          'business_review',
          instantane: const ContentSnapshotData(metadata: {'business_id': 'b7'}),
        )),
        '/businesses/b7',
      );
      expect(routeContenuSignale(_signalement('business_review')), isNull);
    });

    test('un type inconnu ne mène nulle part', () {
      expect(routeContenuSignale(_signalement('autre')), isNull);
    });
  });

  test('chaque statut a sa couleur, un statut inconnu garde le bleu', () {
    expect(couleurStatutSignalement('pending'), AdminColors.statusAmber);
    expect(couleurStatutSignalement('resolved'), AdminColors.statusGreen);
    expect(couleurStatutSignalement('dismissed'), AdminColors.statusGray);
    expect(couleurStatutSignalement('?'), AdminColors.actionBlueLight);
  });

  test('chaque type de cible a une icône', () {
    for (final t in ['user', 'message', 'conversation', 'event', 'group', 'business', 'product']) {
      expect(iconeTypeSignalement(t), isNot(iconeTypeSignalement('inconnu')), reason: t);
    }
  });

  testWidgets('les widgets extraits des écrans se rendent', (tester) async {
    var enregistre = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            const CarteStatSignalement('En attente', 12, Icons.flag, Colors.orange),
            const ApercuContenuSignale(
              snapshot: ContentSnapshotData(
                text: 'Un message signalé',
                contentType: 'text',
                fileName: 'piece.pdf',
              ),
              libelle: 'Contenu capturé',
              date: '14/10/2026 10:00',
            ),
            const ReglagesCarteSection(
              title: 'Frais',
              subtitle: 'Pourcentages',
              icon: Icons.percent,
              color: Colors.blue,
              children: [Text('champ')],
            ),
            ReglagesBoutonEnregistrer(label: 'Enregistrer', onPressed: () => enregistre++),
          ]),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Un message signalé'), findsOneWidget);
    expect(find.text('Contenu capturé'), findsOneWidget);
    expect(find.text('14/10/2026 10:00'), findsOneWidget);
    expect(find.text('champ'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    expect(enregistre, 1);
  });
}
