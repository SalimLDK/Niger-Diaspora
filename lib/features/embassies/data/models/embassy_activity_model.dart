import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/embassy_activity.dart';

part 'embassy_activity_model.freezed.dart';
part 'embassy_activity_model.g.dart';

@freezed
class EmbassyActivityModel with _$EmbassyActivityModel {
  const factory EmbassyActivityModel({
    required String id,
    required String title,
    required String description,
    required DateTime date,
    required String location,
    String? imageUrl,
  }) = _EmbassyActivityModel;

  factory EmbassyActivityModel.fromJson(Map<String, dynamic> json) =>
      _$EmbassyActivityModelFromJson(json);

  factory EmbassyActivityModel.fromEntity(EmbassyActivity entity) {
    return EmbassyActivityModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      date: entity.date,
      location: entity.location,
      imageUrl: entity.imageUrl,
    );
  }
}

extension EmbassyActivityModelX on EmbassyActivityModel {
  EmbassyActivity toEntity() {
    return EmbassyActivity(
      id: id,
      title: title,
      description: description,
      date: date,
      location: location,
      imageUrl: imageUrl,
    );
  }
}
