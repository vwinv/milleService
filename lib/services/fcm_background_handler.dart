import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:milleservices/services/fcm_debug_log.dart';

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
}
