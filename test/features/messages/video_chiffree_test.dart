import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 9, décision C4)
/// ------------------------------------------------------
/// La vidéo était **écartée du chiffrement**, et pour une raison précise : le
/// chiffrement passait par la mémoire, avec un pic proche de trois fois la
/// taille du fichier, et le téléchargement plafonnait à 10 Mo. Les deux sens
/// vont maintenant d'un fichier vers un autre, un morceau à la fois, donc la
/// raison n'existe plus.
///
/// Mais lever l'exclusion ne suffit pas. Une vidéo chiffrée qui arriverait
/// sans aperçu ni badge de durée se lirait comme un défaut d'affichage, et on
/// chercherait le bug ailleurs. Il fallait donc aussi :
///
/// - la cartographier vers `MediaType.video`, et non vers `document` ;
/// - calculer sa vignette et sa durée **sur le fichier en clair**, avant
///   l'envoi ;
/// - lui donner un champ à part dans la charge MLS : `duration` y est lu comme
///   une durée AUDIO par le mapper, une vidéo rangée là aurait disparu.
///
/// Ces gardes lisent la source, parce que le chemin d'envoi demande Firebase,
/// Storage et une conversation réelle — rien qu'un test unitaire puisse tenir.

String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  const depot =
      'lib/features/messages/data/repositories/message_repository_impl.dart';

  group('la vidéo entre dans le chemin chiffré', () {
    test('elle n\'en est plus écartée', () {
      expect(_lire(depot).contains('type != MessageType.video'), isFalse);
    });

    test('elle est cartographiée en vidéo, pas en document', () {
      expect(
        _lire(depot).contains('MessageType.video => MediaType.video'),
        isTrue,
        reason: 'sans ça elle partait comme un document quelconque',
      );
    });

    test('vignette et durée sont calculées avant le chiffrement', () {
      // Sur le fichier en clair : une fois chiffré, il n'y a plus rien à
      // décoder.
      final src = _lire(depot);
      final debut = src.indexOf('_envoyerMediaChiffre');
      expect(debut, isNonNegative);
      final corps = src.substring(debut, debut + 9000);

      expect(corps.contains('generateFromVideo(file)'), isTrue);
      expect(corps.contains('_getVideoDurationSeconds(file.path)'), isTrue);
    });

    test('la durée voyage dans un champ à elle, des deux côtés', () {
      final src = _lire(depot);
      final debut = src.indexOf('_envoyerMediaChiffre');
      final corps = src.substring(debut, debut + 9000);

      // Chemin MLS.
      expect(corps.contains('dureeVideo: videoDuration'), isTrue);
      // Chemin legacy, pour une conversation encore en clair.
      expect(corps.contains('videoDuration: videoDuration'), isTrue);
    });
  });

  group('la charge MLS', () {
    test('sépare la durée vidéo de la durée audio', () {
      final corps = MlsGateway.corpsMedia(
        storagePath: 'p',
        fileName: 'f.mp4',
        mimeType: 'video/mp4',
        fileSize: 10,
        duration: 3,
        dureeVideo: 42,
      );
      expect(corps['duration'], 3);
      expect(corps['videoDuration'], 42);
    });

    test('n\'écrit rien quand la durée manque', () {
      final corps = MlsGateway.corpsMedia(
        storagePath: 'p',
        fileName: 'f.jpg',
        mimeType: 'image/jpeg',
        fileSize: 10,
      );
      expect(corps.containsKey('videoDuration'), isFalse);
      expect(corps.containsKey('duration'), isFalse);
    });
  });
}
