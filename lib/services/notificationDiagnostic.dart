import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationDiagnostic {
  static Future<Map<String, dynamic>> runDiagnostic() async {
    Map<String, dynamic> results = {};

    // 1. Vérifier les permissions système
    results['system_permissions'] = await _checkSystemPermissions();

    // 2. Vérifier le token FCM
    results['fcm_token'] = await _checkFCMToken();

    // 3. Vérifier les paramètres de notification
    results['notification_settings'] = await _checkNotificationSettings();

    // 4. Vérifier les préférences utilisateur
    results['user_preferences'] = await _checkUserPreferences();

    // 5. Vérifier Firebase Messaging
    results['firebase_messaging'] = await _checkFirebaseMessaging();

    return results;
  }

  static Future<Map<String, dynamic>> _checkSystemPermissions() async {
    Map<String, dynamic> result = {};

    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        result['android_notification_permission'] = {
          'status': status.toString(),
          'is_granted': status.isGranted,
          'is_denied': status.isDenied,
          'is_permanently_denied': status.isPermanentlyDenied,
        };
      }

      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      result['firebase_settings'] = {
        'authorization_status': settings.authorizationStatus.toString(),
        'alert': settings.alert.toString(),
        'badge': settings.badge.toString(),
        'sound': settings.sound.toString(),
        'car_play': settings.carPlay.toString(),
        'critical_alert': settings.criticalAlert.toString(),
        'lock_screen': settings.lockScreen.toString(),
        'notification_center': settings.notificationCenter.toString(),
        'show_previews': settings.showPreviews.toString(),
        'time_sensitive': settings.timeSensitive.toString(),
      };
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  static Future<Map<String, dynamic>> _checkFCMToken() async {
    Map<String, dynamic> result = {};

    try {
      final token = await FirebaseMessaging.instance.getToken();
      result['token_exists'] = token != null;
      result['token_length'] = token?.length ?? 0;
      result['token_preview'] = token != null
          ? '${token.substring(0, 20)}...'
          : null;

      // Vérifier si le token est sauvegardé
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('fcm_token');
      result['saved_token_exists'] = savedToken != null;
      result['tokens_match'] = token == savedToken;
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  static Future<Map<String, dynamic>> _checkNotificationSettings() async {
    Map<String, dynamic> result = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? true;

      result['preference_enabled'] = notificationsEnabled;
      result['shared_preferences_available'] = true;
    } catch (e) {
      result['error'] = e.toString();
      result['shared_preferences_available'] = false;
    }

    return result;
  }

  static Future<Map<String, dynamic>> _checkUserPreferences() async {
    Map<String, dynamic> result = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      result['all_keys'] = prefs.getKeys().toList();
      result['notification_keys'] = prefs
          .getKeys()
          .where((key) => key.contains('notification'))
          .toList();
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  static Future<Map<String, dynamic>> _checkFirebaseMessaging() async {
    Map<String, dynamic> result = {};

    try {
      final instance = FirebaseMessaging.instance;
      result['instance_available'] = true;

      // Vérifier si les handlers sont enregistrés
      // Note: On ne peut pas directement vérifier les listeners, mais on peut tester la capacité
      final canReceiveNotifications = await instance.getNotificationSettings();
      result['can_receive_notifications'] =
          canReceiveNotifications.authorizationStatus ==
              AuthorizationStatus.authorized ||
          canReceiveNotifications.authorizationStatus ==
              AuthorizationStatus.provisional;
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  static void showDiagnosticDialog(BuildContext context) async {
    final results = await runDiagnostic();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Diagnostic Notifications'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDiagnosticSection(
                  'Permissions Système',
                  results['system_permissions'],
                ),
                SizedBox(height: 16),
                _buildDiagnosticSection('Token FCM', results['fcm_token']),
                SizedBox(height: 16),
                _buildDiagnosticSection(
                  'Paramètres Notification',
                  results['notification_settings'],
                ),
                SizedBox(height: 16),
                _buildDiagnosticSection(
                  'Préférences Utilisateur',
                  results['user_preferences'],
                ),
                SizedBox(height: 16),
                _buildDiagnosticSection(
                  'Firebase Messaging',
                  results['firebase_messaging'],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildDiagnosticSection(
    String title,
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return Text('$title: Données non disponibles');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        ...data.entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('${entry.key}: ${entry.value}'),
          ),
        ),
      ],
    );
  }
}
