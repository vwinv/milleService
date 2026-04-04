import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Itinéraires routiers via [OSRM](https://project-osrm.org/) (données OpenStreetMap).
///
/// Instance publique de démonstration : usage modéré uniquement. Pour la production,
/// prévoir un serveur OSRM dédié ou un fournisseur (Mapbox, Google Directions, etc.).
class OsrmRouteService {
  OsrmRouteService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'Accept': 'application/json'},
    ),
  );

  static const String _base =
      'https://router.project-osrm.org/route/v1/driving';

  /// Points le long des routes (ordre : du point [from] vers [to]).
  /// `null` si l’API échoue (réseau, aucun chemin) — l’UI peut tracer une ligne droite.
  static Future<List<LatLng>?> fetchDrivingRoute(LatLng from, LatLng to) async {
    final lon1 = from.longitude;
    final lat1 = from.latitude;
    final lon2 = to.longitude;
    final lat2 = to.latitude;
    final url =
        '$_base/$lon1,$lat1;$lon2,$lat2?overview=full&geometries=geojson';
    try {
      final res = await _dio.get<Map<String, dynamic>>(url);
      final data = res.data;
      if (data == null) return null;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final first = routes.first;
      if (first is! Map<String, dynamic>) return null;
      final geom = first['geometry'] as Map<String, dynamic>?;
      if (geom == null) return null;
      final coords = geom['coordinates'] as List<dynamic>?;
      if (coords == null || coords.isEmpty) return null;
      final out = <LatLng>[];
      for (final c in coords) {
        if (c is! List || c.length < 2) continue;
        final lon = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        out.add(LatLng(lat, lon));
      }
      return out.length >= 2 ? out : null;
    } catch (_) {
      return null;
    }
  }
}
