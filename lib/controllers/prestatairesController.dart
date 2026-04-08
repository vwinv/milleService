import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/services/utilities.dart';

/// Extrait un libellé lisible (Nest peut renvoyer `message` en [String] ou [List]).
String _messageFromApiBody(dynamic raw) {
  if (raw == null) return 'Erreur serveur';
  if (raw is! Map) return 'Erreur serveur';
  final m = raw['message'];
  if (m is String && m.isNotEmpty) return m;
  if (m is List) {
    final parts = m
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');
  }
  return 'Erreur serveur';
}

class PrestatairesController {
  PrestatairesController._instantiate();
  PrestatairesController();
  static final PrestatairesController instance =
      PrestatairesController._instantiate();

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
      // Test de connexion avec timeout court pour détecter l'instabilité
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // Test de vitesse pour détecter une connexion lente/instable
        final stopwatch = Stopwatch()..start();
        await InternetAddress.lookup(
          'google.com',
        ).timeout(const Duration(seconds: 2));
        stopwatch.stop();

        // Si la connexion prend plus de 1.5 secondes, elle est considérée comme instable
        if (stopwatch.elapsedMilliseconds > 1500) {
          ConnectionNotifier().showUnstableConnectionMessage();
        }

        return true;
      }
      return false;
    } on TimeoutException catch (_) {
      ConnectionNotifier().showConnectionTimeoutMessage();
      return false;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Méthode publique pour permettre à d'autres services (ex: SettingsProvider)
  /// de vérifier l'état de la connexion et d'être notifiés en cas d'instabilité.
  Future<bool> checkInternetConnection() async {
    return _checkInternetConnection();
  }

  Future<ResponseData> getFavoris({
    double? lat,
    double? lng,
    String? token,
  }) async {
    try {
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

      final response = await dio.get(
        '/prestataires/favoris',
        queryParameters: {
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
        options: Options(
          headers: {
            "Content-Type": "application/json",
            if (token != null && token.isNotEmpty)
              "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final raw = response.data;
      final msg = _messageFromApiBody(raw);

      ResponseData finalResponse = ResponseData.fromJson({
        "success": raw is Map ? raw['success'] : null,
        "data": raw is Map ? raw['data'] : null,
        "message": msg,
        "emailNotVerified":
            raw is Map ? raw["emailNotVerified"] ?? "null" : "null",
        "status": response.statusCode,
      });

      return finalResponse;
    } on DioException catch (e) {
      print("DioException: $e");
      // ⚠️ Erreur côté backend (ex: 400, 401, 500)
      if (e.response != null) {
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "emailNotVerified": e.response?.data["emailNotVerified"] ?? "null",
          "message": _messageFromApiBody(e.response?.data),
        });
        return finalResponse;
      } else {
        print(e.response);
        // 🚨 Problème réseau (timeout, pas d’internet, etc.)
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": 500,
          "message": _messageFromApiBody(e.response?.data),
        });
        return finalResponse;
      }
    } catch (e) {
      // 🚨 Autres erreurs imprévues
      print("error: $e");
      ResponseData finalResponse = ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
      });
      return finalResponse;
    }
  }

  /// Récupère la liste des catégories de services actives (GET /services).
  Future<ResponseData> getCategories() async {
    try {
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
      final response = await dio.get(
        "/services",
        options: Options(
          headers: {"Content-Type": "application/json"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;

      // L'endpoint /services renvoie directement une liste brute de services.
      if (raw is List) {
        return ResponseData.fromJson({
          "success": response.statusCode == 200,
          "data": raw,
          "message": "",
          "emailNotVerified": false,
          "status": response.statusCode,
        });
      }

      // Fallback si jamais le backend est modifié pour renvoyer { success, data, ... }.
      return ResponseData.fromJson({
        "success": raw is Map ? raw['success'] : response.statusCode == 200,
        "data": raw is Map ? (raw['data'] ?? []) : [],
        "message":
            raw is Map ? (raw["message"] ?? "Erreur serveur") : "Erreur serveur",
        "emailNotVerified":
            raw is Map ? (raw["emailNotVerified"] ?? "null") : "null",
        "status": response.statusCode,
      });
    } on DioException catch (e) {
      print("DioException: $e");
      // ⚠️ Erreur côté backend (ex: 400, 401, 500)
      if (e.response != null) {
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "emailNotVerified": e.response?.data["emailNotVerified"] ?? "null",
          "message": e.response?.data["message"] ?? "Erreur serveur",
        });
        return finalResponse;
      } else {
        print(e.response);
        // 🚨 Problème réseau (timeout, pas d’internet, etc.)
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": 500,
          "message": e.response?.data["message"] ?? "Erreur serveur",
        });
        return finalResponse;
      }
    } catch (e) {
      // 🚨 Autres erreurs imprévues
      print("error: $e");
      ResponseData finalResponse = ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
      });
      return finalResponse;
    }
  }

  /// Recherche de prestataires par service, tarif (min/max) et date optionnelle (planifier).
  /// [lat] / [lng] : position actuelle si disponible ; sinon le backend utilise le profil / l’adresse.
  Future<ResponseData> searchPrestataires({
    String? serviceId,
    double? tarifMin,
    double? tarifMax,
    String? date,
    double? lat,
    double? lng,
    String? token,
  }) async {
    try {
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

      final queryParams = <String, dynamic>{};
      if (serviceId != null && serviceId.isNotEmpty) {
        queryParams['serviceId'] = serviceId;
      }
      if (tarifMin != null) queryParams['tarifMin'] = tarifMin.toInt();
      if (tarifMax != null) queryParams['tarifMax'] = tarifMax.toInt();
      if (date != null) queryParams['date'] = date;
      if (lat != null) queryParams['lat'] = lat;
      if (lng != null) queryParams['lng'] = lng;

      final response = await dio.get(
        '/prestataires/search',
        queryParameters: queryParams,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            if (token != null && token.isNotEmpty)
              "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final rawData = response.data;
      final list = rawData is List
          ? rawData
          : (rawData is Map && rawData['data'] != null)
              ? rawData['data'] as List
              : <dynamic>[];

      ResponseData finalResponse = ResponseData.fromJson({
        "success": rawData is Map ? (rawData['success'] ?? response.statusCode == 200) : response.statusCode == 200,
        "data": list,
        "message": rawData is Map ? (rawData["message"] ?? "Erreur serveur") : "Erreur serveur",
        "emailNotVerified": rawData is Map ? (rawData["emailNotVerified"] ?? "null") : "null",
        "status": response.statusCode,
      });

      return finalResponse;
    } on DioException catch (e) {
      print("DioException: $e");
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "emailNotVerified": e.response?.data["emailNotVerified"] ?? "null",
          "message": _messageFromApiBody(e.response?.data),
        });
      } else {
        return ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": 500,
          "message": _messageFromApiBody(e.response?.data),
        });
      }
    } catch (e) {
      print("error: $e");
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
      });
    }
  }

  /// Nombre de prestations en attente et terminées pour le prestataire connecté.
  /// Retourne { enAttente: int, terminee: int }.
  Future<ResponseData> getPrestationStats(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          data: null,
          message: "Non authentifié",
          status: 401,
          emailNotVerified: false,
        );
      }
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
      final response = await dio.get(
        '/prestataires/me/prestation-stats',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final rawData = response.data;
      final data = rawData is Map && rawData['data'] is Map
          ? rawData['data'] as Map<String, dynamic>
          : (rawData is Map ? rawData as Map<String, dynamic> : <String, dynamic>{});
      return ResponseData.fromJson({
        "success": response.statusCode == 200,
        "data": data,
        "message": data["message"] ?? "",
        "status": response.statusCode,
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Liste des IDs des services proposés par le prestataire connecté (GET /prestataires/me/services).
  Future<ResponseData> getMyServiceIds(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          data: null,
          message: "Non authentifié",
          status: 401,
          emailNotVerified: false,
        );
      }
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
      final response = await dio.get(
        '/prestataires/me/services',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final data = raw is Map ? raw : <String, dynamic>{};
      return ResponseData.fromJson({
        "success": response.statusCode == 200,
        "data": data,
        "message": (data["message"] ?? "").toString(),
        "status": response.statusCode,
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Met à jour / renvoie les documents du prestataire connecté
  /// (PATCH /prestataires/me/documents).
  Future<ResponseData> updateMyDocuments({
    required String token,
    required List<Map<String, String>> documents,
  }) async {
    try {
      if (token.isEmpty) {
        return ResponseData(
          success: false,
          data: null,
          message: "Non authentifié",
          status: 401,
          emailNotVerified: false,
        );
      }

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

      final response = await dio.patch(
        '/prestataires/me/documents',
        data: {
          'documents': documents,
        },
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final raw = response.data;
      final data =
          raw is Map ? raw : <String, dynamic>{};

      return ResponseData.fromJson({
        "success": response.statusCode == 200,
        "data": data["data"] ?? data,
        "message": (data["message"] ?? "").toString(),
        "status": response.statusCode,
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Récupère le statut de vérification du prestataire connecté
  /// ainsi que le détail de ses documents (GET /prestataires/me/verification-status).
  Future<ResponseData> getMyVerificationStatus(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          data: null,
          message: "Non authentifié",
          status: 401,
          emailNotVerified: false,
        );
      }

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

      final response = await dio.get(
        '/prestataires/me/verification-status',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final raw = response.data;
      final data = raw is Map ? raw : <String, dynamic>{};

      return ResponseData.fromJson({
        "success": response.statusCode == 200,
        "data": data["data"] ?? data,
        "message": (data["message"] ?? "").toString(),
        "status": response.statusCode,
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Récupère uniquement la liste des documents du prestataire connecté
  /// (GET /prestataires/me/documents).
  Future<ResponseData> getMyDocuments(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          data: null,
          message: "Non authentifié",
          status: 401,
          emailNotVerified: false,
        );
      }

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

      final response = await dio.get(
        '/prestataires/me/documents',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final raw = response.data;
      final data = raw is Map ? raw : <String, dynamic>{};

      return ResponseData.fromJson({
        "success": response.statusCode == 200,
        "data": data["data"] ?? data,
        "message": (data["message"] ?? "").toString(),
        "status": response.statusCode,
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Photos du catalogue du prestataire connecté.
  Future<ResponseData> getMyPhotos(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          data: null,
          message: "Non authentifié",
          status: 401,
          emailNotVerified: false,
        );
      }
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
      final response = await dio.get(
        '/prestataires/me/photos',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return ResponseData.fromJson({
        "success": response.statusCode == 200,
        "data": response.data,
        "status": response.statusCode,
        "message": "",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Ajoute une photo au catalogue du prestataire connecté.
  Future<ResponseData> addPhotoToCatalogue({
    required String url,
    String? titre,
    String? description,
    int? ordre,
    required String? token,
  }) async {
    try {
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          data: null,
          message: "Non authentifié",
          status: 401,
          emailNotVerified: false,
        );
      }
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
      final body = <String, dynamic>{
        "url": url,
      };
      if (titre != null && titre.trim().isNotEmpty) body["titre"] = titre;
      if (description != null && description.trim().isNotEmpty) {
        body["description"] = description;
      }
      if (ordre != null) body["ordre"] = ordre;

      final response = await dio.post(
        '/prestataires/me/photos',
        data: body,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return ResponseData.fromJson({
        "success": response.statusCode == 201 || response.statusCode == 200,
        "data": response.data,
        "status": response.statusCode,
        "message": "",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Photos du catalogue pour un prestataire donné (profil public / particulier).
  Future<ResponseData> getPrestatairePhotos(String prestataireId) async {
    try {
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
      final response = await dio.get(
        '/prestataires/$prestataireId/photos',
        options: Options(
          headers: {"Content-Type": "application/json"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return ResponseData.fromJson({
        "success": response.statusCode == 200,
        "data": response.data,
        "status": response.statusCode,
        "message": "",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Avis des clients sur un prestataire (profil public).
  Future<ResponseData> getAvisPrestataire(String prestataireId) async {
    try {
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
      final response = await dio.get(
        '/prestataires/$prestataireId/avis',
        options: Options(
          headers: {"Content-Type": "application/json"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List)
              ? raw['data'] as List
              : <dynamic>[];
      return ResponseData.fromJson({
        "success": response.statusCode == 200,
        "data": list,
        "status": response.statusCode,
        "message": "",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }
}
