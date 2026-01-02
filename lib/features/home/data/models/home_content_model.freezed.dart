// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_content_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

HomeContentModel _$HomeContentModelFromJson(Map<String, dynamic> json) {
  return _HomeContentModel.fromJson(json);
}

/// @nodoc
mixin _$HomeContentModel {
  HomeStatsModel get stats => throw _privateConstructorUsedError;
  List<NearbyMemberModel> get nearbyMembers =>
      throw _privateConstructorUsedError;
  List<UpcomingEventModel> get upcomingEvents =>
      throw _privateConstructorUsedError;
  List<QuickActionModel> get quickActions => throw _privateConstructorUsedError;
  String? get lastUpdated => throw _privateConstructorUsedError;

  /// Serializes this HomeContentModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HomeContentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeContentModelCopyWith<HomeContentModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeContentModelCopyWith<$Res> {
  factory $HomeContentModelCopyWith(
    HomeContentModel value,
    $Res Function(HomeContentModel) then,
  ) = _$HomeContentModelCopyWithImpl<$Res, HomeContentModel>;
  @useResult
  $Res call({
    HomeStatsModel stats,
    List<NearbyMemberModel> nearbyMembers,
    List<UpcomingEventModel> upcomingEvents,
    List<QuickActionModel> quickActions,
    String? lastUpdated,
  });

  $HomeStatsModelCopyWith<$Res> get stats;
}

/// @nodoc
class _$HomeContentModelCopyWithImpl<$Res, $Val extends HomeContentModel>
    implements $HomeContentModelCopyWith<$Res> {
  _$HomeContentModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeContentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stats = null,
    Object? nearbyMembers = null,
    Object? upcomingEvents = null,
    Object? quickActions = null,
    Object? lastUpdated = freezed,
  }) {
    return _then(
      _value.copyWith(
            stats:
                null == stats
                    ? _value.stats
                    : stats // ignore: cast_nullable_to_non_nullable
                        as HomeStatsModel,
            nearbyMembers:
                null == nearbyMembers
                    ? _value.nearbyMembers
                    : nearbyMembers // ignore: cast_nullable_to_non_nullable
                        as List<NearbyMemberModel>,
            upcomingEvents:
                null == upcomingEvents
                    ? _value.upcomingEvents
                    : upcomingEvents // ignore: cast_nullable_to_non_nullable
                        as List<UpcomingEventModel>,
            quickActions:
                null == quickActions
                    ? _value.quickActions
                    : quickActions // ignore: cast_nullable_to_non_nullable
                        as List<QuickActionModel>,
            lastUpdated:
                freezed == lastUpdated
                    ? _value.lastUpdated
                    : lastUpdated // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of HomeContentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HomeStatsModelCopyWith<$Res> get stats {
    return $HomeStatsModelCopyWith<$Res>(_value.stats, (value) {
      return _then(_value.copyWith(stats: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HomeContentModelImplCopyWith<$Res>
    implements $HomeContentModelCopyWith<$Res> {
  factory _$$HomeContentModelImplCopyWith(
    _$HomeContentModelImpl value,
    $Res Function(_$HomeContentModelImpl) then,
  ) = __$$HomeContentModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    HomeStatsModel stats,
    List<NearbyMemberModel> nearbyMembers,
    List<UpcomingEventModel> upcomingEvents,
    List<QuickActionModel> quickActions,
    String? lastUpdated,
  });

  @override
  $HomeStatsModelCopyWith<$Res> get stats;
}

/// @nodoc
class __$$HomeContentModelImplCopyWithImpl<$Res>
    extends _$HomeContentModelCopyWithImpl<$Res, _$HomeContentModelImpl>
    implements _$$HomeContentModelImplCopyWith<$Res> {
  __$$HomeContentModelImplCopyWithImpl(
    _$HomeContentModelImpl _value,
    $Res Function(_$HomeContentModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HomeContentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stats = null,
    Object? nearbyMembers = null,
    Object? upcomingEvents = null,
    Object? quickActions = null,
    Object? lastUpdated = freezed,
  }) {
    return _then(
      _$HomeContentModelImpl(
        stats:
            null == stats
                ? _value.stats
                : stats // ignore: cast_nullable_to_non_nullable
                    as HomeStatsModel,
        nearbyMembers:
            null == nearbyMembers
                ? _value._nearbyMembers
                : nearbyMembers // ignore: cast_nullable_to_non_nullable
                    as List<NearbyMemberModel>,
        upcomingEvents:
            null == upcomingEvents
                ? _value._upcomingEvents
                : upcomingEvents // ignore: cast_nullable_to_non_nullable
                    as List<UpcomingEventModel>,
        quickActions:
            null == quickActions
                ? _value._quickActions
                : quickActions // ignore: cast_nullable_to_non_nullable
                    as List<QuickActionModel>,
        lastUpdated:
            freezed == lastUpdated
                ? _value.lastUpdated
                : lastUpdated // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HomeContentModelImpl extends _HomeContentModel {
  const _$HomeContentModelImpl({
    required this.stats,
    final List<NearbyMemberModel> nearbyMembers = const [],
    final List<UpcomingEventModel> upcomingEvents = const [],
    final List<QuickActionModel> quickActions = const [],
    this.lastUpdated,
  }) : _nearbyMembers = nearbyMembers,
       _upcomingEvents = upcomingEvents,
       _quickActions = quickActions,
       super._();

  factory _$HomeContentModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$HomeContentModelImplFromJson(json);

  @override
  final HomeStatsModel stats;
  final List<NearbyMemberModel> _nearbyMembers;
  @override
  @JsonKey()
  List<NearbyMemberModel> get nearbyMembers {
    if (_nearbyMembers is EqualUnmodifiableListView) return _nearbyMembers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_nearbyMembers);
  }

  final List<UpcomingEventModel> _upcomingEvents;
  @override
  @JsonKey()
  List<UpcomingEventModel> get upcomingEvents {
    if (_upcomingEvents is EqualUnmodifiableListView) return _upcomingEvents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_upcomingEvents);
  }

  final List<QuickActionModel> _quickActions;
  @override
  @JsonKey()
  List<QuickActionModel> get quickActions {
    if (_quickActions is EqualUnmodifiableListView) return _quickActions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_quickActions);
  }

  @override
  final String? lastUpdated;

  @override
  String toString() {
    return 'HomeContentModel(stats: $stats, nearbyMembers: $nearbyMembers, upcomingEvents: $upcomingEvents, quickActions: $quickActions, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeContentModelImpl &&
            (identical(other.stats, stats) || other.stats == stats) &&
            const DeepCollectionEquality().equals(
              other._nearbyMembers,
              _nearbyMembers,
            ) &&
            const DeepCollectionEquality().equals(
              other._upcomingEvents,
              _upcomingEvents,
            ) &&
            const DeepCollectionEquality().equals(
              other._quickActions,
              _quickActions,
            ) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    stats,
    const DeepCollectionEquality().hash(_nearbyMembers),
    const DeepCollectionEquality().hash(_upcomingEvents),
    const DeepCollectionEquality().hash(_quickActions),
    lastUpdated,
  );

  /// Create a copy of HomeContentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeContentModelImplCopyWith<_$HomeContentModelImpl> get copyWith =>
      __$$HomeContentModelImplCopyWithImpl<_$HomeContentModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$HomeContentModelImplToJson(this);
  }
}

abstract class _HomeContentModel extends HomeContentModel {
  const factory _HomeContentModel({
    required final HomeStatsModel stats,
    final List<NearbyMemberModel> nearbyMembers,
    final List<UpcomingEventModel> upcomingEvents,
    final List<QuickActionModel> quickActions,
    final String? lastUpdated,
  }) = _$HomeContentModelImpl;
  const _HomeContentModel._() : super._();

  factory _HomeContentModel.fromJson(Map<String, dynamic> json) =
      _$HomeContentModelImpl.fromJson;

  @override
  HomeStatsModel get stats;
  @override
  List<NearbyMemberModel> get nearbyMembers;
  @override
  List<UpcomingEventModel> get upcomingEvents;
  @override
  List<QuickActionModel> get quickActions;
  @override
  String? get lastUpdated;

  /// Create a copy of HomeContentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeContentModelImplCopyWith<_$HomeContentModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HomeStatsModel _$HomeStatsModelFromJson(Map<String, dynamic> json) {
  return _HomeStatsModel.fromJson(json);
}

/// @nodoc
mixin _$HomeStatsModel {
  int get totalMembers => throw _privateConstructorUsedError;
  int get nearbyMembersCount => throw _privateConstructorUsedError;
  int get upcomingEventsCount => throw _privateConstructorUsedError;
  int get groupsCount => throw _privateConstructorUsedError;
  int get unreadMessages => throw _privateConstructorUsedError;
  int get pendingFriendRequests => throw _privateConstructorUsedError;

  /// Serializes this HomeStatsModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HomeStatsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeStatsModelCopyWith<HomeStatsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeStatsModelCopyWith<$Res> {
  factory $HomeStatsModelCopyWith(
    HomeStatsModel value,
    $Res Function(HomeStatsModel) then,
  ) = _$HomeStatsModelCopyWithImpl<$Res, HomeStatsModel>;
  @useResult
  $Res call({
    int totalMembers,
    int nearbyMembersCount,
    int upcomingEventsCount,
    int groupsCount,
    int unreadMessages,
    int pendingFriendRequests,
  });
}

/// @nodoc
class _$HomeStatsModelCopyWithImpl<$Res, $Val extends HomeStatsModel>
    implements $HomeStatsModelCopyWith<$Res> {
  _$HomeStatsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeStatsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalMembers = null,
    Object? nearbyMembersCount = null,
    Object? upcomingEventsCount = null,
    Object? groupsCount = null,
    Object? unreadMessages = null,
    Object? pendingFriendRequests = null,
  }) {
    return _then(
      _value.copyWith(
            totalMembers:
                null == totalMembers
                    ? _value.totalMembers
                    : totalMembers // ignore: cast_nullable_to_non_nullable
                        as int,
            nearbyMembersCount:
                null == nearbyMembersCount
                    ? _value.nearbyMembersCount
                    : nearbyMembersCount // ignore: cast_nullable_to_non_nullable
                        as int,
            upcomingEventsCount:
                null == upcomingEventsCount
                    ? _value.upcomingEventsCount
                    : upcomingEventsCount // ignore: cast_nullable_to_non_nullable
                        as int,
            groupsCount:
                null == groupsCount
                    ? _value.groupsCount
                    : groupsCount // ignore: cast_nullable_to_non_nullable
                        as int,
            unreadMessages:
                null == unreadMessages
                    ? _value.unreadMessages
                    : unreadMessages // ignore: cast_nullable_to_non_nullable
                        as int,
            pendingFriendRequests:
                null == pendingFriendRequests
                    ? _value.pendingFriendRequests
                    : pendingFriendRequests // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HomeStatsModelImplCopyWith<$Res>
    implements $HomeStatsModelCopyWith<$Res> {
  factory _$$HomeStatsModelImplCopyWith(
    _$HomeStatsModelImpl value,
    $Res Function(_$HomeStatsModelImpl) then,
  ) = __$$HomeStatsModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int totalMembers,
    int nearbyMembersCount,
    int upcomingEventsCount,
    int groupsCount,
    int unreadMessages,
    int pendingFriendRequests,
  });
}

/// @nodoc
class __$$HomeStatsModelImplCopyWithImpl<$Res>
    extends _$HomeStatsModelCopyWithImpl<$Res, _$HomeStatsModelImpl>
    implements _$$HomeStatsModelImplCopyWith<$Res> {
  __$$HomeStatsModelImplCopyWithImpl(
    _$HomeStatsModelImpl _value,
    $Res Function(_$HomeStatsModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HomeStatsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalMembers = null,
    Object? nearbyMembersCount = null,
    Object? upcomingEventsCount = null,
    Object? groupsCount = null,
    Object? unreadMessages = null,
    Object? pendingFriendRequests = null,
  }) {
    return _then(
      _$HomeStatsModelImpl(
        totalMembers:
            null == totalMembers
                ? _value.totalMembers
                : totalMembers // ignore: cast_nullable_to_non_nullable
                    as int,
        nearbyMembersCount:
            null == nearbyMembersCount
                ? _value.nearbyMembersCount
                : nearbyMembersCount // ignore: cast_nullable_to_non_nullable
                    as int,
        upcomingEventsCount:
            null == upcomingEventsCount
                ? _value.upcomingEventsCount
                : upcomingEventsCount // ignore: cast_nullable_to_non_nullable
                    as int,
        groupsCount:
            null == groupsCount
                ? _value.groupsCount
                : groupsCount // ignore: cast_nullable_to_non_nullable
                    as int,
        unreadMessages:
            null == unreadMessages
                ? _value.unreadMessages
                : unreadMessages // ignore: cast_nullable_to_non_nullable
                    as int,
        pendingFriendRequests:
            null == pendingFriendRequests
                ? _value.pendingFriendRequests
                : pendingFriendRequests // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HomeStatsModelImpl extends _HomeStatsModel {
  const _$HomeStatsModelImpl({
    this.totalMembers = 0,
    this.nearbyMembersCount = 0,
    this.upcomingEventsCount = 0,
    this.groupsCount = 0,
    this.unreadMessages = 0,
    this.pendingFriendRequests = 0,
  }) : super._();

  factory _$HomeStatsModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$HomeStatsModelImplFromJson(json);

  @override
  @JsonKey()
  final int totalMembers;
  @override
  @JsonKey()
  final int nearbyMembersCount;
  @override
  @JsonKey()
  final int upcomingEventsCount;
  @override
  @JsonKey()
  final int groupsCount;
  @override
  @JsonKey()
  final int unreadMessages;
  @override
  @JsonKey()
  final int pendingFriendRequests;

  @override
  String toString() {
    return 'HomeStatsModel(totalMembers: $totalMembers, nearbyMembersCount: $nearbyMembersCount, upcomingEventsCount: $upcomingEventsCount, groupsCount: $groupsCount, unreadMessages: $unreadMessages, pendingFriendRequests: $pendingFriendRequests)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeStatsModelImpl &&
            (identical(other.totalMembers, totalMembers) ||
                other.totalMembers == totalMembers) &&
            (identical(other.nearbyMembersCount, nearbyMembersCount) ||
                other.nearbyMembersCount == nearbyMembersCount) &&
            (identical(other.upcomingEventsCount, upcomingEventsCount) ||
                other.upcomingEventsCount == upcomingEventsCount) &&
            (identical(other.groupsCount, groupsCount) ||
                other.groupsCount == groupsCount) &&
            (identical(other.unreadMessages, unreadMessages) ||
                other.unreadMessages == unreadMessages) &&
            (identical(other.pendingFriendRequests, pendingFriendRequests) ||
                other.pendingFriendRequests == pendingFriendRequests));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalMembers,
    nearbyMembersCount,
    upcomingEventsCount,
    groupsCount,
    unreadMessages,
    pendingFriendRequests,
  );

  /// Create a copy of HomeStatsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeStatsModelImplCopyWith<_$HomeStatsModelImpl> get copyWith =>
      __$$HomeStatsModelImplCopyWithImpl<_$HomeStatsModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$HomeStatsModelImplToJson(this);
  }
}

abstract class _HomeStatsModel extends HomeStatsModel {
  const factory _HomeStatsModel({
    final int totalMembers,
    final int nearbyMembersCount,
    final int upcomingEventsCount,
    final int groupsCount,
    final int unreadMessages,
    final int pendingFriendRequests,
  }) = _$HomeStatsModelImpl;
  const _HomeStatsModel._() : super._();

  factory _HomeStatsModel.fromJson(Map<String, dynamic> json) =
      _$HomeStatsModelImpl.fromJson;

  @override
  int get totalMembers;
  @override
  int get nearbyMembersCount;
  @override
  int get upcomingEventsCount;
  @override
  int get groupsCount;
  @override
  int get unreadMessages;
  @override
  int get pendingFriendRequests;

  /// Create a copy of HomeStatsModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeStatsModelImplCopyWith<_$HomeStatsModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NearbyMemberModel _$NearbyMemberModelFromJson(Map<String, dynamic> json) {
  return _NearbyMemberModel.fromJson(json);
}

/// @nodoc
mixin _$NearbyMemberModel {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  double? get distanceKm => throw _privateConstructorUsedError;
  String? get lastSeen => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;

  /// Serializes this NearbyMemberModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NearbyMemberModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NearbyMemberModelCopyWith<NearbyMemberModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NearbyMemberModelCopyWith<$Res> {
  factory $NearbyMemberModelCopyWith(
    NearbyMemberModel value,
    $Res Function(NearbyMemberModel) then,
  ) = _$NearbyMemberModelCopyWithImpl<$Res, NearbyMemberModel>;
  @useResult
  $Res call({
    String id,
    String displayName,
    String? photoUrl,
    String? city,
    String? country,
    double? distanceKm,
    String? lastSeen,
    bool isOnline,
  });
}

/// @nodoc
class _$NearbyMemberModelCopyWithImpl<$Res, $Val extends NearbyMemberModel>
    implements $NearbyMemberModelCopyWith<$Res> {
  _$NearbyMemberModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NearbyMemberModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? photoUrl = freezed,
    Object? city = freezed,
    Object? country = freezed,
    Object? distanceKm = freezed,
    Object? lastSeen = freezed,
    Object? isOnline = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            displayName:
                null == displayName
                    ? _value.displayName
                    : displayName // ignore: cast_nullable_to_non_nullable
                        as String,
            photoUrl:
                freezed == photoUrl
                    ? _value.photoUrl
                    : photoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            city:
                freezed == city
                    ? _value.city
                    : city // ignore: cast_nullable_to_non_nullable
                        as String?,
            country:
                freezed == country
                    ? _value.country
                    : country // ignore: cast_nullable_to_non_nullable
                        as String?,
            distanceKm:
                freezed == distanceKm
                    ? _value.distanceKm
                    : distanceKm // ignore: cast_nullable_to_non_nullable
                        as double?,
            lastSeen:
                freezed == lastSeen
                    ? _value.lastSeen
                    : lastSeen // ignore: cast_nullable_to_non_nullable
                        as String?,
            isOnline:
                null == isOnline
                    ? _value.isOnline
                    : isOnline // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NearbyMemberModelImplCopyWith<$Res>
    implements $NearbyMemberModelCopyWith<$Res> {
  factory _$$NearbyMemberModelImplCopyWith(
    _$NearbyMemberModelImpl value,
    $Res Function(_$NearbyMemberModelImpl) then,
  ) = __$$NearbyMemberModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String? photoUrl,
    String? city,
    String? country,
    double? distanceKm,
    String? lastSeen,
    bool isOnline,
  });
}

/// @nodoc
class __$$NearbyMemberModelImplCopyWithImpl<$Res>
    extends _$NearbyMemberModelCopyWithImpl<$Res, _$NearbyMemberModelImpl>
    implements _$$NearbyMemberModelImplCopyWith<$Res> {
  __$$NearbyMemberModelImplCopyWithImpl(
    _$NearbyMemberModelImpl _value,
    $Res Function(_$NearbyMemberModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NearbyMemberModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? photoUrl = freezed,
    Object? city = freezed,
    Object? country = freezed,
    Object? distanceKm = freezed,
    Object? lastSeen = freezed,
    Object? isOnline = null,
  }) {
    return _then(
      _$NearbyMemberModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        displayName:
            null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                    as String,
        photoUrl:
            freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        city:
            freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                    as String?,
        country:
            freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                    as String?,
        distanceKm:
            freezed == distanceKm
                ? _value.distanceKm
                : distanceKm // ignore: cast_nullable_to_non_nullable
                    as double?,
        lastSeen:
            freezed == lastSeen
                ? _value.lastSeen
                : lastSeen // ignore: cast_nullable_to_non_nullable
                    as String?,
        isOnline:
            null == isOnline
                ? _value.isOnline
                : isOnline // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NearbyMemberModelImpl extends _NearbyMemberModel {
  const _$NearbyMemberModelImpl({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.city,
    this.country,
    this.distanceKm,
    this.lastSeen,
    this.isOnline = false,
  }) : super._();

  factory _$NearbyMemberModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$NearbyMemberModelImplFromJson(json);

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String? photoUrl;
  @override
  final String? city;
  @override
  final String? country;
  @override
  final double? distanceKm;
  @override
  final String? lastSeen;
  @override
  @JsonKey()
  final bool isOnline;

  @override
  String toString() {
    return 'NearbyMemberModel(id: $id, displayName: $displayName, photoUrl: $photoUrl, city: $city, country: $country, distanceKm: $distanceKm, lastSeen: $lastSeen, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NearbyMemberModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.distanceKm, distanceKm) ||
                other.distanceKm == distanceKm) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    displayName,
    photoUrl,
    city,
    country,
    distanceKm,
    lastSeen,
    isOnline,
  );

  /// Create a copy of NearbyMemberModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NearbyMemberModelImplCopyWith<_$NearbyMemberModelImpl> get copyWith =>
      __$$NearbyMemberModelImplCopyWithImpl<_$NearbyMemberModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NearbyMemberModelImplToJson(this);
  }
}

abstract class _NearbyMemberModel extends NearbyMemberModel {
  const factory _NearbyMemberModel({
    required final String id,
    required final String displayName,
    final String? photoUrl,
    final String? city,
    final String? country,
    final double? distanceKm,
    final String? lastSeen,
    final bool isOnline,
  }) = _$NearbyMemberModelImpl;
  const _NearbyMemberModel._() : super._();

  factory _NearbyMemberModel.fromJson(Map<String, dynamic> json) =
      _$NearbyMemberModelImpl.fromJson;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String? get photoUrl;
  @override
  String? get city;
  @override
  String? get country;
  @override
  double? get distanceKm;
  @override
  String? get lastSeen;
  @override
  bool get isOnline;

  /// Create a copy of NearbyMemberModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NearbyMemberModelImplCopyWith<_$NearbyMemberModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UpcomingEventModel _$UpcomingEventModelFromJson(Map<String, dynamic> json) {
  return _UpcomingEventModel.fromJson(json);
}

/// @nodoc
mixin _$UpcomingEventModel {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get startDate => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  int get attendeesCount => throw _privateConstructorUsedError;
  bool get isAttending => throw _privateConstructorUsedError;

  /// Serializes this UpcomingEventModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UpcomingEventModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UpcomingEventModelCopyWith<UpcomingEventModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpcomingEventModelCopyWith<$Res> {
  factory $UpcomingEventModelCopyWith(
    UpcomingEventModel value,
    $Res Function(UpcomingEventModel) then,
  ) = _$UpcomingEventModelCopyWithImpl<$Res, UpcomingEventModel>;
  @useResult
  $Res call({
    String id,
    String title,
    String startDate,
    String? imageUrl,
    String? location,
    int attendeesCount,
    bool isAttending,
  });
}

/// @nodoc
class _$UpcomingEventModelCopyWithImpl<$Res, $Val extends UpcomingEventModel>
    implements $UpcomingEventModelCopyWith<$Res> {
  _$UpcomingEventModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UpcomingEventModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? startDate = null,
    Object? imageUrl = freezed,
    Object? location = freezed,
    Object? attendeesCount = null,
    Object? isAttending = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            startDate:
                null == startDate
                    ? _value.startDate
                    : startDate // ignore: cast_nullable_to_non_nullable
                        as String,
            imageUrl:
                freezed == imageUrl
                    ? _value.imageUrl
                    : imageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            location:
                freezed == location
                    ? _value.location
                    : location // ignore: cast_nullable_to_non_nullable
                        as String?,
            attendeesCount:
                null == attendeesCount
                    ? _value.attendeesCount
                    : attendeesCount // ignore: cast_nullable_to_non_nullable
                        as int,
            isAttending:
                null == isAttending
                    ? _value.isAttending
                    : isAttending // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UpcomingEventModelImplCopyWith<$Res>
    implements $UpcomingEventModelCopyWith<$Res> {
  factory _$$UpcomingEventModelImplCopyWith(
    _$UpcomingEventModelImpl value,
    $Res Function(_$UpcomingEventModelImpl) then,
  ) = __$$UpcomingEventModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String startDate,
    String? imageUrl,
    String? location,
    int attendeesCount,
    bool isAttending,
  });
}

/// @nodoc
class __$$UpcomingEventModelImplCopyWithImpl<$Res>
    extends _$UpcomingEventModelCopyWithImpl<$Res, _$UpcomingEventModelImpl>
    implements _$$UpcomingEventModelImplCopyWith<$Res> {
  __$$UpcomingEventModelImplCopyWithImpl(
    _$UpcomingEventModelImpl _value,
    $Res Function(_$UpcomingEventModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UpcomingEventModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? startDate = null,
    Object? imageUrl = freezed,
    Object? location = freezed,
    Object? attendeesCount = null,
    Object? isAttending = null,
  }) {
    return _then(
      _$UpcomingEventModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        startDate:
            null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                    as String,
        imageUrl:
            freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        location:
            freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                    as String?,
        attendeesCount:
            null == attendeesCount
                ? _value.attendeesCount
                : attendeesCount // ignore: cast_nullable_to_non_nullable
                    as int,
        isAttending:
            null == isAttending
                ? _value.isAttending
                : isAttending // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UpcomingEventModelImpl extends _UpcomingEventModel {
  const _$UpcomingEventModelImpl({
    required this.id,
    required this.title,
    required this.startDate,
    this.imageUrl,
    this.location,
    this.attendeesCount = 0,
    this.isAttending = false,
  }) : super._();

  factory _$UpcomingEventModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UpcomingEventModelImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String startDate;
  @override
  final String? imageUrl;
  @override
  final String? location;
  @override
  @JsonKey()
  final int attendeesCount;
  @override
  @JsonKey()
  final bool isAttending;

  @override
  String toString() {
    return 'UpcomingEventModel(id: $id, title: $title, startDate: $startDate, imageUrl: $imageUrl, location: $location, attendeesCount: $attendeesCount, isAttending: $isAttending)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpcomingEventModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.attendeesCount, attendeesCount) ||
                other.attendeesCount == attendeesCount) &&
            (identical(other.isAttending, isAttending) ||
                other.isAttending == isAttending));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    startDate,
    imageUrl,
    location,
    attendeesCount,
    isAttending,
  );

  /// Create a copy of UpcomingEventModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UpcomingEventModelImplCopyWith<_$UpcomingEventModelImpl> get copyWith =>
      __$$UpcomingEventModelImplCopyWithImpl<_$UpcomingEventModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$UpcomingEventModelImplToJson(this);
  }
}

abstract class _UpcomingEventModel extends UpcomingEventModel {
  const factory _UpcomingEventModel({
    required final String id,
    required final String title,
    required final String startDate,
    final String? imageUrl,
    final String? location,
    final int attendeesCount,
    final bool isAttending,
  }) = _$UpcomingEventModelImpl;
  const _UpcomingEventModel._() : super._();

  factory _UpcomingEventModel.fromJson(Map<String, dynamic> json) =
      _$UpcomingEventModelImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get startDate;
  @override
  String? get imageUrl;
  @override
  String? get location;
  @override
  int get attendeesCount;
  @override
  bool get isAttending;

  /// Create a copy of UpcomingEventModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UpcomingEventModelImplCopyWith<_$UpcomingEventModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

QuickActionModel _$QuickActionModelFromJson(Map<String, dynamic> json) {
  return _QuickActionModel.fromJson(json);
}

/// @nodoc
mixin _$QuickActionModel {
  String get id => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get route => throw _privateConstructorUsedError;
  int get badgeCount => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;

  /// Serializes this QuickActionModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuickActionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuickActionModelCopyWith<QuickActionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuickActionModelCopyWith<$Res> {
  factory $QuickActionModelCopyWith(
    QuickActionModel value,
    $Res Function(QuickActionModel) then,
  ) = _$QuickActionModelCopyWithImpl<$Res, QuickActionModel>;
  @useResult
  $Res call({
    String id,
    String label,
    String icon,
    String route,
    int badgeCount,
    bool isEnabled,
  });
}

/// @nodoc
class _$QuickActionModelCopyWithImpl<$Res, $Val extends QuickActionModel>
    implements $QuickActionModelCopyWith<$Res> {
  _$QuickActionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuickActionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? icon = null,
    Object? route = null,
    Object? badgeCount = null,
    Object? isEnabled = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            label:
                null == label
                    ? _value.label
                    : label // ignore: cast_nullable_to_non_nullable
                        as String,
            icon:
                null == icon
                    ? _value.icon
                    : icon // ignore: cast_nullable_to_non_nullable
                        as String,
            route:
                null == route
                    ? _value.route
                    : route // ignore: cast_nullable_to_non_nullable
                        as String,
            badgeCount:
                null == badgeCount
                    ? _value.badgeCount
                    : badgeCount // ignore: cast_nullable_to_non_nullable
                        as int,
            isEnabled:
                null == isEnabled
                    ? _value.isEnabled
                    : isEnabled // ignore: cast_nullable_to_non_nullable
                        as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QuickActionModelImplCopyWith<$Res>
    implements $QuickActionModelCopyWith<$Res> {
  factory _$$QuickActionModelImplCopyWith(
    _$QuickActionModelImpl value,
    $Res Function(_$QuickActionModelImpl) then,
  ) = __$$QuickActionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String label,
    String icon,
    String route,
    int badgeCount,
    bool isEnabled,
  });
}

/// @nodoc
class __$$QuickActionModelImplCopyWithImpl<$Res>
    extends _$QuickActionModelCopyWithImpl<$Res, _$QuickActionModelImpl>
    implements _$$QuickActionModelImplCopyWith<$Res> {
  __$$QuickActionModelImplCopyWithImpl(
    _$QuickActionModelImpl _value,
    $Res Function(_$QuickActionModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuickActionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? icon = null,
    Object? route = null,
    Object? badgeCount = null,
    Object? isEnabled = null,
  }) {
    return _then(
      _$QuickActionModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        label:
            null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                    as String,
        icon:
            null == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                    as String,
        route:
            null == route
                ? _value.route
                : route // ignore: cast_nullable_to_non_nullable
                    as String,
        badgeCount:
            null == badgeCount
                ? _value.badgeCount
                : badgeCount // ignore: cast_nullable_to_non_nullable
                    as int,
        isEnabled:
            null == isEnabled
                ? _value.isEnabled
                : isEnabled // ignore: cast_nullable_to_non_nullable
                    as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$QuickActionModelImpl extends _QuickActionModel {
  const _$QuickActionModelImpl({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    this.badgeCount = 0,
    this.isEnabled = true,
  }) : super._();

  factory _$QuickActionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuickActionModelImplFromJson(json);

  @override
  final String id;
  @override
  final String label;
  @override
  final String icon;
  @override
  final String route;
  @override
  @JsonKey()
  final int badgeCount;
  @override
  @JsonKey()
  final bool isEnabled;

  @override
  String toString() {
    return 'QuickActionModel(id: $id, label: $label, icon: $icon, route: $route, badgeCount: $badgeCount, isEnabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuickActionModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.route, route) || other.route == route) &&
            (identical(other.badgeCount, badgeCount) ||
                other.badgeCount == badgeCount) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, label, icon, route, badgeCount, isEnabled);

  /// Create a copy of QuickActionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuickActionModelImplCopyWith<_$QuickActionModelImpl> get copyWith =>
      __$$QuickActionModelImplCopyWithImpl<_$QuickActionModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$QuickActionModelImplToJson(this);
  }
}

abstract class _QuickActionModel extends QuickActionModel {
  const factory _QuickActionModel({
    required final String id,
    required final String label,
    required final String icon,
    required final String route,
    final int badgeCount,
    final bool isEnabled,
  }) = _$QuickActionModelImpl;
  const _QuickActionModel._() : super._();

  factory _QuickActionModel.fromJson(Map<String, dynamic> json) =
      _$QuickActionModelImpl.fromJson;

  @override
  String get id;
  @override
  String get label;
  @override
  String get icon;
  @override
  String get route;
  @override
  int get badgeCount;
  @override
  bool get isEnabled;

  /// Create a copy of QuickActionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuickActionModelImplCopyWith<_$QuickActionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
