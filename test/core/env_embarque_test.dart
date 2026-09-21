// Garde du `.env` : ce fichier part EN CLAIR dans l'APK et dans l'IPA.
//
// `pubspec.yaml` le déclare en asset (`assets: - .env`). Tout ce qu'on y écrit
// est donc extractible de n'importe quel build publié, et le restera dans les
// versions déjà installées : un secret posé ici ne se rattrape pas, il se
// fait tourner.
//
// Ce que ce banc interdit :
//   1. une variable dont le nom n'est pas connu — c'est ainsi qu'un
//      `SUPABASE_SERVICE_ROLE_KEY` arrive « juste pour essayer » ;
//   2. une valeur qui a la forme d'un secret (JWT, clé Stripe, clé de
//      service, clé privée, secret de webhook…) ;
//   3. un chemin absolu de poste de travail, qui livre le nom d'utilisateur
//      et l'arborescence. Il y en avait un jusqu'au 2026-09-21
//      (`GOOGLE_APPLICATION_CREDENTIALS`, retiré ; `scripts/creer_compte_test.js`
//      retrouve la clé tout seul).
//
// Ce qu'il ne peut PAS faire : juger si une valeur autorisée a été changée
// pour une valeur dangereuse de même forme. La liste de noms est la vraie
// barrière ; les motifs ne sont qu'un filet.
//
// Un nom ajouté ici doit être PUBLIC par nature — destiné à être lu par
// n'importe qui possédant l'application. Dans le doute, la valeur passe par
// `--dart-define` (elle n'entre alors pas dans l'asset) ou par un secret
// côté serveur.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les cinq que l'application lit vraiment, par `AppConfig._read`.
/// Leur absence est une panne de configuration, pas un risque.
const _luesParLApp = <String>{
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'GOOGLE_MAPS_API_KEY',
  'LIVEKIT_SERVER_URL',
  'DEEP_LINK_BASE_URL',
};

/// Publiques par nature, mais plus lues par `lib/` : `firebase_options.dart`
/// porte les valeurs Firebase en dur, `main.dart` la clé reCAPTCHA,
/// `app_config.dart` l'identifiant marchand. Elles restent tolérées — les
/// retirer est un ménage sans urgence — mais rien ne doit s'ajouter à cette
/// liste sans passer par la question du dessus.
const _publiquesNonLues = <String>{
  'FIREBASE_WEB_API_KEY',
  'FIREBASE_WEB_APP_ID',
  'FIREBASE_ANDROID_API_KEY',
  'FIREBASE_ANDROID_APP_ID',
  'FIREBASE_IOS_API_KEY',
  'FIREBASE_IOS_APP_ID',
  'FIREBASE_MESSAGING_SENDER_ID',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_STORAGE_BUCKET',
  'FIREBASE_DATABASE_URL',
  'FIREBASE_AUTH_DOMAIN',
  'FIREBASE_MEASUREMENT_ID',
  'GOOGLE_WEB_CLIENT_ID',
  'GOOGLE_IOS_CLIENT_ID',
  'RECAPTCHA_SITE_KEY',
  'STRIPE_MERCHANT_IDENTIFIER',
  'IOS_BUNDLE_ID',
};

/// Formes de secrets. Chaque motif porte le nom de ce qu'il attrape, pour que
/// l'échec se lise sans aller chercher la regex.
const _formesInterdites = <String, String>{
  r'^eyJ[A-Za-z0-9_-]{10,}\.': 'un jeton JWT (clé Supabase legacy, jeton signé)',
  r'\bsb_secret_': 'une clé secrète Supabase',
  r'\bservice_role\b': 'une clé ou un rôle service_role',
  r'\bsk_(live|test)_[A-Za-z0-9]': 'une clé secrète Stripe',
  r'\bwhsec_[A-Za-z0-9]': 'un secret de webhook Stripe',
  r'\brk_(live|test)_': 'une clé restreinte Stripe',
  r'-----BEGIN [A-Z ]*PRIVATE KEY': 'une clé privée',
  r'\bAKIA[0-9A-Z]{8}': 'une clé AWS',
  r'\bSG\.[A-Za-z0-9_-]{16,}': 'une clé SendGrid',
  r'\bxox[baprs]-': 'un jeton Slack',
  r'\bghp_[A-Za-z0-9]{20,}': 'un jeton GitHub',
  r'\bAIzaSy[A-Za-z0-9_-]{20,}:': 'une clé Google suivie d\'un secret',
};

/// Chemins de poste de travail.
final _cheminsAbsolus = RegExp(
  r'^(?:[A-Za-z]:[\\/]|/(?:Users|home|root|mnt|var)/)',
);

void main() {
  group('.env embarqué dans l\'APK', () {
    late Map<String, String> variables;
    late List<String> noms;

    setUpAll(() {
      final fichier = File('.env');
      expect(
        fichier.existsSync(),
        isTrue,
        reason: 'Le `.env` est un asset déclaré dans pubspec.yaml : sans lui, '
            'toute commande Flutter échoue. Copier `.env.example` et le remplir.',
      );

      variables = <String, String>{};
      for (final ligne in fichier.readAsLinesSync()) {
        final nu = ligne.trim();
        if (nu.isEmpty || nu.startsWith('#')) continue;
        final coupure = nu.indexOf('=');
        if (coupure <= 0) continue;
        final nom = nu.substring(0, coupure).trim();
        final valeur = nu.substring(coupure + 1).trim().replaceAll(
              RegExp(r'''^["']|["']$'''),
              '',
            );
        variables[nom] = valeur;
      }
      noms = variables.keys.toList()..sort();
    });

    test('aucune variable inconnue', () {
      final connues = {..._luesParLApp, ..._publiquesNonLues};
      final inconnues = noms.where((n) => !connues.contains(n)).toList();

      expect(
        inconnues,
        isEmpty,
        reason: 'Variables inconnues dans `.env` : ${inconnues.join(', ')}.\n'
            'Ce fichier part en clair dans l\'APK. Si la valeur est PUBLIQUE, '
            'ajouter son nom à `_publiquesNonLues` dans ce test. Sinon, la '
            'passer par `--dart-define` (elle n\'entre alors pas dans l\'asset) '
            'ou par un secret côté serveur.',
      );
    });

    test('aucune valeur n\'a la forme d\'un secret', () {
      final fautes = <String>[];
      _formesInterdites.forEach((motif, quoi) {
        final regex = RegExp(motif);
        for (final nom in noms) {
          if (regex.hasMatch(variables[nom]!)) {
            // La valeur n'est jamais reproduite : seulement le nom et la nature.
            fautes.add('$nom ressemble à $quoi');
          }
        }
      });

      expect(
        fautes,
        isEmpty,
        reason: '${fautes.join('\n')}\n'
            'Un secret dans `.env` est extractible de tout build publié, et le '
            'reste dans les versions déjà installées : le retirer ne suffit '
            'pas, il faut le faire tourner.',
      );
    });

    test('aucun chemin absolu de poste de travail', () {
      final fautes =
          noms.where((n) => _cheminsAbsolus.hasMatch(variables[n]!)).toList();

      expect(
        fautes,
        isEmpty,
        reason: 'Chemins absolus dans `.env` : ${fautes.join(', ')}.\n'
            'Ils livrent le nom d\'utilisateur et l\'arborescence du poste à '
            'quiconque ouvre l\'APK. Passer par une variable d\'environnement '
            'du poste, pas par ce fichier.',
      );
    });

    test('les cinq variables que l\'app lit sont présentes et non vides', () {
      for (final nom in _luesParLApp) {
        expect(
          variables[nom],
          isNotNull,
          reason: '`$nom` manque : `AppConfig` retombera sur sa valeur par '
              'défaut, en silence.',
        );
        expect(
          variables[nom],
          isNotEmpty,
          reason: '`$nom` est vide : `AppConfig._read` traite le vide comme '
              'une absence et passe au repli suivant.',
        );
      }
    });
  });
}
