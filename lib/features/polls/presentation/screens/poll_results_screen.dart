import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../feed/presentation/theme/feed_tokens.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/poll_entity.dart';
import '../providers/poll_provider.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

const _pollAccent = Color(0xFF6B5CE0);

class PollResultsScreen extends ConsumerWidget {
  final String pollId;

  const PollResultsScreen({super.key, required this.pollId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollAsync = ref.watch(pollStreamProvider(pollId));

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(AppIcon.arrowBack, color: _pollAccent),
          onPressed: () => context.pop(),
        ),
        title: const Text('R├®sultats du sondage'),
      ),
      body: pollAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: ErrorHandler.instance.getShortMessage(
            ErrorHandler.instance.handleException(error),
          ),
        ),
        data: (poll) {
          if (poll == null) {
            return const ErrorView(message: 'Sondage introuvable');
          }
          return _PollResultsBody(poll: poll);
        },
      ),
    );
  }
}

class _PollResultsBody extends ConsumerWidget {
  final PollEntity poll;

  const _PollResultsBody({required this.poll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    // L'option gagnante = celle qui a le plus de voix (dès qu'un vote existe).
    final maxVotes = poll.options.isEmpty
        ? 0
        : poll.options
            .map((o) => o.voteCount)
            .reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const AppIcon(AppIcon.poll, size: 20, color: _pollAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                poll.question,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${poll.totalVotes} vote${poll.totalVotes > 1 ? 's' : ''} au total',
          style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
        ),
        const SizedBox(height: 20),
        for (final option in poll.options)
          _OptionResultCard(
            poll: poll,
            option: option,
            tokens: tokens,
            isWinner: poll.totalVotes > 0 && option.voteCount == maxVotes,
            isMyChoice: poll.votedOptionIds.contains(option.id),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            AppIcon(AppIcon.info, size: 14, color: context.textTertiaryColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Les votes sont visibles par l\'auteur du sondage.',
                style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionResultCard extends ConsumerWidget {
  final PollEntity poll;
  final PollOptionEntity option;
  final FeedTokens tokens;
  final bool isWinner;
  final bool isMyChoice;

  const _OptionResultCard({
    required this.poll,
    required this.option,
    required this.tokens,
    required this.isWinner,
    required this.isMyChoice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percentage = poll.percentageFor(option);
    final votersAsync = ref.watch(
      _optionVotersProvider((pollId: poll.id, optionId: option.id)),
    );

    // Carte de base ; l'option gagnante est encadrée 1,5 px en accent2 (#7A8A5E).
    final baseDecoration = context.cardDecoration;
    final decoration = isWinner
        ? baseDecoration.copyWith(
            border: Border.all(color: tokens.accent2, width: 1.5),
          )
        : baseDecoration;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
              if (isMyChoice) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.accent2.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Votre choix',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.accent2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${option.voteCount} · ${(percentage * 100).round()}%',
                style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barre remplie proportionnellement : fond surface + remplissage
          // accent2 à 35 % sur la largeur du pourcentage.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              color: tokens.surface,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage.clamp(0.0, 1.0),
                child: Container(
                  color: tokens.accent2.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          votersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (voters) {
              if (voters.isEmpty) {
                return Text(
                  'Aucun vote pour le moment',
                  style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: voters.map((voter) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundImage: voter.photoUrl != null
                          ? CachedNetworkImageProvider(voter.photoUrl!)
                          : null,
                      child: voter.photoUrl == null
                          ? const AppIcon(AppIcon.person, color: _pollAccent, size: 14)
                          : null,
                    ),
                    label: Text(voter.name ?? 'Utilisateur'),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

final _optionVotersProvider = FutureProvider.family<
    List<PollVoterEntity>, ({String pollId, String optionId})>((ref, args) async {
  return ref
      .read(pollActionsNotifierProvider.notifier)
      .getOptionVoters(args.pollId, args.optionId);
});
