import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';

/// Au retour d'arrière-plan, le jeton Supabase est périmé : la première
/// lecture de la liste des discussions trouve la session absente. Elle ne
/// réessayait qu'au bout de 5 s fixes, alors que le jeton neuf arrive en
/// moins d'une seconde — la notification du message était déjà là, la liste
/// restait figée.
void main() {
  test('la liste relit dès que la session est établie, sans attendre 5 s',
      () async {
    final session = StreamController<void>.broadcast();
    var consultations = 0;
    final source = MessageSupabaseDataSource(
      // Port fermé : aucune requête ne doit aboutir, on ne compte que les
      // passages par la garde.
      client: SupabaseClient('http://127.0.0.1:1', 'cle-anon-de-test'),
      ensureReadableAuth: () async {
        consultations++;
        return false;
      },
      sessionEtablie: session.stream,
    );

    final abonnement = source.getConversations('moi').listen(
          (_) {},
          onError: (_) {},
        );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(consultations, 1, reason: 'lecture initiale, session absente');

    session.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(consultations, 2,
        reason: 'relue aussitôt la session établie, pas au bout de 5 s');

    await abonnement.cancel();
    await session.close();
  });
}
