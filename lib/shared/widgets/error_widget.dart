import 'dart:async';

import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/error_types.dart';
import '../../core/errors/failures.dart';
import 'custom_button.dart';

class CustomErrorWidget extends StatefulWidget {
  final String? message;
  final Failure? failure;
  final VoidCallback? onRetry;
  final int? autoRetrySeconds;

  const CustomErrorWidget({
    super.key,
    this.message,
    this.failure,
    this.onRetry,
    this.autoRetrySeconds,
  }) : assert(message != null || failure != null);

  const CustomErrorWidget.fromFailure({
    super.key,
    required Failure this.failure,
    this.onRetry,
    this.autoRetrySeconds,
  }) : message = null;

  @override
  State<CustomErrorWidget> createState() => _CustomErrorWidgetState();
}

class _CustomErrorWidgetState extends State<CustomErrorWidget> {
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoRetrySeconds != null && widget.onRetry != null) {
      _remainingSeconds = widget.autoRetrySeconds!;
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        widget.onRetry?.call();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final failure = widget.failure;

    final displayMessage = failure != null
        ? failure.getLocalizedMessage(context)
        : widget.message!;

    final icon = failure?.icon ?? Icons.error_outline;
    final iconColor = failure?.iconColor ?? AppColors.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oups !',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 24),
              if (_remainingSeconds > 0)
                Text(
                  l10n.retryIn(_remainingSeconds),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                )
              else
                CustomButton(
                  onPressed: widget.onRetry!,
                  label: l10n.retry,
                  width: 200,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
