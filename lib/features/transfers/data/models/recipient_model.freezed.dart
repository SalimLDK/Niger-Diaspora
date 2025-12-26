// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipient_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecipientModel _$RecipientModelFromJson(Map<String, dynamic> json) {
  return _RecipientModel.fromJson(json);
}

/// @nodoc
mixin _$RecipientModel {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get fullName => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String? get bankName => throw _privateConstructorUsedError;
  String? get bankAccountNumber => throw _privateConstructorUsedError;
  String? get mobileProvider => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  bool get isFavorite => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;

  /// Serializes this RecipientModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipientModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipientModelCopyWith<RecipientModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipientModelCopyWith<$Res> {
  factory $RecipientModelCopyWith(
    RecipientModel value,
    $Res Function(RecipientModel) then,
  ) = _$RecipientModelCopyWithImpl<$Res, RecipientModel>;
  @useResult
  $Res call({
    String id,
    String userId,
    String fullName,
    String phone,
    String? email,
    String type,
    String? bankName,
    String? bankAccountNumber,
    String? mobileProvider,
    String? city,
    String? address,
    bool isFavorite,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastUsedAt,
  });
}

/// @nodoc
class _$RecipientModelCopyWithImpl<$Res, $Val extends RecipientModel>
    implements $RecipientModelCopyWith<$Res> {
  _$RecipientModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipientModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? fullName = null,
    Object? phone = null,
    Object? email = freezed,
    Object? type = null,
    Object? bankName = freezed,
    Object? bankAccountNumber = freezed,
    Object? mobileProvider = freezed,
    Object? city = freezed,
    Object? address = freezed,
    Object? isFavorite = null,
    Object? createdAt = freezed,
    Object? lastUsedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            fullName:
                null == fullName
                    ? _value.fullName
                    : fullName // ignore: cast_nullable_to_non_nullable
                        as String,
            phone:
                null == phone
                    ? _value.phone
                    : phone // ignore: cast_nullable_to_non_nullable
                        as String,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            bankName:
                freezed == bankName
                    ? _value.bankName
                    : bankName // ignore: cast_nullable_to_non_nullable
                        as String?,
            bankAccountNumber:
                freezed == bankAccountNumber
                    ? _value.bankAccountNumber
                    : bankAccountNumber // ignore: cast_nullable_to_non_nullable
                        as String?,
            mobileProvider:
                freezed == mobileProvider
                    ? _value.mobileProvider
                    : mobileProvider // ignore: cast_nullable_to_non_nullable
                        as String?,
            city:
                freezed == city
                    ? _value.city
                    : city // ignore: cast_nullable_to_non_nullable
                        as String?,
            address:
                freezed == address
                    ? _value.address
                    : address // ignore: cast_nullable_to_non_nullable
                        as String?,
            isFavorite:
                null == isFavorite
                    ? _value.isFavorite
                    : isFavorite // ignore: cast_nullable_to_non_nullable
                        as bool,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            lastUsedAt:
                freezed == lastUsedAt
                    ? _value.lastUsedAt
                    : lastUsedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipientModelImplCopyWith<$Res>
    implements $RecipientModelCopyWith<$Res> {
  factory _$$RecipientModelImplCopyWith(
    _$RecipientModelImpl value,
    $Res Function(_$RecipientModelImpl) then,
  ) = __$$RecipientModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String fullName,
    String phone,
    String? email,
    String type,
    String? bankName,
    String? bankAccountNumber,
    String? mobileProvider,
    String? city,
    String? address,
    bool isFavorite,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastUsedAt,
  });
}

/// @nodoc
class __$$RecipientModelImplCopyWithImpl<$Res>
    extends _$RecipientModelCopyWithImpl<$Res, _$RecipientModelImpl>
    implements _$$RecipientModelImplCopyWith<$Res> {
  __$$RecipientModelImplCopyWithImpl(
    _$RecipientModelImpl _value,
    $Res Function(_$RecipientModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipientModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? fullName = null,
    Object? phone = null,
    Object? email = freezed,
    Object? type = null,
    Object? bankName = freezed,
    Object? bankAccountNumber = freezed,
    Object? mobileProvider = freezed,
    Object? city = freezed,
    Object? address = freezed,
    Object? isFavorite = null,
    Object? createdAt = freezed,
    Object? lastUsedAt = freezed,
  }) {
    return _then(
      _$RecipientModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        fullName:
            null == fullName
                ? _value.fullName
                : fullName // ignore: cast_nullable_to_non_nullable
                    as String,
        phone:
            null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                    as String,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        bankName:
            freezed == bankName
                ? _value.bankName
                : bankName // ignore: cast_nullable_to_non_nullable
                    as String?,
        bankAccountNumber:
            freezed == bankAccountNumber
                ? _value.bankAccountNumber
                : bankAccountNumber // ignore: cast_nullable_to_non_nullable
                    as String?,
        mobileProvider:
            freezed == mobileProvider
                ? _value.mobileProvider
                : mobileProvider // ignore: cast_nullable_to_non_nullable
                    as String?,
        city:
            freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                    as String?,
        address:
            freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                    as String?,
        isFavorite:
            null == isFavorite
                ? _value.isFavorite
                : isFavorite // ignore: cast_nullable_to_non_nullable
                    as bool,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        lastUsedAt:
            freezed == lastUsedAt
                ? _value.lastUsedAt
                : lastUsedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipientModelImpl extends _RecipientModel {
  const _$RecipientModelImpl({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    this.email,
    this.type = 'mobileWallet',
    this.bankName,
    this.bankAccountNumber,
    this.mobileProvider,
    this.city,
    this.address,
    this.isFavorite = false,
    @TimestampConverter() this.createdAt,
    @TimestampConverter() this.lastUsedAt,
  }) : super._();

  factory _$RecipientModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipientModelImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String fullName;
  @override
  final String phone;
  @override
  final String? email;
  @override
  @JsonKey()
  final String type;
  @override
  final String? bankName;
  @override
  final String? bankAccountNumber;
  @override
  final String? mobileProvider;
  @override
  final String? city;
  @override
  final String? address;
  @override
  @JsonKey()
  final bool isFavorite;
  @override
  @TimestampConverter()
  final DateTime? createdAt;
  @override
  @TimestampConverter()
  final DateTime? lastUsedAt;

  @override
  String toString() {
    return 'RecipientModel(id: $id, userId: $userId, fullName: $fullName, phone: $phone, email: $email, type: $type, bankName: $bankName, bankAccountNumber: $bankAccountNumber, mobileProvider: $mobileProvider, city: $city, address: $address, isFavorite: $isFavorite, createdAt: $createdAt, lastUsedAt: $lastUsedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipientModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.bankName, bankName) ||
                other.bankName == bankName) &&
            (identical(other.bankAccountNumber, bankAccountNumber) ||
                other.bankAccountNumber == bankAccountNumber) &&
            (identical(other.mobileProvider, mobileProvider) ||
                other.mobileProvider == mobileProvider) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.isFavorite, isFavorite) ||
                other.isFavorite == isFavorite) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastUsedAt, lastUsedAt) ||
                other.lastUsedAt == lastUsedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    fullName,
    phone,
    email,
    type,
    bankName,
    bankAccountNumber,
    mobileProvider,
    city,
    address,
    isFavorite,
    createdAt,
    lastUsedAt,
  );

  /// Create a copy of RecipientModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipientModelImplCopyWith<_$RecipientModelImpl> get copyWith =>
      __$$RecipientModelImplCopyWithImpl<_$RecipientModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipientModelImplToJson(this);
  }
}

abstract class _RecipientModel extends RecipientModel {
  const factory _RecipientModel({
    required final String id,
    required final String userId,
    required final String fullName,
    required final String phone,
    final String? email,
    final String type,
    final String? bankName,
    final String? bankAccountNumber,
    final String? mobileProvider,
    final String? city,
    final String? address,
    final bool isFavorite,
    @TimestampConverter() final DateTime? createdAt,
    @TimestampConverter() final DateTime? lastUsedAt,
  }) = _$RecipientModelImpl;
  const _RecipientModel._() : super._();

  factory _RecipientModel.fromJson(Map<String, dynamic> json) =
      _$RecipientModelImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get fullName;
  @override
  String get phone;
  @override
  String? get email;
  @override
  String get type;
  @override
  String? get bankName;
  @override
  String? get bankAccountNumber;
  @override
  String? get mobileProvider;
  @override
  String? get city;
  @override
  String? get address;
  @override
  bool get isFavorite;
  @override
  @TimestampConverter()
  DateTime? get createdAt;
  @override
  @TimestampConverter()
  DateTime? get lastUsedAt;

  /// Create a copy of RecipientModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipientModelImplCopyWith<_$RecipientModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
