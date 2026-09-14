import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou contre le retour de l'accès Supabase non authentifié dans la
/// gestion des clés E2EE.
///
/// Ce qu'il a coûté, mesuré en production le 2026-09-14 : **aucun** message
/// `encryptionLevel = 'e2ee'` en base — 89 en repli AES, 0 en Signal — alors
/// que les 35 comptes avaient tous publié leurs clés, que les identifiants
/// concordaient et que la RLS autorisait la lecture. Rien ne clochait dans les
/// données. Un mois de chiffrement de bout en bout perdu, sans une seule ligne
/// d'erreur nulle part.
///
/// La cause tenait à une dissymétrie d'une ligne : `ensureAuthenticated()`
/// gardait les trois ÉCRITURES (publication des clés, des OTP, republication)
/// depuis le 2026-07-17, et **aucune des LECTURES**. Or les policies des tables
/// E2EE sont réservées au rôle `authenticated` : un client encore `anon` — la
/// fenêtre du démarrage, avant que le pont de session Supabase réponde — lit
/// zéro ligne **sans erreur**. `getActiveDevices` rendait donc une liste vide,
/// indiscernable de « ce compte n'a jamais publié ses clés » : X3DH n'était
/// même pas tenté, et l'envoi retombait en AES. Les écritures restant gardées,
/// les tables paraissaient impeccables pendant que plus rien ne chiffrait.
///
/// C'est la 7e forme d'échec muet du dépôt : *la requête réussit à vide*.
/// Un test de comportement ne l'aurait pas attrapée — il faudrait un vrai
/// client anon face à une vraie RLS. Ce test lit donc la source et vérifie une
/// règle de structure : **toute méthode qui touche `_supabase` passe d'abord
/// par une garde de session.**
///
/// Limite assumée : il ne vérifie pas que la garde est au BON endroit dans la
/// méthode, seulement qu'elle y est. C'est volontaire — la version qui
/// vérifierait l'ordre serait un analyseur syntaxique, pas un test.
void main() {
  const fichier = 'lib/core/services/e2ee/key_manager_service.dart';

  /// Méthodes autorisées à toucher Supabase sans garde, avec la raison.
  /// Cette liste ne peut que rétrécir : n'y ajoutez rien sans raison écrite.
  const exceptions = <String, String>{
    // Déconnexion : rétablir la session qu'on est en train de démonter serait
    // absurde. Si l'effacement serveur échoue faute de session, le suivant
    // repassera dessus — et les clés locales, elles, sont bien effacées.
    'clearAllKeys': 'chemin de déconnexion, la session part justement',
  };

  /// Les deux gardes acceptables. La bornée pour les lectures (elles ont un
  /// repli, geler l'écran serait pire), la non bornée pour les écritures
  /// (elles n'en ont pas).
  final gardes = RegExp(
    r'ensureReadableSession\(\)|ensureAuthenticated\(\)',
  );

  /// Début d'une méthode de la classe : exactement deux espaces d'indentation,
  /// un type, un nom, une parenthèse. Deux espaces suffisent à exclure le
  /// corps des méthodes, indenté d'au moins quatre.
  ///
  /// Le refus de tête n'est pas cosmétique : sans lui, `  return Machin(` du
  /// provider en haut de fichier passe pour une déclaration, sa tranche avale
  /// le champ `_supabase` de la classe, et le test crie sur une méthode qui
  /// n'existe pas.
  final debutMethode = RegExp(
    r'^  (?!return\b|await\b|if\b|for\b|while\b|else\b|throw\b|yield\b)'
    r'(?:static\s+)?[A-Za-z_][\w<>,?\s.]*\s+([A-Za-z_]\w*)\s*\(',
  );

  test('toute méthode touchant Supabase passe par une garde de session', () {
    final lignes = File(fichier).readAsLinesSync();

    // Découpage en méthodes : chaque déclaration ouvre une tranche, close par
    // la déclaration suivante.
    final debuts = <int, String>{};
    for (var i = 0; i < lignes.length; i++) {
      final m = debutMethode.firstMatch(lignes[i]);
      if (m != null) debuts[i] = m.group(1)!;
    }

    expect(
      debuts,
      isNotEmpty,
      reason:
          'Aucune méthode reconnue dans $fichier : le découpage est cassé, '
          'donc ce test ne garde plus rien. Corrigez-le avant de le croire.',
    );

    final index = debuts.keys.toList()..sort();
    final coupables = <String>[];
    var touchentSupabase = 0;

    for (var k = 0; k < index.length; k++) {
      final debut = index[k];
      final fin = (k + 1 < index.length) ? index[k + 1] : lignes.length;
      final nom = debuts[debut]!;
      final corps = lignes.sublist(debut, fin).join('\n');

      if (!corps.contains('_supabase')) continue;
      touchentSupabase++;

      if (exceptions.containsKey(nom)) continue;
      if (!gardes.hasMatch(corps)) {
        coupables.add('$nom (ligne ${debut + 1})');
      }
    }

    // Sans ce filet, une régression du découpage rendrait le test vert en
    // n'examinant plus rien — exactement le genre de garde qui ment.
    expect(
      touchentSupabase,
      greaterThanOrEqualTo(8),
      reason:
          'Seulement $touchentSupabase méthode(s) vue(s) touchant Supabase '
          'dans $fichier. Le découpage a probablement cessé de fonctionner.',
    );

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces méthodes lisent ou écrivent Supabase sans garde de session. '
          'Sous RLS, une lecture non authentifiée rend ZÉRO ligne sans lever : '
          'le résultat vide se confond alors avec « ce compte n\'a pas de '
          'clés », et tout le chiffrement Signal retombe en AES sans que rien '
          'ne le signale (mesuré le 2026-09-14). Ajoutez '
          'SupabaseAuthBridge.instance.ensureReadableSession() pour une '
          'lecture, .ensureAuthenticated() pour une écriture.\n'
          'Coupables : ${coupables.join(', ')}',
    );
  });

  test('les lectures utilisent la variante bornée, les écritures non', () {
    final source = File(fichier).readAsStringSync();

    // Le chemin d'envoi d'un message traverse getActiveDevices puis
    // fetchPreKeyBundle, déjà sous un délai X3DH de 10 s. Une garde non bornée
    // y ferait attendre l'utilisateur pour obtenir, au mieux, du Signal —
    // alors que le repli AES existe précisément pour ne pas le retarder.
    for (final lecture in const [
      'getActiveDevices',
      'fetchPreKeyBundle',
      'fetchAllPreKeyBundles',
      '_countPublishedOneTimePreKeys',
    ]) {
      // Ancré en début de ligne sur deux espaces : sans ça, `await $lecture(`
      // — un site d'APPEL — matche avant la déclaration, et la fenêtre
      // inspectée n'est pas celle de la méthode.
      final debut = source.indexOf(
        RegExp(r'^  [A-Za-z_][\w<>,?\s]*\s+' '$lecture' r'\(', multiLine: true),
      );
      expect(
        debut,
        isNot(-1),
        reason: '$lecture a disparu de $fichier : ce test ne garde plus rien.',
      );
      // Fenêtre courte : la garde est en tête de méthode, pas au fond.
      final fenetre = source.substring(
        debut,
        (debut + 1200).clamp(0, source.length),
      );
      expect(
        fenetre,
        contains('ensureReadableSession()'),
        reason:
            '$lecture est une lecture sur le chemin d\'envoi : elle doit '
            'utiliser ensureReadableSession() (bornée, dégrade) et non '
            'ensureAuthenticated(), qui peut attendre sans borne.',
      );
    }
  });
}
