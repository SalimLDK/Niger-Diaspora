// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'embassy_employee_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EmbassyEmployeeModel _$EmbassyEmployeeModelFromJson(Map<String, dynamic> json) {
  return _EmbassyEmployeeModel.fromJson(json);
}

/// @nodoc
mixin _$EmbassyEmployeeModel {
  String get id => throw _privateConstructorUsedError;
  String get embassyId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  String? get title =>
      throw _privateConstructorUsedError; // e.g., "Ambassador Extraordinary and Plenipotentiary"
  String? get department =>
      throw _privateConstructorUsedError; // e.g., "Consular Services", "Visa Section"
  String? get email => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  bool get isPublic =>
      throw _privateConstructorUsedError; // Whether to show in public directory
  bool get isActive => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  List<String> get languages => throw _privateConstructorUsedError;
  List<String> get responsibilities =>
      throw _privateConstructorUsedError; // Link to user account if exists
  String? get linkedUserId => throw _privateConstructorUsedError;

  /// Serializes this EmbassyEmployeeModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmbassyEmployeeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmbassyEmployeeModelCopyWith<EmbassyEmployeeModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmbassyEmployeeModelCopyWith<$Res> {
  factory $EmbassyEmployeeModelCopyWith(
    EmbassyEmployeeModel value,
    $Res Function(EmbassyEmployeeModel) then,
  ) = _$EmbassyEmployeeModelCopyWithImpl<$Res, EmbassyEmployeeModel>;
  @useResult
  $Res call({
    String id,
    String embassyId,
    String name,
    String role,
    String? title,
    String? department,
    String? email,
    String? phone,
    String? photoUrl,
    bool isPublic,
    bool isActive,
    String? bio,
    List<String> languages,
    List<String> responsibilities,
    String? linkedUserId,
  });
}

/// @nodoc
class _$EmbassyEmployeeModelCopyWithImpl<
  $Res,
  $Val extends EmbassyEmployeeModel
>
    implements $EmbassyEmployeeModelCopyWith<$Res> {
  _$EmbassyEmployeeModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmbassyEmployeeModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? embassyId = null,
    Object? name = null,
    Object? role = null,
    Object? title = freezed,
    Object? department = freezed,
    Object? email = freezed,
    Object? phone = freezed,
    Object? photoUrl = freezed,
    Object? isPublic = null,
    Object? isActive = null,
    Object? bio = freezed,
    Object? languages = null,
    Object? responsibilities = null,
    Object? linkedUserId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            embassyId:
                null == embassyId
                    ? _value.embassyId
                    : embassyId // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            role:
                null == role
                    ? _value.role
                    : role // ignore: cast_nullable_to_non_nullable
                        as String,
            title:
                freezed == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String?,
            department:
                freezed == department
                    ? _value.department
                    : department // ignore: cast_nullable_to_non_nullable
                        as String?,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            phone:
                freezed == phone
                    ? _value.phone
                    : phone // ignore: cast_nullable_to_non_nullable
                        as String?,
            photoUrl:
                freezed == photoUrl
                    ? _value.photoUrl
                    : photoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            isPublic:
                null == isPublic
                    ? _value.isPublic
                    : isPublic // ignore: cast_nullable_to_non_nullable
                        as bool,
            isActive:
                null == isActive
                    ? _value.isActive
                    : isActive // ignore: cast_nullable_to_non_nullable
                        as bool,
            bio:
                freezed == bio
                    ? _value.bio
                    : bio // ignore: cast_nullable_to_non_nullable
                        as String?,
            languages:
                null == languages
                    ? _value.languages
                    : languages // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            responsibilities:
                null == responsibilities
                    ? _value.responsibilities
                    : responsibilities // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            linkedUserId:
                freezed == linkedUserId
                    ? _value.linkedUserId
                    : linkedUserId // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EmbassyEmployeeModelImplCopyWith<$Res>
    implements $EmbassyEmployeeModelCopyWith<$Res> {
  factory _$$EmbassyEmployeeModelImplCopyWith(
    _$EmbassyEmployeeModelImpl value,
    $Res Function(_$EmbassyEmployeeModelImpl) then,
  ) = __$$EmbassyEmployeeModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String embassyId,
    String name,
    String role,
    String? title,
    String? department,
    String? email,
    String? phone,
    String? photoUrl,
    bool isPublic,
    bool isActive,
    String? bio,
    List<String> languages,
    List<String> responsibilities,
    String? linkedUserId,
  });
}

/// @nodoc
class __$$EmbassyEmployeeModelImplCopyWithImpl<$Res>
    extends _$EmbassyEmployeeModelCopyWithImpl<$Res, _$EmbassyEmployeeModelImpl>
    implements _$$EmbassyEmployeeModelImplCopyWith<$Res> {
  __$$EmbassyEmployeeModelImplCopyWithImpl(
    _$EmbassyEmployeeModelImpl _value,
    $Res Function(_$EmbassyEmployeeModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EmbassyEmployeeModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? embassyId = null,
    Object? name = null,
    Object? role = null,
    Object? title = freezed,
    Object? department = freezed,
    Object? email = freezed,
    Object? phone = freezed,
    Object? photoUrl = freezed,
    Object? isPublic = null,
    Object? isActive = null,
    Object? bio = freezed,
    Object? languages = null,
    Object? responsibilities = null,
    Object? linkedUserId = freezed,
  }) {
    return _then(
      _$EmbassyEmployeeModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        embassyId:
            null == embassyId
                ? _value.embassyId
                : embassyId // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        role:
            null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                    as String,
        title:
            freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String?,
        department:
            freezed == department
                ? _value.department
                : department // ignore: cast_nullable_to_non_nullable
                    as String?,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        phone:
            freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                    as String?,
        photoUrl:
            freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        isPublic:
            null == isPublic
                ? _value.isPublic
                : isPublic // ignore: cast_nullable_to_non_nullable
                    as bool,
        isActive:
            null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                    as bool,
        bio:
            freezed == bio
                ? _value.bio
                : bio // ignore: cast_nullable_to_non_nullable
                    as String?,
        languages:
            null == languages
                ? _value._languages
                : languages // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        responsibilities:
            null == responsibilities
                ? _value._responsibilities
                : responsibilities // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        linkedUserId:
            freezed == linkedUserId
                ? _value.linkedUserId
                : linkedUserId // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EmbassyEmployeeModelImpl extends _EmbassyEmployeeModel {
  const _$EmbassyEmployeeModelImpl({
    required this.id,
    required this.embassyId,
    required this.name,
    required this.role,
    this.title,
    this.department,
    this.email,
    this.phone,
    this.photoUrl,
    this.isPublic = true,
    this.isActive = true,
    this.bio,
    final List<String> languages = const [],
    final List<String> responsibilities = const [],
    this.linkedUserId,
  }) : _languages = languages,
       _responsibilities = responsibilities,
       super._();

  factory _$EmbassyEmployeeModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmbassyEmployeeModelImplFromJson(json);

  @override
  final String id;
  @override
  final String embassyId;
  @override
  final String name;
  @override
  final String role;
  @override
  final String? title;
  // e.g., "Ambassador Extraordinary and Plenipotentiary"
  @override
  final String? department;
  // e.g., "Consular Services", "Visa Section"
  @override
  final String? email;
  @override
  final String? phone;
  @override
  final String? photoUrl;
  @override
  @JsonKey()
  final bool isPublic;
  // Whether to show in public directory
  @override
  @JsonKey()
  final bool isActive;
  @override
  final String? bio;
  final List<String> _languages;
  @override
  @JsonKey()
  List<String> get languages {
    if (_languages is EqualUnmodifiableListView) return _languages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_languages);
  }

  final List<String> _responsibilities;
  @override
  @JsonKey()
  List<String> get responsibilities {
    if (_responsibilities is EqualUnmodifiableListView)
      return _responsibilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_responsibilities);
  }

  // Link to user account if exists
  @override
  final String? linkedUserId;

  @override
  String toString() {
    return 'EmbassyEmployeeModel(id: $id, embassyId: $embassyId, name: $name, role: $role, title: $title, department: $department, email: $email, phone: $phone, photoUrl: $photoUrl, isPublic: $isPublic, isActive: $isActive, bio: $bio, languages: $languages, responsibilities: $responsibilities, linkedUserId: $linkedUserId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmbassyEmployeeModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.embassyId, embassyId) ||
                other.embassyId == embassyId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.department, department) ||
                other.department == department) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.isPublic, isPublic) ||
                other.isPublic == isPublic) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            const DeepCollectionEquality().equals(
              other._languages,
              _languages,
            ) &&
            const DeepCollectionEquality().equals(
              other._responsibilities,
              _responsibilities,
            ) &&
            (identical(other.linkedUserId, linkedUserId) ||
                other.linkedUserId == linkedUserId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    embassyId,
    name,
    role,
    title,
    department,
    email,
    phone,
    photoUrl,
    isPublic,
    isActive,
    bio,
    const DeepCollectionEquality().hash(_languages),
    const DeepCollectionEquality().hash(_responsibilities),
    linkedUserId,
  );

  /// Create a copy of EmbassyEmployeeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmbassyEmployeeModelImplCopyWith<_$EmbassyEmployeeModelImpl>
  get copyWith =>
      __$$EmbassyEmployeeModelImplCopyWithImpl<_$EmbassyEmployeeModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EmbassyEmployeeModelImplToJson(this);
  }
}

abstract class _EmbassyEmployeeModel extends EmbassyEmployeeModel {
  const factory _EmbassyEmployeeModel({
    required final String id,
    required final String embassyId,
    required final String name,
    required final String role,
    final String? title,
    final String? department,
    final String? email,
    final String? phone,
    final String? photoUrl,
    final bool isPublic,
    final bool isActive,
    final String? bio,
    final List<String> languages,
    final List<String> responsibilities,
    final String? linkedUserId,
  }) = _$EmbassyEmployeeModelImpl;
  const _EmbassyEmployeeModel._() : super._();

  factory _EmbassyEmployeeModel.fromJson(Map<String, dynamic> json) =
      _$EmbassyEmployeeModelImpl.fromJson;

  @override
  String get id;
  @override
  String get embassyId;
  @override
  String get name;
  @override
  String get role;
  @override
  String? get title; // e.g., "Ambassador Extraordinary and Plenipotentiary"
  @override
  String? get department; // e.g., "Consular Services", "Visa Section"
  @override
  String? get email;
  @override
  String? get phone;
  @override
  String? get photoUrl;
  @override
  bool get isPublic; // Whether to show in public directory
  @override
  bool get isActive;
  @override
  String? get bio;
  @override
  List<String> get languages;
  @override
  List<String> get responsibilities; // Link to user account if exists
  @override
  String? get linkedUserId;

  /// Create a copy of EmbassyEmployeeModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmbassyEmployeeModelImplCopyWith<_$EmbassyEmployeeModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
