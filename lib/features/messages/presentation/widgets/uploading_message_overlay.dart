import 'package:flutter/material.dart';

/// Overlay de progression affiché sur un message pendant l'upload
class UploadingMessageOverlay extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final VoidCallback onCancel;
  final bool isImage;

  const UploadingMessageOverlay({
    super.key,
    required this.progress,
    required this.onCancel,
    this.isImage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: GestureDetector(
            onTap: onCancel,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress indicator
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  // Cancel icon
                  const Icon(Icons.close, color: Colors.white, size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
