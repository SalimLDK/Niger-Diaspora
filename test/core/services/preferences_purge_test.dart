import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';

/// Purge ciblée à la déconnexion.
///
/// Aucune des clés personnelles de `PreferencesService` ne porte
/// d'identifiant d'utilisateur, et `clearAll()` n'était appelée nulle part :
/// le compte suivant sur le même téléphone héritait des brouillons du
/// précédent. Constaté le 2026-08-04 — l'écran « Mes publications » affichait
/// un brouillon (« Compte rendu de la reunion du 12 ») qui aurait survécu.
///
/// Le test tient les DEUX bords : ce qui doit partir, et ce qui doit rester.
/// Purger trop large renverrait un utilisateur qui revient dans l'onboarding
/// et réactiverait la télémétrie qu'il avait refusée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesService> amorcer() async {
    SharedPreferences.setMockInitialValues({});
    final service = PreferencesService.instance;
    await service.initialize();
    return service;
  }

  test('les données de la personne sont effacées', () async {
    final prefs = await amorcer();

    await prefs.savePostDraft('d1', 'Compte rendu de la reunion du 12');
    await prefs.saveMessageDraft('conv-1', 'message a moitie ecrit');
    await prefs.toggleFollowedHashtag('DiasporaNiger');
    await prefs.markVoiceNotePlayed('vn-1');
    await prefs.setNearbyMembersEnabled(true);

    await prefs.clearUserData();

    expect(prefs.postDrafts, isEmpty, reason: 'texte écrit par l\'utilisateur');
    expect(prefs.getMessageDraft('conv-1'), anyOf(isNull, isEmpty));
    expect(prefs.followedHashtags, isEmpty);
    expect(prefs.isVoiceNotePlayed('vn-1'), isFalse);
    // Exposition sur la carte : choix de la personne, `false` par défaut.
    expect(prefs.nearbyMembersEnabled, isFalse);
  });

  test('les réglages de l\'appareil survivent', () async {
    final prefs = await amorcer();

    await prefs.setThemeMode('dark');
    await prefs.setLocale('fr');
    await prefs.setNotificationsEnabled(false);
    await prefs.setAnalyticsOptOut(true);
    await prefs.setOnboardingComplete();

    await prefs.clearUserData();

    expect(prefs.themeMode, 'dark');
    expect(prefs.locale, 'fr');
    expect(prefs.notificationsEnabled, isFalse);
    // Les effacer renverrait l'utilisateur dans l'onboarding et réactiverait
    // une télémétrie qu'il avait explicitement refusée.
    expect(prefs.analyticsOptOut, isTrue);
    expect(prefs.hasSeenOnboarding, isTrue);
  });
}
