import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/date_formatter.dart';
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

/// Forme compacte de l'anciennete : « 12 min », « 3 j » en francais, « 12m »,
/// « ~1d » ailleurs.
///
/// Le francais passe par [DateFormatter.timeAgoShort], qui est le vocabulaire
/// compact deja en place dans l'app (cartes « Enregistres ») ; on ne le
/// redouble pas ici. `FrShortMessages` de timeago ne conviendrait pas : malgre
/// son nom, il se contente de retirer le « environ » et rend encore
/// « il y a un jour ».
String _formatTimeAgoCompact(DateTime dt, BuildContext context) {
  final locale = Localizations.localeOf(context).languageCode;
  if (locale == 'fr') return DateFormatter.timeAgoShort(dt);
  return timeago.format(dt, locale: 'en_short');
}

/// Rend la forme longue de [_formatTimeAgo] tant qu'elle tient dans [plafond],
/// la forme compacte sinon.
///
/// L'en-tete du sondage doit tenir dans une bulle de discussion large de
/// 288 px, ou « il y a environ un jour » depasse a lui seul (269,5 px) la
/// place laissee par l'icone. Tronquer serait pire que raccourcir : « il y a
/// envi... » supprime justement l'information que le libelle porte.
///
/// On **mesure** au lieu de se fier a la largeur seule, parce que le facteur
/// d'echelle de police vient des reglages de l'appareil : la meme rangee
/// deborde sur un ecran large des que l'utilisateur grossit le texte.
String _libelleTempsTenantEn(
  DateTime dt,
  BuildContext context,
  TextStyle style,
  double plafond,
) {
  final complet = _formatTimeAgo(dt, context);
  final peintre = TextPainter(
    text: TextSpan(text: complet, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return peintre.width <= plafond
      ? complet
      : _formatTimeAgoCompact(dt, context);
}

/// Carte de sondage avec vote inline, reutilisable pour un groupe ou un post.
class PollCard extends ConsumerStatefulWidget {
  final PollEntity poll;
  final String? groupId;
  final String? postId;

  /// Rayons imposes par le contenant. Dans une bulle de discussion, ce sont
  /// ceux de la bulle : sans eux, son coin de queue (arrondi a 6) depassait
  /// de la carte (arrondie a 16) et laissait voir le fond de la bulle.
  final BorderRadiusGeometry? borderRadius;

  const PollCard({
    super.key,
    required this.poll,
    this.groupId,
    this.postId,
    this.borderRadius,
  });

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
      decoration: widget.borderRadius == null
          ? context.cardDecoration
          : context.cardDecoration.copyWith(borderRadius: widget.borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Le libelle de temps garde sa largeur naturelle — c'est ce qui le
          // laisse colle a droite et donne au nom tout le reste. Le rendre
          // `Flexible` a cote d'un `Expanded` le casserait : deux enfants
          // flexibles ne recoivent plus leur largeur intrinseque mais une
          // part de l'espace libre au prorata des flex, donc un nom fige a la
          // moitie de la rangee et un blanc entre lui et l'heure.
          LayoutBuilder(
            builder: (context, contraintes) {
              final styleTemps = TextStyle(
                fontSize: 12,
                color: context.textTertiaryColor,
              );
              // L'icone et son espace ne participent pas au partage entre le
              // nom et l'heure.
              final largeurUtile = contraintes.maxWidth - 18 - 8;
              // Le nom de l'auteur est l'information principale : l'heure ne
              // prend jamais plus de la moitie de ce qui reste.
              final plafondTemps = largeurUtile > 0 ? largeurUtile / 2 : 0.0;
              final libelleTemps = poll.createdAt == null
                  ? null
                  : _libelleTempsTenantEn(
                      poll.createdAt!,
                      context,
                      styleTemps,
                      plafondTemps,
                    );

              return Row(
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
                  if (libelleTemps != null)
                    // Dernier filet : a une echelle de police extreme, meme la
                    // forme compacte peut deborder. L'ellipse est alors le
                    // moindre mal.
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: plafondTemps),
                      child: Text(
                        libelleTemps,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styleTemps,
                      ),
                    ),
                ],
              );
            },
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
