import '../../../src/rust/frb_generated.dart';

/// Charge la bibliothèque native Rust, une fois par isolate.
///
/// **Pourquoi ce fichier existe.** `RustLib.init()` lève
/// `StateError('Should not initialize flutter_rust_bridge twice')` au second
/// appel. Deux appelants vivaient chacun avec sa propre garde `_initRust` :
/// `mlsEngineProvider` (l'application) et `MlsNotificationPreview` (l'isolate
/// de notification). Tant que chacun tournait dans son isolate, les deux
/// gardes suffisaient.
///
/// Elles ont cessé de suffire dès que l'aperçu a été reconstruit **au premier
/// plan**, dans l'isolate de l'application : le moteur MLS y a déjà appelé
/// `RustLib.init()`, la garde de l'aperçu ne le sait pas, son appel lève, et
/// le `catch` de `MlsNotificationPreview.texte` rend `null`. Le symptôme n'est
/// pas une erreur : c'est « Nouveau message » à la place du texte, exactement
/// ce qu'affiche un déchiffrement légitimement impossible. Rien ne distingue
/// les deux dans le journal.
///
/// La garde est donc unique, et elle interroge l'état réel plutôt que de s'en
/// souvenir : `initialized` est un getter public de `BaseEntrypoint`, sûr à
/// lire avant toute initialisation (il ne lève pas, contrairement à `api`).
Future<void> initialiserRustUneFois() {
  if (RustLib.instance.initialized) return Future.value();
  return _init ??= RustLib.init();
}

Future<void>? _init;

/// Oublie l'initialisation en cours ou terminée.
///
/// Réservé aux tests : un `Future` en échec resterait mémorisé pour la durée
/// de l'isolate, et le cas d'erreur ne serait jouable qu'une fois.
void reinitialiserGardeRustPourTests() => _init = null;
