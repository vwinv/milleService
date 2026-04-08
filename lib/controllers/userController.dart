import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/services/utilities.dart';

class UserController {
  UserController._instantiate();
  UserController();
  static final UserController instance = UserController._instantiate();

  final dio = Dio(
    BaseOptions(
      baseUrl: Utilities().baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // Vérifier la connexion internet
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } on TimeoutException catch (_) {
      return false;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<ResponseData> updatePrestataireMe({
    required String token,
    String? nom,
    String? telephone,
    String? adresse,
    String? bio,
    String? avatarUrl,
    List<String>? serviceIds,
    double? latitude,
    double? longitude,
  }) async {
    // Vérifier la connexion internet
    bool hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      return ResponseData(
        success: false,
        message:
            "Aucune connexion internet. Veuillez vérifier votre connexion et réessayer.",
        data: null,
        status: 0,
        emailNotVerified: false,
      );
    }

    try {
      final body = <String, dynamic>{};
      if (nom != null) body['nom'] = nom.trim();
      if (telephone != null) body['telephone'] = telephone.trim();
      if (adresse != null) body['adresse'] = adresse.trim();
      if (bio != null) body['bio'] = bio.trim();
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl.trim();
      if (serviceIds != null) body['serviceIds'] = serviceIds;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final response = await dio.patch(
        '/prestataires/me',
        data: jsonEncode(body),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final code = response.statusCode ?? 500;
      final ok = code >= 200 && code < 300;
      final map = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      return ResponseData(
        success: map['success'] == true || ok,
        data: map['data'],
        message: map['message']?.toString() ?? '',
        status: code,
        emailNotVerified: false,
      );
    } on DioException catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": e.response?.statusCode ?? 500,
        "message":
            e.response?.data?['message'] ?? "Échec de la mise à jour du profil",
        "emailNotVerified": false,
      });
    }
  }

  Future<ResponseData> updateParticulierMe({
    required String token,
    String? nom,
    String? prenom,
    String? telephone,
    String? adresse,
    String? avatarUrl,
    double? latitude,
    double? longitude,
  }) async {
    bool hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      return ResponseData(
        success: false,
        message:
            "Aucune connexion internet. Veuillez vérifier votre connexion et réessayer.",
        data: null,
        status: 0,
        emailNotVerified: false,
      );
    }

    try {
      final body = <String, dynamic>{};
      if (nom != null) body['nom'] = nom.trim();
      if (prenom != null) body['prenom'] = prenom.trim();
      if (telephone != null) body['telephone'] = telephone.trim();
      if (adresse != null) body['adresse'] = adresse.trim();
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl.trim();
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final response = await dio.patch(
        '/auth/me/particulier',
        data: jsonEncode(body),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final code = response.statusCode ?? 500;
      final ok = code >= 200 && code < 300;
      final map = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      return ResponseData(
        success: map['success'] == true || ok,
        data: map['data'],
        message: map['message']?.toString() ?? '',
        status: code,
        emailNotVerified: false,
      );
    } on DioException catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": e.response?.statusCode ?? 500,
        "message": e.response?.data?['message'] ??
            "Échec de la mise à jour du profil",
        "emailNotVerified": false,
      });
    }
  }

  Future<ResponseData> becomePrestataire(String token) async {
    bool hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      return ResponseData(
        success: false,
        message:
            "Aucune connexion internet. Veuillez vérifier votre connexion et réessayer.",
        data: null,
        status: 0,
        emailNotVerified: false,
      );
    }

    try {
      final response = await dio.post(
        '/auth/me/become-prestataire',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return ResponseData.fromJson({
        "success": response.data['success'],
        "data": response.data['data'],
        "message": response.data["message"] ?? "",
        "emailNotVerified": false,
        "status": response.statusCode,
      });
    } on DioException catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": e.response?.statusCode ?? 500,
        "message": e.response?.data?['message'] ??
            "Échec de la création du profil prestataire",
        "emailNotVerified": false,
      });
    }
  }

  Future<ResponseData> becomeParticulier(String token) async {
    bool hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      return ResponseData(
        success: false,
        message:
            "Aucune connexion internet. Veuillez vérifier votre connexion et réessayer.",
        data: null,
        status: 0,
        emailNotVerified: false,
      );
    }

    try {
      final response = await dio.post(
        '/auth/me/become-particulier',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return ResponseData.fromJson({
        "success": response.data['success'],
        "data": response.data['data'],
        "message": response.data["message"] ?? "",
        "emailNotVerified": false,
        "status": response.statusCode,
      });
    } on DioException catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": e.response?.statusCode ?? 500,
        "message": e.response?.data?['message'] ??
            "Échec de la création du profil client",
        "emailNotVerified": false,
      });
    }
  }
}

