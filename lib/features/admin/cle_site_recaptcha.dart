/// Clé de site reCAPTCHA v3 du panneau admin (App Check, web).
///
/// La clé vient de `--dart-define=ADMIN_RECAPTCHA_SITE_KEY=…` posé au build
/// (`tools/build_admin_web.sh`). Sans lui, repli sur [cleSiteRecaptchaAdminRepli].
///
/// Pourquoi un repli en clair : une clé de site reCAPTCHA est publique par
/// construction — elle est dans la page servie à tout visiteur, et ne vaut
/// que pour les domaines autorisés dans la console reCAPTCHA. Ce n'est pas un
/// secret ; `lib/main.dart` porte la même, pour l'app grand public. Le
/// `--dart-define` sert à changer de clé (nouveau domaine, clé dédiée au
/// panneau, rotation) sans toucher au code — pas à la cacher.
const String cleSiteRecaptchaAdmin = String.fromEnvironment(
  'ADMIN_RECAPTCHA_SITE_KEY',
  defaultValue: cleSiteRecaptchaAdminRepli,
);

/// Clé du projet Firebase `diaspo-niger` (reCAPTCHA v3), identique à celle de
/// `lib/main.dart`. Documentée dans `docs/deploiement/HEBERGEMENT_ADMIN.md`.
const String cleSiteRecaptchaAdminRepli =
    '6Ldy7TwsAAAAAI6jQWNmV-I2lkEn31yGG8iRNxTi';
