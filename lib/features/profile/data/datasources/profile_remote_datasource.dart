import '../models/profile_model.dart';

// L'implémentation Firestore de cette interface a été retirée le 2026-08-06.
//
// Les profils vivent dans Supabase (`ProfileSupabaseDataSource`, qui implémente
// l'interface ci-dessous). `ProfileRemoteDataSourceImpl` lisait encore la
// collection Firestore `users`, restée à 2 documents dont un seul nommé, contre
// 10 profils côté Supabase. Trois chemins l'instanciaient encore — recherche
// globale, son provider, « Nouvelle conversation » — et ne trouvaient donc
// qu'une personne sur dix. Voir le commit « fix(recherche) » du même jour.
//
// Le garder « au cas où » aurait laissé une seconde source de vérité, muette et
// périmée, à portée du prochain qui chercherait un `ProfileRemoteDataSource`
// concret. Les 636 lignes retirées restent dans l'historique.

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile(String userId);
  Future<ProfileModel> updateProfile(ProfileModel profile);
  Future<String> uploadProfilePhoto(String userId, String filePath);
  Future<void> updateLocation(String userId, double latitude, double longitude);
  Future<List<ProfileModel>> getNearbyProfiles(
    double latitude,
    double longitude,
    double radiusKm,
  );
  Future<List<ProfileModel>> getProfilesByCountry(String country);
  Future<List<ProfileModel>> searchProfiles(String query);
  Stream<ProfileModel> getUserStream(String userId);
  Future<void> updateLastLogin(String userId);
  Future<void> updateOnlineStatus(
    String userId,
    bool isOnline,
    DateTime lastSeen,
  );
  Future<void> updateOnlineStatusVisibility(String userId, bool showStatus);
  Future<void> updateNotifyLocalEvents(String userId, bool enabled);

  /// Miroir serveur des préférences par type, lu par l'Edge Function
  /// send-push. Sans lui, couper une bascule n'a d'effet qu'au premier plan.
  Future<void> updateNotificationPrefs(String userId, Map<String, bool> prefs);
  ProfileModel? getCachedProfile(String userId);

  /// Vrai si la poignée [handle] est disponible (§16f). Comparaison
  /// insensible à la casse ; [excludeUserId] ignore le propriétaire actuel.
  Future<bool> isHandleAvailable(String handle, {String? excludeUserId});
}
