import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_tokens.dart';

/// Les quatre échecs de chargement du fil (maquette 2b), rendus séparément.
///
/// L'écran affichait le même message et le même bouton « Réessayer » quelle
/// que soit la cause. Or les réactions attendues diffèrent : sans réseau il
/// n'y a rien à réessayer tout de suite, sur une panne serveur c'est à nous
/// de reprendre la main, et sur un réseau lent réessayer a du sens.
class FeedErrorState extends StatefulWidget {
  final FeedFailure failure;
  final VoidCallback onRetry;

  const FeedErrorState({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  @override
  State<FeedErrorState> createState() => _FeedErrorStateState();
}

class _FeedErrorStateState extends State<FeedErrorState> {
  /// Délai avant reprise automatique sur panne serveur. Assez long pour
  /// laisser le serveur se remettre, assez court pour ne pas paraître figé.
  static const _serverRetryDelay = 15;

  Timer? _countdown;
  int _secondsLeft = _serverRetryDelay;

  @override
  void initState() {
    super.initState();
    if (widget.failure == FeedFailure.serverDown) _startCountdown();
  }

  @override
  void didUpdateWidget(FeedErrorState old) {
    super.didUpdateWidget(old);
    if (old.failure != widget.failure) {
      _countdown?.cancel();
      _countdown = null;
      if (widget.failure == FeedFailure.serverDown) {
        _secondsLeft = _serverRetryDelay;
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        widget.onRetry();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);

    final (icon, title, body) = switch (widget.failure) {
      FeedFailure.noConnection => (
          Icons.wifi_off_rounded,
          l10n.feedErrorNoConnectionTitle,
          l10n.feedErrorNoConnectionBody,
        ),
      FeedFailure.serverDown => (
          Icons.cloud_off_rounded,
          l10n.feedErrorServerTitle,
          l10n.feedErrorServerBody,
        ),
      FeedFailure.slowNetwork => (
          Icons.network_check_rounded,
          l10n.feedErrorSlowTitle,
          l10n.feedErrorSlowBody,
        ),
      FeedFailure.unknown => (
          Icons.error_outline_rounded,
          l10n.feedErrorUnknownTitle,
          l10n.feedErrorUnknownBody,
        ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: tokens.mutedText),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: tokens.mutedText),
          ),
          const SizedBox(height: 20),
          if (widget.failure == FeedFailure.serverDown) ...[
            Text(
              l10n.feedErrorServerCountdown(_secondsLeft),
              style: TextStyle(fontSize: 12, color: tokens.mutedText),
            ),
            const SizedBox(height: 10),
          ],
          // Sans réseau, réessayer n'aboutira pas : on ne propose pas un
          // bouton qui échouera à coup sûr.
          if (widget.failure != FeedFailure.noConnection)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: tokens.accent),
              onPressed: widget.onRetry,
              child: Text(l10n.retry),
            ),
        ],
      ),
    );
  }
}

/// Bandeau au-dessus du fil quand les publications affichées viennent du
/// cache local (maquette 2a).
class FeedCachedNotice extends StatelessWidget {
  final DateTime? cachedAt;

  const FeedCachedNotice({super.key, this.cachedAt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: tokens.mutedText.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 15, color: tokens.mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cachedAt == null
                  ? l10n.feedCachedNoticeUnknownTime
                  : l10n.feedCachedNotice(_relative(l10n, cachedAt!)),
              style: TextStyle(fontSize: 12, color: tokens.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  /// Âge du cache en clair. Une date absolue serait moins parlante que
  /// « il y a 20 min » quand on cherche à savoir si l'info est fraîche.
  String _relative(AppLocalizations l10n, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.justNow;
    if (d.inMinutes < 60) return l10n.minutesAgo(d.inMinutes);
    if (d.inHours < 24) return l10n.hoursAgo(d.inHours);
    return l10n.daysAgo(d.inDays);
  }
}

/// Publication dont l'envoi a échoué, gardée en tête du fil (maquette 2b,
/// cas 4). Le même motif existait déjà côté Messages ; il manquait au Fil,
/// où un échec faisait simplement disparaître le texte saisi.
class FailedPostCard extends StatelessWidget {
  final String content;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  const FailedPostCard({
    super.key,
    required this.content,
    required this.onRetry,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = FeedTokens.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.feedPostNotSent,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: tokens.text),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.feedPostNotSentHint,
            style: TextStyle(fontSize: 11.5, color: tokens.mutedText),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDiscard,
                child: Text(
                  l10n.feedPostDiscard,
                  style: TextStyle(color: tokens.mutedText),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: tokens.accent),
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
