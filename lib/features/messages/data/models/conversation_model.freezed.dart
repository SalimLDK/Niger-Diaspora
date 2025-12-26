// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ConversationModel _$ConversationModelFromJson(Map<String, dynamic> json) {
  return _ConversationModel.fromJson(json);
}

/// @nodoc
mixin _$ConversationModel {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get groupId =>
      throw _privateConstructorUsedError; // Add groupId for group conversations
  List<String> get participantIds => throw _privateConstructorUsedError;
  List<String> get adminIds => throw _privateConstructorUsedError;
  List<String> get reportedBy => throw _privateConstructorUsedError;
  String? get lastMessage => throw _privateConstructorUsedError;
  String? get lastMessageSenderId => throw _privateConstructorUsedError;
  MessageStatus get lastMessageStatus => throw _privateConstructorUsedError;
  DateTime? get lastMessageAt => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String get createdBy => throw _privateConstructorUsedError;
  Map<String, dynamic> get unreadCount => throw _privateConstructorUsedError;
  Map<String, dynamic> get mutedBy => throw _privateConstructorUsedError;
  Map<String, dynamic> get archivedBy => throw _privateConstructorUsedError;

  /// Serializes this ConversationModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversationModelCopyWith<ConversationModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationModelCopyWith<$Res> {
  factory $ConversationModelCopyWith(
    ConversationModel value,
    $Res Function(ConversationModel) then,
  ) = _$ConversationModelCopyWithImpl<$Res, ConversationModel>;
  @useResult
  $Res call({
    String id,
    String type,
    String? name,
    String? imageUrl,
    String? groupId,
    List<String> participantIds,
    List<String> adminIds,
    List<String> reportedBy,
    String? lastMessage,
    String? lastMessageSenderId,
    MessageStatus lastMessageStatus,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    String createdBy,
    Map<String, dynamic> unreadCount,
    Map<String, dynamic> mutedBy,
    Map<String, dynamic> archivedBy,
  });
}

/// @nodoc
class _$ConversationModelCopyWithImpl<$Res, $Val extends ConversationModel>
    implements $ConversationModelCopyWith<$Res> {
  _$ConversationModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = freezed,
    Object? imageUrl = freezed,
    Object? groupId = freezed,
    Object? participantIds = null,
    Object? adminIds = null,
    Object? reportedBy = null,
    Object? lastMessage = freezed,
    Object? lastMessageSenderId = freezed,
    Object? lastMessageStatus = null,
    Object? lastMessageAt = freezed,
    Object? createdAt = freezed,
    Object? createdBy = null,
    Object? unreadCount = null,
    Object? mutedBy = null,
    Object? archivedBy = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                freezed == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String?,
            imageUrl:
                freezed == imageUrl
                    ? _value.imageUrl
                    : imageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            groupId:
                freezed == groupId
                    ? _value.groupId
                    : groupId // ignore: cast_nullable_to_non_nullable
                        as String?,
            participantIds:
                null == participantIds
                    ? _value.participantIds
                    : participantIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            adminIds:
                null == adminIds
                    ? _value.adminIds
                    : adminIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            reportedBy:
                null == reportedBy
                    ? _value.reportedBy
                    : reportedBy // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            lastMessage:
                freezed == lastMessage
                    ? _value.lastMessage
                    : lastMessage // ignore: cast_nullable_to_non_nullable
                        as String?,
            lastMessageSenderId:
                freezed == lastMessageSenderId
                    ? _value.lastMessageSenderId
                    : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
                        as String?,
            lastMessageStatus:
                null == lastMessageStatus
                    ? _value.lastMessageStatus
                    : lastMessageStatus // ignore: cast_nullable_to_non_nullable
                        as MessageStatus,
            lastMessageAt:
                freezed == lastMessageAt
                    ? _value.lastMessageAt
                    : lastMessageAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            createdBy:
                null == createdBy
                    ? _value.createdBy
                    : createdBy // ignore: cast_nullable_to_non_nullable
                        as String,
            unreadCount:
                null == unreadCount
                    ? _value.unreadCount
                    : unreadCount // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
            mutedBy:
                null == mutedBy
                    ? _value.mutedBy
                    : mutedBy // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
            archivedBy:
                null == archivedBy
                    ? _value.archivedBy
                    : archivedBy // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConversationModelImplCopyWith<$Res>
    implements $ConversationModelCopyWith<$Res> {
  factory _$$ConversationModelImplCopyWith(
    _$ConversationModelImpl value,
    $Res Function(_$ConversationModelImpl) then,
  ) = __$$ConversationModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String type,
    String? name,
    String? imageUrl,
    String? groupId,
    List<String> participantIds,
    List<String> adminIds,
    List<String> reportedBy,
    String? lastMessage,
    String? lastMessageSenderId,
    MessageStatus lastMessageStatus,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    String createdBy,
    Map<String, dynamic> unreadCount,
    Map<String, dynamic> mutedBy,
    Map<String, dynamic> archivedBy,
  });
}

/// @nodoc
class __$$ConversationModelImplCopyWithImpl<$Res>
    extends _$ConversationModelCopyWithImpl<$Res, _$ConversationModelImpl>
    implements _$$ConversationModelImplCopyWith<$Res> {
  __$$ConversationModelImplCopyWithImpl(
    _$ConversationModelImpl _value,
    $Res Function(_$ConversationModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = freezed,
    Object? imageUrl = freezed,
    Object? groupId = freezed,
    Object? participantIds = null,
    Object? adminIds = null,
    Object? reportedBy = null,
    Object? lastMessage = freezed,
    Object? lastMessageSenderId = freezed,
    Object? lastMessageStatus = null,
    Object? lastMessageAt = freezed,
    Object? createdAt = freezed,
    Object? createdBy = null,
    Object? unreadCount = null,
    Object? mutedBy = null,
    Object? archivedBy = null,
  }) {
    return _then(
      _$ConversationModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String?,
        imageUrl:
            freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        groupId:
            freezed == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                    as String?,
        participantIds:
            null == participantIds
                ? _value._participantIds
                : participantIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        adminIds:
            null == adminIds
                ? _value._adminIds
                : adminIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        reportedBy:
            null == reportedBy
                ? _value._reportedBy
                : reportedBy // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        lastMessage:
            freezed == lastMessage
                ? _value.lastMessage
                : lastMessage // ignore: cast_nullable_to_non_nullable
                    as String?,
        lastMessageSenderId:
            freezed == lastMessageSenderId
                ? _value.lastMessageSenderId
                : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
                    as String?,
        lastMessageStatus:
            null == lastMessageStatus
                ? _value.lastMessageStatus
                : lastMessageStatus // ignore: cast_nullable_to_non_nullable
                    as MessageStatus,
        lastMessageAt:
            freezed == lastMessageAt
                ? _value.lastMessageAt
                : lastMessageAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        createdBy:
            null == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                    as String,
        unreadCount:
            null == unreadCount
                ? _value._unreadCount
                : unreadCount // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
        mutedBy:
            null == mutedBy
                ? _value._mutedBy
                : mutedBy // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
        archivedBy:
            null == archivedBy
                ? _value._archivedBy
                : archivedBy // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConversationModelImpl extends _ConversationModel {
  const _$ConversationModelImpl({
    required this.id,
    this.type = 'individual',
    this.name,
    this.imageUrl,
    this.groupId,
    final List<String> participantIds = const [],
    final List<String> adminIds = const [],
    final List<String> reportedBy = const [],
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageStatus = MessageStatus.sent,
    this.lastMessageAt,
    this.createdAt,
    required this.createdBy,
    final Map<String, dynamic> unreadCount = const {},
    final Map<String, dynamic> mutedBy = const {},
    final Map<String, dynamic> archivedBy = const {},
  }) : _participantIds = participantIds,
       _adminIds = adminIds,
       _reportedBy = reportedBy,
       _unreadCount = unreadCount,
       _mutedBy = mutedBy,
       _archivedBy = archivedBy,
       super._();

  factory _$ConversationModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConversationModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final String type;
  @override
  final String? name;
  @override
  final String? imageUrl;
  @override
  final String? groupId;
  // Add groupId for group conversations
  final List<String> _participantIds;
  // Add groupId for group conversations
  @override
  @JsonKey()
  List<String> get participantIds {
    if (_participantIds is EqualUnmodifiableListView) return _participantIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participantIds);
  }

  final List<String> _adminIds;
  @override
  @JsonKey()
  List<String> get adminIds {
    if (_adminIds is EqualUnmodifiableListView) return _adminIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_adminIds);
  }

  final List<String> _reportedBy;
  @override
  @JsonKey()
  List<String> get reportedBy {
    if (_reportedBy is EqualUnmodifiableListView) return _reportedBy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_reportedBy);
  }

  @override
  final String? lastMessage;
  @override
  final String? lastMessageSenderId;
  @override
  @JsonKey()
  final MessageStatus lastMessageStatus;
  @override
  final DateTime? lastMessageAt;
  @override
  final DateTime? createdAt;
  @override
  final String createdBy;
  final Map<String, dynamic> _unreadCount;
  @override
  @JsonKey()
  Map<String, dynamic> get unreadCount {
    if (_unreadCount is EqualUnmodifiableMapView) return _unreadCount;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_unreadCount);
  }

  final Map<String, dynamic> _mutedBy;
  @override
  @JsonKey()
  Map<String, dynamic> get mutedBy {
    if (_mutedBy is EqualUnmodifiableMapView) return _mutedBy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_mutedBy);
  }

  final Map<String, dynamic> _archivedBy;
  @override
  @JsonKey()
  Map<String, dynamic> get archivedBy {
    if (_archivedBy is EqualUnmodifiableMapView) return _archivedBy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_archivedBy);
  }

  @override
  String toString() {
    return 'ConversationModel(id: $id, type: $type, name: $name, imageUrl: $imageUrl, groupId: $groupId, participantIds: $participantIds, adminIds: $adminIds, reportedBy: $reportedBy, lastMessage: $lastMessage, lastMessageSenderId: $lastMessageSenderId, lastMessageStatus: $lastMessageStatus, lastMessageAt: $lastMessageAt, createdAt: $createdAt, createdBy: $createdBy, unreadCount: $unreadCount, mutedBy: $mutedBy, archivedBy: $archivedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            const DeepCollectionEquality().equals(
              other._participantIds,
              _participantIds,
            ) &&
            const DeepCollectionEquality().equals(other._adminIds, _adminIds) &&
            const DeepCollectionEquality().equals(
              other._reportedBy,
              _reportedBy,
            ) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            (identical(other.lastMessageSenderId, lastMessageSenderId) ||
                other.lastMessageSenderId == lastMessageSenderId) &&
            (identical(other.lastMessageStatus, lastMessageStatus) ||
                other.lastMessageStatus == lastMessageStatus) &&
            (identical(other.lastMessageAt, lastMessageAt) ||
                other.lastMessageAt == lastMessageAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            const DeepCollectionEquality().equals(
              other._unreadCount,
              _unreadCount,
            ) &&
            const DeepCollectionEquality().equals(other._mutedBy, _mutedBy) &&
            const DeepCollectionEquality().equals(
              other._archivedBy,
              _archivedBy,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    name,
    imageUrl,
    groupId,
    const DeepCollectionEquality().hash(_participantIds),
    const DeepCollectionEquality().hash(_adminIds),
    const DeepCollectionEquality().hash(_reportedBy),
    lastMessage,
    lastMessageSenderId,
    lastMessageStatus,
    lastMessageAt,
    createdAt,
    createdBy,
    const DeepCollectionEquality().hash(_unreadCount),
    const DeepCollectionEquality().hash(_mutedBy),
    const DeepCollectionEquality().hash(_archivedBy),
  );

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationModelImplCopyWith<_$ConversationModelImpl> get copyWith =>
      __$$ConversationModelImplCopyWithImpl<_$ConversationModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ConversationModelImplToJson(this);
  }
}

abstract class _ConversationModel extends ConversationModel {
  const factory _ConversationModel({
    required final String id,
    final String type,
    final String? name,
    final String? imageUrl,
    final String? groupId,
    final List<String> participantIds,
    final List<String> adminIds,
    final List<String> reportedBy,
    final String? lastMessage,
    final String? lastMessageSenderId,
    final MessageStatus lastMessageStatus,
    final DateTime? lastMessageAt,
    final DateTime? createdAt,
    required final String createdBy,
    final Map<String, dynamic> unreadCount,
    final Map<String, dynamic> mutedBy,
    final Map<String, dynamic> archivedBy,
  }) = _$ConversationModelImpl;
  const _ConversationModel._() : super._();

  factory _ConversationModel.fromJson(Map<String, dynamic> json) =
      _$ConversationModelImpl.fromJson;

  @override
  String get id;
  @override
  String get type;
  @override
  String? get name;
  @override
  String? get imageUrl;
  @override
  String? get groupId; // Add groupId for group conversations
  @override
  List<String> get participantIds;
  @override
  List<String> get adminIds;
  @override
  List<String> get reportedBy;
  @override
  String? get lastMessage;
  @override
  String? get lastMessageSenderId;
  @override
  MessageStatus get lastMessageStatus;
  @override
  DateTime? get lastMessageAt;
  @override
  DateTime? get createdAt;
  @override
  String get createdBy;
  @override
  Map<String, dynamic> get unreadCount;
  @override
  Map<String, dynamic> get mutedBy;
  @override
  Map<String, dynamic> get archivedBy;

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationModelImplCopyWith<_$ConversationModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
