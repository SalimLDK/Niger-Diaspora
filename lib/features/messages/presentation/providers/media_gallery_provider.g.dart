// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_gallery_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userConversationIdHash() =>
    r'4f93a2f1e58a4567cae1419db88933dbb16f7f54';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Provider to get the conversation ID for a user (for profile media section)
/// Returns the conversation ID if a conversation exists with the given user
///
/// Copied from [userConversationId].
@ProviderFor(userConversationId)
const userConversationIdProvider = UserConversationIdFamily();

/// Provider to get the conversation ID for a user (for profile media section)
/// Returns the conversation ID if a conversation exists with the given user
///
/// Copied from [userConversationId].
class UserConversationIdFamily extends Family<AsyncValue<String?>> {
  /// Provider to get the conversation ID for a user (for profile media section)
  /// Returns the conversation ID if a conversation exists with the given user
  ///
  /// Copied from [userConversationId].
  const UserConversationIdFamily();

  /// Provider to get the conversation ID for a user (for profile media section)
  /// Returns the conversation ID if a conversation exists with the given user
  ///
  /// Copied from [userConversationId].
  UserConversationIdProvider call(String otherUserId) {
    return UserConversationIdProvider(otherUserId);
  }

  @override
  UserConversationIdProvider getProviderOverride(
    covariant UserConversationIdProvider provider,
  ) {
    return call(provider.otherUserId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userConversationIdProvider';
}

/// Provider to get the conversation ID for a user (for profile media section)
/// Returns the conversation ID if a conversation exists with the given user
///
/// Copied from [userConversationId].
class UserConversationIdProvider extends AutoDisposeFutureProvider<String?> {
  /// Provider to get the conversation ID for a user (for profile media section)
  /// Returns the conversation ID if a conversation exists with the given user
  ///
  /// Copied from [userConversationId].
  UserConversationIdProvider(String otherUserId)
    : this._internal(
        (ref) => userConversationId(ref as UserConversationIdRef, otherUserId),
        from: userConversationIdProvider,
        name: r'userConversationIdProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userConversationIdHash,
        dependencies: UserConversationIdFamily._dependencies,
        allTransitiveDependencies:
            UserConversationIdFamily._allTransitiveDependencies,
        otherUserId: otherUserId,
      );

  UserConversationIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.otherUserId,
  }) : super.internal();

  final String otherUserId;

  @override
  Override overrideWith(
    FutureOr<String?> Function(UserConversationIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserConversationIdProvider._internal(
        (ref) => create(ref as UserConversationIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        otherUserId: otherUserId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _UserConversationIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserConversationIdProvider &&
        other.otherUserId == otherUserId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, otherUserId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserConversationIdRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `otherUserId` of this provider.
  String get otherUserId;
}

class _UserConversationIdProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with UserConversationIdRef {
  _UserConversationIdProviderElement(super.provider);

  @override
  String get otherUserId => (origin as UserConversationIdProvider).otherUserId;
}

String _$groupConversationIdHash() =>
    r'bfdea0f396f0c240a5eba4ebfd1d321f6a49796c';

/// Provider to get the conversation ID for a group (for group media section)
/// Returns the conversation ID if a conversation exists with the given group ID
///
/// Copied from [groupConversationId].
@ProviderFor(groupConversationId)
const groupConversationIdProvider = GroupConversationIdFamily();

/// Provider to get the conversation ID for a group (for group media section)
/// Returns the conversation ID if a conversation exists with the given group ID
///
/// Copied from [groupConversationId].
class GroupConversationIdFamily extends Family<AsyncValue<String?>> {
  /// Provider to get the conversation ID for a group (for group media section)
  /// Returns the conversation ID if a conversation exists with the given group ID
  ///
  /// Copied from [groupConversationId].
  const GroupConversationIdFamily();

  /// Provider to get the conversation ID for a group (for group media section)
  /// Returns the conversation ID if a conversation exists with the given group ID
  ///
  /// Copied from [groupConversationId].
  GroupConversationIdProvider call(String groupId) {
    return GroupConversationIdProvider(groupId);
  }

  @override
  GroupConversationIdProvider getProviderOverride(
    covariant GroupConversationIdProvider provider,
  ) {
    return call(provider.groupId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'groupConversationIdProvider';
}

/// Provider to get the conversation ID for a group (for group media section)
/// Returns the conversation ID if a conversation exists with the given group ID
///
/// Copied from [groupConversationId].
class GroupConversationIdProvider extends AutoDisposeFutureProvider<String?> {
  /// Provider to get the conversation ID for a group (for group media section)
  /// Returns the conversation ID if a conversation exists with the given group ID
  ///
  /// Copied from [groupConversationId].
  GroupConversationIdProvider(String groupId)
    : this._internal(
        (ref) => groupConversationId(ref as GroupConversationIdRef, groupId),
        from: groupConversationIdProvider,
        name: r'groupConversationIdProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$groupConversationIdHash,
        dependencies: GroupConversationIdFamily._dependencies,
        allTransitiveDependencies:
            GroupConversationIdFamily._allTransitiveDependencies,
        groupId: groupId,
      );

  GroupConversationIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.groupId,
  }) : super.internal();

  final String groupId;

  @override
  Override overrideWith(
    FutureOr<String?> Function(GroupConversationIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GroupConversationIdProvider._internal(
        (ref) => create(ref as GroupConversationIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        groupId: groupId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _GroupConversationIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupConversationIdProvider && other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GroupConversationIdRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GroupConversationIdProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with GroupConversationIdRef {
  _GroupConversationIdProviderElement(super.provider);

  @override
  String get groupId => (origin as GroupConversationIdProvider).groupId;
}

String _$conversationMediaHash() => r'3a8a0ec6a3f6e9b2cf23d1a516a14f06e921490f';

abstract class _$ConversationMedia
    extends BuildlessAutoDisposeNotifier<MediaGalleryState> {
  late final String conversationId;

  MediaGalleryState build(String conversationId);
}

/// Provider for fetching media (images and files) from a conversation
/// Excludes audio messages
///
/// Copied from [ConversationMedia].
@ProviderFor(ConversationMedia)
const conversationMediaProvider = ConversationMediaFamily();

/// Provider for fetching media (images and files) from a conversation
/// Excludes audio messages
///
/// Copied from [ConversationMedia].
class ConversationMediaFamily extends Family<MediaGalleryState> {
  /// Provider for fetching media (images and files) from a conversation
  /// Excludes audio messages
  ///
  /// Copied from [ConversationMedia].
  const ConversationMediaFamily();

  /// Provider for fetching media (images and files) from a conversation
  /// Excludes audio messages
  ///
  /// Copied from [ConversationMedia].
  ConversationMediaProvider call(String conversationId) {
    return ConversationMediaProvider(conversationId);
  }

  @override
  ConversationMediaProvider getProviderOverride(
    covariant ConversationMediaProvider provider,
  ) {
    return call(provider.conversationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'conversationMediaProvider';
}

/// Provider for fetching media (images and files) from a conversation
/// Excludes audio messages
///
/// Copied from [ConversationMedia].
class ConversationMediaProvider
    extends
        AutoDisposeNotifierProviderImpl<ConversationMedia, MediaGalleryState> {
  /// Provider for fetching media (images and files) from a conversation
  /// Excludes audio messages
  ///
  /// Copied from [ConversationMedia].
  ConversationMediaProvider(String conversationId)
    : this._internal(
        () => ConversationMedia()..conversationId = conversationId,
        from: conversationMediaProvider,
        name: r'conversationMediaProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$conversationMediaHash,
        dependencies: ConversationMediaFamily._dependencies,
        allTransitiveDependencies:
            ConversationMediaFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  ConversationMediaProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  MediaGalleryState runNotifierBuild(covariant ConversationMedia notifier) {
    return notifier.build(conversationId);
  }

  @override
  Override overrideWith(ConversationMedia Function() create) {
    return ProviderOverride(
      origin: this,
      override: ConversationMediaProvider._internal(
        () => create()..conversationId = conversationId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ConversationMedia, MediaGalleryState>
  createElement() {
    return _ConversationMediaProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationMediaProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConversationMediaRef
    on AutoDisposeNotifierProviderRef<MediaGalleryState> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationMediaProviderElement
    extends
        AutoDisposeNotifierProviderElement<ConversationMedia, MediaGalleryState>
    with ConversationMediaRef {
  _ConversationMediaProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationMediaProvider).conversationId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
