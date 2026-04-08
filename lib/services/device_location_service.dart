import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Position GPS appareil pour les cartes (repli possible sur le profil côté UI).
class DeviceLocationService {
  DeviceLocationService._();

  static bool _usablePosition(Position? p) {
    if (p == null) return false;
    if (p.latitude == 0 && p.longitude == 0) return false;
    return p.latitude.abs() <= 90 && p.longitude.abs() <= 180;
  }

  /// Retourne [null] si service désactivé, permission refusée ou erreur.
  ///
  /// Sur **émulateur** : activer la position dans les contrôles étendus (Android)
  /// ou `features > location` (iOS), et donner la permission à l’app. On utilise
  /// une précision moyenne + délai, puis [Geolocator.getLastKnownPosition] en repli.
  static Future<LatLng?> getCurrentLatLngOrNull() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 0,
            timeLimit: Duration(seconds: 20),
          ),
        );
        if (_usablePosition(pos)) {
          return LatLng(pos.latitude, pos.longitude);
        }
      } on TimeoutException {
        // fréquent sur émulateur si aucune position « live » n’est injectée
      } catch (_) {}

      final last = await Geolocator.getLastKnownPosition();
      if (_usablePosition(last)) {
        return LatLng(last!.latitude, last.longitude);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
