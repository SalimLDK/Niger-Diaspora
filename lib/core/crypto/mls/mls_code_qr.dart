import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'mls_code_securite.dart';

/// Le code de sécurité d'un appareil, en QR, prêt à être montré à la personne
/// d'en face (plan MLS, phase 7).
///
/// **La taille est imposée, et ce n'est pas cosmétique.** `AlertDialog` mesure
/// son contenu par dimensions **intrinsèques** ; `QrImageView` contient un
/// `LayoutBuilder`, qui ne sait pas répondre à ce genre de question
/// (« LayoutBuilder does not support returning intrinsic dimensions »). Sans
/// une taille qui arrête la question avant d'atteindre le QR, la mise en page
/// du dialogue échoue **en entier** : ni titre, ni bouton, ni QR — un rectangle
/// vide.
///
/// Et ça ne se voit nulle part : ce dépôt détourne `FlutterError.onError` vers
/// Crashlytics, donc aucune trace dans `logcat` et pas d'écran rouge. Trouvé
/// sur un téléphone le 2026-09-15, diagnostiqué seulement en s'attachant au
/// processus avec `flutter attach`.
///
/// **Le QR ne porte aucun secret** : une identité d'appareil et une empreinte
/// publique, toutes deux déjà lisibles dans `mls_devices`. Photographié par un
/// tiers, il ne lui apprend rien.
class MlsCodeQr extends StatelessWidget {
  const MlsCodeQr({
    super.key,
    required this.mlsIdentity,
    required this.empreinte,
    this.cote = 244,
  });

  final String mlsIdentity;
  final Uint8List empreinte;

  /// Côté du carré blanc, marge comprise.
  final double cote;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cote,
      height: cote,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        // Modules noirs sur fond blanc, quel que soit le thème : une caméra
        // attend ce contraste-là, et un QR rendu aux couleurs d'un thème
        // sombre devient illisible pour elle.
        child: QrImageView(
          data: MlsCodeSecurite.chargeQr(
            mlsIdentity: mlsIdentity,
            empreinte: empreinte,
          ),
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
