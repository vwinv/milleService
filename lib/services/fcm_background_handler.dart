import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:milleservices/services/fcm_debug_log.dart';
import 'package:milleservices/services/push_local_notifications.dart';

/// Doit être enregistré **une fois** avec
/// `FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler)` **avant** `runApp`
/// (voir `main.dart`). Ne pas enregistrer ailleurs.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  fcmAppLog(
    'RÉCEPTION',
    'arrière-plan (isolate) messageId=${message.messageId} '
    'notification=${message.notification != null ? "oui" : "non"} '
    'dataKeys=${message.data.keys.join(",")}',
  );

  // Si le payload contient déjà une section `notification`, FCM affiche la barre système seul(e).
  // Sinon (data-only), il faut une notification locale pour que l’utilisateur la voie hors de l’app.
  if (message.notification != null) {
    fcmAppLog(
      'RÉCEPTION',
      'arrière-plan : bloc notification présent → pas de doublon local',
    );
    return;
  }

  try {
    await displayPushFromRemoteMessage(message);
    fcmAppLog(
      'RÉCEPTION',
      'arrière-plan : notification locale data-only affichée si titre/corps disponibles',
    );
  } catch (e) {
    fcmAppLog('RÉCEPTION', 'arrière-plan : notification locale erreur: $e');
  }
}
