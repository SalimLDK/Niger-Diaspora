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
import '../theme/poll_tokens.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';

class PollResultsScreen extends ConsumerWidget {
  final String pollId;

  const PollResultsScreen({super.key, required this.pollId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pollAsync = ref.watch(pollStreamProvider(pollId));

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(AppIcon.arrowBack, color: kPollAccent),
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/messages'),
        ),
        title: DesignTitle(l10n.pollResultsTitle, size: 22),
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
            return ErrorView(message: l10n.pollNotFound);
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
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    // L'option gagnante = celle qui a le plus de voix (dès qu'un vote existe).
    final maxVotes = poll.options.isEmpty
        ? 0
        : poll.options
            .map((o) => o.voteCount)
            .reduce((a, b) => a > b ? a : b);

    // Un sondage anonyme ne rend ses votants à personne, pas même à son
    // auteur : inutile de demander, et surtout inutile d'afficher une liste
    // vide qui se lirait comme « personne n'a voté ».
    final voters = poll.isAnonymous
        ? const AsyncValue<Map<String, List<PollVoterEntity>>>.data({})
        : ref.watch(pollVotersProvider(poll.id));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const AppIcon(AppIcon.poll, size: 20, color: kPollAccent),
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
          poll.isExpired
              ? '${l10n.pollVotesTotal(poll.totalVotes)} · ${l10n.pollClosedToVotes}'
              : l10n.pollVotesTotal(poll.totalVotes),
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
            showVoters: !poll.isAnonymous,
            voters: voters,
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            AppIcon(AppIcon.info, size: 14, color: context.textTertiaryColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                poll.isAnonymous
                    ? l10n.pollVotersHidden
                    : l10n.pollVotersVisibleToAll,
                style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionResultCard extends StatelessWidget {
  final PollEntity poll;
  final PollOptionEntity option;
  final FeedTokens tokens;
  final bool isWinner;
  final bool isMyChoice;
  final bool showVoters;
  final AsyncValue<Map<String, List<PollVoterEntity>>> voters;

  const _OptionResultCard({
    required this.poll,
    required this.option,
    required this.tokens,
    required this.isWinner,
    required this.isMyChoice,
    required this.showVoters,
    required this.voters,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final percentage = poll.percentageFor(option);

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
                    l10n.pollMyChoice,
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
          if (showVoters) ...[
            const SizedBox(height: 12),
            voters.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (parOption) {
                final liste = parOption[option.id] ?? const <PollVoterEntity>[];
                if (liste.isEmpty) {
                  return Text(
                    l10n.pollNoVoteYet,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiaryColor,
                    ),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: liste.map((voter) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundImage: voter.photoUrl != null
                            ? CachedNetworkImageProvider(voter.photoUrl!)
                            : null,
                        child: voter.photoUrl == null
                            ? const AppIcon(
                                AppIcon.person,
                                color: kPollAccent,
                                size: 14,
                              )
                            : null,
                      ),
                      label: Text(voter.name ?? l10n.user),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
