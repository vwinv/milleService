import 'package:shared_preferences/shared_preferences.dart';

/// Limite la fréquence d’envoi de la position au serveur (UI + tâche premier plan).
/// Persistance [SharedPreferences] pour partager le throttle entre isolates.
class LiveLocationSync {
  LiveLocationSync._();

  static const String _prefKey = 'live_location_last_server_success_ms';
  static const Duration minInterval = Duration(seconds: 45);

  static Future<bool> shouldSendToServer() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_prefKey);
    if (ms == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(last) > minInterval;
  }

  static Future<void> markServerSuccess() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefKey, DateTime.now().millisecondsSinceEpoch);
  }
}
