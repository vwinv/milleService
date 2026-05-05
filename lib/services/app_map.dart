import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:milleservices/services/map_style.dart';

/// Carte Google Maps factorisée pour l'application.
class AppMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController controller)? onMapCreated;

  const AppMap({
    super.key,
    required this.center,
    this.zoom = 15,
    required this.markers,
    this.polylines = const {},
    this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: zoom),
      style: kGrayMapStyle,
      onMapCreated: onMapCreated,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      markers: markers,
      polylines: polylines,
    );
  }
}
