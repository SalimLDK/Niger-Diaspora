// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SearchResultModel _$SearchResultModelFromJson(Map<String, dynamic> json) {
  return _SearchResultModel.fromJson(json);
}

/// @nodoc
mixin _$SearchResultModel {
  String get query => throw _privateConstructorUsedError;
  List<ProfileModel> get profiles => throw _privateConstructorUsedError;
  List<GroupModel> get groups => throw _privateConstructorUsedError;
  List<FriendModel> get friends => throw _privateConstructorUsedError;
  List<ConversationModel> get conversations =>
      throw _privateConstructorUsedError;
  String? get searchedAt => throw _privateConstructorUsedError;

  /// Serializes this SearchResultModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SearchResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResultModelCopyWith<SearchResultModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultModelCopyWith<$Res> {
  factory $SearchResultModelCopyWith(
    SearchResultModel value,
    $Res Function(SearchResultModel) then,
  ) = _$SearchResultModelCopyWithImpl<$Res, SearchResultModel>;
  @useResult
  $Res call({
    String query,
    List<ProfileModel> profiles,
    List<GroupModel> groups,
    List<FriendModel> friends,
    List<ConversationModel> conversations,
    String? searchedAt,
  });
}

/// @nodoc
class _$SearchResultModelCopyWithImpl<$Res, $Val extends SearchResultModel>
    implements $SearchResultModelCopyWith<$Res> {
  _$SearchResultModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResultModel
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
                        as List<GroupModel>,
            friends:
                null == friends
                    ? _value.friends
                    : friends // ignore: cast_nullable_to_non_nullable
                        as List<FriendModel>,
            conversations:
                null == conversations
                    ? _value.conversations
                    : conversations // ignore: cast_nullable_to_non_nullable
                        as List<ConversationModel>,
            searchedAt:
                freezed == searchedAt
                    ? _value.searchedAt
                    : searchedAt // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SearchResultModelImplCopyWith<$Res>
    implements $SearchResultModelCopyWith<$Res> {
  factory _$$SearchResultModelImplCopyWith(
    _$SearchResultModelImpl value,
    $Res Function(_$SearchResultModelImpl) then,
  ) = __$$SearchResultModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String query,
    List<ProfileModel> profiles,
    List<GroupModel> groups,
    List<FriendModel> friends,
    List<ConversationModel> conversations,
    String? searchedAt,
  });
}

/// @nodoc
class __$$SearchResultModelImplCopyWithImpl<$Res>
    extends _$SearchResultModelCopyWithImpl<$Res, _$SearchResultModelImpl>
    implements _$$SearchResultModelImplCopyWith<$Res> {
  __$$SearchResultModelImplCopyWithImpl(
    _$SearchResultModelImpl _value,
    $Res Function(_$SearchResultModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchResultModel
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
      _$SearchResultModelImpl(
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
                    as List<GroupModel>,
        friends:
            null == friends
                ? _value._friends
                : friends // ignore: cast_nullable_to_non_nullable
                    as List<FriendModel>,
        conversations:
            null == conversations
                ? _value._conversations
                : conversations // ignore: cast_nullable_to_non_nullable
                    as List<ConversationModel>,
        searchedAt:
            freezed == searchedAt
                ? _value.searchedAt
                : searchedAt // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SearchResultModelImpl extends _SearchResultModel {
  const _$SearchResultModelImpl({
    required this.query,
    final List<ProfileModel> profiles = const [],
    final List<GroupModel> groups = const [],
    final List<FriendModel> friends = const [],
    final List<ConversationModel> conversations = const [],
    this.searchedAt,
  }) : _profiles = profiles,
       _groups = groups,
       _friends = friends,
       _conversations = conversations,
       super._();

  factory _$SearchResultModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SearchResultModelImplFromJson(json);

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

  final List<GroupModel> _groups;
  @override
  @JsonKey()
  List<GroupModel> get groups {
    if (_groups is EqualUnmodifiableListView) return _groups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_groups);
  }

  final List<FriendModel> _friends;
  @override
  @JsonKey()
  List<FriendModel> get friends {
    if (_friends is EqualUnmodifiableListView) return _friends;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_friends);
  }

  final List<ConversationModel> _conversations;
  @override
  @JsonKey()
  List<ConversationModel> get conversations {
    if (_conversations is EqualUnmodifiableListView) return _conversations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_conversations);
  }

  @override
  final String? searchedAt;

  @override
  String toString() {
    return 'SearchResultModel(query: $query, profiles: $profiles, groups: $groups, friends: $friends, conversations: $conversations, searchedAt: $searchedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultModelImpl &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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

  /// Create a copy of SearchResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultModelImplCopyWith<_$SearchResultModelImpl> get copyWith =>
      __$$SearchResultModelImplCopyWithImpl<_$SearchResultModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SearchResultModelImplToJson(this);
  }
}

abstract class _SearchResultModel extends SearchResultModel {
  const factory _SearchResultModel({
    required final String query,
    final List<ProfileModel> profiles,
    final List<GroupModel> groups,
    final List<FriendModel> friends,
    final List<ConversationModel> conversations,
    final String? searchedAt,
  }) = _$SearchResultModelImpl;
  const _SearchResultModel._() : super._();

  factory _SearchResultModel.fromJson(Map<String, dynamic> json) =
      _$SearchResultModelImpl.fromJson;

  @override
  String get query;
  @override
  List<ProfileModel> get profiles;
  @override
  List<GroupModel> get groups;
  @override
  List<FriendModel> get friends;
  @override
  List<ConversationModel> get conversations;
  @override
  String? get searchedAt;

  /// Create a copy of SearchResultModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResultModelImplCopyWith<_$SearchResultModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
