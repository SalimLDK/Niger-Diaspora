import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/location_publisher_service.dart';
import '../../../../core/services/logger_service.dart';
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
  ///
  /// Rend `false` si la préférence n'a pas été enregistrée — profil
  /// introuvable, écriture refusée, ou exception — et l'interrupteur est alors
  /// déjà revenu à sa valeur d'avant (voir plus bas). C'est à l'écran de le
  /// dire (`reportIfFailed`) : la méthode ne levait ni ne rendait rien, et
  /// l'interrupteur repartait en arrière sans un mot.
  Future<bool> set(ProfilePreference pref, bool value) async {
    try {
      final userId = (await _ref.read(currentUserAsyncProvider.future))?.id;
      if (userId == null) return false;
      final notifier = _ref.read(profileNotifierProvider(userId).notifier);
      // Sans profil de départ on ne peut rien écrire : la bascule sortait sur
      // ce garde SANS RIEN DIRE quand le profil n'était pas encore chargé.
      final profile = await notifier.currentProfile();
      if (profile == null) return false;
      await notifier.updateProfile(pref.write(profile, value));

      // `updateProfile` ne lève pas : sur refus il pose `AsyncValue.error` en
      // conservant la valeur d'avant, ce qui ramène l'interrupteur tout seul
      // (`profilePreferenceProvider` lit `valueOrNull`). Mais rien ne le
      // signale à l'appelant — et la capture GPS ci-dessous partait quand même,
      // sur un `shareLocation` que le serveur n'avait pas reçu.
      if (_ref.read(profileNotifierProvider(userId)).hasError) return false;
    } catch (e, s) {
      LoggerService.w('ProfilePreferences.set($pref): échec', e, s);
      return false;
    }

    // `shareLocation` est le champ que `getNearbyProfiles` consulte pour
    // décider si quelqu'un d'autre voit cette position : l'écrire ne suffit
    // pas, il faut aussi (dé)clencher la capture GPS qui l'alimente,
    // immédiatement plutôt qu'au prochain retour au premier plan.
    //
    // À part : la préférence est écrite, un échec de capture ne doit pas la
    // faire passer pour refusée. `start()` se relance au prochain retour au
    // premier plan.
    if (pref == ProfilePreference.shareLocation) {
      try {
        if (value) {
          await LocationPublisherService.instance.start();
        } else {
          LocationPublisherService.instance.stop();
        }
      } catch (e, s) {
        LoggerService.w('ProfilePreferences.set($pref): capture GPS', e, s);
      }
    }
    return true;
  }
}
