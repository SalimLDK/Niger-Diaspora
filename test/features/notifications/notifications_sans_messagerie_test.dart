import 'package:diaspo_niger/features/notifications/data/datasources/notification_supabase_datasource.dart';
import 'package:diaspo_niger/features/notifications/domain/entities/notification_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// L'écran Notifications n'affiche pas la messagerie.
///
/// Le filtre vit dans la requête et dans le tri des changements temps réel :
/// deux écritures du même critère, qu'un type ajouté d'un côté seulement
/// ferait diverger sans rien casser de visible.
void main() {
  group('filtre de la requête', () {
    test('écarte la messagerie, garde les types nuls', () {
      // `messageEdited` s'y ajoute depuis le 2026-09-16 : elle n'annonce rien,
      // elle corrige une bannière. L'afficher montrerait une entrée par faute
      // de frappe corrigée.
      expect(
        NotificationSupabaseDataSource.filtreTypesAffiches,
        // `messageDeleted` depuis le 2026-09-21 : même régime, il retire une
        // ligne d'une bannière et n'annonce rien.
        'type.is.null,type.not.in.(message,messageReaction,messageEdited,messageDeleted)',
      );
    });

    test('le nom de chaque type écarté est bien la chaîne stockée en base', () {
      // Le filtre SQL compare `type` à `NotificationType.name`. Si le décodage
      // ne ramène pas la chaîne brute au même type, les deux divergent.
      final source = NotificationSupabaseDataSource();
      for (final type in kTypesHorsEcranNotifications) {
        final model = source.fromRow({
          'id': 'n1',
          'user_id': 'u1',
          'type': type.name,
          'title': 't',
          'body': 'b',
          'is_read': false,
          'created_at': '2026-09-13T10:00:00Z',
          'data': <String, dynamic>{},
        });
        expect(model.toEntity().type, type);
      }
    });
  });

  group('type affiché', () {
    test('la messagerie est écartée', () {
      expect(NotificationSupabaseDataSource.typeAffiche('message'), isFalse);
      expect(
        NotificationSupabaseDataSource.typeAffiche('messageReaction'),
        isFalse,
      );
    });

    test('le reste passe, y compris un type nul (affiché en général)', () {
      for (final brut in [null, 'general', 'new_post', 'friendRequest']) {
        expect(NotificationSupabaseDataSource.typeAffiche(brut), isTrue);
      }
    });
  });

  group('changement temps réel pertinent', () {
    bool pertinent(
      PostgresChangeEvent evenement, {
      Map<String, dynamic> nouveau = const {},
      Map<String, dynamic> ancien = const {},
      Set<String> affiches = const {},
    }) => NotificationSupabaseDataSource.changementPertinent(
      evenement,
      nouveau,
      ancien,
      affiches,
    );

    test('un message reçu ne relance pas la requête', () {
      expect(
        pertinent(
          PostgresChangeEvent.insert,
          nouveau: {'id': 'm1', 'type': 'message'},
        ),
        isFalse,
      );
    });

    test('une notification affichable reçue relance la requête', () {
      expect(
        pertinent(
          PostgresChangeEvent.insert,
          nouveau: {'id': 'p1', 'type': 'new_post'},
        ),
        isTrue,
      );
    });

    test('un message marqué lu ne relance pas la requête', () {
      expect(
        pertinent(
          PostgresChangeEvent.update,
          nouveau: {'id': 'm1', 'type': 'message', 'is_read': true},
          affiches: {'p1'},
        ),
        isFalse,
      );
    });

    test('une ligne affichée mise à jour relance la requête', () {
      expect(
        pertinent(
          PostgresChangeEvent.update,
          nouveau: {'id': 'p1', 'type': 'new_post', 'is_read': true},
          affiches: {'p1'},
        ),
        isTrue,
      );
    });

    test('suppression : seule une ligne à l\'écran compte', () {
      // L'ancien enregistrement ne porte que la clé primaire.
      expect(
        pertinent(
          PostgresChangeEvent.delete,
          ancien: {'id': 'p1'},
          affiches: {'p1'},
        ),
        isTrue,
      );
      expect(
        pertinent(
          PostgresChangeEvent.delete,
          ancien: {'id': 'autre'},
          affiches: {'p1'},
        ),
        isFalse,
      );
    });
  });
}
