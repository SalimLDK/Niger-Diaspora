import 'package:equatable/equatable.dart';

/// Contexte dans lequel un poll est publié (post du feed ou groupe).
enum PollContextType { post, group }

class PollOptionEntity extends Equatable {
  final String id;
  final String label;
  final int voteCount;

  const PollOptionEntity({
    required this.id,
    required this.label,
    this.voteCount = 0,
  });

  PollOptionEntity copyWith({String? id, String? label, int? voteCount}) {
    return PollOptionEntity(
      id: id ?? this.id,
      label: label ?? this.label,
      voteCount: voteCount ?? this.voteCount,
    );
  }

  @override
  List<Object?> get props => [id, label, voteCount];
}

/// Entite representant un sondage, reutilisable pour un post du feed ou un groupe.
class PollEntity extends Equatable {
  final String id;
  final PollContextType contextType;
  final String contextId;
  final String question;
  final List<PollOptionEntity> options;
  final bool allowMultiple;
  final DateTime? endsAt;
  final int totalVotes;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final List<String> votedOptionIds;

  const PollEntity({
    required this.id,
    required this.contextType,
    required this.contextId,
    required this.question,
    this.options = const [],
    this.allowMultiple = false,
    this.endsAt,
    this.totalVotes = 0,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.votedOptionIds = const [],
  });

  bool get isExpired => endsAt != null && DateTime.now().isAfter(endsAt!);

  bool get hasVoted => votedOptionIds.isNotEmpty;

  bool get canVote => !isExpired && !hasVoted;

  double percentageFor(PollOptionEntity option) {
    if (totalVotes == 0) return 0;
    return option.voteCount / totalVotes;
  }

  PollEntity copyWith({
    String? id,
    PollContextType? contextType,
    String? contextId,
    String? question,
    List<PollOptionEntity>? options,
    bool? allowMultiple,
    DateTime? endsAt,
    int? totalVotes,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    List<String>? votedOptionIds,
  }) {
    return PollEntity(
      id: id ?? this.id,
      contextType: contextType ?? this.contextType,
      contextId: contextId ?? this.contextId,
      question: question ?? this.question,
      options: options ?? this.options,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      endsAt: endsAt ?? this.endsAt,
      totalVotes: totalVotes ?? this.totalVotes,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      votedOptionIds: votedOptionIds ?? this.votedOptionIds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        contextType,
        contextId,
        question,
        options,
        allowMultiple,
        endsAt,
        totalVotes,
        createdBy,
        createdByName,
        createdAt,
        votedOptionIds,
      ];
}

/// Un votant pour l'ecran de resultats detailles (qui a vote quoi).
class PollVoterEntity extends Equatable {
  final String userId;
  final String? name;
  final String? photoUrl;

  const PollVoterEntity({required this.userId, this.name, this.photoUrl});

  @override
  List<Object?> get props => [userId, name, photoUrl];
}
