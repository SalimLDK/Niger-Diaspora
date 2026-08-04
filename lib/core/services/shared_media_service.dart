import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Service for receiving media/text shared from other apps into Diaspo Niger.
/// Wraps receive_sharing_intent and exposes a Riverpod provider.
class SharedMediaService {
  SharedMediaService() {
    _mediaStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          _onMediaReceived,
          onError: (Object error) {
            debugPrint('SharedMediaService stream error: $error');
          },
        );

    // Also handle the case where the app was launched from a share intent.
    _initialMediaReady =
        ReceiveSharingIntent.instance.getInitialMedia().then(_onInitialMedia).catchError(
      (Object error) {
        debugPrint('SharedMediaService initial media error: $error');
      },
    );
  }

  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSubscription;

  final _controller = StreamController<List<SharedMediaFile>>.broadcast();

  /// Résolu quand le canal natif a répondu pour le contenu initial.
  ///
  /// `consumeInitialMedia` l'attend : la lecture est asynchrone, et le shell
  /// interrogeait `_initialMedia` dès la première frame — avant la réponse. Un
  /// vrai partage était donc perdu, et marqué consommé au passage.
  late final Future<void> _initialMediaReady;

  /// Emits whenever new shared media is received while the app is running.
  Stream<List<SharedMediaFile>> get mediaStream => _controller.stream;

  /// Media received when the app was launched from a share intent.
  List<SharedMediaFile>? _initialMedia;

  /// Whether initial media has already been consumed.
  bool _initialConsumed = false;

  /// Écarte les ouvertures par lien profond du flux « partage ».
  ///
  /// Le plugin ne distingue pas un partage entrant d'une simple ouverture par
  /// lien : côté Android il traduit tout `ACTION_VIEW` sans type MIME en
  /// élément `SharedMediaType.url`. Or l'app déclare bien des liens profonds
  /// (`diasponiger://`, `https://diasponiger.web.app`) mais aucun filtre
  /// `ACTION_SEND` — rien de légitime n'arrive donc ici en `url`.
  ///
  /// Sans ce tri : Android redonne à l'activité racine l'intent d'origine de sa
  /// tâche à chaque relance, si bien qu'une seule ouverture par lien faisait
  /// rouvrir la feuille « Envoyer à… » à tous les démarrages à froid suivants,
  /// alors qu'aucun partage n'avait eu lieu.
  static List<SharedMediaFile> _withoutDeepLinks(List<SharedMediaFile> value) =>
      value.where((file) => file.type != SharedMediaType.url).toList();

  void _onMediaReceived(List<SharedMediaFile> value) {
    final shared = _withoutDeepLinks(value);
    if (shared.isNotEmpty) {
      _controller.add(shared);
    }
  }

  void _onInitialMedia(List<SharedMediaFile> value) {
    final shared = _withoutDeepLinks(value);
    _initialMedia = shared.isNotEmpty ? shared : null;
  }

  /// Returns media received when the app was cold-started from a share intent.
  /// Only returns a non-null value once; subsequent calls return null.
  Future<List<SharedMediaFile>?> consumeInitialMedia() async {
    if (_initialConsumed) return null;
    await _initialMediaReady;
    // Un second appel a pu passer pendant l'attente ci-dessus.
    if (_initialConsumed) return null;
    _initialConsumed = true;
    final media = _initialMedia;
    _initialMedia = null;
    unawaited(_resetPlatformIntent());
    return media;
  }

  /// Efface le contenu initial après traitement — y compris quand l'utilisateur
  /// ferme la feuille sans rien envoyer, sinon le partage resterait en attente.
  ///
  /// Ne ré-arme pas la détection : un vrai démarrage à froid reconstruit ce
  /// service, la remise à zéro du drapeau ne servait qu'à rouvrir la feuille.
  void resetInitialMedia() {
    _initialMedia = null;
    _initialConsumed = true;
    unawaited(_resetPlatformIntent());
  }

  /// Purge la copie que le plugin garde côté natif : elle survit à la
  /// consommation côté Dart et serait resservie à un nouveau rattachement de
  /// l'activité au moteur Flutter.
  Future<void> _resetPlatformIntent() async {
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (error) {
      debugPrint('SharedMediaService reset error: $error');
    }
  }

  /// Cleans up resources.
  void dispose() {
    _mediaStreamSubscription?.cancel();
    _controller.close();
  }
}

/// Provider for the shared media service.
final sharedMediaServiceProvider = Provider<SharedMediaService>((ref) {
  final service = SharedMediaService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of shared media received while the app is in the foreground.
final sharedMediaStreamProvider = StreamProvider<List<SharedMediaFile>>((ref) {
  return ref.watch(sharedMediaServiceProvider).mediaStream;
});

/// Extension helpers to interpret receive_sharing_intent values.
extension SharedMediaFileX on SharedMediaFile {
  bool get isImage => type == SharedMediaType.image;
  bool get isVideo => type == SharedMediaType.video;
  bool get isText => type == SharedMediaType.text || type == SharedMediaType.url;
  bool get isFile => type == SharedMediaType.file;

  /// The actual local file path, when available.
  String get localPath => path;

  /// The shared text content, when the incoming type is text.
  String? get sharedText => message;

  /// Whether the file currently exists on disk.
  bool get exists => File(localPath).existsSync();
}
