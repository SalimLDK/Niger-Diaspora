import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou contre le retour des doublons entre Profil et Réglages.
///
/// Trois écrans — `profile_screen`, `settings_screen` et
/// `notification_settings_screen` — avaient chacun réécrit leur propre
/// `_SettingsCard`, `_SettingsTile`, `_SettingsSwitchTile` et
/// `_SettingsDivider`. Le motif s'est reproduit trois fois avant d'être vu,
/// et il a coûté deux défauts :
///
/// - **Trois filets superposés** entre chaque ligne du Profil :
///   `DesignListCard` en insère déjà un, et l'écran lui passait en plus les
///   siens. Ça ne se lisait pas comme un bug mais comme un trait épais.
/// - **Une bascule qui en écrasait trois autres** : chaque écran gardait une
///   copie `bool` des préférences du profil, et la sauvegarde réécrivait les
///   quatre champs d'un seul `copyWith` à partir de copies jamais rafraîchies.
///
/// La règle : la brique visuelle vit dans `design_kit.dart`, la valeur dans un
/// provider. Un écran ne déclare ni tuile, ni carte, ni filet, ni copie locale
/// d'une préférence serveur.
///
/// Limite assumée : ce test lit la source. Monter les écrans en test widget
/// exigerait l10n, GoRouter, `PreferencesService.instance` initialisé et une
/// dizaine de providers — coût et fragilité disproportionnés pour verrouiller
/// une convention de structure.
void main() {
  /// Écrans qui n'ont pas encore rejoint le kit, avec la raison. Cette liste
  /// ne peut que rétrécir : n'y ajoutez rien sans une raison écrite.
  const exceptions = <String, String>{
    'notification_settings_screen.dart':
        'variante visuelle distincte (rayon 18, ombre, sans pictogramme), '
        'validée telle quelle — rejoindra le kit dans un lot dédié',
  };

  test('aucun écran ne redéclare une brique de réglages', () {
    // Les quatre noms exacts qui ont été dupliqués, pas un motif large :
    // `_Settings\w+` attraperait `_SettingsScreenState`, et
    // `_buildSectionHeader` existe légitimement dans quatre écrans sans
    // rapport (admin, appels, podcasts) avec des signatures différentes. Un
    // garde qui crie à tort finit désactivé.
    final briques = RegExp(r'class _Settings(Card|Tile|SwitchTile|Divider)\b');
    final coupables = <String>[];

    for (final file in Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (exceptions.containsKey(file.uri.pathSegments.last)) continue;
      if (briques.hasMatch(file.readAsStringSync())) {
        coupables.add(file.path);
      }
    }

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces écrans redéclarent une brique de réglages. Utilisez '
          'DesignSettingsCard / DesignSettingsTile / '
          'DesignSettingsSwitchTile / DesignSectionLabel de design_kit.dart.',
    );
  });

  test('Profil et Réglages n\'ont plus d\'alias de sur-titre', () {
    for (final chemin in const [
      'lib/features/profile/presentation/screens/profile_screen.dart',
      'lib/features/settings/presentation/screens/settings_screen.dart',
    ]) {
      expect(
        File(chemin).readAsStringSync(),
        isNot(contains('Widget _buildSectionHeader(')),
        reason:
            '$chemin réintroduit un alias de DesignSectionLabel. Les deux '
            'versions précédentes ignoraient silencieusement leur paramètre '
            'd\'icône, et celle de Réglages ignorait aussi son drapeau '
            'isWarning — « ZONE SENSIBLE » s\'affichait donc en couleur '
            'd\'accent au lieu du rouge que la fiche demande.',
      );
    }
  });

  test('aucun filet à la main dans une carte de réglages', () {
    // On vise l'invariant exact plutôt que le fichier entier : un `Divider`
    // reste légitime ailleurs — la feuille d'aide en pose un entre la FAQ et
    // les contacts, et `_buildStatDivider` est le séparateur **vertical**
    // entre les statistiques du Profil. Seul un filet *dans* une carte se
    // superposerait à celui que la carte insère déjà.
    final filet = RegExp(r'(?<![A-Za-z_])Divider\(');

    for (final chemin in const [
      'lib/features/profile/presentation/screens/profile_screen.dart',
      'lib/features/settings/presentation/screens/settings_screen.dart',
    ]) {
      final source = File(chemin).readAsStringSync();

      for (final debut in _positionsDe(source, 'DesignSettingsCard(')) {
        final corps = _blocParenthese(source, debut);
        expect(
          filet.hasMatch(corps),
          isFalse,
          reason:
              '$chemin pose un filet dans une DesignSettingsCard. La carte '
              'insère déjà les siens : les deux se superposent, comme les '
              'trois filets qui traînaient entre chaque ligne du Profil.',
        );
      }
    }
  });

  test('Profil et Réglages ne recopient aucune préférence serveur', () {
    final champ = RegExp(
      r'bool _\w*(?:[Vv]isible|[Ll]ocation|[Oo]nline|[Nn]otification)\w*\s*=',
    );

    for (final chemin in const [
      'lib/features/profile/presentation/screens/profile_screen.dart',
      'lib/features/settings/presentation/screens/settings_screen.dart',
    ]) {
      expect(
        champ.hasMatch(File(chemin).readAsStringSync()),
        isFalse,
        reason:
            '$chemin garde une copie locale d\'une préférence du profil. '
            'C\'est ce qui faisait que toucher une bascule remettait les '
            'trois autres à « true ». Lisez profilePreferenceProvider.',
      );
    }
  });

  test('le kit n\'expose aucun widget de filet de réglages', () {
    expect(
      File('lib/core/theme/design_kit.dart').readAsStringSync(),
      isNot(contains('class DesignSettingsDivider')),
      reason:
          'Exposer un filet rouvrirait la porte au défaut du triple filet. '
          'C\'est à la carte de poser les siens.',
    );
  });
}

/// Décalages de chaque occurrence de [motif] dans [source].
Iterable<int> _positionsDe(String source, String motif) sync* {
  var i = source.indexOf(motif);
  while (i >= 0) {
    yield i;
    i = source.indexOf(motif, i + motif.length);
  }
}

/// Contenu de la parenthèse ouverte à partir de [debut], parenthèses
/// imbriquées comprises. Permet d'isoler les enfants d'une carte sans
/// analyser le Dart.
String _blocParenthese(String source, int debut) {
  final ouvrante = source.indexOf('(', debut);
  if (ouvrante < 0) return '';
  var profondeur = 0;
  for (var i = ouvrante; i < source.length; i++) {
    if (source[i] == '(') profondeur++;
    if (source[i] == ')') {
      profondeur--;
      if (profondeur == 0) return source.substring(ouvrante, i);
    }
  }
  return source.substring(ouvrante);
}
