import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:milleservices/services/device_location_service.dart';
import 'package:milleservices/services/live_location_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Point d’entrée isolé requis par [flutter_foreground_task] (ne pas supprimer).
@pragma('vm:entry-point')
void liveLocationTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(LiveLocationTaskHandler());
}

String _liveLocationBackendBaseUrl() {
  const env = String.fromEnvironment('API_BASE_URL');
  if (env.isNotEmpty) return env;
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:3001';
  }
  return 'http://127.0.0.1:3001';
}

class LiveLocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _tick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_tick());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _tick() async {
    if (!await LiveLocationSync.shouldSendToServer()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) return;

    final userStr = prefs.getString('user');
    if (userStr == null) return;

    final role = (jsonDecode(userStr) as Map<String, dynamic>)['role']
        ?.toString()
        .toUpperCase();
    if (role != 'PRESTATAIRE' && role != 'PARTICULIER') return;

    final ll = await DeviceLocationService.getCurrentLatLngOrNull();
    if (ll == null) return;

    final baseUrl = _liveLocationBackendBaseUrl();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final path =
        role == 'PRESTATAIRE' ? '/prestataires/me' : '/auth/me/particulier';

    try {
      final response = await dio.patch(
        path,
        data: jsonEncode({
          'latitude': ll.latitude,
          'longitude': ll.longitude,
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final code = response.statusCode ?? 500;
      final okHttp = code >= 200 && code < 300;
      final body = response.data;
      final ok = okHttp ||
          (body is Map && body['success'] == true);

      if (ok) {
        await LiveLocationSync.markServerSuccess();
        await _patchUserCoordsInPrefs(prefs, ll.latitude, ll.longitude);
      }
    } on DioException catch (_) {
      // réseau / timeout : prochain cycle
    }
  }

  static Future<void> _patchUserCoordsInPrefs(
    SharedPreferences prefs,
    double lat,
    double lng,
  ) async {
    final raw = prefs.getString('user');
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['latitude'] = lat;
      map['longitude'] = lng;
      await prefs.setString('user', jsonEncode(map));
    } catch (_) {}
  }
}
