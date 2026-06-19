import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:milleservices/controllers/geocodingController.dart';

/// Libellé d'adresse lisible à partir d'une position GPS.
abstract final class AddressLineHelper {
  static String placemarkToAddressLine(Placemark p) {
    final parts = <String>[];
    void push(String? s) {
      final t = s?.trim() ?? '';
      if (t.isNotEmpty && !parts.contains(t)) parts.add(t);
    }

    final street = (p.street ?? '').trim();
    if (street.isEmpty) {
      push(p.name);
      push(p.thoroughfare);
    } else {
      push(p.street);
    }
    push(p.subLocality);
    push(p.locality);
    push(p.postalCode);
    push(p.administrativeArea);
    push(p.country);
    return parts.join(', ');
  }

  static Future<String?> reverseGeocodeFromLatLng(LatLng latLng) async {
    final fromBackend = await GeocodingController().reverseGeocode(
      latLng.latitude,
      latLng.longitude,
    );
    if (fromBackend != null && fromBackend.isNotEmpty) return fromBackend;

    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (placemarks.isEmpty) return null;
      final line = placemarkToAddressLine(placemarks.first);
      return line.isEmpty ? null : line;
    } catch (_) {
      return null;
    }
  }
}
