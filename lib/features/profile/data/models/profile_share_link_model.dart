import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/profile_share_link_entity.dart';

import '../../../../core/utils/date_parsing.dart';
part 'profile_share_link_model.freezed.dart';
part 'profile_share_link_model.g.dart';

@freezed
class ProfileShareLinkModel with _$ProfileShareLinkModel {
  const ProfileShareLinkModel._();

  const factory ProfileShareLinkModel({
    required String id,
    required String userId,
    required String shortCode,
    @LocalDateTimeConverter() required DateTime createdAt,
    @LocalDateTimeNullableConverter() DateTime? expiresAt,
    @Default(0) int clickCount,
  }) = _ProfileShareLinkModel;

  factory ProfileShareLinkModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileShareLinkModelFromJson(json);

  ProfileShareLinkEntity toEntity() => ProfileShareLinkEntity(
    id: id,
    userId: userId,
    shortCode: shortCode,
    createdAt: createdAt,
    expiresAt: expiresAt,
    clickCount: clickCount,
  );

  static ProfileShareLinkModel fromEntity(ProfileShareLinkEntity entity) =>
      ProfileShareLinkModel(
        id: entity.id,
        userId: entity.userId,
        shortCode: entity.shortCode,
        createdAt: entity.createdAt,
        expiresAt: entity.expiresAt,
        clickCount: entity.clickCount,
      );
}
