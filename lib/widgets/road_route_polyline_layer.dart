import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:milleservices/services/google_route_service.dart';

/// Utilitaire Google Maps: récupère un polyline routier (avec fallback ligne droite).
class RoadRoutePolylineLayer {
  RoadRoutePolylineLayer._();

  static Future<Polyline?> build({
    required String id,
    required LatLng from,
    required LatLng to,
    Color color = Colors.red,
    int width = 4,
  }) async {
    final points = await GoogleRouteService.fetchDrivingRoute(from, to);
    final polylinePoints = (points != null && points.length >= 2)
        ? points
        : <LatLng>[from, to];
    return Polyline(
      polylineId: PolylineId(id),
      points: polylinePoints,
      color: color,
      width: width,
    );
  }
}
