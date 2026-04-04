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
            final lat = e['lat'];
            final lng = e['lng'];
            if (displayName == null || displayName.isEmpty) return null;
            if (lat == null || lng == null) return null;
            return AutocompleteSuggestion(
              displayName: displayName,
              lat: (lat as num).toDouble(),
              lng: (lng as num).toDouble(),
            );
          })
          .whereType<AutocompleteSuggestion>()
          .toList();
    } on DioException catch (_) {
      return [];
    }
  }
}

class AutocompleteSuggestion {
  final String displayName;
  final double lat;
  final double lng;

  AutocompleteSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}
