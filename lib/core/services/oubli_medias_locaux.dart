import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'e2ee/media_dechiffre_cache.dart';
import 'file_download_service.dart';

final oubliMediasLocauxProvider = Provider<OubliMediasLocaux>((ref) {
  final dechiffres = ref.watch(mediaDechiffreCacheProvider);
  final telechargements = FileDownloadService();
  return OubliMediasLocaux(
    oublierUn: (id) async {
      await dechiffres.oublier(id);
      await telechargements.oublier(id);
    },
  );
});

/// Efface les copies locales en clair des médias d'un message **supprimé pour
/// tout le monde** (ou expiré) : le média déchiffré (`MediaDechiffreCache`)
/// et la pièce jointe téléchargée (`FileDownloadService`).
///
/// Appelé là où la suppression est apprise — le dépôt pour les messages en
/// clair, la passerelle pour les messages MLS, y compris par le rattrapage de
/// fond de la liste. Ces chemins revoient les mêmes messages supprimés à
/// chaque chargement : un identifiant n'est traité qu'une fois par processus,
/// pour ne pas refaire des accès disque à chaque page.
///
/// Toujours en tâche de fond : un effacement ne doit jamais retarder un
/// affichage, ni le faire échouer.
class OubliMediasLocaux {
  OubliMediasLocaux({required Future<void> Function(String messageId) oublierUn})
    : _oublierUn = oublierUn;

  final Future<void> Function(String messageId) _oublierUn;
  final Set<String> _traites = {};

  void oublier(Iterable<String> messageIds) {
    for (final id in messageIds) {
      if (id.isEmpty || !_traites.add(id)) continue;
      unawaited(
        _oublierUn(id).catchError((Object _) {
          // Raté : il sera retenté au prochain passage du message.
          _traites.remove(id);
        }),
      );
    }
  }
}
