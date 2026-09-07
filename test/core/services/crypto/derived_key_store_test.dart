import 'package:diaspo_niger/core/services/crypto/derived_key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Une seule propriété, mais c'est celle dont tout le reste dépend : **quand la
/// clé ne peut pas être obtenue, le magasin rend `null` — jamais une clé de
/// substitution.**
///
/// Sans elle, un repli « au cas où » remettrait deux clés en circulation et
/// produirait du contenu illisible plus tard, sans que rien ne le signale. Ce
/// dépôt vient précisément de payer ce scénario : la clé AES de Firebase
/// Functions avait divergé de celle du client pendant des mois, et le seul
/// symptôme était un aperçu de notification en base64.
///
/// L'endpoint est ici volontairement injoignable (port fermé sur la boucle
/// locale) : c'est la façon la plus fidèle de rejouer « hors ligne », « Edge
/// Function pas déployée » et « session absente », qui doivent tous se traduire
/// de la même manière.
void main() {
  group('DerivedKeyStore — refus plutôt que substitution', () {
    late DerivedKeyStore magasin;

    setUp(() {
      // Port fermé : l'échec est immédiat, pas un timeout qui ralentirait la suite.
      final supabase = SupabaseClient(
        'http://127.0.0.1:1',
        'cle-anon-de-test',
      );
      magasin = DerivedKeyStore.pourTests(supabase: supabase);
      magasin.viderMemoirePourTests();
    });

    test('sans serveur joignable, la clé de conversation est nulle', () async {
      final cle = await magasin.cleConversation('conv-quelconque');

      expect(cle, isNull);
    });

    test('sans serveur joignable, la clé utilisateur est nulle', () async {
      final cle = await magasin.cleUtilisateur();

      expect(cle, isNull);
    });

    test('rafraichir signale son échec au lieu de le masquer', () async {
      final abouti = await magasin.rafraichir();

      expect(abouti, isFalse);
    });

    test('un échec ne fabrique aucune version courante', () async {
      await magasin.rafraichir();

      // Une version posée malgré l'échec ferait croire aux appelants qu'ils
      // peuvent chiffrer avec le nouveau schéma.
      expect(magasin.versionCourante, isNull);
    });

    test('deux appels successifs échouent de la même façon', () async {
      final premier = await magasin.cleConversation('conv-a');
      final second = await magasin.cleConversation('conv-a');

      // Pas de mémorisation d'un échec en valeur vide : le second appel doit
      // retenter, pas servir un « null » mis en cache comme s'il était une clé.
      expect(premier, isNull);
      expect(second, isNull);
    });
  });
}
