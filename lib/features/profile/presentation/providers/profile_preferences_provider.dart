import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/location_publisher_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/profile_entity.dart';
import 'profile_provider.dart';

/// Bascules du profil pilotées à la fois par l'écran Profil et l'écran
/// Réglages.
///
/// Elles vivaient en copies `bool` locales dans chaque écran, et ces copies
/// ont produit deux bugs :
///
/// - **Écrasement.** Réglages initialisait ses quatre booléens à `true` et ne
///   les rafraîchissait que par un `ref.listen` posé dans `build` — qui ne se
///   déclenche jamais, le profil étant déjà chargé à l'ouverture. Comme la
///   sauvegarde réécrivait les quatre champs d'un seul `copyWith`, toucher une
///   bascule remettait les trois autres à `true` par-dessus les vraies valeurs.
/// - **Affichage périmé.** Profil lisait les siennes une seule fois au premier
///   frame, sans écoute : son sous-titre « Confidentialité et sécurité » ne
///   bougeait plus jamais.
///
/// D'où la règle portée par ce fichier : **on n'écrit qu'un champ à la fois**.
/// [ProfilePreferences.set] ne prend qu'une seule préférence, ce qui rend le
/// `copyWith` multi-champs — la cause directe de l'écrasement — impossible à
/// écrire plutôt que simplement déconseillé.
enum ProfilePreference {
  /// Apparaître dans les recherches.
  isVisible,

  /// Apparaître sur la carte des membres.
  shareLocation,
}

extension _ProfilePreferenceAccess on ProfilePreference {
  bool read(ProfileEntity profile) => switch (this) {
    ProfilePreference.isVisible => profile.isVisible,
    ProfilePreference.shareLocation => profile.shareLocation,
  };

  ProfileEntity write(ProfileEntity profile, bool value) => switch (this) {
    ProfilePreference.isVisible => profile.copyWith(isVisible: value),
    ProfilePreference.shareLocation => profile.copyWith(shareLocation: value),
  };
}

/// Valeur d'une bascule, dérivée du profil serveur — jamais d'une copie.
///
/// `null` tant que le profil n'est pas chargé : les écrans affichent alors
/// l'interrupteur dans son état par défaut sans prétendre connaître la vraie
/// valeur.
final profilePreferenceProvider = Provider.autoDispose
    .family<bool?, ProfilePreference>((ref, pref) {
      final userId = ref.watch(currentUserAsyncProvider).valueOrNull?.id;
      if (userId == null) return null;
      final profile = ref.watch(profileNotifierProvider(userId)).valueOrNull;
      if (profile == null) return null;
      return pref.read(profile);
    });

/// Écriture des bascules du profil. Une méthode, un champ.
final profilePreferencesProvider = Provider.autoDispose<ProfilePreferences>(
  ProfilePreferences.new,
);

class ProfilePreferences {
  final Ref _ref;

  ProfilePreferences(this._ref);

  /// Écrit **une seule** préférence. Il n'existe volontairement pas de
  /// variante multi-champs : c'en était une qui écrasait les bascules
  /// voisines.
  Future<void> set(ProfilePreference pref, bool value) async {
    final userId = (await _ref.read(currentUserAsyncProvider.future))?.id;
    if (userId == null) return;
    final notifier = _ref.read(profileNotifierProvider(userId).notifier);
    final profile = await _profil(userId);
    if (profile == null) return;
    await notifier.updateProfile(pref.write(profile, value));

    // `shareLocation` est le champ que `getNearbyProfiles` consulte pour
    // décider si quelqu'un d'autre voit cette position : l'écrire ne suffit
    // pas, il faut aussi (dé)clencher la capture GPS qui l'alimente,
    // immédiatement plutôt qu'au prochain retour au premier plan.
    if (pref == ProfilePreference.shareLocation) {
      if (value) {
        await LocationPublisherService.instance.start();
      } else {
        LocationPublisherService.instance.stop();
      }
    }
  }

  /// Profil courant, quitte à aller le chercher.
  ///
  /// `profileNotifierProvider` est un StateNotifierProvider **autoDispose** :
  /// son chargement est asynchrone et il ne pose `state` de façon synchrone
  /// que s'il trouve un cache. Sans cache — après un redémarrage, ou si le
  /// profil n'a pas encore été consulté — `valueOrNull` rend `null` juste
  /// après le `read`, et la bascule sortait sur son garde SANS RIEN DIRE :
  /// l'interrupteur revenait à sa position sans explication.
  ///
  /// Même défaut que celui qui empêchait `setMasterEnabled` d'écrire l'étage
  /// serveur des notifications (constaté sur appareil le 2026-08-06). Un
  /// StateNotifierProvider n'expose pas de `.future`, d'où le repli explicite
  /// sur le dépôt.
  Future<ProfileEntity?> _profil(String userId) async {
    final cache = _ref.read(profileNotifierProvider(userId)).valueOrNull;
    if (cache != null) return cache;
    final res = await _ref.read(profileRepositoryProvider).getProfile(userId);
    return res.fold((_) => null, (p) => p);
  }
}
