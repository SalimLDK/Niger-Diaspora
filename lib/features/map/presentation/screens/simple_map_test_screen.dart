import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SimpleMapTestScreen extends StatelessWidget {
  const SimpleMapTestScreen({super.key});

  static const LatLng _defaultPosition = LatLng(13.5116, 2.1254);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Carte Simple'),
        backgroundColor: Colors.orange,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _defaultPosition,
          zoom: 10,
        ),
        onMapCreated: (controller) {
          // debugPrint('✅ Google Map créée avec succès!');
        },
      ),
    );
  }
}
