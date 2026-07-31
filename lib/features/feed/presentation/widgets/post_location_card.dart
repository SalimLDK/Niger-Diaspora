import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../map/presentation/utils/location_pin_generator.dart';
import '../theme/feed_tokens.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Aperçu du lieu joint à un post (§13/23d) — carte statique + adresse,
/// adapté de `LocationMessageBubble` (messages) pour une carte de fil.
class PostLocationCard extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String address;

  const PostLocationCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
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
    final tokens = FeedTokens.of(context);
    return GestureDetector(
      onTap: _openInMaps,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: FutureBuilder<BitmapDescriptor>(
                future: LocationPinGenerator.getPin(color: tokens.accent),
                builder: (context, snapshot) {
                  return IgnorePointer(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(latitude, longitude),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('post_location'),
                          position: LatLng(latitude, longitude),
                          icon: snapshot.data ??
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
                      liteModeEnabled: true,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  AppIcon(AppIcon.location, size: 16, color: tokens.mutedText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address.isNotEmpty ? address : 'Position partagée',
                      style: TextStyle(fontSize: 13, color: tokens.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 14, color: tokens.mutedText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
