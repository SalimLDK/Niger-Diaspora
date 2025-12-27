// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$messageRemoteDataSourceHash() =>
    r'3a057920f17c0ca5fecdccae492d310ea57091bf';

/// See also [messageRemoteDataSource].
@ProviderFor(messageRemoteDataSource)
final messageRemoteDataSourceProvider =
    AutoDisposeProvider<MessageRemoteDataSource>.internal(
      messageRemoteDataSource,
      name: r'messageRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$messageRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MessageRemoteDataSourceRef =
    AutoDisposeProviderRef<MessageRemoteDataSource>;
String _$messageRepositoryHash() => r'746e90c7ca39b512c221efbbb5639c8e3b3aa4d8';

/// See also [messageRepository].
@ProviderFor(messageRepository)
final messageRepositoryProvider =
    AutoDisposeProvider<MessageRepository>.internal(
      messageRepository,
      name: r'messageRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$messageRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MessageRepositoryRef = AutoDisposeProviderRef<MessageRepository>;
String _$conversationsHash() => r'e43a752352878dbfd7156bfefd44c463835a3e3d';

/// Stream des conversations de l'utilisateur actuel
///
/// Copied from [conversations].
@ProviderFor(conversations)
final conversationsProvider =
    AutoDisposeStreamProvider<List<ConversationEntity>>.internal(
      conversations,
      name: r'conversationsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$conversationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConversationsRef =
    AutoDisposeStreamProviderRef<List<ConversationEntity>>;
String _$conversationStreamHash() =>
    r'e6f300e512a7275675b7e3fc3e0c3729429ee7fb';

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

/// Stream d'une conversation spécifique
///
/// Copied from [conversationStream].
@ProviderFor(conversationStream)
const conversationStreamProvider = ConversationStreamFamily();

/// Stream d'une conversation spécifique
///
/// Copied from [conversationStream].
class ConversationStreamFamily extends Family<AsyncValue<ConversationEntity?>> {
  /// Stream d'une conversation spécifique
  ///
  /// Copied from [conversationStream].
  const ConversationStreamFamily();

  /// Stream d'une conversation spécifique
  ///
  /// Copied from [conversationStream].
  ConversationStreamProvider call(String conversationId) {
    return ConversationStreamProvider(conversationId);
  }

  @override
  ConversationStreamProvider getProviderOverride(
    covariant ConversationStreamProvider provider,
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
  String? get name => r'conversationStreamProvider';
}

/// Stream d'une conversation spécifique
///
/// Copied from [conversationStream].
class ConversationStreamProvider
    extends AutoDisposeStreamProvider<ConversationEntity?> {
  /// Stream d'une conversation spécifique
  ///
  /// Copied from [conversationStream].
  ConversationStreamProvider(String conversationId)
    : this._internal(
        (ref) =>
            conversationStream(ref as ConversationStreamRef, conversationId),
        from: conversationStreamProvider,
        name: r'conversationStreamProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$conversationStreamHash,
        dependencies: ConversationStreamFamily._dependencies,
        allTransitiveDependencies:
            ConversationStreamFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  ConversationStreamProvider._internal(
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
  Override overrideWith(
    Stream<ConversationEntity?> Function(ConversationStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ConversationStreamProvider._internal(
        (ref) => create(ref as ConversationStreamRef),
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
  AutoDisposeStreamProviderElement<ConversationEntity?> createElement() {
    return _ConversationStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationStreamProvider &&
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
mixin ConversationStreamRef
    on AutoDisposeStreamProviderRef<ConversationEntity?> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationStreamProviderElement
    extends AutoDisposeStreamProviderElement<ConversationEntity?>
    with ConversationStreamRef {
  _ConversationStreamProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationStreamProvider).conversationId;
}

String _$messagesHash() => r'3e471101ca0023962ef7cc39d892ead9240de217';

/// Stream des messages d'une conversation
///
/// Copied from [messages].
@ProviderFor(messages)
const messagesProvider = MessagesFamily();

/// Stream des messages d'une conversation
///
/// Copied from [messages].
class MessagesFamily extends Family<AsyncValue<List<MessageEntity>>> {
  /// Stream des messages d'une conversation
  ///
  /// Copied from [messages].
  const MessagesFamily();

  /// Stream des messages d'une conversation
  ///
  /// Copied from [messages].
  MessagesProvider call(String conversationId) {
    return MessagesProvider(conversationId);
  }

  @override
  MessagesProvider getProviderOverride(covariant MessagesProvider provider) {
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
  String? get name => r'messagesProvider';
}

/// Stream des messages d'une conversation
///
/// Copied from [messages].
class MessagesProvider extends AutoDisposeStreamProvider<List<MessageEntity>> {
  /// Stream des messages d'une conversation
  ///
  /// Copied from [messages].
  MessagesProvider(String conversationId)
    : this._internal(
        (ref) => messages(ref as MessagesRef, conversationId),
        from: messagesProvider,
        name: r'messagesProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$messagesHash,
        dependencies: MessagesFamily._dependencies,
        allTransitiveDependencies: MessagesFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  MessagesProvider._internal(
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
  Override overrideWith(
    Stream<List<MessageEntity>> Function(MessagesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MessagesProvider._internal(
        (ref) => create(ref as MessagesRef),
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
  AutoDisposeStreamProviderElement<List<MessageEntity>> createElement() {
    return _MessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MessagesProvider && other.conversationId == conversationId;
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
mixin MessagesRef on AutoDisposeStreamProviderRef<List<MessageEntity>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _MessagesProviderElement
    extends AutoDisposeStreamProviderElement<List<MessageEntity>>
    with MessagesRef {
  _MessagesProviderElement(super.provider);

  @override
  String get conversationId => (origin as MessagesProvider).conversationId;
}

String _$totalUnreadCountHash() => r'7f5baf1312ba8179ffea5593a3f4f32e9d3a0833';

/// Nombre total de messages non lus
///
/// Copied from [totalUnreadCount].
@ProviderFor(totalUnreadCount)
final totalUnreadCountProvider = AutoDisposeProvider<int>.internal(
  totalUnreadCount,
  name: r'totalUnreadCountProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$totalUnreadCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalUnreadCountRef = AutoDisposeProviderRef<int>;
String _$paginatedMessagesHash() => r'3e09c002aa9a9c0e86f62f1318a88e22a24316f1';

abstract class _$PaginatedMessages
    extends BuildlessNotifier<MessagePaginationState> {
  late final String conversationId;

  MessagePaginationState build(String conversationId);
}

/// Notifier pour les messages paginés avec support offline
///
/// Copied from [PaginatedMessages].
@ProviderFor(PaginatedMessages)
const paginatedMessagesProvider = PaginatedMessagesFamily();

/// Notifier pour les messages paginés avec support offline
///
/// Copied from [PaginatedMessages].
class PaginatedMessagesFamily extends Family<MessagePaginationState> {
  /// Notifier pour les messages paginés avec support offline
  ///
  /// Copied from [PaginatedMessages].
  const PaginatedMessagesFamily();

  /// Notifier pour les messages paginés avec support offline
  ///
  /// Copied from [PaginatedMessages].
  PaginatedMessagesProvider call(String conversationId) {
    return PaginatedMessagesProvider(conversationId);
  }

  @override
  PaginatedMessagesProvider getProviderOverride(
    covariant PaginatedMessagesProvider provider,
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
  String? get name => r'paginatedMessagesProvider';
}

/// Notifier pour les messages paginés avec support offline
///
/// Copied from [PaginatedMessages].
class PaginatedMessagesProvider
    extends NotifierProviderImpl<PaginatedMessages, MessagePaginationState> {
  /// Notifier pour les messages paginés avec support offline
  ///
  /// Copied from [PaginatedMessages].
  PaginatedMessagesProvider(String conversationId)
    : this._internal(
        () => PaginatedMessages()..conversationId = conversationId,
        from: paginatedMessagesProvider,
        name: r'paginatedMessagesProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$paginatedMessagesHash,
        dependencies: PaginatedMessagesFamily._dependencies,
        allTransitiveDependencies:
            PaginatedMessagesFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  PaginatedMessagesProvider._internal(
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
  MessagePaginationState runNotifierBuild(
    covariant PaginatedMessages notifier,
  ) {
    return notifier.build(conversationId);
  }

  @override
  Override overrideWith(PaginatedMessages Function() create) {
    return ProviderOverride(
      origin: this,
      override: PaginatedMessagesProvider._internal(
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
  NotifierProviderElement<PaginatedMessages, MessagePaginationState>
  createElement() {
    return _PaginatedMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PaginatedMessagesProvider &&
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
mixin PaginatedMessagesRef on NotifierProviderRef<MessagePaginationState> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _PaginatedMessagesProviderElement
    extends NotifierProviderElement<PaginatedMessages, MessagePaginationState>
    with PaginatedMessagesRef {
  _PaginatedMessagesProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as PaginatedMessagesProvider).conversationId;
}

String _$sendMessageHash() => r'd6fbee1ff7f7edd52047382d346082ca4e1e92a1';

/// Notifier pour envoyer des messages
///
/// Copied from [SendMessage].
@ProviderFor(SendMessage)
final sendMessageProvider =
    AutoDisposeNotifierProvider<SendMessage, AsyncValue<void>>.internal(
      SendMessage.new,
      name: r'sendMessageProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$sendMessageHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SendMessage = AutoDisposeNotifier<AsyncValue<void>>;
String _$createConversationHash() =>
    r'5809a448a78bfa5e6b1124eb7a2f1c7be8fe8811';

/// Notifier pour créer des conversations
///
/// Copied from [CreateConversation].
@ProviderFor(CreateConversation)
final createConversationProvider = AutoDisposeNotifierProvider<
  CreateConversation,
  AsyncValue<ConversationEntity?>
>.internal(
  CreateConversation.new,
  name: r'createConversationProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$createConversationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CreateConversation =
    AutoDisposeNotifier<AsyncValue<ConversationEntity?>>;
String _$markAsReadHash() => r'626d5e9e6cecf7fa46ab50a367f875bb5ada2803';

/// Marquer une conversation comme lue
///
/// Copied from [MarkAsRead].
@ProviderFor(MarkAsRead)
final markAsReadProvider =
    AutoDisposeNotifierProvider<MarkAsRead, AsyncValue<void>>.internal(
      MarkAsRead.new,
      name: r'markAsReadProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$markAsReadHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MarkAsRead = AutoDisposeNotifier<AsyncValue<void>>;
String _$deleteMessageHash() => r'f220687f766e4ecf553b5a02cf4189f355c0e80f';

/// Notifier pour supprimer des messages
///
/// Copied from [DeleteMessage].
@ProviderFor(DeleteMessage)
final deleteMessageProvider =
    AutoDisposeNotifierProvider<DeleteMessage, AsyncValue<void>>.internal(
      DeleteMessage.new,
      name: r'deleteMessageProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$deleteMessageHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DeleteMessage = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
