import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';

/// La policy `messages_select` vaut pour le rôle **`public`** : une lecture
/// sans session Supabase ne lève pas, elle **réussit en ne renvoyant aucune
/// ligne**.
///
/// Ce n'est pas qu'un écran vide : `MessageRepositoryImpl.getMessagesPaginated`
/// prend ce résultat pour la vérité et le met en cache par-dessus la
/// discussion réelle (`cacheService.cacheMessages`). Le cache local d'une
/// discussion entière disparaît, sans une erreur nulle part.
///
/// D'où la garde en tête de la lecture. Le test la prend par le seul bout
/// observable sans serveur : la garde est **avant** tout accès au client, donc
/// une session refusée doit lever sans jamais toucher le réseau.
void main() {
  group('getMessagesPaginated — garde de session', () {
    late SupabaseClient supabase;

    setUp(() {
      // Port fermé : si la garde laissait passer, l'échec serait un timeout
      // réseau, pas la ServerException attendue — le test le verrait.
      supabase = SupabaseClient('http://127.0.0.1:1', 'cle-anon-de-test');
    });

    test('session refusée : la lecture lève au lieu de rendre une liste vide',
        () async {
      final source = MessageSupabaseDataSource(
        client: supabase,
        ensureReadableAuth: () async => false,
      );

      expect(
        () => source.getMessagesPaginated(
          conversationId: 'conv-1',
          limit: 30,
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'la garde est consultée avant toute requête',
      () async {
        var consultee = false;
        final source = MessageSupabaseDataSource(
          client: supabase,
          ensureReadableAuth: () async {
            consultee = true;
            return false;
          },
        );

        try {
          await source.getMessagesPaginated(
            conversationId: 'conv-1',
            limit: 30,
          );
        } catch (_) {
          // L'exception est le sujet de l'autre test.
        }

        expect(consultee, isTrue);
      },
    );
  });
}
