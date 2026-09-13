import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/stories/data/models/story_model.dart';
import 'package:diaspo_niger/features/stories/domain/entities/story_entity.dart';

/// Audience et durée de vie des stories : les valeurs écrites en base sont
/// celles de `stories_audience_check` et `story_audience_members.list`.
void main() {
  test('audiences alignées sur stories_audience_check', () {
    expect(
      StoryAudience.values.map((a) => a.dbValue).toSet(),
      {'public', 'followers', 'friends', 'close'},
    );
    for (final a in StoryAudience.values) {
      expect(StoryAudience.fromDb(a.dbValue), a);
    }
    // Ligne d'avant la colonne : le défaut de la colonne.
    expect(StoryAudience.fromDb(null), StoryAudience.everyone);
  });

  test('listes alignées sur story_audience_members.list', () {
    expect(
      StoryListKind.values.map((k) => k.dbValue).toSet(),
      {'close', 'hidden'},
    );
    expect(StoryListKind.fromDb('autre'), isNull);
  });

  test("une story expire 24 h après sa publication, pas avant", () {
    StoryEntity publieeIlYa(Duration age) => StoryEntity(
          id: 's',
          authorId: 'a',
          authorName: 'A',
          mediaUrl: 'u',
          mediaType: StoryMediaType.image,
          createdAt: DateTime.now().subtract(age),
        );
    expect(publieeIlYa(const Duration(hours: 23, minutes: 59)).isExpired, false);
    expect(publieeIlYa(const Duration(hours: 24, seconds: 1)).isExpired, true);
    // La story du 3 août qui s'affichait encore en septembre.
    expect(publieeIlYa(const Duration(days: 40)).isExpired, true);
  });

  test("le modèle transporte l'audience jusqu'à l'entité", () {
    final entity = StoryModel.fromJson({
      'id': 's',
      'authorId': 'a',
      'createdAt': '2026-09-13T02:54:33Z',
      'audience': 'close',
    }).toEntity();
    expect(entity.audience, StoryAudience.closeList);
  });
}
