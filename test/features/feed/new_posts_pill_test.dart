import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/feed/domain/entities/post_entity.dart';
import 'package:diaspo_niger/features/feed/presentation/widgets/new_posts_pill.dart';

/// Pastille « N nouvelles publications » du fil.
///
/// Elle reste montée en permanence pour jouer son entrée et sa sortie ; deux
/// choses en découlent, et sont vérifiées ici : pendant qu'elle s'efface elle
/// garde son dernier libellé (sinon on lit « Aucune nouvelle publication »
/// une fraction de seconde, ce qui se voit comme un clignotement), et elle
/// cesse d'être cliquable dès qu'elle est vide.
void main() {
  PostEntity post(String id, {required String auteur}) {
    final t = DateTime(2026, 9, 14, 8);
    return PostEntity(
      id: id,
      authorId: auteur,
      authorName: auteur,
      content: 'publication $id',
      createdAt: t,
      updatedAt: t,
    );
  }

  Future<void> poser(
    WidgetTester tester, {
    required List<PostEntity> posts,
    required String label,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NewPostsPill(
              posts: posts,
              label: label,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('annonce le nombre et empile un avatar par auteur distinct',
      (tester) async {
    await poser(
      tester,
      posts: [
        post('p1', auteur: 'Salim'),
        post('p2', auteur: 'Salim'),
        post('p3', auteur: 'Aïcha'),
      ],
      label: '3 nouvelles publications',
    );

    expect(find.text('3 nouvelles publications'), findsOneWidget);
    // Deux auteurs distincts sur trois publications : deux têtes, pas trois.
    expect(find.byType(CircleAvatar), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('vidée, elle garde son libellé le temps de s\'effacer et ne '
      'répond plus au doigt', (tester) async {
    var touches = 0;
    await poser(
      tester,
      posts: [post('p1', auteur: 'Salim')],
      label: '1 nouvelle publication',
      onTap: () => touches++,
    );
    await tester.tap(find.byType(NewPostsPill));
    expect(touches, 1);

    // Le fil a absorbé les publications en attente : la pastille se vide.
    await poser(
      tester,
      posts: const [],
      label: 'Aucune nouvelle publication',
      onTap: () => touches++,
    );
    await tester.pump();

    expect(find.text('1 nouvelle publication'), findsOneWidget,
        reason: 'le libellé doit survivre à l\'animation de sortie');
    expect(find.text('Aucune nouvelle publication'), findsNothing);

    final ignore = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byType(NewPostsPill),
        matching: find.byType(IgnorePointer),
      ).first,
    );
    expect(ignore.ignoring, isTrue);
  });
}
