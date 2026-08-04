import 'package:equatable/equatable.dart';
import '../../domain/entities/poll_entity.dart';

class PollOptionModel extends Equatable {
  final String id;
  final String label;
  final int voteCount;
  final int position;

  const PollOptionModel({
    required this.id,
    required this.label,
    this.voteCount = 0,
    this.position = 0,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      voteCount: json['voteCount'] as int? ?? 0,
      position: json['position'] as int? ?? 0,
    );
  }

  PollOptionEntity toEntity() =>
      PollOptionEntity(id: id, label: label, voteCount: voteCount);

  @override
  List<Object?> get props => [id, label, voteCount, position];
}

class PollModel extends Equatable {
  final String id;
  final String contextType;
  final String contextId;
  final String question;
  final List<PollOptionModel> options;
  final bool allowMultiple;
  final DateTime? endsAt;
  final int totalVotes;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final List<String> votedOptionIds;

  const PollModel({
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  factory PollModel.fromJson(Map<String, dynamic> json) {
    return PollModel(
      id: json['id'] as String? ?? '',
      contextType: json['contextType'] as String? ?? 'group',
      contextId: json['contextId'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => PollOptionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      allowMultiple: json['allowMultiple'] as bool? ?? false,
      endsAt: _parseDateTime(json['endsAt']),
      totalVotes: json['totalVotes'] as int? ?? 0,
      createdBy: json['createdBy'] as String?,
      createdByName: json['createdByName'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      votedOptionIds: (json['votedOptionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  PollEntity toEntity() => PollEntity(
        id: id,
        contextType: contextType == 'post'
            ? PollContextType.post
            : PollContextType.group,
        contextId: contextId,
        question: question,
        options: options.map((o) => o.toEntity()).toList(),
        allowMultiple: allowMultiple,
        endsAt: endsAt,
        totalVotes: totalVotes,
        createdBy: createdBy,
        createdByName: createdByName,
        createdAt: createdAt,
        votedOptionIds: votedOptionIds,
      );

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
