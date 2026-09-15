import 'dart:io';

import 'package:diaspo_niger/features/messages/data/models/conversation_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// `conversations.data->>'lastMessage'` porte le texte du dernier message **en
/// clair** : c'est lui qu'on lit dans la liste des discussions.
/// `deleteMessageForEveryone` vidait la ligne `messages` — contenu, `fileUrl`,
/// cartes de partage, clé du média chiffré — et **ne le touchait pas**.
/// Supprimer son dernier message donnait donc une bulle « Message supprimé »
/// avec, une ligne plus haut, son texte parfaitement lisible. La suppression
/// se disait accomplie pendant que son contenu restait à l'écran.
///
/// Refermer ce trou en ouvre un second, plus discret : deux causes vident
/// désormais cet aperçu — la purge des messages éphémères et la suppression —
/// et elles ne se disent pas pareil. Le client, lui, n'en connaissait qu'une
/// et affichait « Message expiré » pour les deux. D'où les deux marques que
/// ces tests tiennent : `lastMessageDeleted`, `lastMessageExpired`.
///
/// Trois chemins mènent au même aperçu, et les trois sont ici : la base
/// (legacy), le cache local (MLS), et le libellé à l'écran.

/// Lit un fichier du dépôt en normalisant ses fins de ligne : selon qu'il
/// vient d'être écrit ici ou d'un `checkout`, le même fichier arrive en LF ou
/// en CRLF.
String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

ConversationEntity _conv({
  String? apercu,
  DateTime? quand,
  bool supprime = false,
  bool expire = false,
}) =>
    ConversationEntity(
      id: 'c1',
      type: ConversationType.individual,
      participantIds: const ['u1', 'u2'],
      createdBy: 'u1',
      createdAt: DateTime.utc(2026, 9, 1),
      lastMessage: apercu,
      lastMessageAt: quand,
      lastMessageDeleted: supprime,
      lastMessageExpired: expire,
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // La règle, au singulier
  // ═══════════════════════════════════════════════════════════════════════
  group("L'aperçu dit pourquoi il est vide", () {
    test('vidé par une suppression : « supprimé », pas « expiré »', () {
      expect(
        _conv(apercu: '', quand: DateTime.utc(2026, 9, 15), supprime: true)
            .apercuEfface,
        ApercuEfface.supprime,
      );
    });

    test('vidé par la purge : « expiré »', () {
      expect(
        _conv(apercu: '', quand: DateTime.utc(2026, 9, 15), expire: true)
            .apercuEfface,
        ApercuEfface.expire,
      );
    });

    test('vide sans marque : aucune des deux', () {
      // Le cas MLS : le trigger d'aperçu retire `lastMessage` à chaque
      // message chiffré, sans qu'il se soit rien passé de tel. Répondre
      // « expiré » ici, c'est annoncer la disparition d'un message vivant.
      expect(
        _conv(apercu: '', quand: DateTime.utc(2026, 9, 15)).apercuEfface,
        ApercuEfface.aucun,
      );
    });

    test('un texte présent l\'emporte sur une marque périmée', () {
      // Tout écrivain d'aperçu efface les marques en écrivant le sien : un
      // aperçu non vide vient forcément d'un message plus récent. Si une
      // marque traîne quand même, c'est elle qui a tort.
      final c = _conv(
        apercu: 'bonjour',
        quand: DateTime.utc(2026, 9, 15),
        supprime: true,
      );
      expect(c.apercuEfface, ApercuEfface.aucun);
    });

    test('les deux marques à la fois : la suppression prime', () {
      // Elles s'excluent — poser l'une retire l'autre. Mais une base rattrapée
      // à la main peut porter les deux, et la règle doit alors rendre une
      // réponse, pas un coup de dé.
      expect(
        _conv(apercu: '', quand: DateTime.utc(2026, 9, 15),
                supprime: true, expire: true)
            .apercuEfface,
        ApercuEfface.supprime,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Les marques traversent la sérialisation
  // ═══════════════════════════════════════════════════════════════════════
  group('Les marques voyagent de la base à l\'entité', () {
    test('elles se lisent depuis le JSONB `data` de la conversation', () {
      // `_convFromRow` étale `data` à plat avant d'appeler `fromJson` : ce que
      // le serveur écrit dans `data` arrive ici tel quel.
      final m = ConversationModel.fromJson(const {
        'id': 'c1',
        'createdBy': 'u1',
        'lastMessage': '',
        'lastMessageDeleted': true,
      });
      expect(m.lastMessageDeleted, isTrue);
      expect(m.lastMessageExpired, isFalse);
      expect(m.toEntity().apercuEfface, ApercuEfface.supprime);
    });

    test('leur absence vaut « faux », sans rien casser', () {
      // Aucun backfill : les 19 conversations existantes n'ont ni l'une ni
      // l'autre, et doivent se lire inchangées.
      final m = ConversationModel.fromJson(const {
        'id': 'c1',
        'createdBy': 'u1',
        'lastMessage': 'bonjour',
      });
      expect(m.lastMessageDeleted, isFalse);
      expect(m.lastMessageExpired, isFalse);
    });

    test('un aller-retour par le cache Hive les conserve', () {
      // `getCachedConversations` repasse par `toJson`/`fromJson` : sans ce
      // relais, rouvrir l'application hors ligne ferait réapparaître le
      // libellé neutre à la place de « Message supprimé ».
      final avant = ConversationModel.fromEntity(
        _conv(apercu: '', quand: DateTime.utc(2026, 9, 15), expire: true),
      );
      final apres = ConversationModel.fromJson(avant.toJson());
      expect(apres.lastMessageExpired, isTrue);
      expect(apres.toEntity().apercuEfface, ApercuEfface.expire);
    });

    test('elles ne sont écrites que si elles sont vraies', () {
      // Le JSONB de production n'a pas à porter deux `false` sur chacune de
      // ses lignes.
      final json = ConversationModel.fromEntity(_conv(apercu: 'bonjour'))
          .toJson();
      expect(json.containsKey('lastMessageDeleted'), isFalse);
      expect(json.containsKey('lastMessageExpired'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Le cache local ne rouvre pas la fuite
  // ═══════════════════════════════════════════════════════════════════════
  group('Le cache de l\'appareil ne rend pas le texte supprimé', () {
    Map<String, dynamic> cache(
      String texte,
      DateTime quand, {
      bool supprime = false,
    }) =>
        {
          'id': 'm1',
          'content': texte,
          'createdAt': quand.toUtc().toIso8601String(),
          if (supprime) 'deletedForEveryone': true,
        };

    test('une conversation marquée ne va pas rechercher son texte', () {
      // Chemin legacy : la base vient d'être vidée, mais la copie locale garde
      // le texte jusqu'au prochain rechargement. Sans ce garde, la liste le
      // rendrait à l'écran — la fuite refermée en base, rouverte depuis
      // l'appareil.
      final t = DateTime.utc(2026, 9, 15, 12);
      var lectures = 0;
      final sortie = MessageRepositoryImpl.apercuDepuisCache(
        _conv(apercu: '', quand: t, supprime: true),
        () {
          lectures++;
          return [cache('le secret', t)];
        },
      );
      expect(sortie.lastMessage ?? '', isEmpty);
      expect(sortie.apercuEfface, ApercuEfface.supprime);
      expect(lectures, 0, reason: 'inutile de lire un cache qu\'on refusera');
    });

    test('un message caché marqué supprimé devient la marque, pas son texte',
        () {
      // Chemin MLS : le serveur ne porte AUCUNE marque — le trigger retire
      // `lastMessage` à chaque message chiffré, et la suppression n'écrit que
      // dans `mls_messages`. C'est le message caché lui-même qui le dit, la
      // passerelle lui ayant recollé `deletedForEveryone` avant la mise en
      // cache.
      final t = DateTime.utc(2026, 9, 15, 12);
      final sortie = MessageRepositoryImpl.apercuDepuisCache(
        _conv(apercu: '', quand: t),
        () => [cache('le secret', t, supprime: true)],
      );
      expect(sortie.lastMessage ?? '', isEmpty);
      expect(sortie.apercuEfface, ApercuEfface.supprime);
    });

    test('un message vivant donne toujours son texte', () {
      // Le garde ne doit pas coûter l'aperçu des discussions chiffrées
      // ordinaires, qui n'ont que lui.
      final t = DateTime.utc(2026, 9, 15, 12);
      final sortie = MessageRepositoryImpl.apercuDepuisCache(
        _conv(apercu: '', quand: t),
        () => [cache('bonjour', t)],
      );
      expect(sortie.lastMessage, 'bonjour');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Les écrivains d'aperçu — tenus par leur source
  // ═══════════════════════════════════════════════════════════════════════
  //
  // Ces tests ne vérifient pas qu'un calcul est juste : ils vérifient qu'il
  // n'a pas disparu. C'est la classe de panne visée — un chemin d'écriture
  // qui cesse en silence, sans erreur, sans journal, sans indice à l'écran.
  group('Le client vide l\'aperçu quand il supprime le dernier message', () {
    const chemin =
        'lib/features/messages/data/datasources/message_supabase_datasource.dart';

    test('la suppression pour tous touche aussi la conversation', () {
      final src = _source(chemin);
      expect(src.contains('_viderApercuSiDernier'), isTrue);
      // Il lui faut le `created_at` du message : c'est son égalité avec
      // `last_message_at` qui dit « c'était le dernier ».
      expect(src.contains("select('data, created_at')"), isTrue);
      expect(src.contains("select('data, last_message_at')"), isTrue);
    });

    test('elle pose la marque « supprimé » et retire l\'autre', () {
      final src = _source(chemin);
      expect(src.contains("data['lastMessage'] = '';"), isTrue);
      expect(src.contains('data[_kApercuSupprime] = true;'), isTrue);
      expect(src.contains('data.remove(_kApercuExpire);'), isTrue);
    });

    test('un message neuf efface les deux marques', () {
      // `_updateConversationLastMessage` recopie `...current` : sans ce
      // ménage, la liste annoncerait « Message supprimé » sous le texte du
      // message qu'on vient d'envoyer, pour toujours.
      final src = _source(chemin);
      expect(
        src.contains(
            'cle == _kApercuSupprime || cle == _kApercuExpire'),
        isTrue,
      );
    });
  });

  group('Le serveur pose et efface les marques aux mêmes endroits', () {
    const chemin =
        'supabase/migrations/20260915235900_apercu_dit_pourquoi_il_est_vide.sql';

    test('la purge dit « expiré » au lieu de laisser deviner', () {
      final sql = _source(chemin);
      expect(sql.contains("'lastMessageExpired', true"), isTrue);
      expect(sql.contains("c.data - 'lastMessageDeleted'"), isTrue);
    });

    test('le trigger MLS efface les deux marques avec l\'aperçu', () {
      // Une conversation legacy dont le dernier message est supprimé, puis
      // qui bascule vers MLS, afficherait sinon « Message supprimé » sous
      // chacun de ses messages chiffrés suivants.
      final sql = _source(chemin);
      expect(sql.contains("- 'lastMessage'"), isTrue);
      expect(sql.contains("- 'lastMessageDeleted'"), isTrue);
      expect(sql.contains("- 'lastMessageExpired'"), isTrue);
    });

    test('elle ne s\'expose à personne', () {
      final sql = _source(chemin);
      expect(
        sql.contains('REVOKE ALL ON FUNCTION public.purger_messages_expires()'),
        isTrue,
      );
    });
  });

  group('L\'écran distingue les deux causes', () {
    const chemin =
        'lib/features/messages/presentation/widgets/conversation_item.dart';

    test('les trois libellés existent, et chacun a sa cause', () {
      final src = _source(chemin);
      expect(src.contains('ApercuEfface.supprime => l10n.messageDeleted'),
          isTrue);
      expect(src.contains('ApercuEfface.expire => l10n.messageAutoDeleted'),
          isTrue);
      // Le repli des discussions chiffrées : vide sans marque, et pourtant il
      // s'est passé quelque chose. Avant, il se lisait « Message expiré ».
      expect(src.contains('l10n.lastMessageEncrypted'), isTrue);
      expect(src.contains('l10n.newConversation'), isTrue);
    });

    test('la marque passe avant le libellé de type', () {
      // Ni la suppression ni l'expiration ne touchent `lastMessageType` : une
      // photo supprimée continuait de s'annoncer « 📎 Photo », et une note
      // vocale gardait son micro.
      final src = _source(chemin);
      final marque = src.indexOf('final efface = _apercuEfface(conversation');
      final typeLabel = src.indexOf('String? typeLabel;');
      expect(marque, greaterThan(-1));
      expect(typeLabel, greaterThan(marque));
      expect(src.contains('efface == null &&'), isTrue);
    });
  });
}
