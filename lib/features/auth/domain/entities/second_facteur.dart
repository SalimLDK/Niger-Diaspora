/// Second facteur d'authentification (Firebase Auth multi-facteur, TOTP) :
/// ce que la couche présentation en voit.
///
/// Trois objets qu'elle ne fait que porter — ce qu'elle en fait passe par
/// `AuthRepository` (`facteursEnroles`, `commencerEnrolementTotp`,
/// `terminerEnrolementTotp`, `resoudreSecondFacteur`). La couche données
/// les étend pour y garder les poignées du SDK, le résolveur d'un défi ou le
/// secret d'un enrôlement, sans que `firebase_auth` ne remonte jusqu'aux
/// écrans. Le pourquoi et le parcours : `docs/deploiement/MFA_ADMIN.md`.
library;

import '../../../../core/errors/failures.dart';

/// Un facteur enrôlé sur un compte.
class FacteurEnrole {
  const FacteurEnrole({
    required this.id,
    required this.type,
    this.libelle,
    this.enroleLe,
  });

  /// Identifiant d'enrôlement : c'est lui qu'un défi désigne.
  final String id;

  /// `totp` ou `phone`, tels que Firebase les nomme (`factorId`).
  final String type;

  /// Nom donné à l'enrôlement (« Application d'authentification »).
  final String? libelle;

  final DateTime? enroleLe;

  bool get estTotp => type == typeTotp;

  static const typeTotp = 'totp';
  static const typePhone = 'phone';
}

/// Défi levé par une connexion dont le premier facteur a été accepté : le
/// compte porte un facteur enrôlé, il reste à le prouver. Tant qu'il ne
/// l'est pas, **aucune session n'existe**. Se clôt par
/// `AuthRepository.resoudreSecondFacteur`.
abstract class DefiSecondFacteur {
  /// Les facteurs parmi lesquels prouver (Firebase : `resolver.hints`).
  List<FacteurEnrole> get facteurs;
}

/// Secret TOTP d'un enrôlement en cours : à montrer en QR (ou en clé à
/// recopier), puis à confirmer par un premier code via
/// `AuthRepository.terminerEnrolementTotp`.
abstract class SecretTotp {
  /// La clé en base32, pour une saisie manuelle dans l'application.
  String get cle;

  /// L'URL `otpauth://totp/…` que le QR encode, émetteur et compte compris.
  String get urlQr;

  /// Au-delà, Firebase refuse l'enrôlement : il faut regénérer un secret.
  DateTime? get expireLe;
}

/// La connexion est acceptée au premier facteur, mais le compte porte un
/// second facteur à prouver avant qu'une session n'existe.
///
/// Pas une panne : une étape. Elle sort en `Left` parce que `signInWithEmail`
/// ne rend un `UserEntity` qu'avec une session ouverte, et qu'ici il n'y en a
/// pas encore. L'appelant qui sait clore un défi (le panneau
/// d'administration) le fait par `resoudreSecondFacteur` ; les autres
/// affichent [message]. L'app grand public n'a pas d'écran de défi : un
/// compte admin enrôlé n'y entre plus, et le message le dit.
class SecondFacteurRequisFailure extends AuthFailure {
  const SecondFacteurRequisFailure(this.defi)
      : super(
          'Ce compte exige un second facteur : connectez-vous depuis le '
          "panneau d'administration.",
          code: 'multi-factor-auth-required',
        );

  final DefiSecondFacteur defi;

  @override
  List<Object> get props => [message, code ?? '', defi];
}
