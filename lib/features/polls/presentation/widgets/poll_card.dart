import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../domain/entities/poll_entity.dart';
import '../providers/poll_provider.dart';

const _pollAccent = Color(0xFF6B5CE0);

String _formatTimeAgo(DateTime dt, BuildContext context) {
  final locale = Localizations.localeOf(context).languageCode;
  if (locale == 'fr') {
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    return timeago.format(dt, locale: 'fr');
  }
  return timeago.format(dt);
}

/// Carte de sondage avec vote inline, reutilisable pour un groupe ou un post.
class PollCard extends ConsumerStatefulWidget {
  final PollEntity poll;
  final String? groupId;
  final String? postId;

  const PollCard({super.key, required this.poll, this.groupId, this.postId});

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  final Set<String> _selected = {};
  bool _isVoting = false;

  Future<void> _submitVote() async {
    if (_selected.isEmpty) return;
    setState(() => _isVoting = true);
    final success = await ref.read(pollActionsNotifierProvider.notifier).vote(
          widget.poll.id,
          _selected.toList(),
          groupId: widget.groupId,
          postId: widget.postId,
        );
    if (!mounted) return;
    setState(() => _isVoting = false);
    if (success) {
      setState(() => _selected.clear());
    }
  }

  void _toggleOption(String optionId) {
    setState(() {
      if (widget.poll.allowMultiple) {
        _selected.contains(optionId)
            ? _selected.remove(optionId)
            : _selected.add(optionId);
      } else {
        _selected
          ..clear()
          ..add(optionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final showResults = !poll.canVote;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(AppIcon.poll, size: 18, color: _pollAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.createdByName ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
              if (poll.createdAt != null)
                Text(
                  _formatTimeAgo(poll.createdAt!, context),
                  style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            poll.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ...poll.options.map((option) {
            final isSelected = _selected.contains(option.id) ||
                poll.votedOptionIds.contains(option.id);
            final percentage = poll.percentageFor(option);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: showResults || _isVoting
                    ? null
                    : () => _toggleOption(option.id),
                child: Stack(
                  children: [
                    if (showResults)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage.clamp(0, 1),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _pollAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected && !showResults
                              ? _pollAccent
                              : context.borderColor,
                          width: isSelected && !showResults ? 1.6 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: context.textPrimaryColor,
                              ),
                            ),
                          ),
                          if (showResults)
                            Text(
                              '${(percentage * 100).round()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondaryColor,
                              ),
                            )
                          else if (isSelected)
                            Icon(
                              widget.poll.allowMultiple
                                  ? Icons.check_box
                                  : Icons.radio_button_checked,
                              size: 18,
                              color: _pollAccent,
                            )
                          else
                            Icon(
                              widget.poll.allowMultiple
                                  ? Icons.check_box_outline_blank
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: context.textTertiaryColor,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${poll.totalVotes} vote${poll.totalVotes > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
              ),
              if (poll.isExpired) ...[
                const Text(' · '),
                Text(
                  'Terminé',
                  style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
                ),
              ],
              const Spacer(),
              if (_selected.isNotEmpty && !showResults)
                TextButton(
                  onPressed: _isVoting ? null : _submitVote,
                  child: _isVoting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Voter'),
                )
              else
                TextButton(
                  onPressed: () => context.push('/polls/${poll.id}/results'),
                  child: const Text('Voir les résultats'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
