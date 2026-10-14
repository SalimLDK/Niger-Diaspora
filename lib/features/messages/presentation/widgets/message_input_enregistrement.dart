part of 'message_input.dart';

/// Interface d'enregistrement vocal : bandeau, verrou, onde, annulation.
extension _EnregistrementSaisie on _MessageInputState {
  /// Bandeau d'enregistrement (fond selon l'état : en cours / annulation armée).
  Widget _buildRecordingBanner(BuildContext context) {
    final bg =
        _isCancelling
            ? (context.isDarkMode
                ? context.errorColor.withValues(alpha: 0.15)
                : _kBannerCancelBg)
            : (context.isDarkMode
                ? context.surfaceVariantColor
                : _kBannerRecordingBg);
    final borderColor =
        _isCancelling
            ? (context.isDarkMode
                ? context.errorColor.withValues(alpha: 0.4)
                : _kBannerCancelBorder)
            : (context.isDarkMode
                ? AppColors.borderDark
                : _kBannerRecordingBorder);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: _buildInlineRecordingUI(context),
    );
  }

  /// UI d'enregistrement inline (remplace l'input pendant l'enregistrement)
  Widget _buildInlineRecordingUI(BuildContext context) {
    final cancelProgress = (_dragOffset.abs() / 100).clamp(0.0, 1.0);
    final showCancelHint = _dragOffset < -30;
    final showLockIndicator = _verticalDragOffset < -20 && !_isLocked;

    if (_isLocked) {
      // Mode verrouillé : afficher les boutons d'action
      return _buildLockedRecordingUI(context);
    }

    // Mode normal : afficher l'UI d'enregistrement avec hints
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicateur flottant "Relâchez pour verrouiller" (état 4)
        if (showLockIndicator) _buildFloatingLockIndicator(context),

        // Minuterie + waveform sur la première ligne.
        Row(
          children: [
            _buildRecordingIndicator(context),
            const SizedBox(width: 12),
            Expanded(child: _buildSimpleWaveform(context)),
          ],
        ),

        const SizedBox(height: 4),

        // Le libellé a désormais **sa propre ligne**, sur toute la largeur.
        //
        // Il partageait la ligne avec la minuterie et le waveform, et n'en
        // recevait que 2/5 : sur l'appareil (A51, font_scale 1.1) « Relâcher
        // pour annuler » devenait « Relâc… » et « L'enregistrement sera
        // supprimé » devenait « L'enregi… ». Autrement dit, au moment précis
        // où l'utilisateur renonce, il ne pouvait pas lire ce qui allait
        // arriver à son enregistrement. Le waveform, lui, ne dit rien d'utile :
        // il pouvait céder la place.
        SizedBox(
          width: double.infinity,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child:
                showCancelHint
                    ? _buildCancelHint(context, cancelProgress)
                    : _buildDefaultRecordingHint(context),
          ),
        ),
      ],
    );
  }

  /// Indicateur flottant qui apparaît quand on glisse vers le haut
  Widget _buildFloatingLockIndicator(BuildContext context) {
    final progress = (_verticalDragOffset.abs() / 50).clamp(0.0, 1.0);
    final isNearLock = _verticalDragOffset < -40;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            isNearLock
                ? context.adaptivePrimaryColor.withValues(alpha: 0.2)
                : context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.adaptivePrimaryColor.withValues(alpha: progress * 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isNearLock
              ? AppIcon(
                AppIcon.lock,
                color: context.adaptivePrimaryColor.withValues(
                  alpha: 0.5 + progress * 0.5,
                ),
                size: 20,
              )
              : AppIcon(
                AppIcon.lockOpen,
                color: context.adaptivePrimaryColor.withValues(
                  alpha: 0.5 + progress * 0.5,
                ),
                size: 20,
              ),
          const SizedBox(width: 8),
          Text(
            isNearLock
                ? AppLocalizations.of(context)!.releaseToLock
                : AppLocalizations.of(context)!.slideUpToLock,
            style: TextStyle(
              color: context.textSecondaryColor.withValues(
                alpha: 0.7 + progress * 0.3,
              ),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelHint(BuildContext context, double progress) {
    return Row(
      key: const ValueKey('cancel'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_outline, color: context.errorColor, size: 22),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.releaseToCancelNow,
                style: TextStyle(
                  color: context.errorColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                AppLocalizations.of(context)!.recordingWillBeDeleted,
                style: TextStyle(
                  color: context.errorColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
                // Deux lignes plutôt qu'une coupure : à forte échelle de
                // police, la conséquence de l'annulation doit rester lisible.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultRecordingHint(BuildContext context) {
    // Hint "Annuler" avec flèche - le cadenas est au-dessus du bouton micro
    return Row(
      key: const ValueKey('default'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.arrow_back_ios_rounded,
          color: context.textTertiaryColor,
          size: 16,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.recordingGestureHints,
            style: TextStyle(
              color: context.textTertiaryColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            // « Glisser ‹ pour annuler · ↑ pour verrouiller » fait 43
            // caractères : à font_scale 1.1 il ne tient pas sur une ligne,
            // et il devenait « Glisser ‹… », ce qui n'apprend rien.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator(BuildContext context) {
    return StreamBuilder<int>(
      stream: _recordingService.durationStream,
      initialData: 0,
      builder: (context, snapshot) {
        final duration = snapshot.data ?? 0;
        final minutes = duration ~/ 60;
        final secs = duration % 60;
        final durationText = '$minutes:${secs.toString().padLeft(2, '0')}';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing red dot
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: context.errorColor.withValues(alpha: value),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              durationText,
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimpleWaveform(BuildContext context) {
    return StreamBuilder<double>(
      stream: _recordingService.amplitudeStream,
      initialData: 0.3,
      builder: (context, snapshot) {
        final amplitude = snapshot.data ?? 0.3;
        return Container(
          height: 32,
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(15, (index) {
              final height = 8 + (amplitude * 16 * ((index % 3) + 1) / 3);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 3,
                height: height.clamp(4.0, 24.0),
                decoration: BoxDecoration(
                  color:
                      _isCancelling
                          ? context.errorColor
                          : context.adaptivePrimaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildLockedRecordingUI(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge "Enregistrement verrouillé"
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcon.lock,
                color: context.adaptivePrimaryColor,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.recordingLockedBadge,
                style: TextStyle(
                  color: context.adaptivePrimaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        // Le badge seul ne dit pas pourquoi l'enregistrement continue sans
        // le doigt (§4f) : la phrase le dit.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            AppLocalizations.of(context)!.recordingHandsFree,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textTertiaryColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Ligne de contrôles
        Row(
          children: [
            // Delete button
            GestureDetector(
              onTap: () async {
                await _recordingService.cancelRecording();
                _resetRecordingState();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: AppIcon(
                  AppIcon.delete,
                  color: context.errorColor,
                  size: 22,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Recording indicator
            _buildRecordingIndicator(context),

            const SizedBox(width: 10),

            // Waveform
            Expanded(child: _buildSimpleWaveform(context)),

            const SizedBox(width: 12),

            // Send button
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.adaptivePrimaryColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const AppIcon(
                  AppIcon.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

