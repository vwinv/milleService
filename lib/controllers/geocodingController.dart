import 'package:dio/dio.dart';
import 'package:milleservices/services/utilities.dart';

class GeocodingController {
  final _dio = Dio(
    BaseOptions(
      baseUrl: Utilities().baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Appelle GET /geocoding?address=xxx et retourne (lat, lng) ou null si non trouvé.
  Future<({double lat, double lng})?> geocode(String address) async {
    final trimmed = address.trim();
    if (trimmed.length < 3) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/geocoding',
        queryParameters: {'address': trimmed},
      );

      final raw = response.data;
      if (raw == null) return null;
      // Réponse format API: { success, data: { lat, lng, found }, message, status }
      final data = raw['data'] as Map<String, dynamic>? ?? raw;
      final found = data['found'] == true;
      if (!found) return null;

      final lat = data['lat'];
      final lng = data['lng'];
      if (lat == null || lng == null) return null;

      return (lat: (lat as num).toDouble(), lng: (lng as num).toDouble());
    } on DioException catch (_) {
      return null;
    }
  }

  /// Appelle GET /geocoding/autocomplete?q=xxx et retourne les suggestions.
  Future<List<AutocompleteSuggestion>> autocomplete(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    try {
      // Le backend renvoie { success, data: [...], message, status }
      final response = await _dio.get<Map<String, dynamic>>(
        '/geocoding/autocomplete',
        queryParameters: {'q': trimmed},
      );

      final raw = response.data;
      if (raw == null) return [];

      final dynamic data = raw['data'] ?? raw;
      if (data is! List) return [];
      final list = data;
      if (list.isEmpty) return [];

      return list
          .map((e) {
            if (e is! Map<String, dynamic>) return null;
            final displayName = e['displayName'] as String?;
            final placeId = e['placeId'] as String?;
            final lat = e['lat'];
            final lng = e['lng'];
            if (displayName == null || displayName.isEmpty) return null;
            return AutocompleteSuggestion(
              displayName: displayName,
              placeId: placeId,
              lat: lat is num ? lat.toDouble() : null,
              lng: lng is num ? lng.toDouble() : null,
            );
          })
          .whereType<AutocompleteSuggestion>()
          .toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// Résout un placeId Google en coordonnées.
  Future<({double lat, double lng})?> placeDetails(String placeId) async {
    final id = placeId.trim();
    if (id.isEmpty) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/geocoding/place-details',
        queryParameters: {'placeId': id},
      );
      final raw = response.data;
      if (raw == null) return null;
      final data = raw['data'] as Map<String, dynamic>? ?? raw;
      final found = data['found'] == true;
      if (!found) return null;
      final lat = data['lat'];
      final lng = data['lng'];
      if (lat is! num || lng is! num) return null;
      return (lat: lat.toDouble(), lng: lng.toDouble());
    } on DioException catch (_) {
      return null;
    }
  }
}

class AutocompleteSuggestion {
  final String displayName;
  final String? placeId;
  final double? lat;
  final double? lng;

  AutocompleteSuggestion({
    required this.displayName,
    this.placeId,
    this.lat,
    this.lng,
  });
}
