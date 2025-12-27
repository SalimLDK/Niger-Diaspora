import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'embassy_message_model.freezed.dart';
part 'embassy_message_model.g.dart';

/// Embassy message types
enum EmbassyMessageType { general, request, complaint, inquiry, followUp }

/// Embassy message status
enum EmbassyMessageStatus { pending, read, replied, closed }

/// Converter to handle Firestore Timestamp to DateTime conversion
class EmbassyTimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const EmbassyTimestampConverter();

  @override
  DateTime? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is DateTime) return json;
    if (json is Timestamp) return json.toDate();
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
    return null;
  }

  @override
  dynamic toJson(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }
}

@freezed
class EmbassyMessageModel with _$EmbassyMessageModel {
  const EmbassyMessageModel._();

  const factory EmbassyMessageModel({
    required String id,
    required String userId,
    required String embassyId,
    required String subject,
    required String content,
    @Default(EmbassyMessageType.general) EmbassyMessageType messageType,
    @Default(EmbassyMessageStatus.pending) EmbassyMessageStatus status,
    @EmbassyTimestampConverter() DateTime? createdAt,
    @EmbassyTimestampConverter() DateTime? readAt,
    @EmbassyTimestampConverter() DateTime? repliedAt,
    @Default([]) List<String> attachments,
    String? replyContent,
    String? repliedBy, // Embassy staff ID who replied
    // User info for display
    String? userName,
    String? userPhotoUrl,
    String? userEmail,
    // Embassy info for display
    String? embassyName,
    String? embassyCountry,
  }) = _EmbassyMessageModel;

  factory EmbassyMessageModel.fromJson(Map<String, dynamic> json) =>
      _$EmbassyMessageModelFromJson(json);

  factory EmbassyMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return EmbassyMessageModel.fromJson(data);
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}
