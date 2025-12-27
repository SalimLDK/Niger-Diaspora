// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'typing_indicator_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$typingStatusHash() => r'8c065f8b96068c1149fad2eb9745b8bb79085228';

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

/// Stream of users currently typing in a conversation
/// Returns a map of userId -> isTyping
///
/// Copied from [typingStatus].
@ProviderFor(typingStatus)
const typingStatusProvider = TypingStatusFamily();

/// Stream of users currently typing in a conversation
/// Returns a map of userId -> isTyping
///
/// Copied from [typingStatus].
class TypingStatusFamily extends Family<AsyncValue<Map<String, bool>>> {
  /// Stream of users currently typing in a conversation
  /// Returns a map of userId -> isTyping
  ///
  /// Copied from [typingStatus].
  const TypingStatusFamily();

  /// Stream of users currently typing in a conversation
  /// Returns a map of userId -> isTyping
  ///
  /// Copied from [typingStatus].
  TypingStatusProvider call(String conversationId) {
    return TypingStatusProvider(conversationId);
  }

  @override
  TypingStatusProvider getProviderOverride(
    covariant TypingStatusProvider provider,
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
  String? get name => r'typingStatusProvider';
}

/// Stream of users currently typing in a conversation
/// Returns a map of userId -> isTyping
///
/// Copied from [typingStatus].
class TypingStatusProvider
    extends AutoDisposeStreamProvider<Map<String, bool>> {
  /// Stream of users currently typing in a conversation
  /// Returns a map of userId -> isTyping
  ///
  /// Copied from [typingStatus].
  TypingStatusProvider(String conversationId)
    : this._internal(
        (ref) => typingStatus(ref as TypingStatusRef, conversationId),
        from: typingStatusProvider,
        name: r'typingStatusProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$typingStatusHash,
        dependencies: TypingStatusFamily._dependencies,
        allTransitiveDependencies:
            TypingStatusFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  TypingStatusProvider._internal(
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
    Stream<Map<String, bool>> Function(TypingStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TypingStatusProvider._internal(
        (ref) => create(ref as TypingStatusRef),
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
  AutoDisposeStreamProviderElement<Map<String, bool>> createElement() {
    return _TypingStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TypingStatusProvider &&
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
mixin TypingStatusRef on AutoDisposeStreamProviderRef<Map<String, bool>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _TypingStatusProviderElement
    extends AutoDisposeStreamProviderElement<Map<String, bool>>
    with TypingStatusRef {
  _TypingStatusProviderElement(super.provider);

  @override
  String get conversationId => (origin as TypingStatusProvider).conversationId;
}

String _$typingIndicatorNotifierHash() =>
    r'34e01c34df2be8bb6de1ed423928dd04ef175675';

/// Notifier to manage the current user's typing status
/// Includes debouncing to prevent excessive updates
///
/// Copied from [TypingIndicatorNotifier].
@ProviderFor(TypingIndicatorNotifier)
final typingIndicatorNotifierProvider =
    AutoDisposeNotifierProvider<TypingIndicatorNotifier, bool>.internal(
      TypingIndicatorNotifier.new,
      name: r'typingIndicatorNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$typingIndicatorNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TypingIndicatorNotifier = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
