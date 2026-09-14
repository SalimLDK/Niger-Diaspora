import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/image_upload_service.dart';

/// Le réglage distant `app_config/settings.mediaLimits` décide de la
/// définition des photos envoyées. Il portait encore, le 2026-09-14, les
/// valeurs de l'époque où le pipeline encodait deux fois à 85 — 1024 / 85 /
/// 800 — qui livraient une photo de 768 px de petit côté, floue dès qu'un
/// écran de 1080 px l'affiche pleine largeur.
///
/// D'où la règle vérifiée ici : le distant relève la qualité, il ne la baisse
/// pas.
void main() {
  group('ImageUploadConfig.auMoinsLePlancher', () {
    const plancher = ImageUploadConfig();

    test('le réglage distant périmé est remonté au plancher', () {
      // Exactement ce que contient `app_config/settings` en production.
      const distant = ImageUploadConfig(
        maxWidth: 1024,
        maxHeight: 1024,
        pickQuality: 85,
        quality: 85,
        maxImagesPerUpload: 25,
        minWidthForCompression: 800,
      );

      final effectif = distant.auMoinsLePlancher();

      expect(effectif.maxWidth, plancher.maxWidth);
      expect(effectif.maxHeight, plancher.maxHeight);
      expect(effectif.pickQuality, plancher.pickQuality);
      expect(effectif.quality, plancher.quality);
      expect(effectif.minWidthForCompression, plancher.minWidthForCompression);
    });

    test('un réglage distant plus généreux est respecté', () {
      const distant = ImageUploadConfig(
        maxWidth: 4096,
        maxHeight: 4096,
        pickQuality: 100,
        quality: 95,
        minWidthForCompression: 1440,
      );

      final effectif = distant.auMoinsLePlancher();

      expect(effectif.maxWidth, 4096);
      expect(effectif.maxHeight, 4096);
      expect(effectif.pickQuality, 100);
      expect(effectif.quality, 95);
      expect(effectif.minWidthForCompression, 1440);
    });

    test('le nombre d\'images par envoi reste à la main de l\'admin', () {
      expect(
        const ImageUploadConfig(maxImagesPerUpload: 25)
            .auMoinsLePlancher()
            .maxImagesPerUpload,
        25,
      );
      expect(
        const ImageUploadConfig(maxImagesPerUpload: 2)
            .auMoinsLePlancher()
            .maxImagesPerUpload,
        2,
      );
    });

    test(
      'la qualité de sélection reste au-dessus de la qualité livrée',
      () {
        // La sélection n'est qu'une étape intermédiaire : si elle encode plus
        // serré que la passe finale, les deux pertes se cumulent et c'est
        // exactement le défaut corrigé le 2026-09-14.
        expect(plancher.pickQuality, greaterThan(plancher.quality));
      },
    );
  });
}
