import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:milleservices/models/user.dart';
import 'package:milleservices/services/live_location_sync.dart';
import 'package:milleservices/services/live_location_task_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service Android (premier plan) uniquement pendant une prestation
/// acceptée ou en cours. Il s’arrête dès que la prestation est terminée, payée,
/// annulée ou refusée.
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

  /// Démarre ou arrête le suivi selon qu'une prestation a encore besoin de la position.
  static Future<void> apply({
    required bool needed,
    required User? user,
    required String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LiveLocationSync.trackingPrefKey, needed);
    if (!needed) {
      await stop();
      return;
    }
    await startIfAuthenticated(user, token);
  }

  /// Arrêt explicite (déconnexion ou plus aucune prestation à suivre).
  static Future<void> stop() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(LiveLocationSync.trackingPrefKey, false);
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
    // Le service premier plan n'est fiable que sur Android. Sur iOS,
    // le démarrage au moment d'ouvrir une prestation fait quitter l'app.
    if (!Platform.isAndroid) return;

    ensureConfigured();

    if (Platform.isAndroid) {
      try {
        final np = await FlutterForegroundTask.checkNotificationPermission();
        if (np != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
      } on PlatformException catch (e) {
        // L'utilisateur peut fermer la popup Android 13+ (PermissionRequestCancelledException).
        // On n'échoue pas bruyamment: on sort et on retentera plus tard.
        debugPrint(
          'LiveLocationForegroundService.permission: ${e.code} ${e.message}',
        );
        return;
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
