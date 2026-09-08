import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_state.dart';
import 'package:diaspo_niger/features/feed/presentation/screens/my_posts_screen.dart'
    show userPostsCountProvider;
import 'package:diaspo_niger/features/feed/presentation/screens/saved_posts_screen.dart'
    show bookmarkedPostsCountProvider;
import 'package:diaspo_niger/features/profile/presentation/screens/profile_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Débordement signalé sur Pixel 10 Pro XL, écran « Profil » (2026-09-08).
///
/// La carte de statistiques posait ses quatre colonnes à leur largeur
/// naturelle dans une `Row` : « Connexions / Groupes / Événements /
/// Publications » plus trois filets tiennent tout juste dans les 320 dp
/// utiles, et l'échelle de police 1.3 du Pixel les fait déborder par la
/// droite.
///
/// ⚠ La police de test rend chaque glyphe carré (1 em), donc les largeurs
/// mesurées ici sont **plus grandes** qu'à l'écran : le débordement reproduit
/// (300 px) n'est pas celui qu'on voit sur l'appareil. Ce que le banc prouve,
/// c'est que la mise en page ne dépend plus de la longueur des libellés — il
/// échoue bien sans le correctif (vérifié par mutation).
class _AuthConnecte extends AuthNotifier {
  @override
  AuthState build() => const AuthState.authenticated(
        UserEntity(
          id: 'u-banc',
          email: 'banc@example.org',
          displayName: 'Aïssatou Mahamadou Issoufou',
        ),
      );
}

void main() {
  Widget boot() => ProviderScope(
        overrides: [
          // Sans cet override, `AuthNotifier.build()` lance `_initAuthState()`
          // sans l'attendre : l'échec Firebase remonte en erreur asynchrone
          // non capturée et le binding avorte le test avant tout rendu.
          authNotifierProvider.overrideWith(_AuthConnecte.new),
          // Des compteurs à trois chiffres : c'est la ligne « icône + nombre »
          // qui devient la plus large quand les compteurs montent.
          userPostsCountProvider.overrideWith((ref) async => 128),
          bookmarkedPostsCountProvider.overrideWith((ref) async => 342),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const ProfileScreen(),
        ),
      );

  // 1.3 est l'échelle relevée sur le Pixel de Salim ; 2.0 borne le réglage
  // « très grand » d'Android.
  for (final echelle in [1.0, 1.3, 2.0]) {
    testWidgets('Profil : aucun débordement à l\'échelle $echelle', (
      tester,
    ) async {
      final erreurs = <FlutterErrorDetails>[];
      final precedent = FlutterError.onError;
      FlutterError.onError = erreurs.add;
      addTearDown(() => FlutterError.onError = precedent);

      // Géométrie du Pixel 10 Pro XL : 1080 px, densité **surchargée** 440
      // (la densité physique, 390, n'est pas celle qui s'applique).
      tester.view.physicalSize = const Size(1080, 2404);
      tester.view.devicePixelRatio = 2.75;
      tester.platformDispatcher.textScaleFactorTestValue = echelle;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(boot());
      // L'en-tête et la carte de statistiques arrivent par
      // `TweenAnimationBuilder` : des `pump()` bornés, jamais
      // `pumpAndSettle()` (les indicateurs de chargement ne s'arrêtent pas).
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final debordements =
          erreurs
              .map((d) => d.exception.toString())
              .where((e) => e.contains('overflowed'))
              .toList();

      // Rendre le gestionnaire AVANT d'affirmer : un `expect()` qui échoue
      // pendant qu'il est détourné fait lever au binding sa propre assertion,
      // qui masque le motif et met ~6 min à s'arrêter.
      FlutterError.onError = precedent;

      expect(debordements, isEmpty, reason: debordements.join('\n'));
    });
  }
}
