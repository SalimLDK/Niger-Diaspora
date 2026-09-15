import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../src/rust/api/mls.dart';
import '../../services/e2ee/device_label.dart';
import '../../services/e2ee/stable_device_id.dart';
import '../../services/supabase_auth_bridge.dart';
import 'bytea.dart' as bytea_codec;
import 'mls_engine_provider.dart';
import 'mls_notification_preview.dart';

/// Une ligne de `mls_devices`.
class MlsDeviceRecord {
  final String id;
  final String userId;
  final String stableId;
  final String name;
  final String platform;
  final String mlsIdentity;

  /// Clé publique de signature MLS, telle que publiée par l'appareil.
  ///
  /// Publique par construction — elle sert à valider ce qu'il émet. C'est
  /// elle qu'un serveur devrait substituer pour se faire passer pour
  /// quelqu'un, et donc elle qu'on compare hors bande
  /// ([MlsCodeSecurite.empreinteAppareil]). Vide si la ligne est trop
  /// ancienne pour l'avoir : l'écran affiche alors « code indisponible »
  /// plutôt qu'un code faux.
  final Uint8List signatureKey;

  final DateTime createdAt;
  final DateTime lastSeenAt;
  final DateTime? revokedAt;

  /// Vrai pour la ligne de l'appareil qui lit la liste.
  final bool estCetAppareil;

  MlsDeviceRecord({
    required this.id,
    required this.userId,
    required this.stableId,
    required this.name,
    required this.platform,
    required this.mlsIdentity,
    Uint8List? signatureKey,
    required this.createdAt,
    required this.lastSeenAt,
    this.revokedAt,
    this.estCetAppareil = false,
  }) : signatureKey = signatureKey ?? sansCle;

  /// Pas de clé publiée. L'écran doit dire « code indisponible » plutôt que
  /// de calculer un code sur du vide — il serait le MÊME pour tous les
  /// appareils, et deux personnes concluraient à tort qu'elles sont
  /// vérifiées.
  static final Uint8List sansCle = Uint8List(0);

  bool get estRevoque => revokedAt != null;

  factory MlsDeviceRecord.fromRow(
    Map<String, dynamic> row, {
    String? stableIdCourant,
  }) {
    final stableId = row['stable_id'] as String? ?? '';
    return MlsDeviceRecord(
      id: row['id'] as String,
      userId: row['user_id'] as String? ?? '',
      stableId: stableId,
      name: row['name'] as String? ?? '',
      platform: row['platform'] as String? ?? '',
      mlsIdentity: row['mls_identity'] as String? ?? '',
      signatureKey: row['signature_key'] is String
          ? bytea_codec.depuisBytea(row['signature_key'] as String)
          : MlsDeviceRecord.sansCle,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      lastSeenAt: DateTime.tryParse(row['last_seen_at'] as String? ?? '') ?? DateTime.now(),
      revokedAt: DateTime.tryParse(row['revoked_at'] as String? ?? ''),
      estCetAppareil: stableIdCourant != null && stableId == stableIdCourant,
    );
  }
}

/// Registre d'appareils MLS (plan MLS, phase 2) : une ligne `mls_devices` par
/// (compte, appareil), et une réserve de KeyPackages publiée pour chacune.
///
/// Ce que le chantier Signal a appris, appliqué ici :
/// - **`ensureAuthenticated()` avant toute écriture ET toute lecture** — sous
///   `anon`, une lecture rend 0 ligne sans erreur, et l'app conclut à tort
///   qu'il n'y a rien à faire ;
/// - **réessais** au démarrage (le pont de session Supabase n'est pas prêt
///   pendant les premières secondes) ;
/// - **le motif d'échec s'écrit en base** (`mls_diagnostics`), jamais dans un
///   journal que le build release n'émet pas ;
/// - **aucun secret ne sort du moteur Rust** : ce service ne manipule que la
///   clé publique, la credential et des KeyPackages, conçus pour être publiés.
class MlsDeviceRegistry {
  MlsDeviceRegistry({
    required Future<Moteur> Function(String userId) moteur,
    SupabaseClient? client,
    Future<String> Function(String userId)? stableId,
    Future<String> Function()? libelle,
    Future<bool> Function()? ensureAuth,
    String? platforme,
  })  : _moteur = moteur,
        _clientOptionnel = client,
        _stableId = stableId ?? stableDeviceId,
        _libelle = libelle ?? currentDeviceLabel,
        _ensureAuth = ensureAuth ?? SupabaseAuthBridge.instance.ensureAuthenticated,
        _platforme = platforme ?? plateformeCourante();

  final Future<Moteur> Function(String userId) _moteur;
  final SupabaseClient? _clientOptionnel;
  final Future<String> Function(String userId) _stableId;
  final Future<String> Function() _libelle;
  final Future<bool> Function() _ensureAuth;
  final String _platforme;

  SupabaseClient get _client => _clientOptionnel ?? Supabase.instance.client;

  /// Suite de chiffrement du moteur (`CIPHERSUITE` dans `engine.rs`).
  static const cipherSuite = 'MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519';

  /// En dessous de ce nombre de paquets disponibles, on en regénère un lot.
  static const seuilRecharge = 10;
  static const lotRecharge = 50;
  static const validitePaquet = Duration(days: 90);
  static const validiteDernierRecours = Duration(days: 365);

  /// Décision de réapprovisionnement, isolée pour être testée : tout ou rien,
  /// jamais « juste ce qui manque » — un paquet coûte peu, un aller-retour
  /// serveur coûte plus.
  @visibleForTesting
  static int aGenerer(int disponibles) =>
      disponibles >= seuilRecharge ? 0 : lotRecharge;

  static String plateformeCourante() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'desktop';
  }

  /// Enregistre (ou rafraîchit) l'appareil courant et réapprovisionne ses
  /// KeyPackages. À appeler à chaque connexion. Idempotent.
  Future<MlsDeviceRecord> ensureRegistered(String userId) async {
    if (!await _ensureAuth()) {
      throw StateError('Session non établie — enregistrement différé');
    }
    final moteur = await _moteur(userId);
    final stableId = await _stableId(userId);
    final nom = await _libelle();
    final identite = moteur.identite();

    // Identité MLS déjà enregistrée pour cet appareil, AVANT de l'écraser.
    // Une réinstallation en produit une neuve (§ 5.6) : il faut le savoir
    // ici, c'est le seul endroit qui voit les deux.
    final precedente = await _client
        .from('mls_devices')
        .select('id, mls_identity')
        .eq('user_id', userId)
        .eq('stable_id', stableId)
        .maybeSingle();

    final ligne = await _client
        .from('mls_devices')
        .upsert(
          {
            'user_id': userId,
            'stable_id': stableId,
            'name': nom,
            'platform': _platforme,
            'mls_identity': identite,
            'signature_key': versBytea(moteur.cleSignaturePublique()),
            'credential': versBytea(moteur.credential()),
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id,stable_id',
        )
        .select()
        .single();

    final appareil = MlsDeviceRecord.fromRow(ligne, stableIdCourant: stableId);
    if (appareil.estRevoque) {
      // Un appareil révoqué depuis un autre téléphone ne se réenregistre pas
      // tout seul : ce serait défaire la révocation. Il reste visible, sans
      // paquets, jusqu'à ce que l'utilisateur en décide autrement.
      await _diagnostic(userId, 'appareil_revoque_au_demarrage', appareil.id);
      return appareil;
    }

    // Réinstallation : l'identité MLS a changé, mais les KeyPackages publiés
    // sont ceux de l'installation d'AVANT — leurs secrets privés sont partis
    // avec l'ancienne base, et ils portent l'ancienne clé de signature.
    //
    // Les laisser en place est le pire des trois cas possibles : le compteur
    // de réapprovisionnement les voit (51 ≥ 10, rien à faire), un membre en
    // réclame un, et l'ajout **échoue** — la clé est déjà dans l'arbre, celle
    // de l'ancienne installation qui y siège encore. Trouvé par le banc de la
    // phase 3 le 2026-09-15 : trois cas sur douze tombaient dessus, tous avec
    // le même `CreateCommitError`, sans que rien ne désigne la cause.
    final identiteAvant = (precedente?['mls_identity'] as String?) ?? '';
    if (identiteAvant.isNotEmpty && identiteAvant != identite) {
      await _client.from('mls_key_packages').delete().eq('device_id', appareil.id);
      await _diagnostic(userId, 'identite_mls_changee', appareil.id);
      debugPrint('MlsDeviceRegistry: identité MLS changée, KeyPackages purgés');
    }

    // L'isolate de notification ne peut pas recalculer cet identifiant : il
    // vient d'un `MethodChannel` (le SSAID), muet dans un isolate frais. On le
    // dépose ici, au seul endroit qui le connaît de façon sûre.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MlsNotificationPreview.cleStableId(userId), stableId);
    } catch (e) {
      // Sans lui, les notifications retombent sur l'aperçu générique — c'est
      // dégradé, jamais cassé, et ça ne doit pas faire échouer l'inscription.
      debugPrint('MlsDeviceRegistry: identifiant non mémorisé ($e)');
    }

    await _reapprovisionner(moteur, appareil.id, userId);
    return appareil;
  }

  /// Comme [ensureRegistered], avec réessais : le pont de session Supabase
  /// met quelques secondes à s'établir au démarrage, et le premier échange
  /// d'un compte neuf échoue toujours une fois. Même profil que
  /// `KeyManagerService._publishWithRetry`.
  Future<MlsDeviceRecord?> ensureRegisteredWithRetry(
    String userId, {
    int tentatives = 4,
  }) async {
    Object? derniere;
    for (var essai = 1; essai <= tentatives; essai++) {
      try {
        return await ensureRegistered(userId);
      } catch (e) {
        derniere = e;
        debugPrint('MlsDeviceRegistry: tentative $essai/$tentatives ($e)');
        if (essai < tentatives) {
          await Future<void>.delayed(Duration(seconds: essai * 3));
        }
      }
    }
    await _diagnostic(
      userId,
      'enregistrement_echoue',
      null,
      detail: {'erreur': _codeErreur(derniere)},
    );
    return null;
  }

  Future<void> _reapprovisionner(Moteur moteur, String deviceId, String userId) async {
    final maintenant = DateTime.now().toUtc();
    final lignes = await _client
        .from('mls_key_packages')
        .select('id, is_last_resort')
        .eq('device_id', deviceId)
        .isFilter('used_at', null)
        .gt('expires_at', maintenant.toIso8601String());
    final rows = (lignes as List).cast<Map<String, dynamic>>();
    final disponibles = rows.where((r) => r['is_last_resort'] != true).length;
    final dernierRecours = rows.any((r) => r['is_last_resort'] == true);

    final n = aGenerer(disponibles);
    final aInserer = <Map<String, dynamic>>[];
    if (n > 0) {
      final paquets = await moteur.creerKeyPackages(n: n, dernierRecours: false);
      for (final p in paquets) {
        aInserer.add({
          'device_id': deviceId,
          'key_package': versBytea(p),
          'cipher_suite': cipherSuite,
          'is_last_resort': false,
          'expires_at': maintenant.add(validitePaquet).toIso8601String(),
        });
      }
    }
    if (!dernierRecours) {
      final p = (await moteur.creerKeyPackages(n: 1, dernierRecours: true)).first;
      aInserer.add({
        'device_id': deviceId,
        'key_package': versBytea(p),
        'cipher_suite': cipherSuite,
        'is_last_resort': true,
        'expires_at': maintenant.add(validiteDernierRecours).toIso8601String(),
      });
    }
    if (aInserer.isEmpty) return;
    await _client.from('mls_key_packages').insert(aInserer);
    debugPrint('MlsDeviceRegistry: ${aInserer.length} KeyPackages publiés');
  }

  /// Les appareils du compte, l'appareil courant en tête.
  Future<List<MlsDeviceRecord>> myDevices(String userId) async {
    if (!await _ensureAuth()) {
      throw StateError('Session non établie');
    }
    final stableId = await _stableId(userId);
    final rows = await _client
        .from('mls_devices')
        .select()
        .eq('user_id', userId)
        .order('last_seen_at', ascending: false);
    final liste = (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => MlsDeviceRecord.fromRow(r, stableIdCourant: stableId))
        .toList();
    liste.sort((a, b) {
      if (a.estCetAppareil != b.estCetAppareil) return a.estCetAppareil ? -1 : 1;
      return b.lastSeenAt.compareTo(a.lastSeenAt);
    });
    return liste;
  }

  /// Révoque un appareil : plus de KeyPackages (trigger), et il ne se
  /// réenregistre pas seul. Le retrait cryptographique des groupes (Remove +
  /// commit) vient en phase 7.
  Future<void> revoke(String deviceId) async {
    if (!await _ensureAuth()) throw StateError('Session non établie');
    final touchees = await _client
        .from('mls_devices')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', deviceId)
        .select('id');
    // Un `update` que le RLS refuse ne lève pas : il touche zéro ligne, et
    // l'écran annonce « appareil révoqué » alors que rien n'a bougé. C'est la
    // 6e forme des échecs muets de Supabase, et le banc l'a reproduite le
    // 2026-09-15 (un compte tentant de révoquer l'appareil d'un autre).
    if ((touchees as List).isEmpty) {
      throw StateError('Révocation refusée : cet appareil n\'est pas le vôtre');
    }
  }

  Future<void> rename(String deviceId, String nom) async {
    if (!await _ensureAuth()) throw StateError('Session non établie');
    await _client.from('mls_devices').update({'name': nom.trim()}).eq('id', deviceId);
  }

  Future<void> _diagnostic(
    String userId,
    String event,
    String? deviceId, {
    Map<String, dynamic>? detail,
  }) async {
    try {
      await _client.from('mls_diagnostics').insert({
        'user_id': userId,
        if (deviceId != null) 'device_id': deviceId,
        'event': event,
        if (detail != null) 'detail': detail,
      });
    } catch (e) {
      // Le diagnostic ne doit jamais aggraver la panne qu'il décrit.
      debugPrint('MlsDeviceRegistry: diagnostic non écrit ($e)');
    }
  }

  /// Un code, pas un message : `mls_diagnostics` ne porte jamais de contenu.
  static String _codeErreur(Object? e) {
    if (e == null) return 'inconnue';
    final texte = e.toString();
    final code = RegExp(r'[A-Za-z_]+').firstMatch(texte)?.group(0) ?? 'inconnue';
    return code.length > 40 ? code.substring(0, 40) : code;
  }

  /// Encodage `bytea` de PostgREST. L'implémentation vit dans `bytea.dart`,
  /// partagée avec le transport : deux copies auraient divergé, et un `bytea`
  /// mal encodé ne se voit qu'à la lecture, longtemps après l'écriture.
  @visibleForTesting
  static String versBytea(Uint8List octets) => bytea_codec.versBytea(octets);

  @visibleForTesting
  static Uint8List depuisBytea(String hex) => bytea_codec.depuisBytea(hex);
}

/// La clé publique de signature publiée pour une identité MLS.
///
/// Sert au scan d'un code de sécurité (phase 7) : le QR porte l'identité de
/// l'appareil d'en face, il faut aller voir ce que le serveur, lui, sert pour
/// cette identité-là — c'est la comparaison des deux qui détecte une
/// substitution.
///
/// Un appareil **révoqué** est traité comme inconnu : comparer son code
/// donnerait « vérifié » sur un appareil qui ne peut plus rien lire, ce qui
/// ne veut rien dire.
extension MlsDeviceLookup on MlsDeviceRegistry {
  Future<Uint8List?> cleDeIdentite(String mlsIdentity) async {
    // Sans session établie, la lecture part en `anon` et rend 0 ligne SANS
    // erreur : le scan conclurait « appareil inconnu » sur un appareil qui
    // existe.
    if (!await _ensureAuth()) return null;
    final ligne = await _client
        .from('mls_devices')
        .select('signature_key, revoked_at')
        .eq('mls_identity', mlsIdentity)
        .maybeSingle();
    if (ligne == null || ligne['revoked_at'] != null) return null;
    final brut = ligne['signature_key'];
    return brut is String ? bytea_codec.depuisBytea(brut) : null;
  }
}

final mlsDeviceRegistryProvider = Provider<MlsDeviceRegistry>((ref) {
  // `ref.read` dans une fermeture, pas `ref.watch` : le registre ne se
  // reconstruit pas quand le moteur est (re)créé — même règle que le moteur.
  return MlsDeviceRegistry(
    moteur: (userId) => ref.read(mlsEngineProvider(userId).future),
  );
});

/// Les appareils MLS d'un compte, pour l'écran « Appareils ».
final mlsDevicesProvider =
    FutureProvider.autoDispose.family<List<MlsDeviceRecord>, String>((ref, userId) {
  return ref.watch(mlsDeviceRegistryProvider).myDevices(userId);
});
