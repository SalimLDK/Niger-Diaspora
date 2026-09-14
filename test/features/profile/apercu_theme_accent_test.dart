import 'dart:io';

import 'package:diaspo_niger/core/constants/app_colors.dart';
import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : les vignettes d'aperçu de thème doivent dire la vérité sur ce
/// qu'elles proposent — accent compris.
///
/// Le principe est posé par `950024b` (« un aperçu qui ment sur ce qu'il
/// propose », « seuls les aperçus, qui doivent par définition dire la vérité
/// sur le thème, sont corrigés ici »). Ce commit a corrigé la moitié
/// clair/sombre du mensonge et laissé l'autre moitié : la barre d'accent
/// restait figée sur la paire **orange**. Un compte en Vert voyait donc trois
/// vignettes oranges, juste au-dessus de la pastille verte qu'il venait de
/// choisir — observé sur Pixel le 2026-09-14.
///
/// Deux choses sont tenues ici :
///
/// - la correspondance accent → couleur rendue, lue sur les thèmes réels,
///   pour que déplacer un `colorScheme.primary` fasse tomber le test au lieu
///   de désaccorder l'aperçu en silence ;
/// - le fait que l'aperçu **dépende** de l'accent. C'est le cœur : une
///   vignette qui ne lit pas l'accent ne peut pas dire la vérité, quelle que
///   soit la couleur qu'elle peint.
///
/// Limite assumée : le second test lit la source. Il attrape l'aperçu qui
/// ignore l'accent, pas un aperçu qui le lirait puis peindrait de travers —
/// c'est le premier test qui couvre les valeurs.
void main() {
  // `AppTheme` construit ses styles via `google_fonts`, qui lit le binding
  // des services. Sans cette ligne, les quatre tests de valeurs échouent sur
  // « Binding has not yet been initialized » — un échec de banc, pas de code.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('les quatre thèmes rendent bien les quatre jetons attendus', () {
    test('Vert clair rend secondary', () {
      expect(AppTheme.lightTheme.colorScheme.primary, AppColors.secondary);
    });

    test('Vert sombre rend secondaryLight', () {
      expect(AppTheme.darkTheme.colorScheme.primary, AppColors.secondaryLight);
    });

    test('Orange clair rend primaryDark', () {
      expect(AppTheme.orangeTheme.colorScheme.primary, AppColors.primaryDark);
    });

    test('Orange sombre rend primaryLight', () {
      expect(
        AppTheme.orangeDarkTheme.colorScheme.primary,
        AppColors.primaryLight,
      );
    });
  });

  test("l'aperçu de thème dépend de l'accent du compte", () {
    final source =
        File(
          'lib/features/profile/presentation/screens/'
          'profile_config_screen.dart',
        ).readAsStringSync();

    final debut = source.indexOf('class _ThemeModePreview');
    expect(
      debut,
      isNot(-1),
      reason: "la vignette d'aperçu a disparu ou changé de nom",
    );
    final fin = source.indexOf('class _DiagonalClipper', debut);
    final bloc = fin == -1 ? source.substring(debut) : source.substring(debut, fin);

    expect(
      bloc.contains('themeColorNotifierProvider'),
      isTrue,
      reason:
          "la vignette ne lit pas l'accent : elle peindra la même couleur pour "
          'un compte en Vert et un compte en Orange, comme avant le 2026-09-14',
    );

    // Les quatre jetons rendus par les quatre thèmes doivent tous apparaître
    // dans la vignette : sinon c'est qu'une des quatre combinaisons
    // accent × luminosité est peinte avec la couleur d'une autre.
    for (final jeton in [
      'secondaryLight',
      'secondary',
      'primaryLight',
      'primaryDark',
    ]) {
      expect(
        bloc.contains('AppColors.$jeton'),
        isTrue,
        reason:
            "la vignette ne cite pas `AppColors.$jeton` : une des quatre "
            'combinaisons accent × luminosité est peinte avec la couleur '
            "d'une autre",
      );
    }
  });
}
