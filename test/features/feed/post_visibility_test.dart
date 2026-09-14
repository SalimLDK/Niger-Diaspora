import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/feed/data/models/post_model.dart';
import 'package:diaspo_niger/features/feed/domain/entities/post_entity.dart';
import 'package:diaspo_niger/features/feed/presentation/providers/feed_scorer.dart';

/// Audience des publications : les valeurs écrites en base sont celles que
/// `posts_visibility_check` et `peut_voir_publication` connaissent.
void main() {
  group('PostVisibility', () {
    test('valeurs de base alignées sur posts_visibility_check', () {
      expect(
        PostVisibility.values.map((v) => v.dbValue).toSet(),
        {'public', 'followers', 'friends', 'private'},
      );
    });

    // `posts_visibility_check` interdit toute autre valeur : le repli ne sert
    // qu'aux lignes d'avant la colonne, dont le défaut est `public`.
    test('valeur absente : public, le défaut de la colonne', () {
      expect(PostVisibility.fromDb(null), PostVisibility.public);
      expect(PostVisibility.fromDb('x'), PostVisibility.public);
      expect(PostVisibility.fromDb('private'), PostVisibility.onlyMe);
    });

    test('aller-retour modèle ⇄ entité', () {
      for (final v in PostVisibility.values) {
        final entity = PostEntity(
          id: 'p',
          authorId: 'a',
          authorName: 'A',
          content: 'x',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          visibility: v,
        );
        final model = PostModel.fromEntity(entity);
        expect(model.visibility, v.dbValue);
        expect(PostModel.fromJson(model.toJson()).toEntity().visibility, v);
      }
    });
  });

  test('un ami passe devant un compte seulement suivi', () {
    PostEntity post(String author) => PostEntity(
          id: author,
          authorId: author,
          authorName: author,
          content: 'x',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    const scorer = FeedScorer(
      followingIds: {'suivi', 'ami'},
      friendIds: {'ami'},
      myCountry: null,
      hashtagWeights: {},
    );
    expect(scorer.score(post('ami')), greaterThan(scorer.score(post('suivi'))));
    expect(
      scorer.score(post('suivi')),
      greaterThan(scorer.score(post('inconnu'))),
    );
  });
}
