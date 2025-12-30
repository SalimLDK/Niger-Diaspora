// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GroupModel _$GroupModelFromJson(Map<String, dynamic> json) {
  return _GroupModel.fromJson(json);
}

/// @nodoc
mixin _$GroupModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String get creatorId => throw _privateConstructorUsedError;
  String? get creatorName => throw _privateConstructorUsedError;
  List<String> get adminIds => throw _privateConstructorUsedError;
  List<String> get memberIds => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  bool get isPrivate => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  String? get originRegion => throw _privateConstructorUsedError;

  /// Serializes this GroupModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupModelCopyWith<GroupModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupModelCopyWith<$Res> {
  factory $GroupModelCopyWith(
    GroupModel value,
    $Res Function(GroupModel) then,
  ) = _$GroupModelCopyWithImpl<$Res, GroupModel>;
  @useResult
  $Res call({
    String id,
    String name,
    String description,
    String? imageUrl,
    String creatorId,
    String? creatorName,
    List<String> adminIds,
    List<String> memberIds,
    String category,
    bool isPrivate,
    String? location,
    List<String> tags,
    DateTime? createdAt,
    String? country,
    String? originRegion,
  });
}

/// @nodoc
class _$GroupModelCopyWithImpl<$Res, $Val extends GroupModel>
    implements $GroupModelCopyWith<$Res> {
  _$GroupModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? imageUrl = freezed,
    Object? creatorId = null,
    Object? creatorName = freezed,
    Object? adminIds = null,
    Object? memberIds = null,
    Object? category = null,
    Object? isPrivate = null,
    Object? location = freezed,
    Object? tags = null,
    Object? createdAt = freezed,
    Object? country = freezed,
    Object? originRegion = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                null == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String,
            imageUrl:
                freezed == imageUrl
                    ? _value.imageUrl
                    : imageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            creatorId:
                null == creatorId
                    ? _value.creatorId
                    : creatorId // ignore: cast_nullable_to_non_nullable
                        as String,
            creatorName:
                freezed == creatorName
                    ? _value.creatorName
                    : creatorName // ignore: cast_nullable_to_non_nullable
                        as String?,
            adminIds:
                null == adminIds
                    ? _value.adminIds
                    : adminIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            memberIds:
                null == memberIds
                    ? _value.memberIds
                    : memberIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            category:
                null == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as String,
            isPrivate:
                null == isPrivate
                    ? _value.isPrivate
                    : isPrivate // ignore: cast_nullable_to_non_nullable
                        as bool,
            location:
                freezed == location
                    ? _value.location
                    : location // ignore: cast_nullable_to_non_nullable
                        as String?,
            tags:
                null == tags
                    ? _value.tags
                    : tags // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            country:
                freezed == country
                    ? _value.country
                    : country // ignore: cast_nullable_to_non_nullable
                        as String?,
            originRegion:
                freezed == originRegion
                    ? _value.originRegion
                    : originRegion // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupModelImplCopyWith<$Res>
    implements $GroupModelCopyWith<$Res> {
  factory _$$GroupModelImplCopyWith(
    _$GroupModelImpl value,
    $Res Function(_$GroupModelImpl) then,
  ) = __$$GroupModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String description,
    String? imageUrl,
    String creatorId,
    String? creatorName,
    List<String> adminIds,
    List<String> memberIds,
    String category,
    bool isPrivate,
    String? location,
    List<String> tags,
    DateTime? createdAt,
    String? country,
    String? originRegion,
  });
}

/// @nodoc
class __$$GroupModelImplCopyWithImpl<$Res>
    extends _$GroupModelCopyWithImpl<$Res, _$GroupModelImpl>
    implements _$$GroupModelImplCopyWith<$Res> {
  __$$GroupModelImplCopyWithImpl(
    _$GroupModelImpl _value,
    $Res Function(_$GroupModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? imageUrl = freezed,
    Object? creatorId = null,
    Object? creatorName = freezed,
    Object? adminIds = null,
    Object? memberIds = null,
    Object? category = null,
    Object? isPrivate = null,
    Object? location = freezed,
    Object? tags = null,
    Object? createdAt = freezed,
    Object? country = freezed,
    Object? originRegion = freezed,
  }) {
    return _then(
      _$GroupModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String,
        imageUrl:
            freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        creatorId:
            null == creatorId
                ? _value.creatorId
                : creatorId // ignore: cast_nullable_to_non_nullable
                    as String,
        creatorName:
            freezed == creatorName
                ? _value.creatorName
                : creatorName // ignore: cast_nullable_to_non_nullable
                    as String?,
        adminIds:
            null == adminIds
                ? _value._adminIds
                : adminIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        memberIds:
            null == memberIds
                ? _value._memberIds
                : memberIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        category:
            null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as String,
        isPrivate:
            null == isPrivate
                ? _value.isPrivate
                : isPrivate // ignore: cast_nullable_to_non_nullable
                    as bool,
        location:
            freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                    as String?,
        tags:
            null == tags
                ? _value._tags
                : tags // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        country:
            freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                    as String?,
        originRegion:
            freezed == originRegion
                ? _value.originRegion
                : originRegion // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GroupModelImpl extends _GroupModel {
  const _$GroupModelImpl({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.creatorId,
    this.creatorName,
    final List<String> adminIds = const [],
    final List<String> memberIds = const [],
    this.category = 'other',
    this.isPrivate = false,
    this.location,
    final List<String> tags = const [],
    this.createdAt,
    this.country,
    this.originRegion,
  }) : _adminIds = adminIds,
       _memberIds = memberIds,
       _tags = tags,
       super._();

  factory _$GroupModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GroupModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final String? imageUrl;
  @override
  final String creatorId;
  @override
  final String? creatorName;
  final List<String> _adminIds;
  @override
  @JsonKey()
  List<String> get adminIds {
    if (_adminIds is EqualUnmodifiableListView) return _adminIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_adminIds);
  }

  final List<String> _memberIds;
  @override
  @JsonKey()
  List<String> get memberIds {
    if (_memberIds is EqualUnmodifiableListView) return _memberIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_memberIds);
  }

  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey()
  final bool isPrivate;
  @override
  final String? location;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  final DateTime? createdAt;
  @override
  final String? country;
  @override
  final String? originRegion;

  @override
  String toString() {
    return 'GroupModel(id: $id, name: $name, description: $description, imageUrl: $imageUrl, creatorId: $creatorId, creatorName: $creatorName, adminIds: $adminIds, memberIds: $memberIds, category: $category, isPrivate: $isPrivate, location: $location, tags: $tags, createdAt: $createdAt, country: $country, originRegion: $originRegion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.creatorId, creatorId) ||
                other.creatorId == creatorId) &&
            (identical(other.creatorName, creatorName) ||
                other.creatorName == creatorName) &&
            const DeepCollectionEquality().equals(other._adminIds, _adminIds) &&
            const DeepCollectionEquality().equals(
              other._memberIds,
              _memberIds,
            ) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.isPrivate, isPrivate) ||
                other.isPrivate == isPrivate) &&
            (identical(other.location, location) ||
                other.location == location) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.originRegion, originRegion) ||
                other.originRegion == originRegion));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    description,
    imageUrl,
    creatorId,
    creatorName,
    const DeepCollectionEquality().hash(_adminIds),
    const DeepCollectionEquality().hash(_memberIds),
    category,
    isPrivate,
    location,
    const DeepCollectionEquality().hash(_tags),
    createdAt,
    country,
    originRegion,
  );

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupModelImplCopyWith<_$GroupModelImpl> get copyWith =>
      __$$GroupModelImplCopyWithImpl<_$GroupModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GroupModelImplToJson(this);
  }
}

abstract class _GroupModel extends GroupModel {
  const factory _GroupModel({
    required final String id,
    required final String name,
    required final String description,
    final String? imageUrl,
    required final String creatorId,
    final String? creatorName,
    final List<String> adminIds,
    final List<String> memberIds,
    final String category,
    final bool isPrivate,
    final String? location,
    final List<String> tags,
    final DateTime? createdAt,
    final String? country,
    final String? originRegion,
  }) = _$GroupModelImpl;
  const _GroupModel._() : super._();

  factory _GroupModel.fromJson(Map<String, dynamic> json) =
      _$GroupModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  String? get imageUrl;
  @override
  String get creatorId;
  @override
  String? get creatorName;
  @override
  List<String> get adminIds;
  @override
  List<String> get memberIds;
  @override
  String get category;
  @override
  bool get isPrivate;
  @override
  String? get location;
  @override
  List<String> get tags;
  @override
  DateTime? get createdAt;
  @override
  String? get country;
  @override
  String? get originRegion;

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupModelImplCopyWith<_$GroupModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
