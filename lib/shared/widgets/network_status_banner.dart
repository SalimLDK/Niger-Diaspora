import 'dart:async';

import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/connectivity_provider.dart';

class NetworkStatusBanner extends ConsumerStatefulWidget {
  final Widget child;

  const NetworkStatusBanner({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends ConsumerState<NetworkStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _wasOffline = false;
  bool _showRestoredMessage = false;
  Timer? _restoredTimer;
  bool? _lastConnectivityState;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _restoredTimer?.cancel();
    super.dispose();
  }

  void _handleConnectivityChange(bool isConnected) {
    // Avoid processing if connectivity state hasn't changed
    if (_lastConnectivityState == isConnected) return;
    _lastConnectivityState = isConnected;

    if (!isConnected) {
      _wasOffline = true;
      _showRestoredMessage = false;
      _animationController.forward();
    } else if (_wasOffline) {
      _showRestoredMessage = true;
      setState(() {});
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _animationController.reverse();
          setState(() {
            _showRestoredMessage = false;
            _wasOffline = false;
          });
        }
      });
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen<AsyncValue<bool>>(connectivityStatusProvider, (previous, next) {
      next.whenData((isConnected) {
        _handleConnectivityChange(isConnected);
      });
    });

    return Column(
      children: [
        SizeTransition(
          sizeFactor: _animation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: _showRestoredMessage
                  ? AppColors.secondary
                  : AppColors.primary,
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showRestoredMessage ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _showRestoredMessage
                          ? l10n.connectionRestored
                          : l10n.offlineBannerMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.offlineMode,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
