import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// « Supprimer mon compte » ne supprimait presque rien (2026-09-18) : DELETE
/// sur `users` sans policy DELETE (0 ligne, sans erreur), conversations
/// réservées à `created_by`, `groups.member_ids` vide partout. Le dialogue
/// promettait « toutes vos données supprimées définitivement ».
///
/// Ces tests lisent la migration, la Cloud Function, le client et les textes :
/// ils ne prouvent PAS que la base se comporte ainsi — c'est le banc
/// `tools/rls_tests/suppression_compte.sql` (50 cas, rejoué en production dans
/// un `BEGIN … ROLLBACK`). Ils gardent ce que le banc ne peut pas garder :
/// qu'un futur `CREATE OR REPLACE`, une colonne oubliée ou une réécriture du
/// client ne défasse pas discrètement ce qui a été établi.
///
/// Les assertions portent sur les FICHIERS de migration : la première est
/// appliquée en production depuis le 2026-09-19 ; 20260919204100 (appartenances
/// sans groupe) ne l'est pas encore — la DERNIÈRE définition de chaque fonction
/// fait foi, où qu'elle soit.

String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

const _migration =
    'supabase/migrations/20260918224100_suppression_de_compte_par_phases.sql';

/// Une fonction PostgreSQL n'a pas de « fichier source » : elle a un dernier
/// `CREATE OR REPLACE` gagnant. Un test qui vise le fichier de CRÉATION
/// continue de passer longtemps après que le corps a changé ailleurs.
String _derniereMigrationDefinissant(String motif) {
  final fichiers = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((f) => f.endsWith('.sql'))
      .toList()
    ..sort();
  final trouves = fichiers.where((f) => _source(f).contains(motif)).toList();
  if (trouves.isEmpty) {
    throw StateError('aucune migration ne definit « $motif »');
  }
  return trouves.last;
}

/// Le corps d'une fonction, du `CREATE OR REPLACE FUNCTION <nom>(` jusqu'au
/// `$function$;` qui la ferme.
String _corps(String sql, String nom) {
  // `StateError` et non `expect` : appelée à la DÉFINITION des groupes, hors de
  // tout `test`, où `expect` lève OutsideTestException et fait échouer le
  // chargement du fichier entier.
  final debut = sql.lastIndexOf('CREATE OR REPLACE FUNCTION $nom(');
  if (debut < 0) throw StateError('$nom n\'est pas définie');
  final fin = sql.indexOf('\$function\$;', debut);
  if (fin < debut) throw StateError('$nom n\'est pas refermée');
  return sql.substring(debut, fin);
}

void main() {
  final sql = _source(_migration);
  // La DERNIÈRE définition, pas celle du fichier de création : une fonction
  // PostgreSQL n'a pas de « fichier source », elle a un dernier
  // `CREATE OR REPLACE` gagnant. Son corps a été repris par 20260919204100
  // (appartenances sans groupe) ; lire l'original ferait passer ces tests
  // longtemps après que le corps réel a changé — et un remplacement ultérieur
  // qui perdrait un ajout ferait échouer ici, sans qu'aucune erreur ne se
  // voie en base. Motif `CREATE OR REPLACE` : un simple `REVOKE ... FUNCTION
  // private.purge_account(` ne définit rien.
  final purge = _corps(
    _source(
      _derniereMigrationDefinissant(
        'CREATE OR REPLACE FUNCTION private.purge_account(',
      ),
    ),
    'private.purge_account',
  );

  // ═══════════════════════════════════════════════════════════════════════
  // Couverture : chaque colonne d'identifiant SANS clé étrangère est traitée
  // ═══════════════════════════════════════════════════════════════════════
  group('couverture des colonnes d\'identifiant', () {
    // Relevé de production du 2026-09-18 : colonnes portant de vrais uid, sans
    // FK vers `users` — celles qu'un DELETE sur `users` ne peut pas atteindre.
    // Traitées par `private.purge_delete('public.<table>', p_uid, '<col>'…)`.
    const parPurgeDelete = <String, List<String>>{
      'group_invites': ['inviter_id', 'invitee_id'],
      'group_requests': ['requester_id'],
      'departs_groupe_officiel': ['user_id'],
      'mls_message_receipts': ['user_id'],
      'mls_message_reactions': ['user_id'],
      'mls_message_stars': ['user_id'],
      'mls_message_hidden': ['user_id'],
      'mls_message_mentions': ['user_id'],
      'mls_diagnostics': ['user_id'],
      'events': ['organizer_id'],
      'event_attendees': ['user_id'],
      'businesses': ['owner_id'],
      'friends': ['user_id', 'friend_id'],
      'friend_requests': ['sender_id', 'receiver_id'],
      'user_follows': ['follower_id', 'following_id'],
      'post_comments': ['author_id'],
      'post_likes': ['user_id'],
      'e2ee_devices': ['user_id'],
      'e2ee_key_transfers': ['user_id'],
      'e2ee_one_time_prekeys': ['user_id'],
      'e2ee_user_keys': ['user_id'],
      'e2ee_sender_key_distributions': ['sender_id', 'recipient_id'],
      'recipients': ['user_id'],
      'payment_accounts': ['user_id'],
      'notification_preferences': ['user_id'],
      'recent_searches': ['user_id'],
      'reminders': ['user_id'],
      'support_tickets': ['user_id'],
      'administrative_requests': ['user_id'],
      'creator_profiles': ['user_id'],
      'legal_acceptances': ['user_id'],
      'podcast_subscriptions': ['user_id'],
      'podcast_user_data': ['user_id'],
      'user_favorite_stickers': ['user_id'],
      'user_recent_stickers': ['user_id'],
      'user_sticker_packs': ['user_id'],
      'embassy_messages': ['user_id'],
      'activity_logs': ['user_id'],
      'auth_mappings': ['firebase_uid'],
      // Après la boucle sur les groupes : `group_members` n'a AUCUNE clé
      // étrangère vers `groups`, la boucle ne voit que les appartenances dont
      // le groupe existe (voir le test des appartenances sans groupe).
      'group_members': ['user_id'],
      'users': ['id'],
    };

    parPurgeDelete.forEach((table, colonnes) {
      test('$table : ${colonnes.join(', ')} passent par purge_delete', () {
        final appel = RegExp(
          "purge_delete\\('public\\.$table',\\s*p_uid((?:,\\s*'[a-z_]+')+)\\)",
        ).allMatches(purge);
        expect(appel, isNotEmpty, reason: '$table n\'est plus purgée');
        final cites = appel
            .expand((m) => RegExp("'([a-z_]+)'").allMatches(m.group(1)!))
            .map((m) => m.group(1)!)
            .toSet();
        for (final c in colonnes) {
          expect(cites, contains(c), reason: '$table.$c n\'est plus purgée');
        }
      });
    });

    // Traitées par des instructions écrites à la main (logique propre).
    const explicites = <String, List<String>>{
      'conversations': [
        'participant_ids',
        'created_by',
        'last_message_sender_id',
        "type = 'individual'",
      ],
      'messages': ['sender_id', 'senderPhotoUrl', 'editHistory', 'replyToMessageData'],
      'mls_messages': ['sender_id', 'ciphertext', 'is_deleted'],
      'mls_devices': ['user_id', 'revoked_at', 'mls_identity'],
      'groups': ['creator_id', 'creator_name'],
      'notifications': ['user_id', 'actor_id', 'senderId'],
      'business_boosts': ['user_id'],
      'business_reviews': ['user_id'],
      'business_posts': ['business_id'],
      'products': ['seller_id'],
      'group_pinned_items': ['pinned_by'],
    };
    explicites.forEach((table, marqueurs) {
      test('$table est traitée : ${marqueurs.join(', ')}', () {
        expect(purge, contains('public.$table'),
            reason: '$table n\'est plus touchée par la purge');
        for (final m in marqueurs) {
          expect(purge, contains(m), reason: '« $m » a disparu de la purge');
        }
      });
    });

    // Dette nommée : tables vides le 2026-09-18, colonnes NON traitées. La
    // liste ne doit que RÉTRÉCIR — chaque entrée doit rester écrite dans
    // l'en-tête de la migration, et aucune ne doit être purgée (sinon elle a
    // quitté la dette sans qu'on la raye).
    const nonTraitees = <String>[
      'admin_audit_logs.target_id',
      'content_reports.target_id',
      'reminders.target_id',
      'reports.reporter_id',
      'sticker_packs.creator_id',
      'heritage_collections.creatorId',
      'podcasts.host_id',
      'embassy_employees.linked_user_id',
      'business_reviews.helpful_by_user_ids',
      'audio_rooms.*',
    ];
    test('la dette est écrite dans l\'en-tête, et rien de ce qui est purgé n\'y traîne', () {
      final entete = sql.substring(0, sql.indexOf('CREATE TABLE'));
      for (final c in nonTraitees) {
        final table = c.split('.').first;
        final colonne = c.split('.').last;
        // Le nom de la table doit figurer dans la liste de l'en-tête…
        expect(entete, contains(table), reason: '$c n\'est plus listée');
        if (colonne != '*') {
          expect(entete, contains(colonne), reason: '$c n\'est plus listée');
        }
      }
      // …et une table de la dette qui n'est ni `reminders` ni
      // `business_reviews` (purgées par une AUTRE colonne) ne doit pas l'être.
      for (final c in nonTraitees) {
        final table = c.split('.').first;
        if (table == 'reminders' || table == 'business_reviews') continue;
        expect(purge, isNot(contains("public.$table'")),
            reason: '$table est purgée : la retirer de la dette');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Invariants de la purge
  // ═══════════════════════════════════════════════════════════════════════
  group('invariants de la purge', () {
    test('le profil part EN DERNIER : la cascade ne précède aucune étape explicite', () {
      final iProfil = purge.indexOf("purge_delete('public.users'");
      expect(iProfil, isPositive);
      // Toute autre suppression écrite dans la purge la précède.
      for (final m in RegExp(r"purge_delete\('public\.(\w+)'").allMatches(purge)) {
        if (m.group(1) == 'users') continue;
        expect(m.start, lessThan(iProfil),
            reason: '${m.group(1)} est purgée APRÈS le profil');
      }
    });

    test('la purge s\'annonce sous l\'identité du compte (garde des conversations)', () {
      // `conversations_guard_admin_fields` reconnaît un départ volontaire par
      // `firebase_uid()`. Sans identité, l'appelant est service_role (uid
      // NULL) et le garde ne passe que par un hasard de logique à trois
      // valeurs.
      expect(purge, contains("set_config(\n    'request.jwt.claims'"));
      expect(purge, contains("'firebase_uid', p_uid"));
      // …et l'identité de l'appelant est remise à la fin.
      expect(purge, contains("COALESCE(v_prev, '')"));
    });

    test('`editedAt` n\'est jamais retiré : `notifier_edition_message` en dépend', () {
      expect(purge, isNot(contains("- 'editedAt'")));
      expect(purge, isNot(contains("'editedAt'")),
          reason: 'toucher editedAt déclencherait une notification « message modifié »');
    });

    test('le protocole MLS n\'est pas amputé : ni commit ni Welcome des AUTRES', () {
      // Un commit supprimé casse la progression d'époque des autres membres.
      expect(purge, isNot(contains('DELETE FROM public.mls_commits')));
      expect(purge, isNot(contains('UPDATE public.mls_commits')));
      // Les messages MLS sont vidés comme « supprimer pour tous », pas
      // effacés : `reply_to_id` est NO ACTION, une réponse orphelinerait.
      expect(purge, isNot(contains('DELETE FROM public.mls_messages')));
      expect(purge, contains("ciphertext = '\\x'::bytea"));
    });

    test('un appareil MLS cité est gardé en pierre tombale, jamais supprimé', () {
      // NO ACTION depuis mls_commits.sender_device_id et
      // mls_messages.sender_device_id : supprimer un appareil cité échoue.
      expect(purge, contains('NOT EXISTS (SELECT 1 FROM public.mls_commits'));
      expect(purge, contains('NOT EXISTS (SELECT 1 FROM public.mls_messages'));
    });

    test('un groupe dont on est le dernier membre est dissous COMME delete_group', () {
      expect(purge, contains('DELETE FROM public.conversations WHERE group_id = v_g.id::text'));
      expect(purge, contains('DELETE FROM public.group_members WHERE group_id = v_g.id'));
      expect(purge, contains('DELETE FROM public.groups WHERE id = v_g.id'));
      // Un groupe OFFICIEL n'est jamais dissous ni transmis.
      expect(purge, contains('NOT v_g.is_official'));
    });

    test('les appartenances SANS groupe partent aussi, par un DELETE par uid', () {
      // `group_members` n'a aucune clé étrangère vers `groups` : un groupe
      // supprimé, ou hérité de Firestore, laisse ses lignes. La boucle sur les
      // groupes part de `groups` et ne les voit pas. Trouvé le 2026-09-19 par la
      // répétition sur un compte RÉEL : 7 lignes gardaient l'uid pour toujours,
      // que le banc fictif ne pouvait pas voir — ses groupes existent tous.
      final appel = purge.indexOf(
        "purge_delete('public.group_members', p_uid, 'user_id')",
      );
      expect(appel, isPositive, reason: 'les appartenances orphelines ne sont plus purgées');
      // Après la boucle : les vraies appartenances sont déjà parties, il ne
      // reste que les orphelines — et avant le profil.
      expect(appel, greaterThan(purge.indexOf('END LOOP;')));
      expect(appel, lessThan(purge.indexOf("purge_delete('public.users'")));
      expect(purge, contains("'appartenances_orphelines'"));
    });

    test('les boosts partent avant le commerce (NO ACTION)', () {
      expect(purge.indexOf('DELETE FROM public.business_boosts'),
          lessThan(purge.indexOf("purge_delete('public.businesses'")));
    });

    test('le compte Supabase Auth est supprimé, avec son mapping', () {
      // L'e-mail vit dans auth.users, et l'échange Firebase retrouve
      // l'utilisateur PAR E-MAIL : sans cela une réinscription se rattache à
      // l'ancienne ligne.
      expect(purge, contains('DELETE FROM auth.users'));
      expect(purge, contains("purge_delete('public.auth_mappings'"));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Ce qui interdit une suppression
  // ═══════════════════════════════════════════════════════════════════════
  group('refus', () {
    final blocage = _corps(sql, 'private.suppression_bloquee_pour');

    test('le compte plateforme est refusé', () {
      expect(blocage, contains('g.is_official'));
      expect(blocage, contains("'compte_plateforme'"));
    });

    test('l\'historique financier est refusé, pas effacé ni gardé en silence', () {
      expect(blocage, contains("'obligations_financieres'"));
      for (final t in [
        'orders',
        'escrow_transactions',
        'transactions',
        'tips',
        'room_tickets',
        'card_credit_requests',
        'debit_requests',
      ]) {
        expect(blocage, contains('public.$t'), reason: '$t n\'est plus vérifiée');
      }
    });

    test('un compte devenu bloquant n\'est PAS réclamé (Firebase intact)', () {
      final claim = _corps(sql, 'public.claim_due_account_deletions');
      expect(claim, contains('private.suppression_bloquee_pour'));
      // Le passage en `blocked` précède la réclamation.
      expect(claim.indexOf("status = 'blocked'"),
          lessThan(claim.indexOf("status = 'deleting'")));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Droits
  // ═══════════════════════════════════════════════════════════════════════
  group('droits', () {
    test('le client demande et annule, jamais ne réclame ni ne purge', () {
      expect(sql, contains('REVOKE ALL ON FUNCTION public.request_account_deletion() FROM PUBLIC, anon;'));
      expect(sql, contains('GRANT EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;'));
      expect(sql, contains('REVOKE ALL ON FUNCTION public.cancel_account_deletion() FROM PUBLIC, anon;'));
      // Supabase accorde EXECUTE nommément à `authenticated` : sans le
      // révoquer explicitement, n'importe quel client réclamerait ou
      // purgerait n'importe quel compte.
      expect(sql, contains('REVOKE ALL ON FUNCTION public.claim_due_account_deletions(integer) FROM PUBLIC, anon, authenticated;'));
      expect(sql, contains('GRANT EXECUTE ON FUNCTION public.claim_due_account_deletions(integer) TO service_role;'));
      expect(sql, contains('REVOKE ALL ON FUNCTION public.complete_account_deletion(text) FROM PUBLIC, anon, authenticated;'));
      expect(sql, contains('GRANT EXECUTE ON FUNCTION public.complete_account_deletion(text) TO service_role;'));
      expect(sql, contains('REVOKE ALL ON FUNCTION private.purge_account(text) FROM PUBLIC, anon, authenticated;'));
    });

    test('la table ne s\'écrit pas depuis le client et cache ses colonnes internes', () {
      expect(sql, contains('REVOKE ALL ON TABLE public.account_deletion_requests FROM PUBLIC, anon, authenticated;'));
      final octroi = RegExp(r'GRANT SELECT \(([^)]*)\)\s+ON public\.account_deletion_requests')
          .firstMatch(sql)!
          .group(1)!;
      for (final interne in ['last_error', 'restore', 'summary']) {
        expect(octroi, isNot(contains(interne)),
            reason: '$interne doit rester interne');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Publications masquées pendant le délai : la DERNIÈRE définition compte
  // ═══════════════════════════════════════════════════════════════════════
  group('masquage pendant le délai', () {
    // Ces deux helpers sont remplacés par CREATE OR REPLACE au gré des
    // migrations. Si la dernière définition perd la clause, les publications
    // d'un compte désactivé redeviennent visibles — sans aucune erreur.
    for (final nom in [
      'private.peut_voir_publication_pour',
      'private.peut_voir_story_pour',
    ]) {
      test('la dernière définition de $nom lit account_deletion_requests', () {
        final chemin = _derniereMigrationDefinissant('FUNCTION $nom(');
        final corps = _corps(_source(chemin), nom);
        expect(corps, contains('account_deletion_requests'),
            reason: '$chemin remplace $nom sans la clause « compte en suppression »');
        expect(corps, contains("'pending', 'deleting', 'blocked'"));
      });
    }

    test('l\'auteur voit toujours ses propres publications', () {
      final pub = _corps(sql, 'private.peut_voir_publication_pour');
      expect(pub, contains('p_viewer IS DISTINCT FROM p_author'));
      final story = _corps(sql, 'private.peut_voir_story_pour');
      // Dans les stories, « moi-même » est tranché AVANT la clause.
      expect(story.indexOf('p_viewer = p_author'),
          lessThan(story.indexOf('account_deletion_requests')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // La Cloud Function : Firebase d'abord, et jamais « base muette = personne »
  // ═══════════════════════════════════════════════════════════════════════
  group('finalizeAccountDeletions', () {
    final js = _source('functions/index.js');
    final debut = js.indexOf('exports.finalizeAccountDeletions');
    final corps = js.substring(debut, js.indexOf('// BUSINESS REVIEWS', debut));
    final helper = _source('functions/supabase.js');

    test('le compte Firebase est supprimé AVANT la purge', () {
      // Une fois le compte Firebase supprimé, plus aucun échange de jeton ne
      // peut ressusciter la ligne `users` que la purge vient d'effacer.
      expect(corps.indexOf('admin.auth().deleteUser(uid)'),
          lessThan(corps.indexOf('completeAccountDeletion(uid)')));
    });

    test('« déjà supprimé » n\'est pas une erreur (reprise d\'une purge en échec)', () {
      expect(corps, contains('auth/user-not-found'));
    });

    test('une base muette n\'est pas « personne à traiter »', () {
      expect(corps, contains('uids === null'));
      expect(helper, contains('return null;'));
      // `[]` (personne) et `null` (muette) sont deux réponses différentes.
      expect(helper, contains('Array.isArray(rows) ? rows.map((r) => r.uid).filter(Boolean) : null'));
    });

    test('elle est planifiée', () {
      expect(corps, contains('.schedule("every 1 hours")'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Le client ne supprime plus rien lui-même
  // ═══════════════════════════════════════════════════════════════════════
  group('client', () {
    final ds = _source('lib/features/auth/data/datasources/auth_remote_datasource.dart');

    test('le compte Firebase n\'est plus supprimé côté client', () {
      // Il l'est par la Cloud Function, à l'échéance : la personne doit
      // pouvoir se reconnecter pour annuler.
      expect(ds, isNot(contains('user.delete()')));
      expect(ds, isNot(contains(".from('users').delete()")));
    });

    test('la demande passe par la RPC, pas par un DELETE que RLS viderait en silence', () {
      expect(ds, contains("rpc('request_account_deletion')"));
      expect(ds, contains("rpc('cancel_account_deletion')"));
    });

    test('l\'annulation lève quand rien n\'est annulé (pas de succès à vide)', () {
      expect(ds, contains('if (ok != true)'));
    });

    test('la lecture du statut nomme ses colonnes et exige une session', () {
      // Seules les colonnes accordées se lisent : un `select *` échoue en 42501.
      expect(ds, contains(".select('status, execute_at')"));
      // Sans session, RLS rend zéro ligne — exactement ce que rendrait un
      // compte sans demande.
      expect(ds, contains('ensureReadableSession()'));
    });

    test('le routeur garde la porte, et l\'écran d\'annulation existe', () {
      final routeur = _source('lib/core/router/app_router.dart');
      expect(routeur, contains("'/account-deletion'"));
      expect(routeur, contains('accountDeletionStatusProvider'));
      // Une lecture ratée laisse entrer : `valueOrNull`, jamais `.value`, qui
      // relance l'erreur en Riverpod 2.
      expect(routeur, contains('ref.read(accountDeletionStatusProvider).valueOrNull'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Les textes disent ce que fait la base
  // ═══════════════════════════════════════════════════════════════════════
  group('textes', () {
    final fr = jsonDecode(_source('lib/l10n/app_fr.arb')) as Map<String, dynamic>;
    final en = jsonDecode(_source('lib/l10n/app_en.arb')) as Map<String, dynamic>;

    test('le dialogue annonce le délai, l\'annulation et l\'anonymisation', () {
      final f = fr['deleteAccountWarning'] as String;
      final e = en['deleteAccountWarning'] as String;
      for (final t in [f, e]) {
        expect(t, contains('30'), reason: 'le délai de grâce doit être dit');
      }
      expect(f, contains('Compte supprimé'));
      expect(e, contains('Deleted account'));
      // L'ancienne promesse, fausse, ne revient pas.
      expect(f, isNot(contains('Toutes vos données seront supprimées définitivement')));
      expect(e, isNot(contains('All your data will be permanently deleted')));
    });

    test('les nouvelles clés existent dans les DEUX langues', () {
      final cles = fr.keys.where((k) => k.startsWith('accountDeletion')).toSet();
      expect(cles, isNotEmpty);
      expect(en.keys.where((k) => k.startsWith('accountDeletion')).toSet(), cles);
    });

    test('la date est un paramètre des deux messages qui la portent', () {
      for (final langue in [fr, en]) {
        for (final cle in ['accountDeletionScheduled', 'accountDeletionPendingBody']) {
          expect(langue[cle] as String, contains('{date}'));
          expect(langue['@$cle'], isNotNull, reason: '@$cle déclare le paramètre');
        }
      }
    });
  });
}
