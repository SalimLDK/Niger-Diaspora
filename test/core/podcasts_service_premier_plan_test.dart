import 'dart:io';

import 'package:diaspo_niger/core/services/feature_flag_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde-fou du couple « type de service de premier plan / autorisation ».
///
/// Depuis Android 14, un service qui déclare un `foregroundServiceType` doit
/// détenir l'autorisation `FOREGROUND_SERVICE_<TYPE>` correspondante : sinon
/// le premier `startForeground` lève une `SecurityException`. Le manifeste
/// déclare toujours `mediaPlayback` sur `AudioService`, mais
/// `FOREGROUND_SERVICE_MEDIA_PLAYBACK` en a été retirée le 2026-09-09 à la
/// demande de Play (une vidéo de démonstration est exigée par type, et les
/// podcasts étaient injoignables donc infilmables).
///
/// Le déséquilibre est tenable **uniquement** si rien de livré n'atteint le
/// lecteur. `kPodcastsSupportesParCeBuild` à `false` ne le garantissait pas à
/// lui seul, et ce test l'a cru deux fois :
///
/// - le drapeau `podcasts` du back-office rouvrait `/podcasts` d'un clic, à
///   distance, sur un build incapable de jouer quoi que ce soit ;
/// - puis le routeur sautait toute sa garde tant que les drapeaux n'étaient
///   pas chargés (`if (flags != null)`) : pendant le démarrage à froid,
///   `/podcasts/*` s'ouvrait normalement — mesuré sur SM A515F (f8c681d).
///   Ce test ne regardait que le manifeste, jamais le routeur.
///
/// Le lecteur, lui, s'initialise à chaque lancement (le mini-lecteur de
/// `main_shell.dart` surveille `podcastPlayerProvider`), mais sans passer au
/// premier plan : c'est la première lecture qui plante, et elle ne peut
/// partir que d'une route `/podcasts`. Fermer ces routes suffit donc — à
/// condition de les fermer avant la fenêtre.
///
/// Ce test empêche les morceaux de se désynchroniser à nouveau — dans un sens
/// comme dans l'autre.
void main() {
  final manifeste =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  /// Une déclaration `<uses-permission>` réellement active : celles portant
  /// `tools:node="remove"` retirent au contraire la permission de la fusion.
  bool autorisationDeclaree(String nom) {
    final motif = RegExp(
      '<uses-permission[^>]*android:name="android.permission.$nom"[^>]*/?>',
      dotAll: true,
    );
    final trouve = motif.firstMatch(manifeste)?.group(0);
    if (trouve == null) return false;
    return !trouve.contains('tools:node="remove"');
  }

  test('mediaPlayback : le type et son autorisation restent solidaires', () {
    final typeDeclare = manifeste.contains(
      'android:foregroundServiceType="mediaPlayback"',
    );
    final permission = autorisationDeclaree('FOREGROUND_SERVICE_MEDIA_PLAYBACK');

    if (kPodcastsSupportesParCeBuild) {
      expect(
        permission,
        isTrue,
        reason:
            '`kPodcastsSupportesParCeBuild` est à true : la lecture en '
            'arrière-plan est joignable, donc FOREGROUND_SERVICE_MEDIA_PLAYBACK '
            'doit être rétablie dans le manifeste — et sa vidéo de '
            'démonstration fournie à Play.',
      );
    } else {
      expect(
        typeDeclare && permission,
        isFalse,
        reason:
            "L'autorisation est revenue au manifeste alors que les podcasts "
            'restent coupés : Play réclamera une vidéo pour une '
            'fonctionnalité que personne ne peut atteindre — le motif exact '
            'du retrait du 2026-09-09. Rallumez '
            '`kPodcastsSupportesParCeBuild` en même temps.',
      );
    }
  });

  test('location : le type et son autorisation sont bien tous les deux là', () {
    // Le Mode Voyage, lui, est joignable et divulgué : le couple doit être
    // complet des deux côtés.
    expect(
      manifeste.contains('android:foregroundServiceType="location"'),
      isTrue,
      reason: 'BackgroundLocationService doit déclarer son type.',
    );
    expect(
      autorisationDeclaree('FOREGROUND_SERVICE_LOCATION'),
      isTrue,
      reason:
          'Sans cette autorisation, le Mode Voyage lève une SecurityException '
          'au démarrage du service sur Android 14+.',
    );
  });

  test('routeur : les podcasts sont fermés AVANT la fenêtre des drapeaux', () {
    // La constante est connue à la compilation : la fermeture ne doit pas
    // attendre `loadedFeatureFlagsProvider`, sinon elle ne s'applique qu'une
    // fois le démarrage à froid terminé — trop tard pour un lien profond.
    final routeur = File('lib/core/router/app_router.dart').readAsStringSync();
    // La décision des drapeaux (étape 9) : `if (flags != null)` jusqu'au
    // 2026-09-11, la porte à trois issues depuis. Elle ne laisse plus rien
    // passer pendant le démarrage, mais elle ferait attendre /podcasts sur
    // le splash jusqu'à 8 s avant de le refuser : la garde de compilation
    // doit toujours passer avant elle.
    final fenetre = routeur.indexOf('switch (porte(state.matchedLocation))');
    final garde = RegExp(
      r"!kPodcastsSupportesParCeBuild\s*&&\s*"
      r"state\.matchedLocation\.startsWith\('/podcasts'\)",
    ).firstMatch(routeur);

    expect(fenetre, isNot(-1), reason: 'Décision des drapeaux introuvable.');
    expect(
      garde,
      isNotNull,
      reason:
          'Le routeur doit fermer /podcasts sur la seule constante de '
          'compilation, sans passer par les drapeaux serveur.',
    );
    expect(
      garde!.start < fenetre,
      isTrue,
      reason:
          'La garde podcasts est APRÈS la décision des drapeaux (`porte`) : '
          'elle attendrait les drapeaux, et un lien vers /podcasts/* resterait '
          "garé sur le splash au lieu d'être refusé tout de suite.",
    );
  });
}
