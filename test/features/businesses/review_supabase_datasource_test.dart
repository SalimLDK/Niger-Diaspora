import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/businesses/data/datasources/review_supabase_datasource.dart';
import 'package:diaspo_niger/features/businesses/data/models/review_model.dart';

/// Ce que le client envoie à `business_reviews`, et ce qu'il fait d'une
/// réponse vide.
///
/// La base n'accorde au client que `business_id`, `user_id`, `rating`,
/// `title`, `content` et `image_urls` (migration 20260921090000) : une seule
/// colonne de trop — le nom affiché, le statut, le compteur « utile » — et
/// c'est TOUTE la requête qui tombe en 42501. D'où les corps vérifiés ici clé
/// par clé. Le banc `tools/rls_tests/avis_entreprises_sur_supabase.sql` tient
/// l'autre moitié : ce que la base accepte.
void main() {
  late List<http.Request> recues;
  late int statut;
  late String corpsReponse;

  ReviewSupabaseDataSource source() {
    recues = [];
    final client = SupabaseClient(
      'http://localhost:54321',
      'cle-anon-de-test',
      httpClient: MockClient((request) async {
        recues.add(request);
        return http.Response(
          corpsReponse,
          statut,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    return ReviewSupabaseDataSource(client: client, garde: () async {});
  }

  const ligne = {
    'id': 'r1',
    'business_id': 'b1',
    'user_id': 'u1',
    'user_display_name': 'Awa',
    'user_photo_url': null,
    'rating': 4,
    'title': 'Bien',
    'content': 'Accueil chaleureux',
    'image_urls': ['https://x/1.jpg'],
    'helpful_count': 2,
    'helpful_by_user_ids': ['u2', 'u3'],
    'status': 'published',
    'owner_reply': 'Merci',
    'owner_reply_at': '2026-09-21T10:00:00+00:00',
    'created_at': '2026-09-20T10:00:00+00:00',
    'updated_at': '2026-09-20T10:00:00+00:00',
  };

  const avis = ReviewModel(
    id: 'r1',
    businessId: 'b1',
    userId: 'u1',
    // Ces trois-là viennent de l'écran : ils ne doivent PAS partir.
    userDisplayName: 'Le Président',
    helpfulCount: 99,
    status: 'published',
    rating: 5,
    title: 'Parfait',
    content: 'Très bon service',
    imageUrls: ['https://x/2.jpg'],
  );

  setUp(() {
    statut = 200;
    corpsReponse = '[]';
  });

  test('ligne → modèle : toutes les colonnes lues', () {
    final m = ReviewSupabaseDataSource.versModele(Map.of(ligne));
    expect(m.id, 'r1');
    expect(m.businessId, 'b1');
    expect(m.rating, 4);
    expect(m.imageUrls, ['https://x/1.jpg']);
    expect(m.helpfulByUserIds, ['u2', 'u3']);
    expect(m.ownerReply, 'Merci');
    expect(m.toEntity().ownerReplyAt, isNotNull);
  });

  test('créer : seules les colonnes accordées au client partent', () async {
    statut = 201;
    // `.single()` demande un objet (`Accept: …vnd.pgrst.object`), pas un tableau.
    corpsReponse = jsonEncode(ligne);

    await source().createReview(avis);

    expect(recues.single.method, 'POST');
    expect(recues.single.url.path, endsWith('/rest/v1/business_reviews'));
    expect(jsonDecode(recues.single.body), {
      'business_id': 'b1',
      'user_id': 'u1',
      'rating': 5,
      'title': 'Parfait',
      'content': 'Très bon service',
      'image_urls': ['https://x/2.jpg'],
    });
  });

  test('créer deux fois : l\'unicité (23505) devient un message clair', () async {
    statut = 409;
    corpsReponse = jsonEncode({
      'code': '23505',
      'message': 'duplicate key value violates unique constraint',
      'details': null,
      'hint': null,
    });

    await expectLater(
      source().createReview(avis),
      throwsA(isA<ServerException>()
          .having((e) => e.message, 'message', contains('déjà laissé un avis'))),
    );
  });

  test('retoucher : note, titre, texte, photos — rien d\'autre', () async {
    corpsReponse = jsonEncode([ligne]);

    await source().updateReview(avis);

    expect(recues.single.method, 'PATCH');
    expect(recues.single.url.queryParameters['id'], 'eq.r1');
    expect(jsonDecode(recues.single.body), {
      'rating': 5,
      'title': 'Parfait',
      'content': 'Très bon service',
      'image_urls': ['https://x/2.jpg'],
    });
  });

  test('retoucher l\'avis d\'autrui : zéro ligne ne « réussit » pas', () async {
    corpsReponse = '[]';
    await expectLater(source().updateReview(avis), throwsA(isA<ServerException>()));
  });

  test('supprimer : zéro ligne ne « réussit » pas', () async {
    corpsReponse = '[]';
    await expectLater(source().deleteReview('r1'), throwsA(isA<ServerException>()));
  });

  test('supprimer : une ligne, la suppression aboutit', () async {
    corpsReponse = '[{"id":"r1"}]';
    await source().deleteReview('r1');
    expect(recues.single.method, 'DELETE');
    expect(recues.single.url.queryParameters['id'], 'eq.r1');
  });

  test('« utile » : fonction serveur, sans identifiant d\'utilisateur', () async {
    corpsReponse = '1';
    final s = source();

    await s.markHelpful('r1');
    await s.unmarkHelpful('r1');

    expect(recues.map((r) => r.url.path),
        everyElement(endsWith('/rest/v1/rpc/avis_marquer_utile')));
    expect(jsonDecode(recues[0].body), {'p_review_id': 'r1', 'p_utile': true});
    expect(jsonDecode(recues[1].body), {'p_review_id': 'r1', 'p_utile': false});
  });

  test('réponse du gérant : fonction serveur ; retirer = texte vide', () async {
    corpsReponse = 'null';
    final s = source();

    await s.replyToReview('r1', 'Merci !');
    await s.replyToReview('r1', null);

    expect(recues.map((r) => r.url.path),
        everyElement(endsWith('/rest/v1/rpc/avis_repondre')));
    expect(jsonDecode(recues[0].body), {'p_review_id': 'r1', 'p_reponse': 'Merci !'});
    expect(jsonDecode(recues[1].body), {'p_review_id': 'r1', 'p_reponse': ''});
  });

  test('signaler : fonction serveur, le motif et rien d\'autre', () async {
    corpsReponse = 'null';

    await source().reportReview('r1', 'faux avis');

    expect(recues.single.url.path, endsWith('/rest/v1/rpc/avis_signaler'));
    expect(jsonDecode(recues.single.body), {'p_review_id': 'r1', 'p_motif': 'faux avis'});
  });

  test('un refus du serveur remonte en ServerException', () async {
    statut = 403;
    corpsReponse = jsonEncode({
      'code': '42501',
      'message': 'avis : seul le gérant de la fiche répond à ses avis',
      'details': null,
      'hint': null,
    });

    await expectLater(
      source().replyToReview('r1', 'je ne suis pas le gérant'),
      throwsA(isA<ServerException>()),
    );
  });
}
