import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Libellé lisible de l'appareil courant, pour tout ce que l'utilisateur voit :
/// liste des appareils connectés, métadonnées de sauvegarde des clés.
///
/// Existait en double auparavant — une version correcte dans
/// `DeviceSyncService`, et une version `'${platform.name} Device'` dans
/// `KeyBackupService` qui affichait « android Device » sur l'écran de
/// sauvegarde (constaté sur appareil le 2026-08-04).
Future<String> currentDeviceLabel() async {
  try {
    if (kIsWeb) return 'Navigateur web';

    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final brand = android.brand.trim();
      final model = android.model.trim();
      // `brand` remonte en minuscules chez la plupart des constructeurs
      // (« samsung »), ce qui fait négligé à côté du modèle en capitales.
      final prettyBrand = brand.isEmpty
          ? ''
          : brand[0].toUpperCase() + brand.substring(1);
      final label = '$prettyBrand $model'.trim();
      if (label.isNotEmpty) return label;
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      if (ios.name.trim().isNotEmpty) return ios.name.trim();
    } else if (Platform.isMacOS) {
      final mac = await info.macOsInfo;
      if (mac.computerName.trim().isNotEmpty) return mac.computerName.trim();
    } else if (Platform.isWindows) {
      final win = await info.windowsInfo;
      if (win.computerName.trim().isNotEmpty) return win.computerName.trim();
    } else if (Platform.isLinux) {
      final linux = await info.linuxInfo;
      if (linux.prettyName.trim().isNotEmpty) return linux.prettyName.trim();
    }
  } catch (e) {
    // Un libellé est du confort : il ne doit jamais faire échouer une
    // sauvegarde de clés ni un enregistrement d'appareil.
    debugPrint('currentDeviceLabel: $e');
  }
  return 'Appareil inconnu';
}
