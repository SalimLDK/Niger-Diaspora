// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocked_users_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$blockedUsersDataSourceHash() =>
    r'4bd4e3e5e46b4a14a235d33cd72b7e371a34c333';

/// See also [blockedUsersDataSource].
@ProviderFor(blockedUsersDataSource)
final blockedUsersDataSourceProvider =
    AutoDisposeProvider<BlockedUsersDataSource>.internal(
      blockedUsersDataSource,
      name: r'blockedUsersDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$blockedUsersDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BlockedUsersDataSourceRef =
    AutoDisposeProviderRef<BlockedUsersDataSource>;
String _$blockedUsersRepositoryHash() =>
    r'c28c7cc9a61fb3517f70c0ed1bb67703867b07ff';

/// See also [blockedUsersRepository].
@ProviderFor(blockedUsersRepository)
final blockedUsersRepositoryProvider =
    AutoDisposeProvider<BlockedUsersRepository>.internal(
      blockedUsersRepository,
      name: r'blockedUsersRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$blockedUsersRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BlockedUsersRepositoryRef =
    AutoDisposeProviderRef<BlockedUsersRepository>;
String _$blockedUsersHash() => r'7e1ff2aae8c1ac40adf92de0a43375b1690f3f0a';

/// See also [blockedUsers].
@ProviderFor(blockedUsers)
final blockedUsersProvider =
    AutoDisposeStreamProvider<List<BlockedUserEntity>>.internal(
      blockedUsers,
      name: r'blockedUsersProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$blockedUsersHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BlockedUsersRef = AutoDisposeStreamProviderRef<List<BlockedUserEntity>>;
String _$usersWhoBlockedMeHash() => r'77b07db0d8d1a33b3a39f0ce6c3bed8a27ff95e0';

/// Les identifiants qui **m'ont bloqué**.
///
/// Le pendant de [blockedUsers], qui donne le sens direct. Celui-ci n'existait
/// pas : les dix endroits qui posent la question lisaient
/// `profil.blockedByUserIds`, un champ que `_mapProfile` code en dur à vide
/// depuis que les profils viennent de Supabase. La réponse était donc toujours
/// non, et une personne qui vous a bloqué continuait d'apparaître sur la carte,
/// en ligne, et de recevoir vos messages.
///
/// Rend un ensemble vide tant que rien n'est chargé — c'est le défaut sûr côté
/// affichage : on ne masque personne à tort pendant le chargement.
///
/// Copied from [usersWhoBlockedMe].
@ProviderFor(usersWhoBlockedMe)
final usersWhoBlockedMeProvider =
    AutoDisposeStreamProvider<Set<String>>.internal(
      usersWhoBlockedMe,
      name: r'usersWhoBlockedMeProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$usersWhoBlockedMeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UsersWhoBlockedMeRef = AutoDisposeStreamProviderRef<Set<String>>;
String _$blockUserNotifierHash() => r'f63d4492dcc45d55d80d2a0f23a2efc04e572ddc';

/// See also [BlockUserNotifier].
@ProviderFor(BlockUserNotifier)
final blockUserNotifierProvider =
    AutoDisposeNotifierProvider<BlockUserNotifier, AsyncValue<void>>.internal(
      BlockUserNotifier.new,
      name: r'blockUserNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$blockUserNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BlockUserNotifier = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
