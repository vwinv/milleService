import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:milleservices/models/user.dart';
import 'package:milleservices/services/live_location_task_handler.dart';

/// Service Android (premier plan, notification persistante) + cadence iOS limitée par le système.
/// Continue d’envoyer la position tant que l’utilisateur est connecté (particulier ou prestataire).
class LiveLocationForegroundService {
  LiveLocationForegroundService._();

  static bool _configured = false;

  static void ensureConfigured() {
    if (_configured) return;
    _configured = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mille_live_location',
        channelName: 'Localisation Mille Services',
        channelDescription:
            'Synchronisation de votre position pour les cartes et prestations.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(45000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Arrêt explicite (déconnexion).
  static Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  /// Démarre le service si rôle particulier/prestataire et token présents.
  static Future<void> startIfAuthenticated(User? user, String? token) async {
    if (token == null || token.isEmpty || user == null) return;

    final r = user.role?.toString().toUpperCase() ?? '';
    if (r != 'PRESTATAIRE' && r != 'PARTICULIER') return;

    if (kIsWeb) return;

    ensureConfigured();

    if (Platform.isAndroid) {
      final np = await FlutterForegroundTask.checkNotificationPermission();
      if (np != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
        return;
      }

      await FlutterForegroundTask.startService(
        serviceId: 891,
        notificationTitle: 'Mille Services',
        notificationText: 'Position mise à jour en arrière-plan',
        notificationIcon: null,
        serviceTypes: [ForegroundServiceTypes.location],
        callback: liveLocationTaskStartCallback,
      );
    } catch (e, st) {
      debugPrint('LiveLocationForegroundService.start: $e');
      debugPrint('$st');
    }
  }
}
