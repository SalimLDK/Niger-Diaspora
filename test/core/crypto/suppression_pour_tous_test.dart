import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 6.3, ligne « Supprimer pour tous »)
/// --------------------------------------------------------------------------
/// Le plan promet que le serveur **cesse de servir le ciphertext**. Il ne
/// cessait pas : `supprimerPourTous` posait `is_deleted` et `deleted_at`, et
/// rien d'autre. Le contenu restait en base, et un destinataire qui n'avait pas
/// encore rattrapé pouvait encore le déchiffrer.
///
/// Le client ne pouvait pas mieux faire : `UPDATE` ne lui est pas accordé sur
/// `ciphertext`, et cette restriction doit **rester** — c'est elle qui
/// l'empêche de réécrire son propre message des heures après, un défaut que ce
/// dépôt a déjà trouvé et fermé. D'où une fonction `SECURITY DEFINER` qui fait
/// le geste précis, vider, sans donner le moyen d'écrire n'importe quoi.
///
/// Ce que ces tests empêchent : qu'on rouvre `UPDATE (ciphertext)` pour aller
/// plus vite, que la fonction oublie de se réserver à l'expéditeur — elle
/// passe outre le RLS, donc la condition doit être écrite dans son corps —, et
/// qu'elle redevienne muette en cas de refus.

String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  const migration =
      'supabase/migrations/20260916001500_mls_supprimer_pour_tous_efface_vraiment.sql';
  const client = 'lib/core/crypto/mls/mls_metadonnees.dart';

  group('la fonction serveur', () {
    test('vide le ciphertext, pas seulement le drapeau', () {
      final sql = _lire(migration);
      expect(sql.contains('is_deleted = true'), isTrue);
      expect(sql.contains('deleted_at = now()'), isTrue);
      expect(
        sql.contains("ciphertext = '\\x'::bytea"),
        isTrue,
        reason: 'sans ça, le contenu reste lisible par qui n\'a pas rattrapé',
      );
    });

    test('se réserve à l\'expéditeur dans son corps', () {
      // `SECURITY DEFINER` passe outre le RLS : la policy de la table ne
      // protège plus rien ici, la condition doit être explicite.
      final sql = _lire(migration);
      expect(sql.contains('SECURITY DEFINER'), isTrue);
      expect(sql.contains('SET search_path = public'), isTrue);
      expect(sql.contains('sender_id = public.firebase_uid()'), isTrue);
    });

    test('rend l\'identifiant touché, pour que le refus se voie', () {
      final sql = _lire(migration);
      expect(sql.contains('RETURNS uuid'), isTrue);
      expect(sql.contains('RETURNING id INTO v_id'), isTrue);
    });

    test('révoque avant d\'accorder, pour les deux rôles', () {
      // Un GRANT n'enlève rien : Supabase accorde EXECUTE par défaut.
      final sql = _lire(migration);
      for (final role in ['PUBLIC', 'anon', 'authenticated']) {
        expect(
          sql.contains('REVOKE ALL ON FUNCTION '
              'public.mls_supprimer_pour_tous(uuid) FROM $role'),
          isTrue,
          reason: 'révocation manquante pour $role',
        );
      }
      expect(sql.contains('GRANT EXECUTE ON FUNCTION '
          'public.mls_supprimer_pour_tous(uuid) TO authenticated'), isTrue);
    });
  });

  group('le client', () {
    test('appelle la fonction et lève quand elle ne rend rien', () {
      final dart = _lire(client);
      final debut = dart.indexOf('Future<void> supprimerPourTous(');
      expect(debut, isNonNegative);
      final corps = dart.substring(debut, debut + 1400);

      expect(corps.contains("rpc<dynamic>(\n      'mls_supprimer_pour_tous'"),
          isTrue,
          reason: 'la suppression doit passer par la fonction');
      expect(corps.contains('if (id == null)'), isTrue);
      expect(corps.contains('throw StateError'), isTrue,
          reason: 'un refus du RLS ne doit pas passer pour un succès');
    });

    test('ne repasse pas par un update direct de la table', () {
      final dart = _lire(client);
      final debut = dart.indexOf('Future<void> supprimerPourTous(');
      final corps = dart.substring(debut, debut + 1400);
      expect(corps.contains(".from('mls_messages').update("), isFalse);
    });
  });
}
