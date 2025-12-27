// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'administrative_request_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AdministrativeRequestModel _$AdministrativeRequestModelFromJson(
  Map<String, dynamic> json,
) {
  return _AdministrativeRequestModel.fromJson(json);
}

/// @nodoc
mixin _$AdministrativeRequestModel {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get embassyId => throw _privateConstructorUsedError;
  AdministrativeRequestType get requestType =>
      throw _privateConstructorUsedError;
  AdministrativeRequestStatus get status =>
      throw _privateConstructorUsedError; // Pre-filled form data from user profile
  String? get fullName => throw _privateConstructorUsedError;
  String? get dateOfBirth => throw _privateConstructorUsedError;
  String? get placeOfBirth => throw _privateConstructorUsedError;
  String? get nationality => throw _privateConstructorUsedError;
  String? get currentAddress => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get passportNumber => throw _privateConstructorUsedError;
  String? get passportExpiryDate =>
      throw _privateConstructorUsedError; // Dynamic form data
  Map<String, dynamic> get additionalData =>
      throw _privateConstructorUsedError; // Attachments
  List<String> get attachments =>
      throw _privateConstructorUsedError; // Notes and comments
  String? get userNotes => throw _privateConstructorUsedError;
  String? get embassyNotes => throw _privateConstructorUsedError;
  String? get rejectionReason =>
      throw _privateConstructorUsedError; // Timestamps
  @RequestTimestampConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @RequestTimestampConverter()
  DateTime? get submittedAt => throw _privateConstructorUsedError;
  @RequestTimestampConverter()
  DateTime? get processedAt => throw _privateConstructorUsedError;
  @RequestTimestampConverter()
  DateTime? get completedAt => throw _privateConstructorUsedError; // Tracking
  String? get trackingNumber => throw _privateConstructorUsedError;
  String? get processedBy =>
      throw _privateConstructorUsedError; // User info for display
  String? get userName => throw _privateConstructorUsedError;
  String? get userPhotoUrl =>
      throw _privateConstructorUsedError; // Embassy info for display
  String? get embassyName => throw _privateConstructorUsedError;
  String? get embassyCountry => throw _privateConstructorUsedError;

  /// Serializes this AdministrativeRequestModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdministrativeRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdministrativeRequestModelCopyWith<AdministrativeRequestModel>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdministrativeRequestModelCopyWith<$Res> {
  factory $AdministrativeRequestModelCopyWith(
    AdministrativeRequestModel value,
    $Res Function(AdministrativeRequestModel) then,
  ) =
      _$AdministrativeRequestModelCopyWithImpl<
        $Res,
        AdministrativeRequestModel
      >;
  @useResult
  $Res call({
    String id,
    String userId,
    String embassyId,
    AdministrativeRequestType requestType,
    AdministrativeRequestStatus status,
    String? fullName,
    String? dateOfBirth,
    String? placeOfBirth,
    String? nationality,
    String? currentAddress,
    String? phone,
    String? email,
    String? passportNumber,
    String? passportExpiryDate,
    Map<String, dynamic> additionalData,
    List<String> attachments,
    String? userNotes,
    String? embassyNotes,
    String? rejectionReason,
    @RequestTimestampConverter() DateTime? createdAt,
    @RequestTimestampConverter() DateTime? submittedAt,
    @RequestTimestampConverter() DateTime? processedAt,
    @RequestTimestampConverter() DateTime? completedAt,
    String? trackingNumber,
    String? processedBy,
    String? userName,
    String? userPhotoUrl,
    String? embassyName,
    String? embassyCountry,
  });
}

/// @nodoc
class _$AdministrativeRequestModelCopyWithImpl<
  $Res,
  $Val extends AdministrativeRequestModel
>
    implements $AdministrativeRequestModelCopyWith<$Res> {
  _$AdministrativeRequestModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdministrativeRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? embassyId = null,
    Object? requestType = null,
    Object? status = null,
    Object? fullName = freezed,
    Object? dateOfBirth = freezed,
    Object? placeOfBirth = freezed,
    Object? nationality = freezed,
    Object? currentAddress = freezed,
    Object? phone = freezed,
    Object? email = freezed,
    Object? passportNumber = freezed,
    Object? passportExpiryDate = freezed,
    Object? additionalData = null,
    Object? attachments = null,
    Object? userNotes = freezed,
    Object? embassyNotes = freezed,
    Object? rejectionReason = freezed,
    Object? createdAt = freezed,
    Object? submittedAt = freezed,
    Object? processedAt = freezed,
    Object? completedAt = freezed,
    Object? trackingNumber = freezed,
    Object? processedBy = freezed,
    Object? userName = freezed,
    Object? userPhotoUrl = freezed,
    Object? embassyName = freezed,
    Object? embassyCountry = freezed,
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
            embassyId:
                null == embassyId
                    ? _value.embassyId
                    : embassyId // ignore: cast_nullable_to_non_nullable
                        as String,
            requestType:
                null == requestType
                    ? _value.requestType
                    : requestType // ignore: cast_nullable_to_non_nullable
                        as AdministrativeRequestType,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as AdministrativeRequestStatus,
            fullName:
                freezed == fullName
                    ? _value.fullName
                    : fullName // ignore: cast_nullable_to_non_nullable
                        as String?,
            dateOfBirth:
                freezed == dateOfBirth
                    ? _value.dateOfBirth
                    : dateOfBirth // ignore: cast_nullable_to_non_nullable
                        as String?,
            placeOfBirth:
                freezed == placeOfBirth
                    ? _value.placeOfBirth
                    : placeOfBirth // ignore: cast_nullable_to_non_nullable
                        as String?,
            nationality:
                freezed == nationality
                    ? _value.nationality
                    : nationality // ignore: cast_nullable_to_non_nullable
                        as String?,
            currentAddress:
                freezed == currentAddress
                    ? _value.currentAddress
                    : currentAddress // ignore: cast_nullable_to_non_nullable
                        as String?,
            phone:
                freezed == phone
                    ? _value.phone
                    : phone // ignore: cast_nullable_to_non_nullable
                        as String?,
            email:
                freezed == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String?,
            passportNumber:
                freezed == passportNumber
                    ? _value.passportNumber
                    : passportNumber // ignore: cast_nullable_to_non_nullable
                        as String?,
            passportExpiryDate:
                freezed == passportExpiryDate
                    ? _value.passportExpiryDate
                    : passportExpiryDate // ignore: cast_nullable_to_non_nullable
                        as String?,
            additionalData:
                null == additionalData
                    ? _value.additionalData
                    : additionalData // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
            attachments:
                null == attachments
                    ? _value.attachments
                    : attachments // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            userNotes:
                freezed == userNotes
                    ? _value.userNotes
                    : userNotes // ignore: cast_nullable_to_non_nullable
                        as String?,
            embassyNotes:
                freezed == embassyNotes
                    ? _value.embassyNotes
                    : embassyNotes // ignore: cast_nullable_to_non_nullable
                        as String?,
            rejectionReason:
                freezed == rejectionReason
                    ? _value.rejectionReason
                    : rejectionReason // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            submittedAt:
                freezed == submittedAt
                    ? _value.submittedAt
                    : submittedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            processedAt:
                freezed == processedAt
                    ? _value.processedAt
                    : processedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            completedAt:
                freezed == completedAt
                    ? _value.completedAt
                    : completedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            trackingNumber:
                freezed == trackingNumber
                    ? _value.trackingNumber
                    : trackingNumber // ignore: cast_nullable_to_non_nullable
                        as String?,
            processedBy:
                freezed == processedBy
                    ? _value.processedBy
                    : processedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            userName:
                freezed == userName
                    ? _value.userName
                    : userName // ignore: cast_nullable_to_non_nullable
                        as String?,
            userPhotoUrl:
                freezed == userPhotoUrl
                    ? _value.userPhotoUrl
                    : userPhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            embassyName:
                freezed == embassyName
                    ? _value.embassyName
                    : embassyName // ignore: cast_nullable_to_non_nullable
                        as String?,
            embassyCountry:
                freezed == embassyCountry
                    ? _value.embassyCountry
                    : embassyCountry // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdministrativeRequestModelImplCopyWith<$Res>
    implements $AdministrativeRequestModelCopyWith<$Res> {
  factory _$$AdministrativeRequestModelImplCopyWith(
    _$AdministrativeRequestModelImpl value,
    $Res Function(_$AdministrativeRequestModelImpl) then,
  ) = __$$AdministrativeRequestModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String embassyId,
    AdministrativeRequestType requestType,
    AdministrativeRequestStatus status,
    String? fullName,
    String? dateOfBirth,
    String? placeOfBirth,
    String? nationality,
    String? currentAddress,
    String? phone,
    String? email,
    String? passportNumber,
    String? passportExpiryDate,
    Map<String, dynamic> additionalData,
    List<String> attachments,
    String? userNotes,
    String? embassyNotes,
    String? rejectionReason,
    @RequestTimestampConverter() DateTime? createdAt,
    @RequestTimestampConverter() DateTime? submittedAt,
    @RequestTimestampConverter() DateTime? processedAt,
    @RequestTimestampConverter() DateTime? completedAt,
    String? trackingNumber,
    String? processedBy,
    String? userName,
    String? userPhotoUrl,
    String? embassyName,
    String? embassyCountry,
  });
}

/// @nodoc
class __$$AdministrativeRequestModelImplCopyWithImpl<$Res>
    extends
        _$AdministrativeRequestModelCopyWithImpl<
          $Res,
          _$AdministrativeRequestModelImpl
        >
    implements _$$AdministrativeRequestModelImplCopyWith<$Res> {
  __$$AdministrativeRequestModelImplCopyWithImpl(
    _$AdministrativeRequestModelImpl _value,
    $Res Function(_$AdministrativeRequestModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdministrativeRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? embassyId = null,
    Object? requestType = null,
    Object? status = null,
    Object? fullName = freezed,
    Object? dateOfBirth = freezed,
    Object? placeOfBirth = freezed,
    Object? nationality = freezed,
    Object? currentAddress = freezed,
    Object? phone = freezed,
    Object? email = freezed,
    Object? passportNumber = freezed,
    Object? passportExpiryDate = freezed,
    Object? additionalData = null,
    Object? attachments = null,
    Object? userNotes = freezed,
    Object? embassyNotes = freezed,
    Object? rejectionReason = freezed,
    Object? createdAt = freezed,
    Object? submittedAt = freezed,
    Object? processedAt = freezed,
    Object? completedAt = freezed,
    Object? trackingNumber = freezed,
    Object? processedBy = freezed,
    Object? userName = freezed,
    Object? userPhotoUrl = freezed,
    Object? embassyName = freezed,
    Object? embassyCountry = freezed,
  }) {
    return _then(
      _$AdministrativeRequestModelImpl(
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
        embassyId:
            null == embassyId
                ? _value.embassyId
                : embassyId // ignore: cast_nullable_to_non_nullable
                    as String,
        requestType:
            null == requestType
                ? _value.requestType
                : requestType // ignore: cast_nullable_to_non_nullable
                    as AdministrativeRequestType,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as AdministrativeRequestStatus,
        fullName:
            freezed == fullName
                ? _value.fullName
                : fullName // ignore: cast_nullable_to_non_nullable
                    as String?,
        dateOfBirth:
            freezed == dateOfBirth
                ? _value.dateOfBirth
                : dateOfBirth // ignore: cast_nullable_to_non_nullable
                    as String?,
        placeOfBirth:
            freezed == placeOfBirth
                ? _value.placeOfBirth
                : placeOfBirth // ignore: cast_nullable_to_non_nullable
                    as String?,
        nationality:
            freezed == nationality
                ? _value.nationality
                : nationality // ignore: cast_nullable_to_non_nullable
                    as String?,
        currentAddress:
            freezed == currentAddress
                ? _value.currentAddress
                : currentAddress // ignore: cast_nullable_to_non_nullable
                    as String?,
        phone:
            freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                    as String?,
        email:
            freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String?,
        passportNumber:
            freezed == passportNumber
                ? _value.passportNumber
                : passportNumber // ignore: cast_nullable_to_non_nullable
                    as String?,
        passportExpiryDate:
            freezed == passportExpiryDate
                ? _value.passportExpiryDate
                : passportExpiryDate // ignore: cast_nullable_to_non_nullable
                    as String?,
        additionalData:
            null == additionalData
                ? _value._additionalData
                : additionalData // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
        attachments:
            null == attachments
                ? _value._attachments
                : attachments // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        userNotes:
            freezed == userNotes
                ? _value.userNotes
                : userNotes // ignore: cast_nullable_to_non_nullable
                    as String?,
        embassyNotes:
            freezed == embassyNotes
                ? _value.embassyNotes
                : embassyNotes // ignore: cast_nullable_to_non_nullable
                    as String?,
        rejectionReason:
            freezed == rejectionReason
                ? _value.rejectionReason
                : rejectionReason // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        submittedAt:
            freezed == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        processedAt:
            freezed == processedAt
                ? _value.processedAt
                : processedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        completedAt:
            freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        trackingNumber:
            freezed == trackingNumber
                ? _value.trackingNumber
                : trackingNumber // ignore: cast_nullable_to_non_nullable
                    as String?,
        processedBy:
            freezed == processedBy
                ? _value.processedBy
                : processedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        userName:
            freezed == userName
                ? _value.userName
                : userName // ignore: cast_nullable_to_non_nullable
                    as String?,
        userPhotoUrl:
            freezed == userPhotoUrl
                ? _value.userPhotoUrl
                : userPhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        embassyName:
            freezed == embassyName
                ? _value.embassyName
                : embassyName // ignore: cast_nullable_to_non_nullable
                    as String?,
        embassyCountry:
            freezed == embassyCountry
                ? _value.embassyCountry
                : embassyCountry // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdministrativeRequestModelImpl extends _AdministrativeRequestModel {
  const _$AdministrativeRequestModelImpl({
    required this.id,
    required this.userId,
    required this.embassyId,
    required this.requestType,
    this.status = AdministrativeRequestStatus.draft,
    this.fullName,
    this.dateOfBirth,
    this.placeOfBirth,
    this.nationality,
    this.currentAddress,
    this.phone,
    this.email,
    this.passportNumber,
    this.passportExpiryDate,
    final Map<String, dynamic> additionalData = const {},
    final List<String> attachments = const [],
    this.userNotes,
    this.embassyNotes,
    this.rejectionReason,
    @RequestTimestampConverter() this.createdAt,
    @RequestTimestampConverter() this.submittedAt,
    @RequestTimestampConverter() this.processedAt,
    @RequestTimestampConverter() this.completedAt,
    this.trackingNumber,
    this.processedBy,
    this.userName,
    this.userPhotoUrl,
    this.embassyName,
    this.embassyCountry,
  }) : _additionalData = additionalData,
       _attachments = attachments,
       super._();

  factory _$AdministrativeRequestModelImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$AdministrativeRequestModelImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String embassyId;
  @override
  final AdministrativeRequestType requestType;
  @override
  @JsonKey()
  final AdministrativeRequestStatus status;
  // Pre-filled form data from user profile
  @override
  final String? fullName;
  @override
  final String? dateOfBirth;
  @override
  final String? placeOfBirth;
  @override
  final String? nationality;
  @override
  final String? currentAddress;
  @override
  final String? phone;
  @override
  final String? email;
  @override
  final String? passportNumber;
  @override
  final String? passportExpiryDate;
  // Dynamic form data
  final Map<String, dynamic> _additionalData;
  // Dynamic form data
  @override
  @JsonKey()
  Map<String, dynamic> get additionalData {
    if (_additionalData is EqualUnmodifiableMapView) return _additionalData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_additionalData);
  }

  // Attachments
  final List<String> _attachments;
  // Attachments
  @override
  @JsonKey()
  List<String> get attachments {
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachments);
  }

  // Notes and comments
  @override
  final String? userNotes;
  @override
  final String? embassyNotes;
  @override
  final String? rejectionReason;
  // Timestamps
  @override
  @RequestTimestampConverter()
  final DateTime? createdAt;
  @override
  @RequestTimestampConverter()
  final DateTime? submittedAt;
  @override
  @RequestTimestampConverter()
  final DateTime? processedAt;
  @override
  @RequestTimestampConverter()
  final DateTime? completedAt;
  // Tracking
  @override
  final String? trackingNumber;
  @override
  final String? processedBy;
  // User info for display
  @override
  final String? userName;
  @override
  final String? userPhotoUrl;
  // Embassy info for display
  @override
  final String? embassyName;
  @override
  final String? embassyCountry;

  @override
  String toString() {
    return 'AdministrativeRequestModel(id: $id, userId: $userId, embassyId: $embassyId, requestType: $requestType, status: $status, fullName: $fullName, dateOfBirth: $dateOfBirth, placeOfBirth: $placeOfBirth, nationality: $nationality, currentAddress: $currentAddress, phone: $phone, email: $email, passportNumber: $passportNumber, passportExpiryDate: $passportExpiryDate, additionalData: $additionalData, attachments: $attachments, userNotes: $userNotes, embassyNotes: $embassyNotes, rejectionReason: $rejectionReason, createdAt: $createdAt, submittedAt: $submittedAt, processedAt: $processedAt, completedAt: $completedAt, trackingNumber: $trackingNumber, processedBy: $processedBy, userName: $userName, userPhotoUrl: $userPhotoUrl, embassyName: $embassyName, embassyCountry: $embassyCountry)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdministrativeRequestModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.embassyId, embassyId) ||
                other.embassyId == embassyId) &&
            (identical(other.requestType, requestType) ||
                other.requestType == requestType) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.dateOfBirth, dateOfBirth) ||
                other.dateOfBirth == dateOfBirth) &&
            (identical(other.placeOfBirth, placeOfBirth) ||
                other.placeOfBirth == placeOfBirth) &&
            (identical(other.nationality, nationality) ||
                other.nationality == nationality) &&
            (identical(other.currentAddress, currentAddress) ||
                other.currentAddress == currentAddress) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.passportNumber, passportNumber) ||
                other.passportNumber == passportNumber) &&
            (identical(other.passportExpiryDate, passportExpiryDate) ||
                other.passportExpiryDate == passportExpiryDate) &&
            const DeepCollectionEquality().equals(
              other._additionalData,
              _additionalData,
            ) &&
            const DeepCollectionEquality().equals(
              other._attachments,
              _attachments,
            ) &&
            (identical(other.userNotes, userNotes) ||
                other.userNotes == userNotes) &&
            (identical(other.embassyNotes, embassyNotes) ||
                other.embassyNotes == embassyNotes) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.processedAt, processedAt) ||
                other.processedAt == processedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.trackingNumber, trackingNumber) ||
                other.trackingNumber == trackingNumber) &&
            (identical(other.processedBy, processedBy) ||
                other.processedBy == processedBy) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.userPhotoUrl, userPhotoUrl) ||
                other.userPhotoUrl == userPhotoUrl) &&
            (identical(other.embassyName, embassyName) ||
                other.embassyName == embassyName) &&
            (identical(other.embassyCountry, embassyCountry) ||
                other.embassyCountry == embassyCountry));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    userId,
    embassyId,
    requestType,
    status,
    fullName,
    dateOfBirth,
    placeOfBirth,
    nationality,
    currentAddress,
    phone,
    email,
    passportNumber,
    passportExpiryDate,
    const DeepCollectionEquality().hash(_additionalData),
    const DeepCollectionEquality().hash(_attachments),
    userNotes,
    embassyNotes,
    rejectionReason,
    createdAt,
    submittedAt,
    processedAt,
    completedAt,
    trackingNumber,
    processedBy,
    userName,
    userPhotoUrl,
    embassyName,
    embassyCountry,
  ]);

  /// Create a copy of AdministrativeRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdministrativeRequestModelImplCopyWith<_$AdministrativeRequestModelImpl>
  get copyWith => __$$AdministrativeRequestModelImplCopyWithImpl<
    _$AdministrativeRequestModelImpl
  >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AdministrativeRequestModelImplToJson(this);
  }
}

abstract class _AdministrativeRequestModel extends AdministrativeRequestModel {
  const factory _AdministrativeRequestModel({
    required final String id,
    required final String userId,
    required final String embassyId,
    required final AdministrativeRequestType requestType,
    final AdministrativeRequestStatus status,
    final String? fullName,
    final String? dateOfBirth,
    final String? placeOfBirth,
    final String? nationality,
    final String? currentAddress,
    final String? phone,
    final String? email,
    final String? passportNumber,
    final String? passportExpiryDate,
    final Map<String, dynamic> additionalData,
    final List<String> attachments,
    final String? userNotes,
    final String? embassyNotes,
    final String? rejectionReason,
    @RequestTimestampConverter() final DateTime? createdAt,
    @RequestTimestampConverter() final DateTime? submittedAt,
    @RequestTimestampConverter() final DateTime? processedAt,
    @RequestTimestampConverter() final DateTime? completedAt,
    final String? trackingNumber,
    final String? processedBy,
    final String? userName,
    final String? userPhotoUrl,
    final String? embassyName,
    final String? embassyCountry,
  }) = _$AdministrativeRequestModelImpl;
  const _AdministrativeRequestModel._() : super._();

  factory _AdministrativeRequestModel.fromJson(Map<String, dynamic> json) =
      _$AdministrativeRequestModelImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get embassyId;
  @override
  AdministrativeRequestType get requestType;
  @override
  AdministrativeRequestStatus get status; // Pre-filled form data from user profile
  @override
  String? get fullName;
  @override
  String? get dateOfBirth;
  @override
  String? get placeOfBirth;
  @override
  String? get nationality;
  @override
  String? get currentAddress;
  @override
  String? get phone;
  @override
  String? get email;
  @override
  String? get passportNumber;
  @override
  String? get passportExpiryDate; // Dynamic form data
  @override
  Map<String, dynamic> get additionalData; // Attachments
  @override
  List<String> get attachments; // Notes and comments
  @override
  String? get userNotes;
  @override
  String? get embassyNotes;
  @override
  String? get rejectionReason; // Timestamps
  @override
  @RequestTimestampConverter()
  DateTime? get createdAt;
  @override
  @RequestTimestampConverter()
  DateTime? get submittedAt;
  @override
  @RequestTimestampConverter()
  DateTime? get processedAt;
  @override
  @RequestTimestampConverter()
  DateTime? get completedAt; // Tracking
  @override
  String? get trackingNumber;
  @override
  String? get processedBy; // User info for display
  @override
  String? get userName;
  @override
  String? get userPhotoUrl; // Embassy info for display
  @override
  String? get embassyName;
  @override
  String? get embassyCountry;

  /// Create a copy of AdministrativeRequestModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdministrativeRequestModelImplCopyWith<_$AdministrativeRequestModelImpl>
  get copyWith => throw _privateConstructorUsedError;
}
