import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/services/utilities.dart';

class NotificationController {
  NotificationController._instantiate();
  NotificationController();
  static final NotificationController instance =
      NotificationController._instantiate();

  final dio = Dio(
    BaseOptions(
      baseUrl: Utilities().baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Enregistre ou met à jour le token FCM de l'utilisateur connecté.
  /// Aligne le front sur le backend Nest `/notifications/fcm-token`.
  Future<ResponseData> registerDevice(
    String fcmToken,
    String platform,
    String deviceInfo,
    String token,
  ) async {
    try {
      final response = await dio.patch(
        "/notifications/fcm-token",
        data: json.encode({"fcmToken": fcmToken}),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );

      debugPrint(
        '[FCM trace] PATCH /notifications/fcm-token → HTTP ${response.statusCode} '
        'success=${response.data is Map ? response.data['success'] : response.data}',
      );

      ResponseData finalResponse = ResponseData.fromJson({
        "success": response.data['success'],
        "data": response.data['data'],
        "status": response.statusCode,
      });

      return finalResponse;
    } on DioException catch (e) {
      debugPrint(
        '[FCM trace] PATCH /notifications/fcm-token DIO ERROR '
        'type=${e.type} message=${e.message} status=${e.response?.statusCode}',
      );
      // ⚠️ Erreur côté backend (ex: 400, 401, 500)
      if (e.response != null) {
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "errors": e.response?.data["errors"] ?? "",
        });
        return finalResponse;
      } else {
        // 🚨 Problème réseau (timeout, pas d’internet, etc.)
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": 500,
          "message": "Erreur serveur",
        });
        return finalResponse;
      }
    }
  }

  Future<ResponseData> deleteDevice(String fcmToken, String token) async {
    try {
      // Pour désactiver, on envoie fcmToken = null
      final response = await dio.patch(
        "/notifications/fcm-token",
        data: json.encode({"fcmToken": null}),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );

      ResponseData finalResponse = ResponseData.fromJson({
        "success": response.data['success'],
        "data": response.data['data'],
        "status": response.statusCode,
      });

      return finalResponse;
    } on DioException catch (e) {
      // ⚠️ Erreur côté backend (ex: 400, 401, 500)
      if (e.response != null) {
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "errors": e.response?.data["errors"] ?? "",
        });
        return finalResponse;
      } else {
        // 🚨 Problème réseau (timeout, pas d’internet, etc.)
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": 500,
          "message": "Erreur serveur",
        });
        return finalResponse;
      }
    }
  }
}
