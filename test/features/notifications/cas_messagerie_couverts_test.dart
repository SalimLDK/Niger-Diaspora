import 'dart:io';

import 'package:diaspo_niger/core/services/notification_pref_keys.dart';
import 'package:diaspo_niger/features/notifications/domain/entities/notification_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce banc protège
/// ----------------------
/// Trois cas de messagerie que les notifications ne couvraient pas, trouvés le
/// 2026-09-16 en comparant les deux déclencheurs de production. Aucun ne
/// produisait d'erreur — c'est ce qui les avait gardés en place :
///
/// 1. l'aperçu serveur ignorait `voiceNote`, `audioFile` et `sticker`, les
///    trois noms que l'application écrit vraiment ;
/// 2. une réaction dans une conversation chiffrée ne notifiait personne ;
/// 3. une mention dans une conversation muette ne prévenait personne.
String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  const migCas =
      'supabase/migrations/20260916120000_notifications_messagerie_cas_manquants.sql';
  const migMention =
      'supabase/migrations/20260916130000_mention_passe_outre_la_sourdine.sql';
  const service = 'lib/core/services/notification_service.dart';

  group('l\'aperçu serveur connaît les types que l\'app écrit', () {
    test('les trois noms réels sont traités, chiffré comme en clair', () {
      final sql = _lire(migCas);
      // Deux CASE : la branche chiffrée (étiquette seule) et la branche en
      // clair. Les trois doivent figurer dans les deux.
      for (final type in const ['voiceNote', 'audioFile', 'sticker']) {
        expect("WHEN '$type'".allMatches(sql).length, greaterThanOrEqualTo(2),
            reason: '$type doit être traité des deux côtés du chiffrement');
      }
    });

    test('la table cliente et la table serveur nomment les mêmes types', () {
      // C'est l'écart qui a produit le défaut : `_formatMessagePreview`
      // connaissait `voiceNote` et `sticker` depuis toujours, le SQL non.
      final client = _lire(service);
      final i = client.indexOf('String _formatMessagePreview(');
      expect(i, greaterThan(-1));
      final corps = client.substring(i, client.indexOf('\n  }', i));
      final sql = _lire(migCas);
      for (final m in RegExp(r"case '([A-Za-z]+)':").allMatches(corps)) {
        final type = m.group(1)!;
        expect(sql, contains("WHEN '$type'"),
            reason: '$type est connu du client mais pas du serveur');
      }
    });

    test('un sticker ne peut plus sortir en URL', () {
      // En clair, le `ELSE` rend `data->>'content'` — pour un sticker, son URL.
      // L'étiquette n'est donc pas qu'un confort d'affichage.
      final sql = _lire(migCas);
      final i = sql.indexOf("-- Ni E2EE ni AES");
      expect(i, greaterThan(-1));
      final brancheClaire = sql.substring(i, sql.indexOf('END;', i));
      expect(brancheClaire, contains("WHEN 'sticker'"));
      expect(brancheClaire, contains("WHEN 'contact'"));
    });
  });

  group('une réaction chiffrée notifie l\'auteur', () {
    test('le déclencheur existe, sur les trois écritures', () {
      final sql = _lire(migCas);
      expect(sql, contains('AFTER INSERT OR UPDATE OR DELETE ON public.mls_message_reactions'));
      expect(sql, contains("'messageReaction'"));
    });

    test('l\'emoji ne part PAS dans le push', () {
      // Il est déjà en clair côté serveur ; le mettre dans la notification le
      // donnerait en plus à FCM, sur une conversation chiffrée. Ni dans le
      // corps, ni dans `data` — `send-push` recopie chaque clé de `data`.
      final sql = _lire(migCas);
      final i = sql.indexOf('FUNCTION public.mls_notifier_reaction()');
      expect(i, greaterThan(-1));
      final corps = sql.substring(i, sql.indexOf('mls_notifier_reaction_trg', i));
      expect(corps.contains("'emoji',"), isFalse,
          reason: 'pas de clé emoji dans la charge du push');
      expect(corps, contains('a réagi à votre message'));
    });

    test('mêmes gardes que le chemin en clair', () {
      final sql = _lire(migCas);
      final i = sql.indexOf('FUNCTION public.mls_notifier_reaction()');
      final corps = sql.substring(i, sql.indexOf('mls_notifier_reaction_trg', i));
      expect(corps, contains('is_conversation_muted_for'));
      expect(corps, contains('v_msg.sender_id = v_acteur'));
      expect(corps, contains('SELECT 1 FROM users WHERE id = v_msg.sender_id'));
      // Dédoublonnage : la notification précédente du même acteur part avant.
      expect(corps, contains('DELETE FROM notifications'));
      expect(corps, contains('RAISE WARNING'));
    });
  });

  group('toute notification de messagerie est datée', () {
    const migHeure =
        'supabase/migrations/20260916160000_les_reactions_sont_datees.sql';

    test('les deux chemins de réaction posent `sentAt`', () {
      // Trouvé par le banc de bout en bout : les cinq notifications produites
      // portaient `sentAt`… sauf celle de réaction. Le client retombait alors
      // sur l'heure de LIVRAISON — le défaut corrigé la veille pour les
      // messages, resté sur son voisin.
      final sql = _lire(migHeure);
      expect(sql, contains('FUNCTION public.mls_notifier_reaction()'));
      expect(sql, contains('FUNCTION public.set_message_reaction('));
      expect("'sentAt',".allMatches(sql).length, 2,
          reason: 'un par chemin, chiffré et clair');
    });

    test('c’est l’heure de la RÉACTION, pas celle du message', () {
      // C'est la réaction qu'on annonce ; la dater du message auquel elle
      // répond donnerait une bannière antidatée de plusieurs jours.
      final sql = _lire(migHeure);
      expect(sql, contains('COALESCE(NEW.created_at, now())'));
      expect(sql, contains('extract(epoch from now())'));
    });

    test('aucun écrivain de notification de messagerie ne l’oublie', () {
      // Les quatre migrations qui posent une notification de messagerie
      // doivent toutes dater leur charge.
      for (final f in const [
        'supabase/migrations/20260916140000_le_push_porte_l_heure_du_message.sql',
        migHeure,
      ]) {
        expect(_lire(f), contains("'sentAt',"), reason: f);
      }
    });
  });

  group('les droits de la table sont au plus juste', () {
    const migDroits =
        'supabase/migrations/20260916180000_droits_au_plus_juste_et_emoji_partout.sql';

    test('on RÉVOQUE avant d’accorder', () {
      // Un GRANT seul n'enlève rien : Supabase accorde ALL par défaut sur
      // toute table neuve du schéma public.
      final sql = _lire(migDroits);
      final revoque = sql.indexOf('REVOKE ALL ON TABLE public.notifications');
      final accorde = sql.indexOf('GRANT SELECT, DELETE');
      expect(revoque, greaterThan(-1));
      expect(accorde, greaterThan(revoque), reason: 'REVOKE d’abord');
      // Les deux rôles, pas seulement `anon` auquel on pense davantage.
      expect(sql, contains('FROM anon;'));
      expect(sql, contains('FROM authenticated;'));
    });

    test('`anon` ne reçoit rien', () {
      final sql = _lire(migDroits);
      expect(sql.contains('TO anon'), isFalse,
          reason: '`notifications_own` compare à firebase_uid(), nul pour lui');
    });

    test('l’UPDATE est borné aux colonnes de lecture', () {
      // Personne n'a besoin de réécrire le titre, le corps ou le `data` d'une
      // notification : le client ne fait que poser `is_read`.
      expect(_lire(migDroits), contains('GRANT UPDATE (is_read, read_at)'));
    });

    test('ni INSERT ni TRUNCATE', () {
      // TRUNCATE ignore la RLS — c'est le seul verbe qu'aucune policy
      // n'arrête. INSERT est inutile : tout passe par la RPC SECURITY DEFINER
      // ou par les déclencheurs.
      final sql = _lire(migDroits);
      final accords = RegExp(r'GRANT ([^;]+) ON TABLE public\.notifications')
          .allMatches(sql).map((m) => m.group(1)!).join(' ');
      expect(accords.contains('INSERT'), isFalse);
      expect(accords.contains('TRUNCATE'), isFalse);
    });
  });

  group('l’emoji d’une réaction passe des deux côtés', () {
    const migDroits =
        'supabase/migrations/20260916180000_droits_au_plus_juste_et_emoji_partout.sql';

    test('les deux transports le posent, dans le corps et dans `data`', () {
      // Décision du 2026-09-16 : les deux bannières se ressemblent, quitte à
      // donner l'emoji à FCM sur une conversation chiffrée.
      final sql = _lire(migDroits);
      expect(sql, contains("' a réagi ' || NEW.emoji || ' à '"));
      expect(sql, contains("'A réagi ' || NEW.emoji || ' à '"));
      expect(sql, contains("'emoji',            NEW.emoji,"));
    });

    test('et les deux disent À QUOI on a réagi', () {
      final sql = _lire(migDroits);
      expect(sql, contains('FUNCTION private.libelle_message_reagi(p_type TEXT)'));
      // Une seule table pour les deux vocabulaires : `content_type` côté
      // chiffré, `type` côté clair.
      expect(sql, contains("WHEN 'voice'     THEN 'votre note vocale'"));
      expect(sql, contains("WHEN 'voiceNote' THEN 'votre note vocale'"));
      // `media` est le type grossier du transport chiffré.
      expect(sql, contains("WHEN 'media'     THEN 'votre pièce jointe'"));
      expect('libelle_message_reagi'.allMatches(sql).length,
          greaterThanOrEqualTo(5),
          reason: 'définie, révoquée, commentée, et appelée des deux côtés');
    });

    test('le libellé ne dit que le TYPE, jamais le contenu', () {
      // C'est ce qui le rend acceptable sur une conversation chiffrée : la
      // métadonnée servait déjà à composer la notification du message lui-même.
      final sql = _lire(migDroits);
      final i = sql.indexOf('FUNCTION private.libelle_message_reagi');
      final corps = sql.substring(i, sql.indexOf(r'$$;', i));
      expect(corps.contains('ciphertext'), isFalse);
      expect(corps.contains("data->>"), isFalse);
    });
  });

  group('une mention passe outre la sourdine', () {
    test('elle n\'est posée QUE dans la branche muette', () {
      // Hors sourdine, la notification `message` suffit : en ajouter une
      // seconde doublerait chaque mention.
      final sql = _lire(migMention);
      final i = sql.indexOf('IF public.is_conversation_muted_for');
      expect(i, greaterThan(-1));
      final brancheMuette = sql.substring(i, sql.indexOf('CONTINUE;', i));
      expect(brancheMuette, contains("'messageMention'"));
      expect("'messageMention'".allMatches(sql).length, 2,
          reason: 'le type et le champ `type` de data, pas davantage');
    });

    test('elle lit les deux écritures de l\'identifiant mentionné', () {
      expect(_lire(migMention), contains("COALESCE(mention->>'id', mention->>'userId')"));
    });

    test('le type mène à la DISCUSSION, pas au fil', () {
      // `mentioned` appartient au fil et ouvre `/feed/<cible>` ; la cible est
      // ici une conversation. D'où un type distinct.
      final ecran = _lire(
          'lib/features/notifications/presentation/screens/notifications_screen.dart');
      final i = ecran.indexOf('case NotificationType.messageMention:');
      expect(i, greaterThan(-1));
      expect(ecran.substring(i, i + 220), contains("context.push('/messages/"));
    });

    test('elle suit la bascule « Messages »', () {
      // La sourdine est par conversation, l'interrupteur est global : céder à
      // l'une n'est pas céder à l'autre.
      expect(kClePreferenceParType['messageMention'], 'messages');
    });

    test('le type existe et porte son libellé', () {
      expect(NotificationType.messageMention.label, 'Mention');
    });

    test('la limite MLS est écrite, pas seulement subie', () {
      // Dans une conversation chiffrée, les mentions sont dans la charge : le
      // serveur ne peut pas savoir. Quelqu'un finira par croire à un oubli.
      expect(_lire(migMention), contains('TRANSPORT EN CLAIR SEULEMENT'));
    });
  });
}
