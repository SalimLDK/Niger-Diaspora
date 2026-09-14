import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../domain/entities/poll_entity.dart';
import '../providers/poll_provider.dart';
import '../theme/poll_tokens.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final Set<String> _selected = {};
  bool _isVoting = false;

  /// Vrai quand on a rouvert la selection pour changer d'avis. Le sondage
  /// reste modifiable tant qu'il n'est pas termine : la policy DELETE
  /// « Users can retract their own vote » existe en base depuis le debut.
  bool _editing = false;

  /// Les resultats remplacent les cases a cocher : sondage termine, ou deja
  /// vote sans avoir demande a se corriger.
  bool get _showResults =>
      widget.poll.isExpired || (widget.poll.hasVoted && !_editing);

  Future<void> _submitVote() async {
    setState(() => _isVoting = true);
    final success = await ref.read(pollActionsNotifierProvider.notifier).vote(
          widget.poll.id,
          _selected.toList(),
          groupId: widget.groupId,
          postId: widget.postId,
        );
    if (!mounted) return;
    setState(() {
      _isVoting = false;
      if (success) {
        _selected.clear();
        _editing = false;
      }
    });
    if (!success) {
      // Meme regle que la feuille de creation : la cause remontee par le
      // notifier vaut mieux qu'un message generique, qui a deja masque des
      // mois durant un refus RLS.
      final cause = ref.read(pollActionsNotifierProvider).error?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cause == null || cause.isEmpty
                ? l10n.pollVoteFailed
                : '${l10n.pollVoteFailed} : $cause',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _selected
        ..clear()
        ..addAll(widget.poll.votedOptionIds);
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _selected.clear();
    });
  }

  void _toggleOption(String optionId) {
    setState(() {
      if (_selected.contains(optionId)) {
        // Deselectionner reste possible en choix unique : c'est ce qui permet
        // de retirer son vote sans en poser un autre.
        _selected.remove(optionId);
      } else {
        if (!widget.poll.allowMultiple) _selected.clear();
        _selected.add(optionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final showResults = _showResults;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(AppIcon.poll, size: 18, color: kPollAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.createdByName ?? '',
                  overflow: TextOverflow.ellipsis,
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
          // La regle de confidentialite se lit AVANT de choisir, pas sur
          // l'ecran de resultats ou il est trop tard.
          const SizedBox(height: 4),
          Text(
            poll.isAnonymous ? l10n.pollVotesAreAnonymous : l10n.pollVotesArePublic,
            style: TextStyle(fontSize: 11.5, color: context.textTertiaryColor),
          ),
          const SizedBox(height: 10),
          ...poll.options.map((option) {
            final isSelected = showResults
                ? poll.votedOptionIds.contains(option.id)
                : _selected.contains(option.id);
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
                              color: kPollAccent.withValues(alpha: 0.12),
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
                          color: isSelected ? kPollAccent : context.borderColor,
                          width: isSelected ? 1.6 : 1,
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
                          const SizedBox(width: 8),
                          if (showResults)
                            Text(
                              '${(percentage * 100).round()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondaryColor,
                              ),
                            )
                          else
                            Icon(
                              poll.allowMultiple
                                  ? (isSelected
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank)
                                  : (isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked),
                              size: 18,
                              color: isSelected
                                  ? kPollAccent
                                  : context.textTertiaryColor,
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
          _pied(context),
        ],
      ),
    );
  }

  /// Pied de carte : le compte de voix, et les actions.
  ///
  /// Une seule action tient sur la ligne du compte — c'est le cas courant
  /// (« Voter », ou « Voir les resultats »). Deux actions passent sur leur
  /// propre ligne, alignees a droite : sur une bulle RECUE, plus etroite
  /// qu'une bulle envoyee, elles ne tenaient pas a cote du compte, et un
  /// `Wrap` unique les empilait en laissant « N votes » centre entre les
  /// deux — verifie sur SM A515F le 2026-09-14. Rien ne deborde dans aucun
  /// des deux cas, l'echelle de police comprise.
  Widget _pied(BuildContext context) {
    final poll = widget.poll;
    final actions = _actions();
    final compte = Text(
      poll.isExpired
          ? '${l10n.pollVotesCount(poll.totalVotes)} · ${l10n.pollClosedToVotes}'
          : l10n.pollVotesCount(poll.totalVotes),
      style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
    );

    if (actions.length <= 1) {
      return Row(
        children: [
          Expanded(child: compte),
          if (actions.isNotEmpty) actions.single,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        compte,
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ),
      ],
    );
  }

  List<Widget> _actions() {
    final poll = widget.poll;

    if (_isVoting) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    if (!_showResults) {
      return [
        if (_editing)
          TextButton(onPressed: _cancelEditing, child: Text(l10n.cancel)),
        // En correction, une selection vide est un retrait de vote — c'est le
        // seul chemin vers la policy « Users can retract their own vote ».
        if (_editing || _selected.isNotEmpty)
          TextButton(
            onPressed: _submitVote,
            child: Text(
              _editing && _selected.isEmpty
                  ? l10n.pollWithdrawVote
                  : l10n.pollVoteAction,
            ),
          )
        else
          TextButton(
            onPressed: () => context.push('/polls/${poll.id}/results'),
            child: Text(l10n.pollViewResults),
          ),
      ];
    }

    return [
      if (!poll.isExpired && poll.hasVoted)
        TextButton(onPressed: _startEditing, child: Text(l10n.pollChangeVote)),
      TextButton(
        onPressed: () => context.push('/polls/${poll.id}/results'),
        child: Text(l10n.pollViewResults),
      ),
    ];
  }
}
