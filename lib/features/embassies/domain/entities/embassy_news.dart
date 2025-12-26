import 'package:equatable/equatable.dart';

class EmbassyNews extends Equatable {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String? imageUrl;

  const EmbassyNews({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, title, content, date, imageUrl];
}
