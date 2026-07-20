import 'package:equatable/equatable.dart';

/// Attribution d'un repartage affiché dans le fil : qui a reposté, quand, et la
/// citation éventuelle. Porté à côté du [PostEntity] (jamais dedans) pour rester
/// une préoccupation de présentation du feed.
class RepostRef extends Equatable {
  final String reposterId;
  final String reposterName;
  final String? comment;
  final DateTime repostedAt;

  const RepostRef({
    required this.reposterId,
    required this.reposterName,
    this.comment,
    required this.repostedAt,
  });

  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  @override
  List<Object?> get props => [reposterId, reposterName, comment, repostedAt];
}
