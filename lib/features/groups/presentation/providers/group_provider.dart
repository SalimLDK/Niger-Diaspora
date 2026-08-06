import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/group_remote_datasource.dart';
import '../../data/datasources/group_request_datasource.dart';
import '../../data/datasources/group_supabase_datasource.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_request_entity.dart';
import '../../domain/repositories/group_repository.dart';

part 'group_provider.g.dart';

/// Source de données des groupes : **Supabase**, depuis le 2026-08-06.
///
/// Elle a toujours rendu l'implémentation Firestore
/// (`GroupRemoteDataSourceImpl`), depuis le commit initial et sans exception,
/// alors que les groupes vivent dans Supabase et que la collection Firestore
/// `groups` est vide. C'est le seul point de câblage de toute la
/// fonctionnalité — liste, découverte, fiche, création, adhésion, recherche —
/// si bien que tout le travail fait sur `GroupSupabaseDataSource` (session
/// avant lecture, appartenance lue dans `group_members`, garde « Officiel »)
/// portait sur une classe que ce provider n'instanciait pas.
///
/// Conséquences observées, toutes le même défaut :
/// - « Découvrir » annonçait « Aucun groupe public » sur trois groupes publics,
///   et la recherche ne remontait rien ;
/// - l'onglet « Mes groupes » ne montrait AUCUN groupe Supabase ;
/// - la fiche d'un groupe Supabase affichait « Erreur de chargement » et rien
///   d'autre : ni ouverture de la discussion, ni membres, ni quitter/partager ;
/// - le menu « + » du composer n'offrait ni sondage ni événement, leurs
///   permissions dérivant de l'entité groupe restée nulle ;
/// - le groupe officiel du pays n'était jamais rejoint à l'inscription :
///   `GroupRemoteDataSourceImpl.ensureOfficialGroup` lève `UnimplementedError`,
///   que `GroupRepositoryImpl` traduit en `Left(...)` que
///   `ProfileNotifier._joinOfficialGroup` ignore (`(failure) async {}`).
///
/// ⚠️ Les groupes hérités de Firestore (id de 20 caractères, hors de
/// `public.groups` dont l'`id` est `uuid`) ne sont PAS lisibles par cette
/// source. Ils doivent être migrés — voir `tools/migrate_legacy_groups.sql`,
/// qui leur attribue un uuid et réaligne `conversations.group_id`.
@riverpod
GroupRemoteDataSource groupRemoteDataSource(Ref ref) {
  return GroupSupabaseDataSource();
}

@riverpod
GroupRequestDataSource groupRequestDataSource(Ref ref) {
  return GroupRequestDataSourceImpl();
}

@riverpod
GroupRepository groupRepository(Ref ref) {
  return GroupRepositoryImpl(
    remoteDataSource: ref.watch(groupRemoteDataSourceProvider),
    requestDataSource: ref.watch(groupRequestDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
    messageRepository: ref.watch(messageRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
class GroupsNotifier extends _$GroupsNotifier {
  @override
  AsyncValue<List<GroupEntity>> build() {
    loadGroups();
    return const AsyncValue.loading();
  }

  /// Préfixe de journal de `loadGroups`.
  ///
  /// « Découvrir » a annoncé « Aucun groupe public » pendant deux sessions
  /// alors que la base en contenait trois, et rien dans les journaux ne
  /// permettait de distinguer les quatre issues possibles : cache servi,
  /// réseau vide, échec avalé, ou source qui interroge le mauvais backend.
  /// C'était le dernier cas — et il ne se voyait nulle part. La trace nomme
  /// désormais la source interrogée, ce qui suffit à le voir en une ligne.
  static const _trace = '[groupes] loadGroups';

  Future<void> loadGroups() async {
    final repository = ref.read(groupRepositoryProvider);
    if (kDebugMode) {
      debugPrint(
        '$_trace source=${ref.read(groupRemoteDataSourceProvider).runtimeType}',
      );
    }

    // 1. Try to load from cache first (Cache-First Strategy)
    final cachedResult = repository.getCachedGroups();
    cachedResult.fold(
      (failure) {
        // Cache miss or error - show loading
        if (kDebugMode) debugPrint('$_trace cache=échec ${failure.message}');
        state = const AsyncValue.loading();
      },
      (cachedGroups) {
        if (kDebugMode) debugPrint('$_trace cache=${cachedGroups.length}');
        if (cachedGroups.isNotEmpty) {
          state = AsyncValue.data(cachedGroups);
        } else {
          state = const AsyncValue.loading();
        }
      },
    );

    // 2. Fetch from network
    final result = await repository.getGroups();
    result.fold((failure) {
      // `getGroups` est le seul chemin de l'onglet « Découvrir » : un échec
      // ici et un backend réellement vide donnent le même écran. Il faut donc
      // que le journal les sépare, même quand l'état n'est pas mis à jour.
      if (kDebugMode) debugPrint('$_trace réseau=échec ${failure.message}');
      // Only update to error if we don't have cached data
      if (state.valueOrNull == null || state.valueOrNull!.isEmpty) {
        state = AsyncValue.error(failure.message, StackTrace.current);
      }
    }, (groups) {
      if (kDebugMode) debugPrint('$_trace réseau=${groups.length} groupes');
      state = AsyncValue.data(groups);
    });
  }

  Future<void> loadGroupsByCategory(GroupCategory category) async {
    state = const AsyncValue.loading();
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.getGroupsByCategory(category);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (groups) => state = AsyncValue.data(groups),
    );
  }

  Future<void> refresh() async {
    await loadGroups();
  }
}

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier {
  @override
  AsyncValue<GroupEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadGroup(String groupId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.getGroupById(groupId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (group) => state = AsyncValue.data(group),
    );
  }

  Future<bool> joinGroup(String groupId, String userId) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.joinGroup(groupId, userId);
    return result.fold((failure) => false, (_) {
      loadGroup(groupId);
      return true;
    });
  }

  Future<bool> leaveGroup(String groupId, String userId) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.leaveGroup(groupId, userId);
    return result.fold((failure) => false, (_) {
      loadGroup(groupId);
      return true;
    });
  }
}

/// Find a group by its name - useful as fallback when groupId is missing
@riverpod
Future<GroupEntity?> groupByName(Ref ref, String groupName) async {
  final repository = ref.watch(groupRepositoryProvider);
  final result = await repository.getGroups();

  return result.fold((failure) => null, (groups) {
    try {
      return groups.firstWhere((g) => g.name == groupName);
    } catch (e) {
      return null;
    }
  });
}

/// Récupérer un groupe par son ID
@riverpod
Future<GroupEntity?> groupById(Ref ref, String groupId) async {
  final repository = ref.watch(groupRepositoryProvider);
  final result = await repository.getGroupById(groupId);

  return result.fold((failure) => null, (group) => group);
}

@Riverpod(keepAlive: true)
class MyGroupsNotifier extends _$MyGroupsNotifier {
  @override
  AsyncValue<List<GroupEntity>> build() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null) {
      loadMyGroups(user.id);
    }
    return const AsyncValue.loading();
  }

  Future<void> loadMyGroups(String userId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.getMyGroups(userId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (groups) => state = AsyncValue.data(groups),
    );
  }

  /// Motif du dernier échec d'écriture, pour que l'écran puisse le dire à
  /// l'utilisateur au lieu d'un « Erreur » générique.
  String? lastError;

  Future<bool> createGroup(GroupEntity group) async {
    lastError = null;
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.createGroup(group);
    return result.fold(
      (failure) {
        lastError = failure.message;
        return false;
      },
      (created) {
        final currentGroups = state.valueOrNull ?? [];
        state = AsyncValue.data([created, ...currentGroups]);
        return true;
      },
    );
  }

  Future<bool> updateGroup(GroupEntity group) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.updateGroup(group);
    return result.fold((failure) => false, (updated) {
      final currentGroups = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentGroups.map((g) => g.id == updated.id ? updated : g).toList(),
      );
      return true;
    });
  }

  Future<bool> deleteGroup(String groupId) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.deleteGroup(groupId);
    return result.fold((failure) => false, (_) {
      final currentGroups = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentGroups.where((g) => g.id != groupId).toList(),
      );
      return true;
    });
  }
}

/// Stream provider for real-time group updates
@riverpod
Stream<GroupEntity?> groupStream(Ref ref, String groupId) {
  final repository = ref.watch(groupRepositoryProvider);
  return repository.getGroupStream(groupId).map((either) {
    return either.fold((failure) => null, (group) => group);
  });
}

@riverpod
Stream<List<GroupRequestEntity>> groupPendingRequests(Ref ref, String groupId) {
  final repository = ref.watch(groupRepositoryProvider);
  return repository.getPendingRequests(groupId).map((either) {
    return either.fold((failure) => [], (requests) => requests);
  });
}

@riverpod
Stream<List<GroupRequestEntity>> myGroupRequests(Ref ref, String userId) {
  final repository = ref.watch(groupRepositoryProvider);
  return repository.getMyGroupRequests(userId).map((either) {
    return either.fold((failure) => [], (requests) => requests);
  });
}

/// Provider pour récupérer la liste des pays disponibles (depuis les groupes existants)
@riverpod
List<String> availableGroupCountries(Ref ref) {
  final groupsAsync = ref.watch(groupsNotifierProvider);
  final myGroupsAsync = ref.watch(myGroupsNotifierProvider);

  final allGroups = <GroupEntity>[
    ...groupsAsync.valueOrNull ?? [],
    ...myGroupsAsync.valueOrNull ?? [],
  ];

  // Extraire les pays uniques non-null
  final countries = allGroups
      .map((g) => g.country)
      .whereType<String>()
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  return countries;
}

/// Provider pour récupérer la liste des régions d'origine disponibles
@riverpod
List<String> availableGroupRegions(Ref ref) {
  final groupsAsync = ref.watch(groupsNotifierProvider);
  final myGroupsAsync = ref.watch(myGroupsNotifierProvider);

  final allGroups = <GroupEntity>[
    ...groupsAsync.valueOrNull ?? [],
    ...myGroupsAsync.valueOrNull ?? [],
  ];

  // Extraire les régions uniques non-null
  final regions = allGroups
      .map((g) => g.originRegion)
      .whereType<String>()
      .where((r) => r.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  return regions;
}
