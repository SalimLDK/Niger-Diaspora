import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ce que ce banc protège
/// ----------------------
/// Le ciphertext d'un message MLS existe en **deux** endroits : la colonne
/// `mls_messages.ciphertext`, et la copie que `mls_notify_recipients` dépose
/// dans `notifications.data->>'mlsCiphertext'` pour que l'appareil
/// reconstruise l'aperçu (plan MLS § 8).
///
/// « Supprimer pour tous » et la purge des éphémères vident la colonne. Ils
/// oubliaient la copie — qui est lisible, par PostgREST, par exactement celui
/// qui sait la déchiffrer. Mesuré avant correction : 8 messages supprimés
/// portaient encore leur ciphertext dans une notification.
///
/// Rien de tout ça ne se voit à l'exécution : la suppression « marche »,
/// l'écran obéit, et le contenu reste à un `select` de distance. D'où un banc
/// sur le texte des migrations.
String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  const migration =
      'supabase/migrations/20260916030000_mls_notifications_suivent_le_message.sql';

  group('la copie du ciphertext suit le sort du message', () {
    test('le déclencheur est posé là où le ciphertext disparaît vraiment', () {
      final sql = _lire(migration);
      // `UPDATE OF ciphertext` couvre d'un coup `mls_supprimer_pour_tous` ET
      // `purger_messages_expires`, sans les modifier — et couvrira le
      // troisième effaceur, celui qu'on aurait oublié de patcher.
      expect(
        sql,
        contains('AFTER UPDATE OF is_deleted, ciphertext, edited_at ON public.mls_messages'),
      );
      expect(sql, contains('AFTER DELETE ON public.mls_messages'));
    });

    test('la suppression dure passe par un déclencheur PAR INSTRUCTION', () {
      // Effacer une conversation efface ses messages en cascade : un
      // déclencheur par ligne relirait `notifications` une fois par message.
      final sql = _lire(migration);
      expect(sql, contains('REFERENCING OLD TABLE AS mls_messages_supprimes'));
      expect(sql, contains('FOR EACH STATEMENT'));
    });

    test('le geste retire la copie, il ne la remplace pas', () {
      expect(_lire(migration), contains("data    = n.data - 'mlsCiphertext'"));
    });

    test('une édition ne marque pas la notification lue', () {
      // Le message existe toujours : une notification non lue à juste titre
      // ne doit pas disparaître parce que son auteur a corrigé une faute.
      // Elle perd seulement la copie, qui porte le texte d'AVANT.
      final sql = _lire(migration);
      final i = sql.indexOf('v_edite    :=');
      expect(i, greaterThan(-1));
      final corps = sql.substring(i, sql.indexOf('RETURN NULL;', i));
      expect(corps, contains("mls_notifications_oublier(ARRAY[NEW.id::text], FALSE)"));
    });

    test('les fonctions ne sont appelables par personne depuis le client', () {
      final sql = _lire(migration);
      for (final nom in const [
        'private.mls_notifications_oublier(TEXT[], BOOLEAN)',
        'private.trg_mls_notifications_supprimes()',
        'private.trg_mls_notifications_message_change()',
      ]) {
        expect(sql, contains('REVOKE ALL ON FUNCTION $nom'),
            reason: '$nom doit être révoquée');
      }
    });

    test('les copies déjà orphelines sont rattrapées', () {
      final sql = _lire(migration);
      // Celles dont le message est supprimé ou vidé…
      expect(sql, contains('SELECT private.mls_notifications_oublier('));
      // …et celles dont le message a entièrement disparu de la table.
      expect(sql, contains('AND NOT EXISTS ('));
    });

    test('un échec de nettoyage ne fait pas échouer la suppression', () {
      final sql = _lire(migration);
      expect('RAISE WARNING'.allMatches(sql).length, greaterThanOrEqualTo(2));
    });
  });

  group('la copie n’a toujours qu’un seul écrivain', () {
    test('seul `mls_notify_recipients` la pose', () {
      // Si un second trigger se mettait à écrire `mlsCiphertext`, le nettoyage
      // ci-dessus ne couvrirait plus tout — et rien ne le dirait.
      final ecrivains = <String>[];
      for (final f in Directory('supabase/migrations').listSync()) {
        if (f is! File || !f.path.endsWith('.sql')) continue;
        final sql = _lire(f.path);
        if (sql.contains("'mlsCiphertext'") &&
            !f.path.endsWith('20260916030000_mls_notifications_suivent_le_message.sql')) {
          ecrivains.add(f.path.split(RegExp(r'[\\/]')).last);
        }
      }
      // Les deux fichiers portent le MÊME `mls_notify_recipients` : le second
      // le remplace pour retirer les sauts de ligne du base64. Un troisième
      // nom dans cette liste voudrait dire un second écrivain, et un nettoyage
      // qui ne couvre plus tout.
      expect(
        ecrivains,
        const [
          '20260915140000_mls_notifications.sql',
          '20260915160000_mls_notifications_base64_sans_sauts.sql',
        ],
        reason: 'écrivains inattendus de la copie : $ecrivains',
      );
      for (final fichier in ecrivains) {
        expect(_lire('supabase/migrations/$fichier'),
            contains('FUNCTION public.mls_notify_recipients()'));
      }
    });
  });
}
