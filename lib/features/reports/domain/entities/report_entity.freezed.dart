// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ContentSnapshot {
  /// Texte du message ou description
  String? get text => throw _privateConstructorUsedError;

  /// URL de l'image (si applicable)
  String? get imageUrl => throw _privateConstructorUsedError;

  /// URL de la vidéo (si applicable)
  String? get videoUrl => throw _privateConstructorUsedError;

  /// URL du fichier/document (si applicable)
  String? get fileUrl => throw _privateConstructorUsedError;

  /// Nom du fichier
  String? get fileName => throw _privateConstructorUsedError;

  /// Type de contenu (text, image, video, audio, file, product)
  String? get contentType => throw _privateConstructorUsedError;

  /// Données additionnelles (ex: infos produit, profil)
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Date de capture
  DateTime? get capturedAt => throw _privateConstructorUsedError;

  /// Create a copy of ContentSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ContentSnapshotCopyWith<ContentSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContentSnapshotCopyWith<$Res> {
  factory $ContentSnapshotCopyWith(
    ContentSnapshot value,
    $Res Function(ContentSnapshot) then,
  ) = _$ContentSnapshotCopyWithImpl<$Res, ContentSnapshot>;
  @useResult
  $Res call({
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? fileUrl,
    String? fileName,
    String? contentType,
    Map<String, dynamic>? metadata,
    DateTime? capturedAt,
  });
}

/// @nodoc
class _$ContentSnapshotCopyWithImpl<$Res, $Val extends ContentSnapshot>
    implements $ContentSnapshotCopyWith<$Res> {
  _$ContentSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ContentSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = freezed,
    Object? imageUrl = freezed,
    Object? videoUrl = freezed,
    Object? fileUrl = freezed,
    Object? fileName = freezed,
    Object? contentType = freezed,
    Object? metadata = freezed,
    Object? capturedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            text:
                freezed == text
                    ? _value.text
                    : text // ignore: cast_nullable_to_non_nullable
                        as String?,
            imageUrl:
                freezed == imageUrl
                    ? _value.imageUrl
                    : imageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            videoUrl:
                freezed == videoUrl
                    ? _value.videoUrl
                    : videoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            fileUrl:
                freezed == fileUrl
                    ? _value.fileUrl
                    : fileUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            fileName:
                freezed == fileName
                    ? _value.fileName
                    : fileName // ignore: cast_nullable_to_non_nullable
                        as String?,
            contentType:
                freezed == contentType
                    ? _value.contentType
                    : contentType // ignore: cast_nullable_to_non_nullable
                        as String?,
            metadata:
                freezed == metadata
                    ? _value.metadata
                    : metadata // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>?,
            capturedAt:
                freezed == capturedAt
                    ? _value.capturedAt
                    : capturedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ContentSnapshotImplCopyWith<$Res>
    implements $ContentSnapshotCopyWith<$Res> {
  factory _$$ContentSnapshotImplCopyWith(
    _$ContentSnapshotImpl value,
    $Res Function(_$ContentSnapshotImpl) then,
  ) = __$$ContentSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? fileUrl,
    String? fileName,
    String? contentType,
    Map<String, dynamic>? metadata,
    DateTime? capturedAt,
  });
}

/// @nodoc
class __$$ContentSnapshotImplCopyWithImpl<$Res>
    extends _$ContentSnapshotCopyWithImpl<$Res, _$ContentSnapshotImpl>
    implements _$$ContentSnapshotImplCopyWith<$Res> {
  __$$ContentSnapshotImplCopyWithImpl(
    _$ContentSnapshotImpl _value,
    $Res Function(_$ContentSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ContentSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = freezed,
    Object? imageUrl = freezed,
    Object? videoUrl = freezed,
    Object? fileUrl = freezed,
    Object? fileName = freezed,
    Object? contentType = freezed,
    Object? metadata = freezed,
    Object? capturedAt = freezed,
  }) {
    return _then(
      _$ContentSnapshotImpl(
        text:
            freezed == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                    as String?,
        imageUrl:
            freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        videoUrl:
            freezed == videoUrl
                ? _value.videoUrl
                : videoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        fileUrl:
            freezed == fileUrl
                ? _value.fileUrl
                : fileUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        fileName:
            freezed == fileName
                ? _value.fileName
                : fileName // ignore: cast_nullable_to_non_nullable
                    as String?,
        contentType:
            freezed == contentType
                ? _value.contentType
                : contentType // ignore: cast_nullable_to_non_nullable
                    as String?,
        metadata:
            freezed == metadata
                ? _value._metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
        capturedAt:
            freezed == capturedAt
                ? _value.capturedAt
                : capturedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$ContentSnapshotImpl implements _ContentSnapshot {
  const _$ContentSnapshotImpl({
    this.text,
    this.imageUrl,
    this.videoUrl,
    this.fileUrl,
    this.fileName,
    this.contentType,
    final Map<String, dynamic>? metadata,
    this.capturedAt,
  }) : _metadata = metadata;

  /// Texte du message ou description
  @override
  final String? text;

  /// URL de l'image (si applicable)
  @override
  final String? imageUrl;

  /// URL de la vidéo (si applicable)
  @override
  final String? videoUrl;

  /// URL du fichier/document (si applicable)
  @override
  final String? fileUrl;

  /// Nom du fichier
  @override
  final String? fileName;

  /// Type de contenu (text, image, video, audio, file, product)
  @override
  final String? contentType;

  /// Données additionnelles (ex: infos produit, profil)
  final Map<String, dynamic>? _metadata;

  /// Données additionnelles (ex: infos produit, profil)
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Date de capture
  @override
  final DateTime? capturedAt;

  @override
  String toString() {
    return 'ContentSnapshot(text: $text, imageUrl: $imageUrl, videoUrl: $videoUrl, fileUrl: $fileUrl, fileName: $fileName, contentType: $contentType, metadata: $metadata, capturedAt: $capturedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContentSnapshotImpl &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.videoUrl, videoUrl) ||
                other.videoUrl == videoUrl) &&
            (identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    text,
    imageUrl,
    videoUrl,
    fileUrl,
    fileName,
    contentType,
    const DeepCollectionEquality().hash(_metadata),
    capturedAt,
  );

  /// Create a copy of ContentSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ContentSnapshotImplCopyWith<_$ContentSnapshotImpl> get copyWith =>
      __$$ContentSnapshotImplCopyWithImpl<_$ContentSnapshotImpl>(
        this,
        _$identity,
      );
}

abstract class _ContentSnapshot implements ContentSnapshot {
  const factory _ContentSnapshot({
    final String? text,
    final String? imageUrl,
    final String? videoUrl,
    final String? fileUrl,
    final String? fileName,
    final String? contentType,
    final Map<String, dynamic>? metadata,
    final DateTime? capturedAt,
  }) = _$ContentSnapshotImpl;

  /// Texte du message ou description
  @override
  String? get text;

  /// URL de l'image (si applicable)
  @override
  String? get imageUrl;

  /// URL de la vidéo (si applicable)
  @override
  String? get videoUrl;

  /// URL du fichier/document (si applicable)
  @override
  String? get fileUrl;

  /// Nom du fichier
  @override
  String? get fileName;

  /// Type de contenu (text, image, video, audio, file, product)
  @override
  String? get contentType;

  /// Données additionnelles (ex: infos produit, profil)
  @override
  Map<String, dynamic>? get metadata;

  /// Date de capture
  @override
  DateTime? get capturedAt;

  /// Create a copy of ContentSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ContentSnapshotImplCopyWith<_$ContentSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ReportEntity {
  String get id => throw _privateConstructorUsedError;
  String get reporterId => throw _privateConstructorUsedError;
  String? get reporterName => throw _privateConstructorUsedError;
  String? get reporterPhotoUrl => throw _privateConstructorUsedError;
  ReportTargetType get targetType => throw _privateConstructorUsedError;
  String get targetId => throw _privateConstructorUsedError;
  String? get targetName => throw _privateConstructorUsedError;
  String? get targetPreview => throw _privateConstructorUsedError;
  String? get conversationId => throw _privateConstructorUsedError;
  ReportReason get reason => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// Snapshot du contenu au moment du signalement
  ContentSnapshot? get contentSnapshot => throw _privateConstructorUsedError;

  /// ID de la personne signalée (pour notification)
  String? get reportedUserId => throw _privateConstructorUsedError;
  ReportStatus get status => throw _privateConstructorUsedError;
  String? get adminNote => throw _privateConstructorUsedError;
  String? get reviewedBy => throw _privateConstructorUsedError;
  String? get reviewerName => throw _privateConstructorUsedError;
  String? get resolution => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get reviewedAt => throw _privateConstructorUsedError;

  /// Indique si la personne signalée a été notifiée
  bool get reportedUserNotified => throw _privateConstructorUsedError;

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReportEntityCopyWith<ReportEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReportEntityCopyWith<$Res> {
  factory $ReportEntityCopyWith(
    ReportEntity value,
    $Res Function(ReportEntity) then,
  ) = _$ReportEntityCopyWithImpl<$Res, ReportEntity>;
  @useResult
  $Res call({
    String id,
    String reporterId,
    String? reporterName,
    String? reporterPhotoUrl,
    ReportTargetType targetType,
    String targetId,
    String? targetName,
    String? targetPreview,
    String? conversationId,
    ReportReason reason,
    String? description,
    ContentSnapshot? contentSnapshot,
    String? reportedUserId,
    ReportStatus status,
    String? adminNote,
    String? reviewedBy,
    String? reviewerName,
    String? resolution,
    DateTime? createdAt,
    DateTime? reviewedAt,
    bool reportedUserNotified,
  });

  $ContentSnapshotCopyWith<$Res>? get contentSnapshot;
}

/// @nodoc
class _$ReportEntityCopyWithImpl<$Res, $Val extends ReportEntity>
    implements $ReportEntityCopyWith<$Res> {
  _$ReportEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? reporterId = null,
    Object? reporterName = freezed,
    Object? reporterPhotoUrl = freezed,
    Object? targetType = null,
    Object? targetId = null,
    Object? targetName = freezed,
    Object? targetPreview = freezed,
    Object? conversationId = freezed,
    Object? reason = null,
    Object? description = freezed,
    Object? contentSnapshot = freezed,
    Object? reportedUserId = freezed,
    Object? status = null,
    Object? adminNote = freezed,
    Object? reviewedBy = freezed,
    Object? reviewerName = freezed,
    Object? resolution = freezed,
    Object? createdAt = freezed,
    Object? reviewedAt = freezed,
    Object? reportedUserNotified = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            reporterId:
                null == reporterId
                    ? _value.reporterId
                    : reporterId // ignore: cast_nullable_to_non_nullable
                        as String,
            reporterName:
                freezed == reporterName
                    ? _value.reporterName
                    : reporterName // ignore: cast_nullable_to_non_nullable
                        as String?,
            reporterPhotoUrl:
                freezed == reporterPhotoUrl
                    ? _value.reporterPhotoUrl
                    : reporterPhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            targetType:
                null == targetType
                    ? _value.targetType
                    : targetType // ignore: cast_nullable_to_non_nullable
                        as ReportTargetType,
            targetId:
                null == targetId
                    ? _value.targetId
                    : targetId // ignore: cast_nullable_to_non_nullable
                        as String,
            targetName:
                freezed == targetName
                    ? _value.targetName
                    : targetName // ignore: cast_nullable_to_non_nullable
                        as String?,
            targetPreview:
                freezed == targetPreview
                    ? _value.targetPreview
                    : targetPreview // ignore: cast_nullable_to_non_nullable
                        as String?,
            conversationId:
                freezed == conversationId
                    ? _value.conversationId
                    : conversationId // ignore: cast_nullable_to_non_nullable
                        as String?,
            reason:
                null == reason
                    ? _value.reason
                    : reason // ignore: cast_nullable_to_non_nullable
                        as ReportReason,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            contentSnapshot:
                freezed == contentSnapshot
                    ? _value.contentSnapshot
                    : contentSnapshot // ignore: cast_nullable_to_non_nullable
                        as ContentSnapshot?,
            reportedUserId:
                freezed == reportedUserId
                    ? _value.reportedUserId
                    : reportedUserId // ignore: cast_nullable_to_non_nullable
                        as String?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as ReportStatus,
            adminNote:
                freezed == adminNote
                    ? _value.adminNote
                    : adminNote // ignore: cast_nullable_to_non_nullable
                        as String?,
            reviewedBy:
                freezed == reviewedBy
                    ? _value.reviewedBy
                    : reviewedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            reviewerName:
                freezed == reviewerName
                    ? _value.reviewerName
                    : reviewerName // ignore: cast_nullable_to_non_nullable
                        as String?,
            resolution:
                freezed == resolution
                    ? _value.resolution
                    : resolution // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            reviewedAt:
                freezed == reviewedAt
                    ? _value.reviewedAt
                    : reviewedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            reportedUserNotified:
                null == reportedUserNotified
                    ? _value.reportedUserNotified
                    : reportedUserNotified // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ContentSnapshotCopyWith<$Res>? get contentSnapshot {
    if (_value.contentSnapshot == null) {
      return null;
    }

    return $ContentSnapshotCopyWith<$Res>(_value.contentSnapshot!, (value) {
      return _then(_value.copyWith(contentSnapshot: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ReportEntityImplCopyWith<$Res>
    implements $ReportEntityCopyWith<$Res> {
  factory _$$ReportEntityImplCopyWith(
    _$ReportEntityImpl value,
    $Res Function(_$ReportEntityImpl) then,
  ) = __$$ReportEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String reporterId,
    String? reporterName,
    String? reporterPhotoUrl,
    ReportTargetType targetType,
    String targetId,
    String? targetName,
    String? targetPreview,
    String? conversationId,
    ReportReason reason,
    String? description,
    ContentSnapshot? contentSnapshot,
    String? reportedUserId,
    ReportStatus status,
    String? adminNote,
    String? reviewedBy,
    String? reviewerName,
    String? resolution,
    DateTime? createdAt,
    DateTime? reviewedAt,
    bool reportedUserNotified,
  });

  @override
  $ContentSnapshotCopyWith<$Res>? get contentSnapshot;
}

/// @nodoc
class __$$ReportEntityImplCopyWithImpl<$Res>
    extends _$ReportEntityCopyWithImpl<$Res, _$ReportEntityImpl>
    implements _$$ReportEntityImplCopyWith<$Res> {
  __$$ReportEntityImplCopyWithImpl(
    _$ReportEntityImpl _value,
    $Res Function(_$ReportEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? reporterId = null,
    Object? reporterName = freezed,
    Object? reporterPhotoUrl = freezed,
    Object? targetType = null,
    Object? targetId = null,
    Object? targetName = freezed,
    Object? targetPreview = freezed,
    Object? conversationId = freezed,
    Object? reason = null,
    Object? description = freezed,
    Object? contentSnapshot = freezed,
    Object? reportedUserId = freezed,
    Object? status = null,
    Object? adminNote = freezed,
    Object? reviewedBy = freezed,
    Object? reviewerName = freezed,
    Object? resolution = freezed,
    Object? createdAt = freezed,
    Object? reviewedAt = freezed,
    Object? reportedUserNotified = null,
  }) {
    return _then(
      _$ReportEntityImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        reporterId:
            null == reporterId
                ? _value.reporterId
                : reporterId // ignore: cast_nullable_to_non_nullable
                    as String,
        reporterName:
            freezed == reporterName
                ? _value.reporterName
                : reporterName // ignore: cast_nullable_to_non_nullable
                    as String?,
        reporterPhotoUrl:
            freezed == reporterPhotoUrl
                ? _value.reporterPhotoUrl
                : reporterPhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        targetType:
            null == targetType
                ? _value.targetType
                : targetType // ignore: cast_nullable_to_non_nullable
                    as ReportTargetType,
        targetId:
            null == targetId
                ? _value.targetId
                : targetId // ignore: cast_nullable_to_non_nullable
                    as String,
        targetName:
            freezed == targetName
                ? _value.targetName
                : targetName // ignore: cast_nullable_to_non_nullable
                    as String?,
        targetPreview:
            freezed == targetPreview
                ? _value.targetPreview
                : targetPreview // ignore: cast_nullable_to_non_nullable
                    as String?,
        conversationId:
            freezed == conversationId
                ? _value.conversationId
                : conversationId // ignore: cast_nullable_to_non_nullable
                    as String?,
        reason:
            null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                    as ReportReason,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        contentSnapshot:
            freezed == contentSnapshot
                ? _value.contentSnapshot
                : contentSnapshot // ignore: cast_nullable_to_non_nullable
                    as ContentSnapshot?,
        reportedUserId:
            freezed == reportedUserId
                ? _value.reportedUserId
                : reportedUserId // ignore: cast_nullable_to_non_nullable
                    as String?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as ReportStatus,
        adminNote:
            freezed == adminNote
                ? _value.adminNote
                : adminNote // ignore: cast_nullable_to_non_nullable
                    as String?,
        reviewedBy:
            freezed == reviewedBy
                ? _value.reviewedBy
                : reviewedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        reviewerName:
            freezed == reviewerName
                ? _value.reviewerName
                : reviewerName // ignore: cast_nullable_to_non_nullable
                    as String?,
        resolution:
            freezed == resolution
                ? _value.resolution
                : resolution // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        reviewedAt:
            freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        reportedUserNotified:
            null == reportedUserNotified
                ? _value.reportedUserNotified
                : reportedUserNotified // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc

class _$ReportEntityImpl extends _ReportEntity {
  const _$ReportEntityImpl({
    required this.id,
    required this.reporterId,
    this.reporterName,
    this.reporterPhotoUrl,
    required this.targetType,
    required this.targetId,
    this.targetName,
    this.targetPreview,
    this.conversationId,
    required this.reason,
    this.description,
    this.contentSnapshot,
    this.reportedUserId,
    this.status = ReportStatus.pending,
    this.adminNote,
    this.reviewedBy,
    this.reviewerName,
    this.resolution,
    this.createdAt,
    this.reviewedAt,
    this.reportedUserNotified = false,
  }) : super._();

  @override
  final String id;
  @override
  final String reporterId;
  @override
  final String? reporterName;
  @override
  final String? reporterPhotoUrl;
  @override
  final ReportTargetType targetType;
  @override
  final String targetId;
  @override
  final String? targetName;
  @override
  final String? targetPreview;
  @override
  final String? conversationId;
  @override
  final ReportReason reason;
  @override
  final String? description;

  /// Snapshot du contenu au moment du signalement
  @override
  final ContentSnapshot? contentSnapshot;

  /// ID de la personne signalée (pour notification)
  @override
  final String? reportedUserId;
  @override
  @JsonKey()
  final ReportStatus status;
  @override
  final String? adminNote;
  @override
  final String? reviewedBy;
  @override
  final String? reviewerName;
  @override
  final String? resolution;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? reviewedAt;

  /// Indique si la personne signalée a été notifiée
  @override
  @JsonKey()
  final bool reportedUserNotified;

  @override
  String toString() {
    return 'ReportEntity(id: $id, reporterId: $reporterId, reporterName: $reporterName, reporterPhotoUrl: $reporterPhotoUrl, targetType: $targetType, targetId: $targetId, targetName: $targetName, targetPreview: $targetPreview, conversationId: $conversationId, reason: $reason, description: $description, contentSnapshot: $contentSnapshot, reportedUserId: $reportedUserId, status: $status, adminNote: $adminNote, reviewedBy: $reviewedBy, reviewerName: $reviewerName, resolution: $resolution, createdAt: $createdAt, reviewedAt: $reviewedAt, reportedUserNotified: $reportedUserNotified)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReportEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.reporterId, reporterId) ||
                other.reporterId == reporterId) &&
            (identical(other.reporterName, reporterName) ||
                other.reporterName == reporterName) &&
            (identical(other.reporterPhotoUrl, reporterPhotoUrl) ||
                other.reporterPhotoUrl == reporterPhotoUrl) &&
            (identical(other.targetType, targetType) ||
                other.targetType == targetType) &&
            (identical(other.targetId, targetId) ||
                other.targetId == targetId) &&
            (identical(other.targetName, targetName) ||
                other.targetName == targetName) &&
            (identical(other.targetPreview, targetPreview) ||
                other.targetPreview == targetPreview) &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.contentSnapshot, contentSnapshot) ||
                other.contentSnapshot == contentSnapshot) &&
            (identical(other.reportedUserId, reportedUserId) ||
                other.reportedUserId == reportedUserId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.adminNote, adminNote) ||
                other.adminNote == adminNote) &&
            (identical(other.reviewedBy, reviewedBy) ||
                other.reviewedBy == reviewedBy) &&
            (identical(other.reviewerName, reviewerName) ||
                other.reviewerName == reviewerName) &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.reportedUserNotified, reportedUserNotified) ||
                other.reportedUserNotified == reportedUserNotified));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    reporterId,
    reporterName,
    reporterPhotoUrl,
    targetType,
    targetId,
    targetName,
    targetPreview,
    conversationId,
    reason,
    description,
    contentSnapshot,
    reportedUserId,
    status,
    adminNote,
    reviewedBy,
    reviewerName,
    resolution,
    createdAt,
    reviewedAt,
    reportedUserNotified,
  ]);

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReportEntityImplCopyWith<_$ReportEntityImpl> get copyWith =>
      __$$ReportEntityImplCopyWithImpl<_$ReportEntityImpl>(this, _$identity);
}

abstract class _ReportEntity extends ReportEntity {
  const factory _ReportEntity({
    required final String id,
    required final String reporterId,
    final String? reporterName,
    final String? reporterPhotoUrl,
    required final ReportTargetType targetType,
    required final String targetId,
    final String? targetName,
    final String? targetPreview,
    final String? conversationId,
    required final ReportReason reason,
    final String? description,
    final ContentSnapshot? contentSnapshot,
    final String? reportedUserId,
    final ReportStatus status,
    final String? adminNote,
    final String? reviewedBy,
    final String? reviewerName,
    final String? resolution,
    final DateTime? createdAt,
    final DateTime? reviewedAt,
    final bool reportedUserNotified,
  }) = _$ReportEntityImpl;
  const _ReportEntity._() : super._();

  @override
  String get id;
  @override
  String get reporterId;
  @override
  String? get reporterName;
  @override
  String? get reporterPhotoUrl;
  @override
  ReportTargetType get targetType;
  @override
  String get targetId;
  @override
  String? get targetName;
  @override
  String? get targetPreview;
  @override
  String? get conversationId;
  @override
  ReportReason get reason;
  @override
  String? get description;

  /// Snapshot du contenu au moment du signalement
  @override
  ContentSnapshot? get contentSnapshot;

  /// ID de la personne signalée (pour notification)
  @override
  String? get reportedUserId;
  @override
  ReportStatus get status;
  @override
  String? get adminNote;
  @override
  String? get reviewedBy;
  @override
  String? get reviewerName;
  @override
  String? get resolution;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get reviewedAt;

  /// Indique si la personne signalée a été notifiée
  @override
  bool get reportedUserNotified;

  /// Create a copy of ReportEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReportEntityImplCopyWith<_$ReportEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
