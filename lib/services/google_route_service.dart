import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:milleservices/services/utilities.dart';

/// Itineraires routiers via le backend (Google Routes API).
class GoogleRouteService {
  GoogleRouteService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'Accept': 'application/json'},
    ),
  );

  static String get _base => Utilities().baseUrl;

  static Future<List<LatLng>?> fetchDrivingRoute(LatLng from, LatLng to) async {
    debugPrint(
      '[ROUTE] Request start from=(${from.latitude},${from.longitude}) to=(${to.latitude},${to.longitude})',
    );
    try {
      final res = await _dio.get<dynamic>(
        '$_base/geocoding/route',
        queryParameters: {
          'fromLat': from.latitude,
          'fromLng': from.longitude,
          'toLat': to.latitude,
          'toLng': to.longitude,
        },
      );
      debugPrint('[ROUTE] HTTP ${res.statusCode} on /geocoding/route');
      final raw = res.data;
      if (raw == null) {
        debugPrint('[ROUTE] Empty response body');
        return null;
      }
      final List<dynamic>? data = raw is List
          ? raw
          : (raw is Map && raw['data'] is List)
          ? (raw['data'] as List<dynamic>)
          : null;
      if (data == null) {
        debugPrint(
          '[ROUTE] Unexpected payload format (expected List or {data: List})',
        );
        return null;
      }
      final out = <LatLng>[];
      for (final c in data) {
        if (c is! Map) continue;
        final rawLat = c['lat'] ?? c['latitude'];
        final rawLng = c['lng'] ?? c['lon'] ?? c['longitude'];
        final lat = rawLat is num
            ? rawLat.toDouble()
            : double.tryParse(rawLat?.toString() ?? '');
        final lng = rawLng is num
            ? rawLng.toDouble()
            : double.tryParse(rawLng?.toString() ?? '');
        if (lat == null || lng == null) continue;
        out.add(LatLng(lat, lng));
      }
      if (out.length < 2) {
        debugPrint('[ROUTE] Parsed route has less than 2 points (${out.length})');
        return null;
      }
      debugPrint('[ROUTE] Parsed route OK with ${out.length} points');
      return out;
    } on DioException catch (e) {
      debugPrint(
        '[ROUTE] DioException type=${e.type} status=${e.response?.statusCode} message=${e.message}',
      );
      if (e.response?.data != null) {
        debugPrint('[ROUTE] Response data: ${e.response?.data}');
      }
      return null;
    } catch (e, st) {
      debugPrint('[ROUTE] Unexpected error: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }
}
