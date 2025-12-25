import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ToastUtils {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void _show(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    hide(); // Clear any existing toast immediately

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            bottom: 80, // Positioned above the bottom nav (roughly)
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isError ? Colors.red : AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(_currentEntry!);

    // Auto hide after 2 seconds
    _timer = Timer(const Duration(seconds: 2), () {
      hide();
    });
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;

    if (_currentEntry != null) {
      try {
        _currentEntry!.remove();
      } catch (e) {
        // Ignore if already removed
      }
      _currentEntry = null;
    }
  }
}
