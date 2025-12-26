import 'package:equatable/equatable.dart';

class EmbassyActivity extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final String? imageUrl;

  const EmbassyActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, title, description, date, location, imageUrl];
}
