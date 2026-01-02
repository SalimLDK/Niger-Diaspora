// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SearchResult {
  String get query => throw _privateConstructorUsedError;
  List<ProfileModel> get profiles => throw _privateConstructorUsedError;
  List<GroupEntity> get groups => throw _privateConstructorUsedError;
  List<FriendEntity> get friends => throw _privateConstructorUsedError;
  List<ConversationEntity> get conversations =>
      throw _privateConstructorUsedError;
  DateTime? get searchedAt => throw _privateConstructorUsedError;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResultCopyWith<SearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultCopyWith<$Res> {
  factory $SearchResultCopyWith(
    SearchResult value,
    $Res Function(SearchResult) then,
  ) = _$SearchResultCopyWithImpl<$Res, SearchResult>;
  @useResult
  $Res call({
    String query,
    List<ProfileModel> profiles,
    List<GroupEntity> groups,
    List<FriendEntity> friends,
    List<ConversationEntity> conversations,
    DateTime? searchedAt,
  });
}

/// @nodoc
class _$SearchResultCopyWithImpl<$Res, $Val extends SearchResult>
    implements $SearchResultCopyWith<$Res> {
  _$SearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? profiles = null,
    Object? groups = null,
    Object? friends = null,
    Object? conversations = null,
    Object? searchedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            query:
                null == query
                    ? _value.query
                    : query // ignore: cast_nullable_to_non_nullable
                        as String,
            profiles:
                null == profiles
                    ? _value.profiles
                    : profiles // ignore: cast_nullable_to_non_nullable
                        as List<ProfileModel>,
            groups:
                null == groups
                    ? _value.groups
                    : groups // ignore: cast_nullable_to_non_nullable
                        as List<GroupEntity>,
            friends:
                null == friends
                    ? _value.friends
                    : friends // ignore: cast_nullable_to_non_nullable
                        as List<FriendEntity>,
            conversations:
                null == conversations
                    ? _value.conversations
                    : conversations // ignore: cast_nullable_to_non_nullable
                        as List<ConversationEntity>,
            searchedAt:
                freezed == searchedAt
                    ? _value.searchedAt
                    : searchedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SearchResultImplCopyWith<$Res>
    implements $SearchResultCopyWith<$Res> {
  factory _$$SearchResultImplCopyWith(
    _$SearchResultImpl value,
    $Res Function(_$SearchResultImpl) then,
  ) = __$$SearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String query,
    List<ProfileModel> profiles,
    List<GroupEntity> groups,
    List<FriendEntity> friends,
    List<ConversationEntity> conversations,
    DateTime? searchedAt,
  });
}

/// @nodoc
class __$$SearchResultImplCopyWithImpl<$Res>
    extends _$SearchResultCopyWithImpl<$Res, _$SearchResultImpl>
    implements _$$SearchResultImplCopyWith<$Res> {
  __$$SearchResultImplCopyWithImpl(
    _$SearchResultImpl _value,
    $Res Function(_$SearchResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? profiles = null,
    Object? groups = null,
    Object? friends = null,
    Object? conversations = null,
    Object? searchedAt = freezed,
  }) {
    return _then(
      _$SearchResultImpl(
        query:
            null == query
                ? _value.query
                : query // ignore: cast_nullable_to_non_nullable
                    as String,
        profiles:
            null == profiles
                ? _value._profiles
                : profiles // ignore: cast_nullable_to_non_nullable
                    as List<ProfileModel>,
        groups:
            null == groups
                ? _value._groups
                : groups // ignore: cast_nullable_to_non_nullable
                    as List<GroupEntity>,
        friends:
            null == friends
                ? _value._friends
                : friends // ignore: cast_nullable_to_non_nullable
                    as List<FriendEntity>,
        conversations:
            null == conversations
                ? _value._conversations
                : conversations // ignore: cast_nullable_to_non_nullable
                    as List<ConversationEntity>,
        searchedAt:
            freezed == searchedAt
                ? _value.searchedAt
                : searchedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$SearchResultImpl extends _SearchResult {
  const _$SearchResultImpl({
    required this.query,
    final List<ProfileModel> profiles = const [],
    final List<GroupEntity> groups = const [],
    final List<FriendEntity> friends = const [],
    final List<ConversationEntity> conversations = const [],
    this.searchedAt,
  }) : _profiles = profiles,
       _groups = groups,
       _friends = friends,
       _conversations = conversations,
       super._();

  @override
  final String query;
  final List<ProfileModel> _profiles;
  @override
  @JsonKey()
  List<ProfileModel> get profiles {
    if (_profiles is EqualUnmodifiableListView) return _profiles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_profiles);
  }

  final List<GroupEntity> _groups;
  @override
  @JsonKey()
  List<GroupEntity> get groups {
    if (_groups is EqualUnmodifiableListView) return _groups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_groups);
  }

  final List<FriendEntity> _friends;
  @override
  @JsonKey()
  List<FriendEntity> get friends {
    if (_friends is EqualUnmodifiableListView) return _friends;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_friends);
  }

  final List<ConversationEntity> _conversations;
  @override
  @JsonKey()
  List<ConversationEntity> get conversations {
    if (_conversations is EqualUnmodifiableListView) return _conversations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_conversations);
  }

  @override
  final DateTime? searchedAt;

  @override
  String toString() {
    return 'SearchResult(query: $query, profiles: $profiles, groups: $groups, friends: $friends, conversations: $conversations, searchedAt: $searchedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultImpl &&
            (identical(other.query, query) || other.query == query) &&
            const DeepCollectionEquality().equals(other._profiles, _profiles) &&
            const DeepCollectionEquality().equals(other._groups, _groups) &&
            const DeepCollectionEquality().equals(other._friends, _friends) &&
            const DeepCollectionEquality().equals(
              other._conversations,
              _conversations,
            ) &&
            (identical(other.searchedAt, searchedAt) ||
                other.searchedAt == searchedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    query,
    const DeepCollectionEquality().hash(_profiles),
    const DeepCollectionEquality().hash(_groups),
    const DeepCollectionEquality().hash(_friends),
    const DeepCollectionEquality().hash(_conversations),
    searchedAt,
  );

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      __$$SearchResultImplCopyWithImpl<_$SearchResultImpl>(this, _$identity);
}

abstract class _SearchResult extends SearchResult {
  const factory _SearchResult({
    required final String query,
    final List<ProfileModel> profiles,
    final List<GroupEntity> groups,
    final List<FriendEntity> friends,
    final List<ConversationEntity> conversations,
    final DateTime? searchedAt,
  }) = _$SearchResultImpl;
  const _SearchResult._() : super._();

  @override
  String get query;
  @override
  List<ProfileModel> get profiles;
  @override
  List<GroupEntity> get groups;
  @override
  List<FriendEntity> get friends;
  @override
  List<ConversationEntity> get conversations;
  @override
  DateTime? get searchedAt;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SearchParams {
  String get query => throw _privateConstructorUsedError;
  SearchType get type => throw _privateConstructorUsedError;
  int get limit => throw _privateConstructorUsedError;
  String? get cursor => throw _privateConstructorUsedError;

  /// Create a copy of SearchParams
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchParamsCopyWith<SearchParams> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchParamsCopyWith<$Res> {
  factory $SearchParamsCopyWith(
    SearchParams value,
    $Res Function(SearchParams) then,
  ) = _$SearchParamsCopyWithImpl<$Res, SearchParams>;
  @useResult
  $Res call({String query, SearchType type, int limit, String? cursor});
}

/// @nodoc
class _$SearchParamsCopyWithImpl<$Res, $Val extends SearchParams>
    implements $SearchParamsCopyWith<$Res> {
  _$SearchParamsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchParams
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? type = null,
    Object? limit = null,
    Object? cursor = freezed,
  }) {
    return _then(
      _value.copyWith(
            query:
                null == query
                    ? _value.query
                    : query // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as SearchType,
            limit:
                null == limit
                    ? _value.limit
                    : limit // ignore: cast_nullable_to_non_nullable
                        as int,
            cursor:
                freezed == cursor
                    ? _value.cursor
                    : cursor // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SearchParamsImplCopyWith<$Res>
    implements $SearchParamsCopyWith<$Res> {
  factory _$$SearchParamsImplCopyWith(
    _$SearchParamsImpl value,
    $Res Function(_$SearchParamsImpl) then,
  ) = __$$SearchParamsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String query, SearchType type, int limit, String? cursor});
}

/// @nodoc
class __$$SearchParamsImplCopyWithImpl<$Res>
    extends _$SearchParamsCopyWithImpl<$Res, _$SearchParamsImpl>
    implements _$$SearchParamsImplCopyWith<$Res> {
  __$$SearchParamsImplCopyWithImpl(
    _$SearchParamsImpl _value,
    $Res Function(_$SearchParamsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchParams
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? type = null,
    Object? limit = null,
    Object? cursor = freezed,
  }) {
    return _then(
      _$SearchParamsImpl(
        query:
            null == query
                ? _value.query
                : query // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as SearchType,
        limit:
            null == limit
                ? _value.limit
                : limit // ignore: cast_nullable_to_non_nullable
                    as int,
        cursor:
            freezed == cursor
                ? _value.cursor
                : cursor // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc

class _$SearchParamsImpl implements _SearchParams {
  const _$SearchParamsImpl({
    required this.query,
    this.type = SearchType.all,
    this.limit = 20,
    this.cursor,
  });

  @override
  final String query;
  @override
  @JsonKey()
  final SearchType type;
  @override
  @JsonKey()
  final int limit;
  @override
  final String? cursor;

  @override
  String toString() {
    return 'SearchParams(query: $query, type: $type, limit: $limit, cursor: $cursor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchParamsImpl &&
            (identical(other.query, query) || other.query == query) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.cursor, cursor) || other.cursor == cursor));
  }

  @override
  int get hashCode => Object.hash(runtimeType, query, type, limit, cursor);

  /// Create a copy of SearchParams
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchParamsImplCopyWith<_$SearchParamsImpl> get copyWith =>
      __$$SearchParamsImplCopyWithImpl<_$SearchParamsImpl>(this, _$identity);
}

abstract class _SearchParams implements SearchParams {
  const factory _SearchParams({
    required final String query,
    final SearchType type,
    final int limit,
    final String? cursor,
  }) = _$SearchParamsImpl;

  @override
  String get query;
  @override
  SearchType get type;
  @override
  int get limit;
  @override
  String? get cursor;

  /// Create a copy of SearchParams
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchParamsImplCopyWith<_$SearchParamsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TypedSearchResult<T> {
  List<T> get items => throw _privateConstructorUsedError;
  String? get nextCursor => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;

  /// Create a copy of TypedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TypedSearchResultCopyWith<T, TypedSearchResult<T>> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TypedSearchResultCopyWith<T, $Res> {
  factory $TypedSearchResultCopyWith(
    TypedSearchResult<T> value,
    $Res Function(TypedSearchResult<T>) then,
  ) = _$TypedSearchResultCopyWithImpl<T, $Res, TypedSearchResult<T>>;
  @useResult
  $Res call({List<T> items, String? nextCursor, bool hasMore});
}

/// @nodoc
class _$TypedSearchResultCopyWithImpl<
  T,
  $Res,
  $Val extends TypedSearchResult<T>
>
    implements $TypedSearchResultCopyWith<T, $Res> {
  _$TypedSearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TypedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? nextCursor = freezed,
    Object? hasMore = null,
  }) {
    return _then(
      _value.copyWith(
            items:
                null == items
                    ? _value.items
                    : items // ignore: cast_nullable_to_non_nullable
                        as List<T>,
            nextCursor:
                freezed == nextCursor
                    ? _value.nextCursor
                    : nextCursor // ignore: cast_nullable_to_non_nullable
                        as String?,
            hasMore:
                null == hasMore
                    ? _value.hasMore
                    : hasMore // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TypedSearchResultImplCopyWith<T, $Res>
    implements $TypedSearchResultCopyWith<T, $Res> {
  factory _$$TypedSearchResultImplCopyWith(
    _$TypedSearchResultImpl<T> value,
    $Res Function(_$TypedSearchResultImpl<T>) then,
  ) = __$$TypedSearchResultImplCopyWithImpl<T, $Res>;
  @override
  @useResult
  $Res call({List<T> items, String? nextCursor, bool hasMore});
}

/// @nodoc
class __$$TypedSearchResultImplCopyWithImpl<T, $Res>
    extends _$TypedSearchResultCopyWithImpl<T, $Res, _$TypedSearchResultImpl<T>>
    implements _$$TypedSearchResultImplCopyWith<T, $Res> {
  __$$TypedSearchResultImplCopyWithImpl(
    _$TypedSearchResultImpl<T> _value,
    $Res Function(_$TypedSearchResultImpl<T>) _then,
  ) : super(_value, _then);

  /// Create a copy of TypedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? nextCursor = freezed,
    Object? hasMore = null,
  }) {
    return _then(
      _$TypedSearchResultImpl<T>(
        items:
            null == items
                ? _value._items
                : items // ignore: cast_nullable_to_non_nullable
                    as List<T>,
        nextCursor:
            freezed == nextCursor
                ? _value.nextCursor
                : nextCursor // ignore: cast_nullable_to_non_nullable
                    as String?,
        hasMore:
            null == hasMore
                ? _value.hasMore
                : hasMore // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc

class _$TypedSearchResultImpl<T> implements _TypedSearchResult<T> {
  const _$TypedSearchResultImpl({
    required final List<T> items,
    this.nextCursor,
    this.hasMore = false,
  }) : _items = items;

  final List<T> _items;
  @override
  List<T> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String? nextCursor;
  @override
  @JsonKey()
  final bool hasMore;

  @override
  String toString() {
    return 'TypedSearchResult<$T>(items: $items, nextCursor: $nextCursor, hasMore: $hasMore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TypedSearchResultImpl<T> &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.nextCursor, nextCursor) ||
                other.nextCursor == nextCursor) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_items),
    nextCursor,
    hasMore,
  );

  /// Create a copy of TypedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TypedSearchResultImplCopyWith<T, _$TypedSearchResultImpl<T>>
  get copyWith =>
      __$$TypedSearchResultImplCopyWithImpl<T, _$TypedSearchResultImpl<T>>(
        this,
        _$identity,
      );
}

abstract class _TypedSearchResult<T> implements TypedSearchResult<T> {
  const factory _TypedSearchResult({
    required final List<T> items,
    final String? nextCursor,
    final bool hasMore,
  }) = _$TypedSearchResultImpl<T>;

  @override
  List<T> get items;
  @override
  String? get nextCursor;
  @override
  bool get hasMore;

  /// Create a copy of TypedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TypedSearchResultImplCopyWith<T, _$TypedSearchResultImpl<T>>
  get copyWith => throw _privateConstructorUsedError;
}
