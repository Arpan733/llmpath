import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';

class CustomMap extends StatelessWidget {
  const CustomMap({super.key});

  @override
  Widget build(BuildContext context) {
    final location = Provider.of<LocationProvider>(context).currentLocation;

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('car'),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: location, zoom: 15),
      markers: markers,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}
