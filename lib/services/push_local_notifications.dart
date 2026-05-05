import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Identique au canal déclaré dans AndroidManifest (meta-data FCM).
const String _channelId = 'mille_services_default';
const String _channelName = 'Mille Services';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;

Future<void> initPushLocalNotifications() async {
  if (_initialized) return;

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  await _plugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  if (Platform.isAndroid) {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Notifications Mille Services',
            importance: Importance.high,
            playSound: true,
          ),
        );
  }

  _initialized = true;
}

String _titleFromMessage(RemoteMessage m) {
  final fromBlock = m.notification?.title?.trim();
  if (fromBlock != null && fromBlock.isNotEmpty) return fromBlock;
  final fromData = m.data['title']?.toString().trim();
  if (fromData != null && fromData.isNotEmpty) return fromData;
  return 'Notification';
}

String _bodyFromMessage(RemoteMessage m) {
  final fromBlock = m.notification?.body?.trim();
  if (fromBlock != null && fromBlock.isNotEmpty) return fromBlock;
  final fromData = m.data['body']?.toString().trim();
  if (fromData != null && fromData.isNotEmpty) return fromData;
  return '';
}

/// Affiche une notification dans la barre système (Android / iOS).
///
/// Utile quand l’app est au premier plan sur Android (FCM n’affiche pas la heads-up seule),
/// et pour les payloads **data-only** en arrière-plan.
Future<void> displayPushFromRemoteMessage(RemoteMessage message) async {
  await initPushLocalNotifications();

  final title = _titleFromMessage(message);
  var body = _bodyFromMessage(message);
  if (title == 'Notification' && body.isEmpty) {
    return;
  }
  if (body.isEmpty) {
    body = ' ';
  }

  final rawId = message.messageId ?? message.sentTime?.toString() ?? '';
  final id = rawId.isEmpty
      ? DateTime.now().millisecondsSinceEpoch.remainder(1000000000)
      : rawId.hashCode.abs();

  const androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Notifications Mille Services',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  await _plugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
  );
}
