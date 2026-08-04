import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/business_boost_entity.dart';

import '../../../../core/utils/date_parsing.dart';
part 'business_boost_model.freezed.dart';
part 'business_boost_model.g.dart';

@freezed
class BusinessBoostModel with _$BusinessBoostModel {
  const BusinessBoostModel._();

  const factory BusinessBoostModel({
    required String id,
    required String businessId,
    required String userId,
    @Default('standard') String type,
    @Default('days7') String duration,
    required double amount,
    @Default('XOF') String currency,
    @LocalDateTimeConverter() required DateTime startDate,
    @LocalDateTimeConverter() required DateTime endDate,
    @Default('active') String status,
    String? paymentReference,
    @LocalDateTimeNullableConverter() DateTime? createdAt,
  }) = _BusinessBoostModel;

  factory BusinessBoostModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessBoostModelFromJson(json);

  BusinessBoostEntity toEntity() => BusinessBoostEntity(
        id: id,
        businessId: businessId,
        userId: userId,
        type: _parseBoostType(type),
        duration: _parseBoostDuration(duration),
        amount: amount,
        currency: currency,
        startDate: startDate,
        endDate: endDate,
        status: _parseBoostStatus(status),
        paymentReference: paymentReference,
        createdAt: createdAt,
      );

  static BoostType _parseBoostType(String value) {
    return BoostType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BoostType.standard,
    );
  }

  static BoostDuration _parseBoostDuration(String value) {
    return BoostDuration.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BoostDuration.days7,
    );
  }

  static BoostStatus _parseBoostStatus(String value) {
    return BoostStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BoostStatus.pending,
    );
  }

  factory BusinessBoostModel.fromEntity(BusinessBoostEntity entity) =>
      BusinessBoostModel(
        id: entity.id,
        businessId: entity.businessId,
        userId: entity.userId,
        type: entity.type.name,
        duration: entity.duration.name,
        amount: entity.amount,
        currency: entity.currency,
        startDate: entity.startDate,
        endDate: entity.endDate,
        status: entity.status.name,
        paymentReference: entity.paymentReference,
        createdAt: entity.createdAt,
      );
}
