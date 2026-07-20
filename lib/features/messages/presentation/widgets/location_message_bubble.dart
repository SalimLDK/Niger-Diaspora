import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../map/presentation/utils/location_pin_generator.dart';
import '../../domain/entities/message_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Bulle de message pour afficher une position partagée
class LocationMessageBubble extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String address;
  final bool isMe;
  final DateTime? createdAt;
  final MessageStatus? status;
  final List<String>? readBy;
  final List<String>? deliveredTo;
  final String? senderId;
  final VoidCallback? onRetry;

  const LocationMessageBubble({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.isMe,
    this.createdAt,
    this.status,
    this.readBy,
    this.deliveredTo,
    this.senderId,
    this.onRetry,
  });

  Future<void> _openInMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = status == MessageStatus.failed;

    return GestureDetector(
      onTap: isFailed && onRetry != null ? onRetry : _openInMaps,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isMe
              ? context.adaptiveSecondaryColor.withValues(alpha: 0.9)
              : context.adaptivePrimaryColor.withValues(alpha: 0.65),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Static map preview
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  FutureBuilder<BitmapDescriptor>(
                    future: LocationPinGenerator.getPin(
                      color:
                          isMe
                              ? context.adaptiveSecondaryColor
                              : context.adaptivePrimaryColor,
                    ),
                    builder: (context, snapshot) {
                      return GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(latitude, longitude),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('location'),
                            position: LatLng(latitude, longitude),
                            icon:
                                snapshot.data ??
                                BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueOrange,
                                ),
                            anchor: const Offset(0.5, 0.95),
                          ),
                        },
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                        liteModeEnabled: true, // Performance
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                      );
                    },
                  ),
                  // Tap overlay to open in maps or retry
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isFailed && onRetry != null ? onRetry : _openInMaps,
                        child: Container(),
                      ),
                    ),
                  ),
                  // Failed overlay with retry button
                  if (isFailed)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppIcon(AppIcon.error,
                                color: Colors.red,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Échec de l\'envoi',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                              if (onRetry != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'Appuyez pour réessayer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Address and open button
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  AppIcon(AppIcon.location,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.isNotEmpty ? address : 'Position partagée',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Appuyez pour ouvrir',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (createdAt != null)
                                  Text(
                                    _formatTime(createdAt!),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                if (isMe && status != null) ...[
                                  const SizedBox(width: 4),
                                  _buildStatusIcon(),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusIcon() {
    switch (status!) {
      case MessageStatus.sending:
        return AppIcon(AppIcon.clock,
          size: 14,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case MessageStatus.failed:
        return const AppIcon(AppIcon.error, size: 14, color: Colors.red);
      case MessageStatus.sent:
        final otherReadersCount = (readBy ?? [])
            .where((id) => id != senderId)
            .length;
        final isRead = otherReadersCount > 0;

        final otherDeliveredCount = (deliveredTo ?? [])
            .where((id) => id != senderId)
            .length;
        final isDelivered = otherDeliveredCount > 0;

        if (isRead) {
          return const AppIcon(AppIcon.doneAll, size: 16, color: Colors.blue);
        } else if (isDelivered) {
          return AppIcon(AppIcon.doneAll, size: 16, color: Colors.white.withValues(alpha: 0.7));
        } else {
          return AppIcon(AppIcon.check, size: 14, color: Colors.white.withValues(alpha: 0.7));
        }
    }
  }
}
