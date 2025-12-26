import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/embassy_news.dart';

part 'embassy_news_model.freezed.dart';
part 'embassy_news_model.g.dart';

@freezed
class EmbassyNewsModel with _$EmbassyNewsModel {
  const factory EmbassyNewsModel({
    required String id,
    required String title,
    required String content,
    required DateTime date,
    String? imageUrl,
  }) = _EmbassyNewsModel;

  factory EmbassyNewsModel.fromJson(Map<String, dynamic> json) =>
      _$EmbassyNewsModelFromJson(json);

  factory EmbassyNewsModel.fromEntity(EmbassyNews entity) {
    return EmbassyNewsModel(
      id: entity.id,
      title: entity.title,
      content: entity.content,
      date: entity.date,
      imageUrl: entity.imageUrl,
    );
  }
}

extension EmbassyNewsModelX on EmbassyNewsModel {
  EmbassyNews toEntity() {
    return EmbassyNews(
      id: id,
      title: title,
      content: content,
      date: date,
      imageUrl: imageUrl,
    );
  }
}
