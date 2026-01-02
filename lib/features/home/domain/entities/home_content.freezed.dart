// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$HomeContent {
  HomeStats get stats => throw _privateConstructorUsedError;
  List<NearbyMember> get nearbyMembers => throw _privateConstructorUsedError;
  List<UpcomingEvent> get upcomingEvents => throw _privateConstructorUsedError;
  List<QuickAction> get quickActions => throw _privateConstructorUsedError;
  DateTime? get lastUpdated => throw _privateConstructorUsedError;

  /// Create a copy of HomeContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeContentCopyWith<HomeContent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeContentCopyWith<$Res> {
  factory $HomeContentCopyWith(
    HomeContent value,
    $Res Function(HomeContent) then,
  ) = _$HomeContentCopyWithImpl<$Res, HomeContent>;
  @useResult
  $Res call({
    HomeStats stats,
    List<NearbyMember> nearbyMembers,
    List<UpcomingEvent> upcomingEvents,
    List<QuickAction> quickActions,
    DateTime? lastUpdated,
  });

  $HomeStatsCopyWith<$Res> get stats;
}

/// @nodoc
class _$HomeContentCopyWithImpl<$Res, $Val extends HomeContent>
    implements $HomeContentCopyWith<$Res> {
  _$HomeContentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeContent
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
                        as HomeStats,
            nearbyMembers:
                null == nearbyMembers
                    ? _value.nearbyMembers
                    : nearbyMembers // ignore: cast_nullable_to_non_nullable
                        as List<NearbyMember>,
            upcomingEvents:
                null == upcomingEvents
                    ? _value.upcomingEvents
                    : upcomingEvents // ignore: cast_nullable_to_non_nullable
                        as List<UpcomingEvent>,
            quickActions:
                null == quickActions
                    ? _value.quickActions
                    : quickActions // ignore: cast_nullable_to_non_nullable
                        as List<QuickAction>,
            lastUpdated:
                freezed == lastUpdated
                    ? _value.lastUpdated
                    : lastUpdated // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }

  /// Create a copy of HomeContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HomeStatsCopyWith<$Res> get stats {
    return $HomeStatsCopyWith<$Res>(_value.stats, (value) {
      return _then(_value.copyWith(stats: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HomeContentImplCopyWith<$Res>
    implements $HomeContentCopyWith<$Res> {
  factory _$$HomeContentImplCopyWith(
    _$HomeContentImpl value,
    $Res Function(_$HomeContentImpl) then,
  ) = __$$HomeContentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    HomeStats stats,
    List<NearbyMember> nearbyMembers,
    List<UpcomingEvent> upcomingEvents,
    List<QuickAction> quickActions,
    DateTime? lastUpdated,
  });

  @override
  $HomeStatsCopyWith<$Res> get stats;
}

/// @nodoc
class __$$HomeContentImplCopyWithImpl<$Res>
    extends _$HomeContentCopyWithImpl<$Res, _$HomeContentImpl>
    implements _$$HomeContentImplCopyWith<$Res> {
  __$$HomeContentImplCopyWithImpl(
    _$HomeContentImpl _value,
    $Res Function(_$HomeContentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HomeContent
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
      _$HomeContentImpl(
        stats:
            null == stats
                ? _value.stats
                : stats // ignore: cast_nullable_to_non_nullable
                    as HomeStats,
        nearbyMembers:
            null == nearbyMembers
                ? _value._nearbyMembers
                : nearbyMembers // ignore: cast_nullable_to_non_nullable
                    as List<NearbyMember>,
        upcomingEvents:
            null == upcomingEvents
                ? _value._upcomingEvents
                : upcomingEvents // ignore: cast_nullable_to_non_nullable
                    as List<UpcomingEvent>,
        quickActions:
            null == quickActions
                ? _value._quickActions
                : quickActions // ignore: cast_nullable_to_non_nullable
                    as List<QuickAction>,
        lastUpdated:
            freezed == lastUpdated
                ? _value.lastUpdated
                : lastUpdated // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$HomeContentImpl implements _HomeContent {
  const _$HomeContentImpl({
    required this.stats,
    required final List<NearbyMember> nearbyMembers,
    required final List<UpcomingEvent> upcomingEvents,
    required final List<QuickAction> quickActions,
    this.lastUpdated,
  }) : _nearbyMembers = nearbyMembers,
       _upcomingEvents = upcomingEvents,
       _quickActions = quickActions;

  @override
  final HomeStats stats;
  final List<NearbyMember> _nearbyMembers;
  @override
  List<NearbyMember> get nearbyMembers {
    if (_nearbyMembers is EqualUnmodifiableListView) return _nearbyMembers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_nearbyMembers);
  }

  final List<UpcomingEvent> _upcomingEvents;
  @override
  List<UpcomingEvent> get upcomingEvents {
    if (_upcomingEvents is EqualUnmodifiableListView) return _upcomingEvents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_upcomingEvents);
  }

  final List<QuickAction> _quickActions;
  @override
  List<QuickAction> get quickActions {
    if (_quickActions is EqualUnmodifiableListView) return _quickActions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_quickActions);
  }

  @override
  final DateTime? lastUpdated;

  @override
  String toString() {
    return 'HomeContent(stats: $stats, nearbyMembers: $nearbyMembers, upcomingEvents: $upcomingEvents, quickActions: $quickActions, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeContentImpl &&
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

  @override
  int get hashCode => Object.hash(
    runtimeType,
    stats,
    const DeepCollectionEquality().hash(_nearbyMembers),
    const DeepCollectionEquality().hash(_upcomingEvents),
    const DeepCollectionEquality().hash(_quickActions),
    lastUpdated,
  );

  /// Create a copy of HomeContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeContentImplCopyWith<_$HomeContentImpl> get copyWith =>
      __$$HomeContentImplCopyWithImpl<_$HomeContentImpl>(this, _$identity);
}

abstract class _HomeContent implements HomeContent {
  const factory _HomeContent({
    required final HomeStats stats,
    required final List<NearbyMember> nearbyMembers,
    required final List<UpcomingEvent> upcomingEvents,
    required final List<QuickAction> quickActions,
    final DateTime? lastUpdated,
  }) = _$HomeContentImpl;

  @override
  HomeStats get stats;
  @override
  List<NearbyMember> get nearbyMembers;
  @override
  List<UpcomingEvent> get upcomingEvents;
  @override
  List<QuickAction> get quickActions;
  @override
  DateTime? get lastUpdated;

  /// Create a copy of HomeContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeContentImplCopyWith<_$HomeContentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$HomeStats {
  int get totalMembers => throw _privateConstructorUsedError;
  int get nearbyMembersCount => throw _privateConstructorUsedError;
  int get upcomingEventsCount => throw _privateConstructorUsedError;
  int get groupsCount => throw _privateConstructorUsedError;
  int get unreadMessages => throw _privateConstructorUsedError;
  int get pendingFriendRequests => throw _privateConstructorUsedError;

  /// Create a copy of HomeStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeStatsCopyWith<HomeStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeStatsCopyWith<$Res> {
  factory $HomeStatsCopyWith(HomeStats value, $Res Function(HomeStats) then) =
      _$HomeStatsCopyWithImpl<$Res, HomeStats>;
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
class _$HomeStatsCopyWithImpl<$Res, $Val extends HomeStats>
    implements $HomeStatsCopyWith<$Res> {
  _$HomeStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeStats
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
abstract class _$$HomeStatsImplCopyWith<$Res>
    implements $HomeStatsCopyWith<$Res> {
  factory _$$HomeStatsImplCopyWith(
    _$HomeStatsImpl value,
    $Res Function(_$HomeStatsImpl) then,
  ) = __$$HomeStatsImplCopyWithImpl<$Res>;
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
class __$$HomeStatsImplCopyWithImpl<$Res>
    extends _$HomeStatsCopyWithImpl<$Res, _$HomeStatsImpl>
    implements _$$HomeStatsImplCopyWith<$Res> {
  __$$HomeStatsImplCopyWithImpl(
    _$HomeStatsImpl _value,
    $Res Function(_$HomeStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HomeStats
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
      _$HomeStatsImpl(
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

class _$HomeStatsImpl implements _HomeStats {
  const _$HomeStatsImpl({
    this.totalMembers = 0,
    this.nearbyMembersCount = 0,
    this.upcomingEventsCount = 0,
    this.groupsCount = 0,
    this.unreadMessages = 0,
    this.pendingFriendRequests = 0,
  });

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
    return 'HomeStats(totalMembers: $totalMembers, nearbyMembersCount: $nearbyMembersCount, upcomingEventsCount: $upcomingEventsCount, groupsCount: $groupsCount, unreadMessages: $unreadMessages, pendingFriendRequests: $pendingFriendRequests)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeStatsImpl &&
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

  /// Create a copy of HomeStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeStatsImplCopyWith<_$HomeStatsImpl> get copyWith =>
      __$$HomeStatsImplCopyWithImpl<_$HomeStatsImpl>(this, _$identity);
}

abstract class _HomeStats implements HomeStats {
  const factory _HomeStats({
    final int totalMembers,
    final int nearbyMembersCount,
    final int upcomingEventsCount,
    final int groupsCount,
    final int unreadMessages,
    final int pendingFriendRequests,
  }) = _$HomeStatsImpl;

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

  /// Create a copy of HomeStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeStatsImplCopyWith<_$HomeStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$NearbyMember {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  double? get distanceKm => throw _privateConstructorUsedError;
  DateTime? get lastSeen => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;

  /// Create a copy of NearbyMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NearbyMemberCopyWith<NearbyMember> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NearbyMemberCopyWith<$Res> {
  factory $NearbyMemberCopyWith(
    NearbyMember value,
    $Res Function(NearbyMember) then,
  ) = _$NearbyMemberCopyWithImpl<$Res, NearbyMember>;
  @useResult
  $Res call({
    String id,
    String displayName,
    String? photoUrl,
    String? city,
    String? country,
    double? distanceKm,
    DateTime? lastSeen,
    bool isOnline,
  });
}

/// @nodoc
class _$NearbyMemberCopyWithImpl<$Res, $Val extends NearbyMember>
    implements $NearbyMemberCopyWith<$Res> {
  _$NearbyMemberCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NearbyMember
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
                        as DateTime?,
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
abstract class _$$NearbyMemberImplCopyWith<$Res>
    implements $NearbyMemberCopyWith<$Res> {
  factory _$$NearbyMemberImplCopyWith(
    _$NearbyMemberImpl value,
    $Res Function(_$NearbyMemberImpl) then,
  ) = __$$NearbyMemberImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String? photoUrl,
    String? city,
    String? country,
    double? distanceKm,
    DateTime? lastSeen,
    bool isOnline,
  });
}

/// @nodoc
class __$$NearbyMemberImplCopyWithImpl<$Res>
    extends _$NearbyMemberCopyWithImpl<$Res, _$NearbyMemberImpl>
    implements _$$NearbyMemberImplCopyWith<$Res> {
  __$$NearbyMemberImplCopyWithImpl(
    _$NearbyMemberImpl _value,
    $Res Function(_$NearbyMemberImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NearbyMember
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
      _$NearbyMemberImpl(
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
                    as DateTime?,
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

class _$NearbyMemberImpl implements _NearbyMember {
  const _$NearbyMemberImpl({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.city,
    this.country,
    this.distanceKm,
    this.lastSeen,
    this.isOnline = false,
  });

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
  final DateTime? lastSeen;
  @override
  @JsonKey()
  final bool isOnline;

  @override
  String toString() {
    return 'NearbyMember(id: $id, displayName: $displayName, photoUrl: $photoUrl, city: $city, country: $country, distanceKm: $distanceKm, lastSeen: $lastSeen, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NearbyMemberImpl &&
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

  /// Create a copy of NearbyMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NearbyMemberImplCopyWith<_$NearbyMemberImpl> get copyWith =>
      __$$NearbyMemberImplCopyWithImpl<_$NearbyMemberImpl>(this, _$identity);
}

abstract class _NearbyMember implements NearbyMember {
  const factory _NearbyMember({
    required final String id,
    required final String displayName,
    final String? photoUrl,
    final String? city,
    final String? country,
    final double? distanceKm,
    final DateTime? lastSeen,
    final bool isOnline,
  }) = _$NearbyMemberImpl;

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
  DateTime? get lastSeen;
  @override
  bool get isOnline;

  /// Create a copy of NearbyMember
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NearbyMemberImplCopyWith<_$NearbyMemberImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$UpcomingEvent {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  int get attendeesCount => throw _privateConstructorUsedError;
  bool get isAttending => throw _privateConstructorUsedError;

  /// Create a copy of UpcomingEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UpcomingEventCopyWith<UpcomingEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpcomingEventCopyWith<$Res> {
  factory $UpcomingEventCopyWith(
    UpcomingEvent value,
    $Res Function(UpcomingEvent) then,
  ) = _$UpcomingEventCopyWithImpl<$Res, UpcomingEvent>;
  @useResult
  $Res call({
    String id,
    String title,
    DateTime startDate,
    String? imageUrl,
    String? location,
    int attendeesCount,
    bool isAttending,
  });
}

/// @nodoc
class _$UpcomingEventCopyWithImpl<$Res, $Val extends UpcomingEvent>
    implements $UpcomingEventCopyWith<$Res> {
  _$UpcomingEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UpcomingEvent
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
                        as DateTime,
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
abstract class _$$UpcomingEventImplCopyWith<$Res>
    implements $UpcomingEventCopyWith<$Res> {
  factory _$$UpcomingEventImplCopyWith(
    _$UpcomingEventImpl value,
    $Res Function(_$UpcomingEventImpl) then,
  ) = __$$UpcomingEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    DateTime startDate,
    String? imageUrl,
    String? location,
    int attendeesCount,
    bool isAttending,
  });
}

/// @nodoc
class __$$UpcomingEventImplCopyWithImpl<$Res>
    extends _$UpcomingEventCopyWithImpl<$Res, _$UpcomingEventImpl>
    implements _$$UpcomingEventImplCopyWith<$Res> {
  __$$UpcomingEventImplCopyWithImpl(
    _$UpcomingEventImpl _value,
    $Res Function(_$UpcomingEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UpcomingEvent
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
      _$UpcomingEventImpl(
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
                    as DateTime,
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

class _$UpcomingEventImpl implements _UpcomingEvent {
  const _$UpcomingEventImpl({
    required this.id,
    required this.title,
    required this.startDate,
    this.imageUrl,
    this.location,
    this.attendeesCount = 0,
    this.isAttending = false,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final DateTime startDate;
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
    return 'UpcomingEvent(id: $id, title: $title, startDate: $startDate, imageUrl: $imageUrl, location: $location, attendeesCount: $attendeesCount, isAttending: $isAttending)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpcomingEventImpl &&
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

  /// Create a copy of UpcomingEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UpcomingEventImplCopyWith<_$UpcomingEventImpl> get copyWith =>
      __$$UpcomingEventImplCopyWithImpl<_$UpcomingEventImpl>(this, _$identity);
}

abstract class _UpcomingEvent implements UpcomingEvent {
  const factory _UpcomingEvent({
    required final String id,
    required final String title,
    required final DateTime startDate,
    final String? imageUrl,
    final String? location,
    final int attendeesCount,
    final bool isAttending,
  }) = _$UpcomingEventImpl;

  @override
  String get id;
  @override
  String get title;
  @override
  DateTime get startDate;
  @override
  String? get imageUrl;
  @override
  String? get location;
  @override
  int get attendeesCount;
  @override
  bool get isAttending;

  /// Create a copy of UpcomingEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UpcomingEventImplCopyWith<_$UpcomingEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$QuickAction {
  String get id => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get route => throw _privateConstructorUsedError;
  int get badgeCount => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;

  /// Create a copy of QuickAction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuickActionCopyWith<QuickAction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuickActionCopyWith<$Res> {
  factory $QuickActionCopyWith(
    QuickAction value,
    $Res Function(QuickAction) then,
  ) = _$QuickActionCopyWithImpl<$Res, QuickAction>;
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
class _$QuickActionCopyWithImpl<$Res, $Val extends QuickAction>
    implements $QuickActionCopyWith<$Res> {
  _$QuickActionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuickAction
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
abstract class _$$QuickActionImplCopyWith<$Res>
    implements $QuickActionCopyWith<$Res> {
  factory _$$QuickActionImplCopyWith(
    _$QuickActionImpl value,
    $Res Function(_$QuickActionImpl) then,
  ) = __$$QuickActionImplCopyWithImpl<$Res>;
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
class __$$QuickActionImplCopyWithImpl<$Res>
    extends _$QuickActionCopyWithImpl<$Res, _$QuickActionImpl>
    implements _$$QuickActionImplCopyWith<$Res> {
  __$$QuickActionImplCopyWithImpl(
    _$QuickActionImpl _value,
    $Res Function(_$QuickActionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuickAction
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
      _$QuickActionImpl(
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

class _$QuickActionImpl implements _QuickAction {
  const _$QuickActionImpl({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    this.badgeCount = 0,
    this.isEnabled = true,
  });

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
    return 'QuickAction(id: $id, label: $label, icon: $icon, route: $route, badgeCount: $badgeCount, isEnabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuickActionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.route, route) || other.route == route) &&
            (identical(other.badgeCount, badgeCount) ||
                other.badgeCount == badgeCount) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, label, icon, route, badgeCount, isEnabled);

  /// Create a copy of QuickAction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuickActionImplCopyWith<_$QuickActionImpl> get copyWith =>
      __$$QuickActionImplCopyWithImpl<_$QuickActionImpl>(this, _$identity);
}

abstract class _QuickAction implements QuickAction {
  const factory _QuickAction({
    required final String id,
    required final String label,
    required final String icon,
    required final String route,
    final int badgeCount,
    final bool isEnabled,
  }) = _$QuickActionImpl;

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

  /// Create a copy of QuickAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuickActionImplCopyWith<_$QuickActionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
