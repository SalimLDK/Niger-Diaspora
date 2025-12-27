// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'embassy_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EmbassyMessageModel _$EmbassyMessageModelFromJson(Map<String, dynamic> json) {
  return _EmbassyMessageModel.fromJson(json);
}

/// @nodoc
mixin _$EmbassyMessageModel {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get embassyId => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  EmbassyMessageType get messageType => throw _privateConstructorUsedError;
  EmbassyMessageStatus get status => throw _privateConstructorUsedError;
  @EmbassyTimestampConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @EmbassyTimestampConverter()
  DateTime? get readAt => throw _privateConstructorUsedError;
  @EmbassyTimestampConverter()
  DateTime? get repliedAt => throw _privateConstructorUsedError;
  List<String> get attachments => throw _privateConstructorUsedError;
  String? get replyContent => throw _privateConstructorUsedError;
  String? get repliedBy =>
      throw _privateConstructorUsedError; // Embassy staff ID who replied
  // User info for display
  String? get userName => throw _privateConstructorUsedError;
  String? get userPhotoUrl => throw _privateConstructorUsedError;
  String? get userEmail =>
      throw _privateConstructorUsedError; // Embassy info for display
  String? get embassyName => throw _privateConstructorUsedError;
  String? get embassyCountry => throw _privateConstructorUsedError;

  /// Serializes this EmbassyMessageModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmbassyMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmbassyMessageModelCopyWith<EmbassyMessageModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmbassyMessageModelCopyWith<$Res> {
  factory $EmbassyMessageModelCopyWith(
    EmbassyMessageModel value,
    $Res Function(EmbassyMessageModel) then,
  ) = _$EmbassyMessageModelCopyWithImpl<$Res, EmbassyMessageModel>;
  @useResult
  $Res call({
    String id,
    String userId,
    String embassyId,
    String subject,
    String content,
    EmbassyMessageType messageType,
    EmbassyMessageStatus status,
    @EmbassyTimestampConverter() DateTime? createdAt,
    @EmbassyTimestampConverter() DateTime? readAt,
    @EmbassyTimestampConverter() DateTime? repliedAt,
    List<String> attachments,
    String? replyContent,
    String? repliedBy,
    String? userName,
    String? userPhotoUrl,
    String? userEmail,
    String? embassyName,
    String? embassyCountry,
  });
}

/// @nodoc
class _$EmbassyMessageModelCopyWithImpl<$Res, $Val extends EmbassyMessageModel>
    implements $EmbassyMessageModelCopyWith<$Res> {
  _$EmbassyMessageModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmbassyMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? embassyId = null,
    Object? subject = null,
    Object? content = null,
    Object? messageType = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? readAt = freezed,
    Object? repliedAt = freezed,
    Object? attachments = null,
    Object? replyContent = freezed,
    Object? repliedBy = freezed,
    Object? userName = freezed,
    Object? userPhotoUrl = freezed,
    Object? userEmail = freezed,
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
            subject:
                null == subject
                    ? _value.subject
                    : subject // ignore: cast_nullable_to_non_nullable
                        as String,
            content:
                null == content
                    ? _value.content
                    : content // ignore: cast_nullable_to_non_nullable
                        as String,
            messageType:
                null == messageType
                    ? _value.messageType
                    : messageType // ignore: cast_nullable_to_non_nullable
                        as EmbassyMessageType,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as EmbassyMessageStatus,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            readAt:
                freezed == readAt
                    ? _value.readAt
                    : readAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            repliedAt:
                freezed == repliedAt
                    ? _value.repliedAt
                    : repliedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            attachments:
                null == attachments
                    ? _value.attachments
                    : attachments // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            replyContent:
                freezed == replyContent
                    ? _value.replyContent
                    : replyContent // ignore: cast_nullable_to_non_nullable
                        as String?,
            repliedBy:
                freezed == repliedBy
                    ? _value.repliedBy
                    : repliedBy // ignore: cast_nullable_to_non_nullable
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
            userEmail:
                freezed == userEmail
                    ? _value.userEmail
                    : userEmail // ignore: cast_nullable_to_non_nullable
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
abstract class _$$EmbassyMessageModelImplCopyWith<$Res>
    implements $EmbassyMessageModelCopyWith<$Res> {
  factory _$$EmbassyMessageModelImplCopyWith(
    _$EmbassyMessageModelImpl value,
    $Res Function(_$EmbassyMessageModelImpl) then,
  ) = __$$EmbassyMessageModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String embassyId,
    String subject,
    String content,
    EmbassyMessageType messageType,
    EmbassyMessageStatus status,
    @EmbassyTimestampConverter() DateTime? createdAt,
    @EmbassyTimestampConverter() DateTime? readAt,
    @EmbassyTimestampConverter() DateTime? repliedAt,
    List<String> attachments,
    String? replyContent,
    String? repliedBy,
    String? userName,
    String? userPhotoUrl,
    String? userEmail,
    String? embassyName,
    String? embassyCountry,
  });
}

/// @nodoc
class __$$EmbassyMessageModelImplCopyWithImpl<$Res>
    extends _$EmbassyMessageModelCopyWithImpl<$Res, _$EmbassyMessageModelImpl>
    implements _$$EmbassyMessageModelImplCopyWith<$Res> {
  __$$EmbassyMessageModelImplCopyWithImpl(
    _$EmbassyMessageModelImpl _value,
    $Res Function(_$EmbassyMessageModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EmbassyMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? embassyId = null,
    Object? subject = null,
    Object? content = null,
    Object? messageType = null,
    Object? status = null,
    Object? createdAt = freezed,
    Object? readAt = freezed,
    Object? repliedAt = freezed,
    Object? attachments = null,
    Object? replyContent = freezed,
    Object? repliedBy = freezed,
    Object? userName = freezed,
    Object? userPhotoUrl = freezed,
    Object? userEmail = freezed,
    Object? embassyName = freezed,
    Object? embassyCountry = freezed,
  }) {
    return _then(
      _$EmbassyMessageModelImpl(
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
        subject:
            null == subject
                ? _value.subject
                : subject // ignore: cast_nullable_to_non_nullable
                    as String,
        content:
            null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                    as String,
        messageType:
            null == messageType
                ? _value.messageType
                : messageType // ignore: cast_nullable_to_non_nullable
                    as EmbassyMessageType,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as EmbassyMessageStatus,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        readAt:
            freezed == readAt
                ? _value.readAt
                : readAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        repliedAt:
            freezed == repliedAt
                ? _value.repliedAt
                : repliedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        attachments:
            null == attachments
                ? _value._attachments
                : attachments // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        replyContent:
            freezed == replyContent
                ? _value.replyContent
                : replyContent // ignore: cast_nullable_to_non_nullable
                    as String?,
        repliedBy:
            freezed == repliedBy
                ? _value.repliedBy
                : repliedBy // ignore: cast_nullable_to_non_nullable
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
        userEmail:
            freezed == userEmail
                ? _value.userEmail
                : userEmail // ignore: cast_nullable_to_non_nullable
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
class _$EmbassyMessageModelImpl extends _EmbassyMessageModel {
  const _$EmbassyMessageModelImpl({
    required this.id,
    required this.userId,
    required this.embassyId,
    required this.subject,
    required this.content,
    this.messageType = EmbassyMessageType.general,
    this.status = EmbassyMessageStatus.pending,
    @EmbassyTimestampConverter() this.createdAt,
    @EmbassyTimestampConverter() this.readAt,
    @EmbassyTimestampConverter() this.repliedAt,
    final List<String> attachments = const [],
    this.replyContent,
    this.repliedBy,
    this.userName,
    this.userPhotoUrl,
    this.userEmail,
    this.embassyName,
    this.embassyCountry,
  }) : _attachments = attachments,
       super._();

  factory _$EmbassyMessageModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmbassyMessageModelImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String embassyId;
  @override
  final String subject;
  @override
  final String content;
  @override
  @JsonKey()
  final EmbassyMessageType messageType;
  @override
  @JsonKey()
  final EmbassyMessageStatus status;
  @override
  @EmbassyTimestampConverter()
  final DateTime? createdAt;
  @override
  @EmbassyTimestampConverter()
  final DateTime? readAt;
  @override
  @EmbassyTimestampConverter()
  final DateTime? repliedAt;
  final List<String> _attachments;
  @override
  @JsonKey()
  List<String> get attachments {
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_attachments);
  }

  @override
  final String? replyContent;
  @override
  final String? repliedBy;
  // Embassy staff ID who replied
  // User info for display
  @override
  final String? userName;
  @override
  final String? userPhotoUrl;
  @override
  final String? userEmail;
  // Embassy info for display
  @override
  final String? embassyName;
  @override
  final String? embassyCountry;

  @override
  String toString() {
    return 'EmbassyMessageModel(id: $id, userId: $userId, embassyId: $embassyId, subject: $subject, content: $content, messageType: $messageType, status: $status, createdAt: $createdAt, readAt: $readAt, repliedAt: $repliedAt, attachments: $attachments, replyContent: $replyContent, repliedBy: $repliedBy, userName: $userName, userPhotoUrl: $userPhotoUrl, userEmail: $userEmail, embassyName: $embassyName, embassyCountry: $embassyCountry)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmbassyMessageModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.embassyId, embassyId) ||
                other.embassyId == embassyId) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.messageType, messageType) ||
                other.messageType == messageType) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.readAt, readAt) || other.readAt == readAt) &&
            (identical(other.repliedAt, repliedAt) ||
                other.repliedAt == repliedAt) &&
            const DeepCollectionEquality().equals(
              other._attachments,
              _attachments,
            ) &&
            (identical(other.replyContent, replyContent) ||
                other.replyContent == replyContent) &&
            (identical(other.repliedBy, repliedBy) ||
                other.repliedBy == repliedBy) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.userPhotoUrl, userPhotoUrl) ||
                other.userPhotoUrl == userPhotoUrl) &&
            (identical(other.userEmail, userEmail) ||
                other.userEmail == userEmail) &&
            (identical(other.embassyName, embassyName) ||
                other.embassyName == embassyName) &&
            (identical(other.embassyCountry, embassyCountry) ||
                other.embassyCountry == embassyCountry));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    embassyId,
    subject,
    content,
    messageType,
    status,
    createdAt,
    readAt,
    repliedAt,
    const DeepCollectionEquality().hash(_attachments),
    replyContent,
    repliedBy,
    userName,
    userPhotoUrl,
    userEmail,
    embassyName,
    embassyCountry,
  );

  /// Create a copy of EmbassyMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmbassyMessageModelImplCopyWith<_$EmbassyMessageModelImpl> get copyWith =>
      __$$EmbassyMessageModelImplCopyWithImpl<_$EmbassyMessageModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EmbassyMessageModelImplToJson(this);
  }
}

abstract class _EmbassyMessageModel extends EmbassyMessageModel {
  const factory _EmbassyMessageModel({
    required final String id,
    required final String userId,
    required final String embassyId,
    required final String subject,
    required final String content,
    final EmbassyMessageType messageType,
    final EmbassyMessageStatus status,
    @EmbassyTimestampConverter() final DateTime? createdAt,
    @EmbassyTimestampConverter() final DateTime? readAt,
    @EmbassyTimestampConverter() final DateTime? repliedAt,
    final List<String> attachments,
    final String? replyContent,
    final String? repliedBy,
    final String? userName,
    final String? userPhotoUrl,
    final String? userEmail,
    final String? embassyName,
    final String? embassyCountry,
  }) = _$EmbassyMessageModelImpl;
  const _EmbassyMessageModel._() : super._();

  factory _EmbassyMessageModel.fromJson(Map<String, dynamic> json) =
      _$EmbassyMessageModelImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get embassyId;
  @override
  String get subject;
  @override
  String get content;
  @override
  EmbassyMessageType get messageType;
  @override
  EmbassyMessageStatus get status;
  @override
  @EmbassyTimestampConverter()
  DateTime? get createdAt;
  @override
  @EmbassyTimestampConverter()
  DateTime? get readAt;
  @override
  @EmbassyTimestampConverter()
  DateTime? get repliedAt;
  @override
  List<String> get attachments;
  @override
  String? get replyContent;
  @override
  String? get repliedBy; // Embassy staff ID who replied
  // User info for display
  @override
  String? get userName;
  @override
  String? get userPhotoUrl;
  @override
  String? get userEmail; // Embassy info for display
  @override
  String? get embassyName;
  @override
  String? get embassyCountry;

  /// Create a copy of EmbassyMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmbassyMessageModelImplCopyWith<_$EmbassyMessageModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
