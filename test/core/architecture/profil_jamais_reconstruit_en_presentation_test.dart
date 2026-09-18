import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Une couche de présentation ne construit jamais un `ProfileEntity` de zéro.
///
/// `ProfileNotifier.updateProfile` → `ProfileRepositoryImpl.updateProfile` →
/// `ProfileSupabaseDataSource.updateProfile` écrit **toutes** les colonnes de
/// l'entité, par un upsert : aucune fusion avec le profil existant en chemin
/// (le dépôt n'ouvre l'ancien profil que pour les abonnements aux topics). Un
/// champ que l'appelant ne renseigne pas repart donc à son défaut — `true` pour
/// `shareLocation`, `notificationsEnabled` et `showOnlineStatus`, `[]` pour
/// `skills`, `null` pour `currentRegion`.
///
/// C'est ce que faisait l'écran « Modifier le profil » : il bâtissait
/// `ProfileEntity(...)` avec les seuls champs de son formulaire. **Modifier sa
/// bio réactivait, en silence, la position partagée et le statut en ligne qu'on
/// avait coupés.** Même famille que l'« écrasement » des bascules du profil
/// (voir `profile_preferences_provider.dart`), et invisible à la relecture :
/// aucune erreur, aucun message, la valeur reprend seulement son défaut.
///
/// Pour écrire, on part du profil courant :
///
/// ```dart
/// final base = await ref.read(profileNotifierProvider(id).notifier).currentProfile();
/// final profil = base.copyWith(/* les champs du formulaire */);
/// ```
///
/// Seule la couche de données (`ProfileModel.toEntity`) et le codec du routeur
/// construisent légitimement une entité complète.
void main() {
  // `ProfileEntity(` précédé d'un caractère d'identifiant serait un autre type
  // (`CreatorProfileEntity(`).
  final construction = RegExp(r'(?<![A-Za-z0-9_])ProfileEntity\(');

  test('aucune présentation ne construit un ProfileEntity de zéro', () {
    final fautes = <String>[];

    for (final fichier in Directory('lib').listSync(recursive: true)) {
      if (fichier is! File || !fichier.path.endsWith('.dart')) continue;
      final chemin = fichier.path.replaceAll(r'\', '/');
      if (!chemin.contains('/presentation/')) continue;

      final lignes = fichier.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final ligne = lignes[i];
        if (ligne.trimLeft().startsWith('//')) continue;
        if (construction.hasMatch(ligne)) {
          fautes.add('$chemin:${i + 1} → ${ligne.trim()}');
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason:
          'Ces fichiers construisent un ProfileEntity de zéro. `updateProfile` '
          'écrit TOUTES les colonnes : ce que le formulaire ne porte pas '
          'repart à son défaut (position partagée, statut en ligne, '
          'notifications remis à `true`). Partir de '
          '`profileNotifierProvider(id).notifier.currentProfile()` puis '
          '`copyWith`.\n${fautes.join('\n')}',
    );
  });
}
