import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/embassies_local_datasource.dart';
import '../../data/datasources/embassies_supabase_datasource.dart';
import '../../data/repositories/embassies_repository_impl.dart';
import '../../domain/entities/embassy_entity.dart';
import '../../domain/repositories/embassies_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

part 'embassies_provider.g.dart';

// Data Source Provider
@riverpod
EmbassiesLocalDataSource embassiesLocalDataSource(Ref ref) {
  return EmbassiesLocalDataSource();
}

// Source distante : l'annuaire vient de Supabase depuis la migration
// `20260907180000_annuaire_postes_diplomatiques`. La collection Firestore
// `embassies` qu'on lisait avant n'a jamais contenu la moindre fiche.
@riverpod
EmbassiesDataSource embassiesDataSource(Ref ref) {
  return EmbassiesSupabaseDataSource();
}

// Repository Provider
@riverpod
EmbassiesRepository embassiesRepository(Ref ref) {
  final remoteDataSource = ref.watch(embassiesDataSourceProvider);
  final localDataSource = ref.watch(embassiesLocalDataSourceProvider);
  final networkInfo = ref.watch(networkInfoProvider);

  return EmbassiesRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    networkInfo: networkInfo,
  );
}

/// Date de la copie locale servie hors ligne, pour que l'écran puisse dire
/// « données du 3 septembre » plutôt que de les présenter comme courantes.
@riverpod
Future<DateTime?> embassiesCachedAt(Ref ref) {
  return ref.watch(embassiesRepositoryProvider).cachedAt();
}

// Imports moved to top

// Embassies List Provider
@Riverpod(keepAlive: true)
Future<List<EmbassyEntity>> embassiesList(Ref ref) async {
  // 1. Utilisateur courant, pour le contournement admin -- et rien d'autre.
  //
  // `.valueOrNull`, surtout pas `.value` : en Riverpod 2 ce dernier **relance**
  // l'erreur au lieu de rendre `null`, et l'exception traversait alors tout ce
  // provider jusqu'a l'ecran, qui affichait la trace brute.
  //
  // Et surtout : l'annuaire ne doit PAS etre conditionne a une session. C'est
  // une donnee publique -- la table est en lecture ouverte, y compris a `anon`,
  // precisement pour qu'on trouve son consulat avant d'avoir un compte. Le
  // `if (user == null) return []` qui etait ici renvoyait une liste vide sans
  // jamais appeler le depot, donc sans jamais lire le cache local.
  //
  // Verifie en mode avion sur SM A515F le 2026-09-07 : la session Supabase ne
  // peut plus se rafraichir (« Access token is expired and refreshing
  // failed »), l'utilisateur est vu comme deconnecte, et l'ecran affichait
  // « Aucune ambassade disponible » avec 32 fiches en cache sur l'appareil.
  // C'est exactement l'usage principal de cet ecran qui tombait : chercher le
  // numero de son consulat quand on n'a pas de reseau.
  final user = ref.watch(currentUserAsyncProvider).valueOrNull;

  // 2. Profil, pour la juridiction. Absent hors ligne ou sans session : le
  //    filtre plus bas traite deja le cas nul.
  final profile = user == null
      ? null
      : ref.watch(userStreamProvider(user.id)).valueOrNull;

  // 3. L'annuaire : Supabase si le reseau repond, copie locale sinon.
  final repository = ref.watch(embassiesRepositoryProvider);
  final allEmbassies = await repository.getEmbassies();

  // 4. Admin Bypass -- sans session, pas de contournement.
  if (user?.isAdmin ?? false) {
    return allEmbassies;
  }

  // 5. Filter for Normal Users
  return allEmbassies.where((e) {
    // Must be verified and not suspended
    if (!e.isVerified || e.isSuspended) return false;

    // Check Jurisdiction
    if (e.jurisdictionCountries.isNotEmpty) {
      final userCountry = profile?.currentCountry;
      if (userCountry == null) {
        return false;
      }

      // Check if user's country is in jurisdiction
      // Case-insensitive check recommended
      return e.jurisdictionCountries.any(
        (c) => c.toLowerCase() == userCountry.toLowerCase(),
      );
    }

    // If no jurisdiction specified, assume global/visible
    return true;
  }).toList();
}

// Search/Filter Interface
class EmbassiesState {
  final AsyncValue<List<EmbassyEntity>> embassies;
  final String searchQuery;

  EmbassiesState({required this.embassies, this.searchQuery = ''});

  EmbassiesState copyWith({
    AsyncValue<List<EmbassyEntity>>? embassies,
    String? searchQuery,
  }) {
    return EmbassiesState(
      embassies: embassies ?? this.embassies,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

@riverpod
class EmbassiesController extends _$EmbassiesController {
  @override
  EmbassiesState build() {
    final embassiesAsync = ref.watch(embassiesListProvider);
    return EmbassiesState(embassies: embassiesAsync);
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  List<EmbassyEntity> get filteredEmbassies {
    return state.embassies.when(
      data: (list) {
        if (state.searchQuery.isEmpty) return list;
        final lowerQuery = state.searchQuery.toLowerCase();
        return list.where((e) {
          return e.name.toLowerCase().contains(lowerQuery) ||
              e.country.toLowerCase().contains(lowerQuery) ||
              e.city.toLowerCase().contains(lowerQuery);
        }).toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );
  }
}

/// La fiche d'un poste, résolue par son identifiant seul.
///
/// Le lien profond (`diasponiger:///embassies/<id>`) et la notification
/// n'arrivent jamais avec l'entité en `state.extra` — c'est nul par
/// construction. Sans cette voie, la route n'avait que l'objet passé par la
/// liste, et un `!` sur ce nul faisait l'écran rouge « Null check operator
/// used on a null value » dès qu'on l'atteignait autrement.
///
/// Rend `null` — et non une erreur — quand la fiche n'existe pas ou n'est pas
/// montrable : l'écran distingue « introuvable » (rien à réessayer) de
/// « chargement impossible » (réessayer a du sens).
@riverpod
Future<EmbassyEntity?> embassyById(Ref ref, String id) async {
  // 1. L'annuaire, **attendu** et non simplement échantillonné.
  //
  //    Lire sa valeur courante ne servirait à rien ici : au démarrage à froid
  //    — précisément le cas du lien profond — la liste est encore en vol, on
  //    la verrait vide, et on repartirait vers le réseau pour une fiche que
  //    le même chargement était en train de ramener. Mesuré sur SM A515F le
  //    2026-09-08 : hors ligne, la liste sert la copie locale en quelques
  //    secondes là où ce second appel reste suspendu jusqu'à son délai de
  //    garde. La fiche s'ouvre donc en mode avion, ce qui est l'usage même
  //    de cet écran.
  //
  //    L'échec de la liste n'est pas notre échec : le dépôt sait encore
  //    servir le cache, donc on l'avale ici plutôt que de le propager.
  List<EmbassyEntity> visibles = const [];
  try {
    visibles = await ref.watch(embassiesListProvider.future);
  } catch (_) {
    // Volontairement ignoré -- l'étape 2 reste à essayer.
  }
  for (final embassy in visibles) {
    if (embassy.id == id) return embassy;
  }

  // 2. Absente de la liste : la fiche est hors de la juridiction de
  //    l'utilisateur, ou elle n'existe pas. Le premier cas est légitime sur
  //    un lien partagé — le consulat de Paris envoyé à quelqu'un qui vit au
  //    Canada — donc on passe par le dépôt, qui ne filtre pas.
  //
  //    Avec un délai de garde, parce que cet appel-là n'en a aucun : la
  //    requête Supabase attend indéfiniment quand le réseau est un trou noir
  //    plutôt qu'absent (VPN par-dessus le mode avion — `networkInfo` le voit
  //    connecté). Vérifié sur SM A515F le 2026-09-08 : sans cette borne, un
  //    identifiant inconnu laissait tourner le rond de chargement sans jamais
  //    atteindre « Fiche introuvable ».
  //
  //    Le dépassement est **relancé**, pas avalé : on ne sait pas si la fiche
  //    existe, donc l'écran doit dire « Chargement impossible » et proposer
  //    de réessayer, jamais affirmer qu'elle est introuvable.
  final embassy = await ref
      .watch(embassiesRepositoryProvider)
      .getEmbassyById(id)
      .timeout(const Duration(seconds: 8));
  if (embassy == null) return null;

  // 3. Le filtre de juridiction ne s'applique pas au lien direct, mais la
  //    modération si : une fiche non vérifiée ou suspendue reste invisible,
  //    exactement comme dans la liste. L'admin voit tout, comme ailleurs.
  final user = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (user?.isAdmin ?? false) return embassy;
  if (!embassy.isVerified || embassy.isSuspended) return null;
  return embassy;
}
