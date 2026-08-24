import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../polls/presentation/providers/poll_provider.dart';
import '../../../polls/presentation/widgets/poll_card.dart';

/// Bulle « sondage » d'une conversation.
///
/// Le message ne transporte que `pollId` : la question, les options et les
/// compteurs sont relus depuis `post_polls` a chaque affichage. Voter ne
/// reecrit donc jamais le message — c'est la carte qui se met a jour.
class PollMessageBubble extends ConsumerWidget {
  final String pollId;

  /// Question au moment de l'envoi : sert de repli tant que le sondage
  /// n'est pas charge, pour ne pas afficher une bulle vide.
  final String fallbackQuestion;

  final String? groupId;

  const PollMessageBubble({
    super.key,
    required this.pollId,
    required this.fallbackQuestion,
    this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollAsync = ref.watch(pollStreamProvider(pollId));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: pollAsync.when(
        data: (poll) => poll == null
            ? _placeholder(context, 'Sondage supprimé')
            : PollCard(poll: poll, groupId: groupId),
        loading: () => _placeholder(context, fallbackQuestion),
        error: (_, __) => _placeholder(context, fallbackQuestion),
      ),
    );
  }

  Widget _placeholder(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.textSecondaryColor,
        ),
      ),
    );
  }
}
