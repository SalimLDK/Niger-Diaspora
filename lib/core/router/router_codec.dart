import 'dart:convert';

import '../../features/businesses/domain/entities/business_entity.dart';
import '../../features/embassies/domain/entities/embassy_activity.dart';
import '../../features/embassies/domain/entities/embassy_entity.dart';
import '../../features/embassies/domain/entities/embassy_news.dart';
import '../../features/events/domain/entities/event_entity.dart';
import '../../features/groups/domain/entities/group_entity.dart';
import '../../features/marketplace/domain/entities/product_entity.dart';
import '../../features/profile/domain/entities/profile_entity.dart';
import '../../features/transfers/domain/entities/recipient_entity.dart';

/// Custom codec for GoRouter to serialize/deserialize entity types
/// This enables proper deep linking and state restoration on web
class AppRouterCodec extends Codec<Object?, Object?> {
  const AppRouterCodec();

  @override
  Converter<Object?, Object?> get decoder => const _AppRouterDecoder();

  @override
  Converter<Object?, Object?> get encoder => const _AppRouterEncoder();
}

class _AppRouterEncoder extends Converter<Object?, Object?> {
  const _AppRouterEncoder();

  @override
  Object? convert(Object? input) {
    if (input == null) return null;

    // Handle entity types - encode as [type, data]
    if (input is GroupEntity) {
      return ['GroupEntity', _encodeGroupEntity(input)];
    }
    if (input is ProfileEntity) {
      return ['ProfileEntity', _encodeProfileEntity(input)];
    }
    if (input is EventEntity) {
      return ['EventEntity', _encodeEventEntity(input)];
    }
    if (input is EmbassyEntity) {
      return ['EmbassyEntity', _encodeEmbassyEntity(input)];
    }
    if (input is BusinessEntity) {
      return ['BusinessEntity', _encodeBusinessEntity(input)];
    }
    if (input is ProductEntity) {
      return ['ProductEntity', _encodeProductEntity(input)];
    }
    if (input is RecipientEntity) {
      return ['RecipientEntity', _encodeRecipientEntity(input)];
    }

    // Handle Map<String, dynamic> (for conversation extras)
    if (input is Map<String, dynamic>) {
      return ['Map', _encodeMap(input)];
    }

    // Primitives pass through
    return input;
  }

  Map<String, dynamic> _encodeMap(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is DateTime) {
        return MapEntry(key, {'__type': 'DateTime', 'value': value.toIso8601String()});
      }
      return MapEntry(key, value);
    });
  }

  // ============ GroupEntity ============
  Map<String, dynamic> _encodeGroupEntity(GroupEntity entity) => {
    'id': entity.id,
    'name': entity.name,
    'description': entity.description,
    'imageUrl': entity.imageUrl,
    'creatorId': entity.creatorId,
    'creatorName': entity.creatorName,
    'adminIds': entity.adminIds,
    'memberIds': entity.memberIds,
    'category': entity.category.index,
    'isPrivate': entity.isPrivate,
    'location': entity.location,
    'tags': entity.tags,
    'createdAt': entity.createdAt?.toIso8601String(),
  };

  // ============ ProfileEntity ============
  Map<String, dynamic> _encodeProfileEntity(ProfileEntity entity) => {
    'id': entity.id,
    'email': entity.email,
    'displayName': entity.displayName,
    'photoUrl': entity.photoUrl,
    'phoneNumber': entity.phoneNumber,
    'bio': entity.bio,
    'profession': entity.profession,
    'currentCity': entity.currentCity,
    'currentCountry': entity.currentCountry,
    'currentRegion': entity.currentRegion,
    'countryCode': entity.countryCode,
    'originRegion': entity.originRegion,
    'originCity': entity.originCity,
    'latitude': entity.latitude,
    'longitude': entity.longitude,
    'isVisible': entity.isVisible,
    'notificationsEnabled': entity.notificationsEnabled,
    'shareLocation': entity.shareLocation,
    'phoneVisibility': entity.phoneVisibility,
    'isPhoneVerified': entity.isPhoneVerified,
    'interests': entity.interests,
    'skills': entity.skills,
    'languages': entity.languages,
    'connectionsCount': entity.connectionsCount,
    'groupsCount': entity.groupsCount,
    'eventsCount': entity.eventsCount,
    'createdAt': entity.createdAt?.toIso8601String(),
    'lastLoginAt': entity.lastLoginAt?.toIso8601String(),
    'isOnline': entity.isOnline,
    'lastSeen': entity.lastSeen?.toIso8601String(),
    'showOnlineStatus': entity.showOnlineStatus,
  };

  // ============ EventEntity ============
  Map<String, dynamic> _encodeEventEntity(EventEntity entity) => {
    'id': entity.id,
    'title': entity.title,
    'description': entity.description,
    'startDate': entity.startDate.toIso8601String(),
    'endDate': entity.endDate?.toIso8601String(),
    'location': entity.location,
    'address': entity.address,
    'latitude': entity.latitude,
    'longitude': entity.longitude,
    'organizerId': entity.organizerId,
    'organizerName': entity.organizerName,
    'organizerPhotoUrl': entity.organizerPhotoUrl,
    'posterUrls': entity.posterUrls,
    'attendeeIds': entity.attendeeIds,
    'maxAttendees': entity.maxAttendees,
    'isOnline': entity.isOnline,
    'onlineLink': entity.onlineLink,
    'category': entity.category.index,
    'status': entity.status.index,
    'createdAt': entity.createdAt?.toIso8601String(),
    'recapPhotoUrls': entity.recapPhotoUrls,
    'recapDescription': entity.recapDescription,
    'recapCreatedAt': entity.recapCreatedAt?.toIso8601String(),
  };

  // ============ EmbassyEntity ============
  Map<String, dynamic> _encodeEmbassyEntity(EmbassyEntity entity) => {
    'id': entity.id,
    'name': entity.name,
    'country': entity.country,
    'city': entity.city,
    'address': entity.address,
    'phone': entity.phone,
    'email': entity.email,
    'website': entity.website,
    'latitude': entity.latitude,
    'longitude': entity.longitude,
    'imageUrl': entity.imageUrl,
    'type': entity.type,
    'services': entity.services,
    'openingHours': entity.openingHours,
    'isVerified': entity.isVerified,
    'isSuspended': entity.isSuspended,
    'verifiedAt': entity.verifiedAt?.toIso8601String(),
    'rejectionReason': entity.rejectionReason,
    'jurisdictionCountries': entity.jurisdictionCountries,
    'activities': entity.activities.map(_encodeEmbassyActivity).toList(),
    'news': entity.news.map(_encodeEmbassyNews).toList(),
    'isTemporarilyClosed': entity.isTemporarilyClosed,
    'closureMessage': entity.closureMessage,
    'reopenDate': entity.reopenDate?.toIso8601String(),
    'upcomingServices': entity.upcomingServices,
  };

  Map<String, dynamic> _encodeEmbassyActivity(EmbassyActivity activity) => {
    'id': activity.id,
    'title': activity.title,
    'description': activity.description,
    'date': activity.date.toIso8601String(),
    'location': activity.location,
    'imageUrl': activity.imageUrl,
  };

  Map<String, dynamic> _encodeEmbassyNews(EmbassyNews news) => {
    'id': news.id,
    'title': news.title,
    'content': news.content,
    'date': news.date.toIso8601String(),
    'imageUrl': news.imageUrl,
  };

  // ============ BusinessEntity ============
  Map<String, dynamic> _encodeBusinessEntity(BusinessEntity entity) => {
    'id': entity.id,
    'ownerId': entity.ownerId,
    'ownerName': entity.ownerName,
    'name': entity.name,
    'description': entity.description,
    'category': entity.category.index,
    'photoUrls': entity.photoUrls,
    'logoUrl': entity.logoUrl,
    'phone': entity.phone,
    'email': entity.email,
    'website': entity.website,
    'address': entity.address,
    'city': entity.city,
    'country': entity.country,
    'latitude': entity.latitude,
    'longitude': entity.longitude,
    'openingHours': entity.openingHours.map((k, v) => MapEntry(k, v.toJson())),
    'isVerified': entity.isVerified,
    'isBoosted': entity.isBoosted,
    'boostExpiresAt': entity.boostExpiresAt?.toIso8601String(),
    'averageRating': entity.averageRating,
    'reviewCount': entity.reviewCount,
    'viewCount': entity.viewCount,
    'tags': entity.tags,
    'services': entity.services,
    'createdAt': entity.createdAt?.toIso8601String(),
    'updatedAt': entity.updatedAt?.toIso8601String(),
  };

  // ============ ProductEntity ============
  Map<String, dynamic> _encodeProductEntity(ProductEntity entity) => {
    'id': entity.id,
    'sellerId': entity.sellerId,
    'sellerName': entity.sellerName,
    'sellerPhotoUrl': entity.sellerPhotoUrl,
    'title': entity.title,
    'description': entity.description,
    'price': entity.price,
    'currency': entity.currency,
    'imageUrls': entity.imageUrls,
    'category': entity.category.index,
    'condition': entity.condition.index,
    'location': entity.location,
    'isAvailable': entity.isAvailable,
    'quantity': entity.quantity,
    'viewCount': entity.viewCount,
    'tags': entity.tags,
    'isTaxable': entity.isTaxable,
    'customTaxRate': entity.customTaxRate,
    'taxIncludedInPrice': entity.taxIncludedInPrice,
    'createdAt': entity.createdAt?.toIso8601String(),
    'updatedAt': entity.updatedAt?.toIso8601String(),
  };

  // ============ RecipientEntity ============
  Map<String, dynamic> _encodeRecipientEntity(RecipientEntity entity) => {
    'id': entity.id,
    'userId': entity.userId,
    'fullName': entity.fullName,
    'phone': entity.phone,
    'email': entity.email,
    'type': entity.type.index,
    'bankName': entity.bankName,
    'bankAccountNumber': entity.bankAccountNumber,
    'mobileProvider': entity.mobileProvider,
    'city': entity.city,
    'address': entity.address,
    'isFavorite': entity.isFavorite,
    'createdAt': entity.createdAt?.toIso8601String(),
    'lastUsedAt': entity.lastUsedAt?.toIso8601String(),
  };
}

class _AppRouterDecoder extends Converter<Object?, Object?> {
  const _AppRouterDecoder();

  @override
  Object? convert(Object? input) {
    if (input == null) return null;

    // Check if it's our encoded format [type, data]
    if (input is List && input.length == 2 && input[0] is String) {
      final type = input[0] as String;
      final data = input[1];

      switch (type) {
        case 'GroupEntity':
          return _decodeGroupEntity(data as Map<String, dynamic>);
        case 'ProfileEntity':
          return _decodeProfileEntity(data as Map<String, dynamic>);
        case 'EventEntity':
          return _decodeEventEntity(data as Map<String, dynamic>);
        case 'EmbassyEntity':
          return _decodeEmbassyEntity(data as Map<String, dynamic>);
        case 'BusinessEntity':
          return _decodeBusinessEntity(data as Map<String, dynamic>);
        case 'ProductEntity':
          return _decodeProductEntity(data as Map<String, dynamic>);
        case 'RecipientEntity':
          return _decodeRecipientEntity(data as Map<String, dynamic>);
        case 'Map':
          return _decodeMap(data as Map<String, dynamic>);
      }
    }

    return input;
  }

  Map<String, dynamic> _decodeMap(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is Map && value['__type'] == 'DateTime') {
        return MapEntry(key, DateTime.parse(value['value'] as String).toLocal());
      }
      return MapEntry(key, value);
    });
  }

  // ============ GroupEntity ============
  GroupEntity _decodeGroupEntity(Map<String, dynamic> data) => GroupEntity(
    id: data['id'] as String,
    name: data['name'] as String,
    description: data['description'] as String,
    imageUrl: data['imageUrl'] as String?,
    creatorId: data['creatorId'] as String,
    creatorName: data['creatorName'] as String?,
    adminIds: List<String>.from(data['adminIds'] ?? []),
    memberIds: List<String>.from(data['memberIds'] ?? []),
    category: GroupCategory.values[data['category'] as int? ?? 8],
    isPrivate: data['isPrivate'] as bool? ?? false,
    location: data['location'] as String?,
    tags: List<String>.from(data['tags'] ?? []),
    createdAt:
        data['createdAt'] != null
            ? DateTime.parse(data['createdAt'] as String).toLocal()
            : null,
  );

  // ============ ProfileEntity ============
  ProfileEntity _decodeProfileEntity(Map<String, dynamic> data) =>
      ProfileEntity(
        id: data['id'] as String,
        email: data['email'] as String?,
        displayName: data['displayName'] as String?,
        photoUrl: data['photoUrl'] as String?,
        phoneNumber: data['phoneNumber'] as String?,
        bio: data['bio'] as String?,
        profession: data['profession'] as String?,
        currentCity: data['currentCity'] as String?,
        currentCountry: data['currentCountry'] as String?,
        currentRegion: data['currentRegion'] as String?,
        countryCode: data['countryCode'] as String?,
        originRegion: data['originRegion'] as String?,
        originCity: data['originCity'] as String?,
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        isVisible: data['isVisible'] as bool? ?? true,
        notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
        shareLocation: data['shareLocation'] as bool? ?? true,
        phoneVisibility: data['phoneVisibility'] as String? ?? 'everyone',
        isPhoneVerified: data['isPhoneVerified'] as bool? ?? false,
        interests: List<String>.from(data['interests'] ?? []),
        skills: List<String>.from(data['skills'] ?? []),
        languages: List<String>.from(data['languages'] ?? []),
        connectionsCount: data['connectionsCount'] as int? ?? 0,
        groupsCount: data['groupsCount'] as int? ?? 0,
        eventsCount: data['eventsCount'] as int? ?? 0,
        createdAt:
            data['createdAt'] != null
                ? DateTime.parse(data['createdAt'] as String).toLocal()
                : null,
        lastLoginAt:
            data['lastLoginAt'] != null
                ? DateTime.parse(data['lastLoginAt'] as String).toLocal()
                : null,
        isOnline: data['isOnline'] as bool? ?? false,
        lastSeen:
            data['lastSeen'] != null
                ? DateTime.parse(data['lastSeen'] as String).toLocal()
                : null,
        showOnlineStatus: data['showOnlineStatus'] as bool? ?? true,
      );

  // ============ EventEntity ============
  EventEntity _decodeEventEntity(Map<String, dynamic> data) => EventEntity(
    id: data['id'] as String,
    title: data['title'] as String,
    description: data['description'] as String,
    startDate: DateTime.parse(data['startDate'] as String).toLocal(),
    endDate:
        data['endDate'] != null
            ? DateTime.parse(data['endDate'] as String).toLocal()
            : null,
    location: data['location'] as String,
    address: data['address'] as String?,
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    organizerId: data['organizerId'] as String,
    organizerName: data['organizerName'] as String?,
    organizerPhotoUrl: data['organizerPhotoUrl'] as String?,
    posterUrls: List<String>.from(data['posterUrls'] ?? []),
    attendeeIds: List<String>.from(data['attendeeIds'] ?? []),
    maxAttendees: data['maxAttendees'] as int? ?? 0,
    isOnline: data['isOnline'] as bool? ?? false,
    onlineLink: data['onlineLink'] as String?,
    category: EventCategory.values[data['category'] as int? ?? 7],
    status: EventStatus.values[data['status'] as int? ?? 0],
    createdAt:
        data['createdAt'] != null
            ? DateTime.parse(data['createdAt'] as String).toLocal()
            : null,
    recapPhotoUrls: List<String>.from(data['recapPhotoUrls'] ?? []),
    recapDescription: data['recapDescription'] as String?,
    recapCreatedAt:
        data['recapCreatedAt'] != null
            ? DateTime.parse(data['recapCreatedAt'] as String).toLocal()
            : null,
  );

  // ============ EmbassyEntity ============
  EmbassyEntity _decodeEmbassyEntity(Map<String, dynamic> data) =>
      EmbassyEntity(
        id: data['id'] as String,
        name: data['name'] as String,
        country: data['country'] as String,
        city: data['city'] as String,
        address: data['address'] as String,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        website: data['website'] as String?,
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        imageUrl: data['imageUrl'] as String?,
        type: data['type'] as String? ?? 'embassy',
        services: List<String>.from(data['services'] ?? []),
        openingHours: Map<String, String>.from(data['openingHours'] ?? {}),
        isVerified: data['isVerified'] as bool? ?? false,
        isSuspended: data['isSuspended'] as bool? ?? false,
        verifiedAt:
            data['verifiedAt'] != null
                ? DateTime.parse(data['verifiedAt'] as String).toLocal()
                : null,
        rejectionReason: data['rejectionReason'] as String?,
        jurisdictionCountries: List<String>.from(
          data['jurisdictionCountries'] ?? [],
        ),
        activities:
            (data['activities'] as List?)
                ?.map(
                  (e) => _decodeEmbassyActivity(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        news:
            (data['news'] as List?)
                ?.map((e) => _decodeEmbassyNews(e as Map<String, dynamic>))
                .toList() ??
            [],
        isTemporarilyClosed: data['isTemporarilyClosed'] as bool? ?? false,
        closureMessage: data['closureMessage'] as String?,
        reopenDate:
            data['reopenDate'] != null
                ? DateTime.parse(data['reopenDate'] as String).toLocal()
                : null,
        upcomingServices: List<String>.from(data['upcomingServices'] ?? []),
      );

  EmbassyActivity _decodeEmbassyActivity(Map<String, dynamic> data) =>
      EmbassyActivity(
        id: data['id'] as String,
        title: data['title'] as String,
        description: data['description'] as String,
        date: DateTime.parse(data['date'] as String).toLocal(),
        location: data['location'] as String,
        imageUrl: data['imageUrl'] as String?,
      );

  EmbassyNews _decodeEmbassyNews(Map<String, dynamic> data) => EmbassyNews(
    id: data['id'] as String,
    title: data['title'] as String,
    content: data['content'] as String,
    date: DateTime.parse(data['date'] as String).toLocal(),
    imageUrl: data['imageUrl'] as String?,
  );

  // ============ BusinessEntity ============
  BusinessEntity _decodeBusinessEntity(Map<String, dynamic> data) =>
      BusinessEntity(
        id: data['id'] as String,
        ownerId: data['ownerId'] as String,
        ownerName: data['ownerName'] as String?,
        name: data['name'] as String,
        description: data['description'] as String,
        category: BusinessCategory.values[data['category'] as int? ?? 11],
        photoUrls: List<String>.from(data['photoUrls'] ?? []),
        logoUrl: data['logoUrl'] as String?,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        website: data['website'] as String?,
        address: data['address'] as String?,
        city: data['city'] as String?,
        country: data['country'] as String?,
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        openingHours:
            (data['openingHours'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(
                k,
                OpeningHours.fromJson(v as Map<String, dynamic>),
              ),
            ) ??
            {},
        isVerified: data['isVerified'] as bool? ?? false,
        isBoosted: data['isBoosted'] as bool? ?? false,
        boostExpiresAt:
            data['boostExpiresAt'] != null
                ? DateTime.parse(data['boostExpiresAt'] as String).toLocal()
                : null,
        averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: data['reviewCount'] as int? ?? 0,
        viewCount: data['viewCount'] as int? ?? 0,
        tags: List<String>.from(data['tags'] ?? []),
        services: List<String>.from(data['services'] ?? []),
        createdAt:
            data['createdAt'] != null
                ? DateTime.parse(data['createdAt'] as String).toLocal()
                : null,
        updatedAt:
            data['updatedAt'] != null
                ? DateTime.parse(data['updatedAt'] as String).toLocal()
                : null,
      );

  // ============ ProductEntity ============
  ProductEntity _decodeProductEntity(Map<String, dynamic> data) =>
      ProductEntity(
        id: data['id'] as String,
        sellerId: data['sellerId'] as String,
        sellerName: data['sellerName'] as String?,
        sellerPhotoUrl: data['sellerPhotoUrl'] as String?,
        title: data['title'] as String,
        description: data['description'] as String,
        price: (data['price'] as num).toDouble(),
        currency: data['currency'] as String? ?? 'XOF',
        imageUrls: List<String>.from(data['imageUrls'] ?? []),
        category: ProductCategory.values[data['category'] as int? ?? 6],
        condition: ProductCondition.values[data['condition'] as int? ?? 0],
        location: data['location'] as String?,
        isAvailable: data['isAvailable'] as bool? ?? true,
        quantity: data['quantity'] as int? ?? 1,
        viewCount: data['viewCount'] as int? ?? 0,
        tags: List<String>.from(data['tags'] ?? []),
        isTaxable: data['isTaxable'] as bool? ?? true,
        customTaxRate: (data['customTaxRate'] as num?)?.toDouble(),
        taxIncludedInPrice: data['taxIncludedInPrice'] as bool? ?? false,
        createdAt:
            data['createdAt'] != null
                ? DateTime.parse(data['createdAt'] as String).toLocal()
                : null,
        updatedAt:
            data['updatedAt'] != null
                ? DateTime.parse(data['updatedAt'] as String).toLocal()
                : null,
      );

  // ============ RecipientEntity ============
  RecipientEntity _decodeRecipientEntity(Map<String, dynamic> data) =>
      RecipientEntity(
        id: data['id'] as String,
        userId: data['userId'] as String,
        fullName: data['fullName'] as String,
        phone: data['phone'] as String,
        email: data['email'] as String?,
        type: RecipientType.values[data['type'] as int? ?? 0],
        bankName: data['bankName'] as String?,
        bankAccountNumber: data['bankAccountNumber'] as String?,
        mobileProvider: data['mobileProvider'] as String?,
        city: data['city'] as String?,
        address: data['address'] as String?,
        isFavorite: data['isFavorite'] as bool? ?? false,
        createdAt:
            data['createdAt'] != null
                ? DateTime.parse(data['createdAt'] as String).toLocal()
                : null,
        lastUsedAt:
            data['lastUsedAt'] != null
                ? DateTime.parse(data['lastUsedAt'] as String).toLocal()
                : null,
      );
}
