// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_pagination_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MessagePaginationState {
  List<MessageEntity> get messages => throw _privateConstructorUsedError;
  bool get isLoadingInitial => throw _privateConstructorUsedError;
  bool get isLoadingMore => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;
  String? get lastMessageId => throw _privateConstructorUsedError;
  DateTime? get oldestMessageTimestamp => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  bool get isOffline => throw _privateConstructorUsedError;

  /// Create a copy of MessagePaginationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessagePaginationStateCopyWith<MessagePaginationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessagePaginationStateCopyWith<$Res> {
  factory $MessagePaginationStateCopyWith(
    MessagePaginationState value,
    $Res Function(MessagePaginationState) then,
  ) = _$MessagePaginationStateCopyWithImpl<$Res, MessagePaginationState>;
  @useResult
  $Res call({
    List<MessageEntity> messages,
    bool isLoadingInitial,
    bool isLoadingMore,
    bool hasMore,
    String? lastMessageId,
    DateTime? oldestMessageTimestamp,
    String? error,
    bool isOffline,
  });
}

/// @nodoc
class _$MessagePaginationStateCopyWithImpl<
  $Res,
  $Val extends MessagePaginationState
>
    implements $MessagePaginationStateCopyWith<$Res> {
  _$MessagePaginationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessagePaginationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? isLoadingInitial = null,
    Object? isLoadingMore = null,
    Object? hasMore = null,
    Object? lastMessageId = freezed,
    Object? oldestMessageTimestamp = freezed,
    Object? error = freezed,
    Object? isOffline = null,
  }) {
    return _then(
      _value.copyWith(
            messages:
                null == messages
                    ? _value.messages
                    : messages // ignore: cast_nullable_to_non_nullable
                        as List<MessageEntity>,
            isLoadingInitial:
                null == isLoadingInitial
                    ? _value.isLoadingInitial
                    : isLoadingInitial // ignore: cast_nullable_to_non_nullable
                        as bool,
            isLoadingMore:
                null == isLoadingMore
                    ? _value.isLoadingMore
                    : isLoadingMore // ignore: cast_nullable_to_non_nullable
                        as bool,
            hasMore:
                null == hasMore
                    ? _value.hasMore
                    : hasMore // ignore: cast_nullable_to_non_nullable
                        as bool,
            lastMessageId:
                freezed == lastMessageId
                    ? _value.lastMessageId
                    : lastMessageId // ignore: cast_nullable_to_non_nullable
                        as String?,
            oldestMessageTimestamp:
                freezed == oldestMessageTimestamp
                    ? _value.oldestMessageTimestamp
                    : oldestMessageTimestamp // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            error:
                freezed == error
                    ? _value.error
                    : error // ignore: cast_nullable_to_non_nullable
                        as String?,
            isOffline:
                null == isOffline
                    ? _value.isOffline
                    : isOffline // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MessagePaginationStateImplCopyWith<$Res>
    implements $MessagePaginationStateCopyWith<$Res> {
  factory _$$MessagePaginationStateImplCopyWith(
    _$MessagePaginationStateImpl value,
    $Res Function(_$MessagePaginationStateImpl) then,
  ) = __$$MessagePaginationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<MessageEntity> messages,
    bool isLoadingInitial,
    bool isLoadingMore,
    bool hasMore,
    String? lastMessageId,
    DateTime? oldestMessageTimestamp,
    String? error,
    bool isOffline,
  });
}

/// @nodoc
class __$$MessagePaginationStateImplCopyWithImpl<$Res>
    extends
        _$MessagePaginationStateCopyWithImpl<$Res, _$MessagePaginationStateImpl>
    implements _$$MessagePaginationStateImplCopyWith<$Res> {
  __$$MessagePaginationStateImplCopyWithImpl(
    _$MessagePaginationStateImpl _value,
    $Res Function(_$MessagePaginationStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessagePaginationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? isLoadingInitial = null,
    Object? isLoadingMore = null,
    Object? hasMore = null,
    Object? lastMessageId = freezed,
    Object? oldestMessageTimestamp = freezed,
    Object? error = freezed,
    Object? isOffline = null,
  }) {
    return _then(
      _$MessagePaginationStateImpl(
        messages:
            null == messages
                ? _value._messages
                : messages // ignore: cast_nullable_to_non_nullable
                    as List<MessageEntity>,
        isLoadingInitial:
            null == isLoadingInitial
                ? _value.isLoadingInitial
                : isLoadingInitial // ignore: cast_nullable_to_non_nullable
                    as bool,
        isLoadingMore:
            null == isLoadingMore
                ? _value.isLoadingMore
                : isLoadingMore // ignore: cast_nullable_to_non_nullable
                    as bool,
        hasMore:
            null == hasMore
                ? _value.hasMore
                : hasMore // ignore: cast_nullable_to_non_nullable
                    as bool,
        lastMessageId:
            freezed == lastMessageId
                ? _value.lastMessageId
                : lastMessageId // ignore: cast_nullable_to_non_nullable
                    as String?,
        oldestMessageTimestamp:
            freezed == oldestMessageTimestamp
                ? _value.oldestMessageTimestamp
                : oldestMessageTimestamp // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        error:
            freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                    as String?,
        isOffline:
            null == isOffline
                ? _value.isOffline
                : isOffline // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc

class _$MessagePaginationStateImpl extends _MessagePaginationState {
  const _$MessagePaginationStateImpl({
    final List<MessageEntity> messages = const [],
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastMessageId,
    this.oldestMessageTimestamp,
    this.error,
    this.isOffline = false,
  }) : _messages = messages,
       super._();

  final List<MessageEntity> _messages;
  @override
  @JsonKey()
  List<MessageEntity> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  @override
  @JsonKey()
  final bool isLoadingInitial;
  @override
  @JsonKey()
  final bool isLoadingMore;
  @override
  @JsonKey()
  final bool hasMore;
  @override
  final String? lastMessageId;
  @override
  final DateTime? oldestMessageTimestamp;
  @override
  final String? error;
  @override
  @JsonKey()
  final bool isOffline;

  @override
  String toString() {
    return 'MessagePaginationState(messages: $messages, isLoadingInitial: $isLoadingInitial, isLoadingMore: $isLoadingMore, hasMore: $hasMore, lastMessageId: $lastMessageId, oldestMessageTimestamp: $oldestMessageTimestamp, error: $error, isOffline: $isOffline)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessagePaginationStateImpl &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.isLoadingInitial, isLoadingInitial) ||
                other.isLoadingInitial == isLoadingInitial) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.lastMessageId, lastMessageId) ||
                other.lastMessageId == lastMessageId) &&
            (identical(other.oldestMessageTimestamp, oldestMessageTimestamp) ||
                other.oldestMessageTimestamp == oldestMessageTimestamp) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.isOffline, isOffline) ||
                other.isOffline == isOffline));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_messages),
    isLoadingInitial,
    isLoadingMore,
    hasMore,
    lastMessageId,
    oldestMessageTimestamp,
    error,
    isOffline,
  );

  /// Create a copy of MessagePaginationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessagePaginationStateImplCopyWith<_$MessagePaginationStateImpl>
  get copyWith =>
      __$$MessagePaginationStateImplCopyWithImpl<_$MessagePaginationStateImpl>(
        this,
        _$identity,
      );
}

abstract class _MessagePaginationState extends MessagePaginationState {
  const factory _MessagePaginationState({
    final List<MessageEntity> messages,
    final bool isLoadingInitial,
    final bool isLoadingMore,
    final bool hasMore,
    final String? lastMessageId,
    final DateTime? oldestMessageTimestamp,
    final String? error,
    final bool isOffline,
  }) = _$MessagePaginationStateImpl;
  const _MessagePaginationState._() : super._();

  @override
  List<MessageEntity> get messages;
  @override
  bool get isLoadingInitial;
  @override
  bool get isLoadingMore;
  @override
  bool get hasMore;
  @override
  String? get lastMessageId;
  @override
  DateTime? get oldestMessageTimestamp;
  @override
  String? get error;
  @override
  bool get isOffline;

  /// Create a copy of MessagePaginationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessagePaginationStateImplCopyWith<_$MessagePaginationStateImpl>
  get copyWith => throw _privateConstructorUsedError;
}
