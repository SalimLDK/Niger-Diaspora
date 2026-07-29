// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EventModelImpl _$$EventModelImplFromJson(Map<String, dynamic> json) =>
    _$EventModelImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate:
          json['endDate'] == null
              ? null
              : DateTime.parse(json['endDate'] as String),
      location: json['location'] as String,
      address: json['address'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      organizerId: json['organizerId'] as String,
      organizerName: json['organizerName'] as String?,
      organizerPhotoUrl: json['organizerPhotoUrl'] as String?,
      posterUrls:
          (json['posterUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      attendeeIds:
          (json['attendeeIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      maxAttendees: (json['maxAttendees'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isOnline: json['isOnline'] as bool? ?? false,
      onlineLink: json['onlineLink'] as String?,
      category: json['category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'upcoming',
      createdAt:
          json['createdAt'] == null
              ? null
              : DateTime.parse(json['createdAt'] as String),
      recapPhotoUrls:
          (json['recapPhotoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      recapDescription: json['recapDescription'] as String?,
      recapCreatedAt:
          json['recapCreatedAt'] == null
              ? null
              : DateTime.parse(json['recapCreatedAt'] as String),
    );

Map<String, dynamic> _$$EventModelImplToJson(_$EventModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'location': instance.location,
      'address': instance.address,
      'country': instance.country,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'organizerId': instance.organizerId,
      'organizerName': instance.organizerName,
      'organizerPhotoUrl': instance.organizerPhotoUrl,
      'posterUrls': instance.posterUrls,
      'attendeeIds': instance.attendeeIds,
      'maxAttendees': instance.maxAttendees,
      'price': instance.price,
      'isOnline': instance.isOnline,
      'onlineLink': instance.onlineLink,
      'category': instance.category,
      'status': instance.status,
      'createdAt': instance.createdAt?.toIso8601String(),
      'recapPhotoUrls': instance.recapPhotoUrls,
      'recapDescription': instance.recapDescription,
      'recapCreatedAt': instance.recapCreatedAt?.toIso8601String(),
    };
