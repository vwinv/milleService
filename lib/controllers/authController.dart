import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/models/user.dart';
import 'package:milleservices/services/utilities.dart';

class Authcontroller {
  Authcontroller._instantiate();
  Authcontroller();
  static final Authcontroller instance = Authcontroller._instantiate();

  /// Délais relevés : inscription prestataire = uploads Cloudinary + POST register + géocodage serveur (souvent > 10 s sur mobile / Render).
  final dio = Dio(
    BaseOptions(
      baseUrl: Utilities().baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 90),
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

  Future<ResponseData> singIn(login, mdp, {required String role}) async {
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

      final loginStr = login.toString().trim();
      final isAdmin = role == 'ADMIN';
      final response = await dio.post(
        "/auth/login",
        data: jsonEncode({
          if (isAdmin) 'email': loginStr,
          if (!isAdmin) 'telephone': loginStr,
          'password': mdp,
          'role': role,
        }),
        options: Options(
          headers: {"Content-Type": "application/json"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print("response: ${response.data}");

      ResponseData finalResponse = ResponseData.fromJson({
        "success": response.data['success'],
        "data": response.data['data'],
        "message": response.data["message"] ?? "Erreur serveur",
        "emailNotVerified": response.data["emailNotVerified"] ?? "null",
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

  Future<ResponseData> refreshToken(String token) async {
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
      final response = await dio.post(
        "/auth/refresh",
        data: jsonEncode({"refresh_token": token}),
        options: Options(headers: {"Content-Type": "application/json"}),
      );
      // L'API retourne directement { access_token, refresh_token, user }
      return ResponseData.fromJson({
        "success": true,
        "data": response.data,
        "status": response.statusCode,
        "message": "",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": null,
        "status": e.response?.statusCode ?? 500,
        "message":
            e.response?.data?['message'] ??
            "Échec du rafraîchissement du token",
        "emailNotVerified": false,
      });
    }
  }

  /// Résout le contenu réel du fichier : [bytes] (file_picker + withData) prime sur [path],
  /// car sur Android le chemin cache des PDF peut être vide alors que [bytes] est correct.
  Future<Uint8List?> _resolveUploadPayload(String? path, List<int>? bytes) async {
    if (bytes != null && bytes.isNotEmpty) {
      return Uint8List.fromList(bytes);
    }
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        final data = await file.readAsBytes();
        if (data.isNotEmpty) return data;
      }
    } catch (e) {
      print('uploadDocument _resolveUploadPayload: $e');
    }
    return null;
  }

  MediaType _mediaTypeForFileName(String name) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot >= 0 && dot < lower.length - 1
        ? lower.substring(dot + 1)
        : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
      case 'heif':
        return MediaType('image', 'heic');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// Corps d'erreur Nest (`message` string ou liste pour class-validator).
  String? _nestApiMessage(dynamic responseBody) {
    if (responseBody is! Map) return null;
    final m = responseBody['message'];
    if (m == null) return null;
    if (m is String) {
      final t = m.trim();
      return t.isEmpty ? null : t;
    }
    if (m is List) {
      final parts = <String>[];
      for (final item in m) {
        if (item is String && item.trim().isNotEmpty) {
          parts.add(item.trim());
        } else if (item != null) {
          final s = item.toString().trim();
          if (s.isNotEmpty) parts.add(s);
        }
      }
      if (parts.isEmpty) return null;
      return parts.join('\n');
    }
    final s = m.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _dioErrorMessage(DioException e) {
    final fromBody = _nestApiMessage(e.response?.data);
    if (fromBody != null) return fromBody;
    return e.message;
  }

  String _networkErrorMessageForUser(DioException e) {
    switch (e.type) {
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionTimeout:
        return 'Le serveur met trop longtemps à répondre. Vérifiez votre connexion '
            'ou réessayez dans quelques instants (réseau lent ou serveur occupé).';
      default:
        return _dioErrorMessage(e) ?? 'Erreur réseau. Réessayez.';
    }
  }

  String? _messageFromUploadBody(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final m = map['message'];
    if (m is String) return m;
    if (m is List && m.isNotEmpty) return m.first.toString();
    return null;
  }

  /// Réponse enveloppée par ResponseInterceptor : `{ data: { url, ... } }` ou corps plat.
  Map<String, dynamic>? _uploadResultMapFromResponse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final inner = map['data'];
    if (inner is Map && inner['url'] is String) {
      return Map<String, dynamic>.from(inner);
    }
    if (map['url'] is String) return map;
    return null;
  }

  /// Upload un fichier vers le backend (Cloudinary).
  /// [error] contient le message serveur (ex. type MIME refusé) si [url] est null.
  Future<({String? url, String? error})> uploadDocument({
    String? path,
    List<int>? bytes,
    required String name,
  }) async {
    final payload = await _resolveUploadPayload(path, bytes);
    if (payload == null || payload.isEmpty) {
      print(
        'uploadDocument: contenu vide (path=${path != null && path.isNotEmpty}, '
        'bytesIn=${bytes?.length ?? 0})',
      );
      return (
        url: null,
        error: 'Fichier vide ou illisible. Réessayez avec un autre fichier.',
      );
    }
    try {
      final multipartFile = MultipartFile.fromBytes(
        payload,
        filename: name,
        contentType: _mediaTypeForFileName(name),
      );
      final formData = FormData.fromMap({'file': multipartFile});
      final response = await dio.post<Map<String, dynamic>>(
        '/documents/upload',
        data: formData,
      );
      // Réponse API : { success, data: { url, publicId, originalName }, message, status }
      final data = response.data;
      final body = data?['data'];
      final url = (body is Map ? body['url'] : data?['url']) as String?;
      if (url != null && url.isNotEmpty) {
        return (url: url, error: null);
      }
      return (url: null, error: 'Réponse serveur sans URL.');
    } on DioException catch (e) {
      final msg = _dioErrorMessage(e);
      print('uploadDocument error: $msg');
      return (
        url: null,
        error: msg ?? 'Erreur réseau lors de l\'upload.',
      );
    } catch (e) {
      return (url: null, error: e.toString());
    }
  }

  Future<ResponseData> singUp(
    User user,
    String password, {
    List<Map<String, String>>? documents,
    List<String>? serviceIds,
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

      final body = <String, dynamic>{
        "email": user.email ?? '',
        "password": password,
        "nom": user.nom,
        "prenom": user.prenom,
        "telephone": user.telephone,
        "role": user.role,
        "bio": user.bio,
        "zoneIntervention": user.zoneIntervention,
        "adresse": user.adresse,
        "latitude": user.latitude,
        "longitude": user.longitude,
      };
      if (user.role == 'PRESTATAIRE') {
        body["name"] = user.nom;
        if (documents != null && documents.isNotEmpty) {
          body["documents"] = documents;
        }
        if (serviceIds != null && serviceIds.isNotEmpty) {
          body["serviceIds"] = serviceIds;
        }
      }

      final response = await dio.post(
        "/auth/register",
        data: json.encode(body),
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      ResponseData finalResponse = ResponseData.fromJson({
        "success": response.data['success'] ?? true,
        "data": response.data['data'] ?? response.data,
        "status": response.statusCode,
      });

      return finalResponse;
    } on DioException catch (e) {
      // Erreurs HTTP (409 email dupliqué, 400 validation, etc.) : message Nest dans le corps.
      if (e.response != null) {
        final raw = e.response!.data;
        final msg = _nestApiMessage(raw) ?? 'Erreur serveur';
        final emailNv = raw is Map ? raw['emailNotVerified'] : null;
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "emailNotVerified": emailNv ?? 'null',
          "message": msg,
        });
        return finalResponse;
      } else {
        // 🚨 Problème réseau (timeout, pas d’internet, etc.) — pas de e.response
        return ResponseData(
          success: false,
          data: [],
          status: 500,
          message: _networkErrorMessageForUser(e),
          emailNotVerified: false,
        );
      }
    } catch (e) {
      // 🚨 Autres erreurs imprévues
      ResponseData finalResponse = ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
      });
      return finalResponse;
    }
  }

  Future<ResponseData> forgotPassword({
    required String email,
    required String telephone,
    required String newPassword,
  }) async {
    try {
      final hasInternet = await _checkInternetConnection();
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

      final response = await dio.post(
        "/auth/forgot-password",
        data: jsonEncode({
          "email": email.trim(),
          "telephone": telephone.trim(),
          "newPassword": newPassword,
        }),
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      return ResponseData.fromJson({
        "success": response.data['success'] ?? true,
        "data": response.data['data'] ?? response.data,
        "status": response.statusCode,
        "message":
            response.data["message"] ?? "Mot de passe mis à jour avec succès",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        final raw = e.response!.data;
        return ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "message": _nestApiMessage(raw) ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": _networkErrorMessageForUser(e),
        "emailNotVerified": false,
      });
    } catch (_) {
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  Future<ResponseData> changePassword(currentMdp, newMdp, id, token) async {
    try {
      final response = await dio.patch(
        "/api/v1/users/$id/password",
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "authorization": "Bearer $token",
          },
        ),
        data: jsonEncode({
          "currentPassword": currentMdp,
          "newPassword": newMdp,
        }),
      );

      ResponseData finalResponse = ResponseData.fromJson({
        "success": response.data['success'],
        "data": [],
        "status": response.statusCode,
        "message": response.data['message'],
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
        });
        return finalResponse;
      } else {
        // 🚨 Problème réseau (timeout, pas d’internet, etc.)
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
        });
        return finalResponse;
      }
    } catch (e) {
      // 🚨 Autres erreurs imprévues
      ResponseData finalResponse = ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
      });
      return finalResponse;
    }
  }

  Future<ResponseData> uploadPhoto(file, token) async {
    try {
      // Gérer File, XFile ou chemin brut
      String filePath;
      if (file is String) {
        filePath = file;
      } else if (file is File) {
        filePath = file.path;
      } else {
        // Essayer d'accéder à .path pour XFile ou autres
        try {
          filePath = file.path as String;
        } catch (_) {
          return ResponseData(
            success: false,
            data: null,
            message: "Fichier invalide",
            status: 400,
            emailNotVerified: false,
          );
        }
      }

      final String filename = filePath.split('\\').last.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });

      final response = await dio.post<Map<String, dynamic>>(
        '/documents/upload',
        data: formData,
        options: Options(
          headers: {'authorization': 'Bearer $token'},
          contentType: 'multipart/form-data',
        ),
      );

      final raw = response.data;
      final code = response.statusCode ?? 500;
      final payload = _uploadResultMapFromResponse(raw);
      final urlStr = payload?['url'] as String?;
      if (code >= 200 &&
          code < 300 &&
          urlStr != null &&
          urlStr.isNotEmpty) {
        return ResponseData(
          success: true,
          data: payload,
          message: '',
          status: code,
          emailNotVerified: false,
        );
      }

      return ResponseData(
        success: false,
        data: null,
        message: _messageFromUploadBody(raw) ??
            'Réponse serveur sans URL.',
        status: code,
        emailNotVerified: false,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
        });
        return finalResponse;
      } else {
        ResponseData finalResponse = ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": 500,
          "message": "Problème réseau",
        });
        return finalResponse;
      }
    } catch (e) {
      ResponseData finalResponse = ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
      });
      return finalResponse;
    }
  }

  /// Désactive le compte de l'utilisateur connecté (endpoint public aux utilisateurs authentifiés).
  Future<ResponseData> deactivateMyAccount(String token) async {
    print("desactiver le compte");
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

      final response = await dio.post(
        "/auth/me/deactivate",
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
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
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": e.response!.data['success'],
          "data": e.response!.data['data'],
          "message": e.response!.data["message"] ?? "Erreur serveur",
          "status": e.response!.statusCode,
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Récupère la liste des offres d'abonnement disponibles.
  Future<ResponseData> getAbonnementOffres(String? token) async {
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
        "/abonnements/offres",
        options: Options(
          headers: {
            "Content-Type": "application/json",
            if (token != null) "authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return ResponseData.fromJson({
        "success": response.data['success'] ?? true,
        "data": response.data['data'] ?? response.data,
        "status": response.statusCode,
        "message": response.data['message'] ?? "",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (_) {
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Souscrit à une offre d'abonnement pour le prestataire connecté.
  Future<ResponseData> souscrireAbonnement(
    String offreId,
    String? token,
  ) async {
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

      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          message: "Utilisateur non authentifié",
          data: null,
          status: 401,
          emailNotVerified: false,
        );
      }

      final response = await dio.post(
        "/abonnements/souscrire",
        data: jsonEncode({"offreId": offreId}),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return ResponseData.fromJson({
        "success": response.data['success'] ?? true,
        "data": response.data['data'] ?? response.data,
        "status": response.statusCode,
        "message": response.data['message'] ?? "",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": [],
          "status": e.response!.statusCode,
          "message": e.response?.data["message"] ?? "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur serveur",
        "emailNotVerified": false,
      });
    } catch (_) {
      return ResponseData.fromJson({
        "success": false,
        "data": [],
        "status": 500,
        "message": "Erreur inconnue",
        "emailNotVerified": false,
      });
    }
  }

  /// Prépare un paiement PayDunya pour souscrire (checkout + token facture).
  Future<ResponseData> initPaydunyaAbonnement(
    String offreId,
    String? token,
  ) async {
    try {
      final hasInternet = await _checkInternetConnection();
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
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          message: "Utilisateur non authentifié",
          data: null,
          status: 401,
          emailNotVerified: false,
        );
      }
      final response = await dio.post(
        "/abonnements/souscrire/paydunya/init",
        data: jsonEncode({"offreId": offreId}),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return ResponseData.fromJson({
        "success": response.statusCode == 200 || response.statusCode == 201,
        "data": response.data['data'] ?? response.data,
        "status": response.statusCode,
        "message": response.data is Map ? (response.data['message'] ?? "") : "",
        "emailNotVerified": false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          "success": false,
          "data": null,
          "status": e.response!.statusCode,
          "message": e.response?.data is Map
              ? (e.response!.data['message'] ?? "Erreur serveur")
              : "Erreur serveur",
          "emailNotVerified": false,
        });
      }
      return ResponseData(
        success: false,
        message: "Erreur réseau",
        data: null,
        status: 500,
        emailNotVerified: false,
      );
    } catch (_) {
      return ResponseData(
        success: false,
        message: "Erreur inconnue",
        data: null,
        status: 500,
        emailNotVerified: false,
      );
    }
  }

  Future<ResponseData> _abonnementPaydunyaSoftPay({
    required String token,
    required String offreId,
    required String invoiceToken,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
    required String endpointSegment,
  }) async {
    try {
      final hasInternet = await _checkInternetConnection();
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
      if (token.isEmpty) {
        return ResponseData(
          success: false,
          message: "Utilisateur non authentifié",
          data: null,
          status: 401,
          emailNotVerified: false,
        );
      }
      final path = '/abonnements/souscrire/paydunya/$endpointSegment';
      final body = <String, dynamic>{
        'offreId': offreId,
        'invoiceToken': invoiceToken.trim(),
        'prenom': prenom,
        'nom': nom,
        'telephone': telephone,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      };
      final response = await dio.post(
        path,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final data = raw is Map && raw['data'] != null
          ? raw['data']
          : raw is Map
              ? raw
              : null;
      final ok = response.statusCode == 200 || response.statusCode == 201;
      return ResponseData.fromJson({
        'success': ok,
        'data': data,
        'message': raw is Map ? (raw['message'] ?? '') : '',
        'status': response.statusCode,
        'emailNotVerified': false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData.fromJson({
          'success': false,
          'data': null,
          'status': e.response!.statusCode,
          'message': e.response?.data is Map
              ? (e.response!.data['message'] ?? 'Erreur serveur')
              : 'Erreur serveur',
          'emailNotVerified': false,
        });
      }
      return ResponseData(
        success: false,
        message: 'Erreur réseau',
        data: null,
        status: 500,
        emailNotVerified: false,
      );
    } catch (_) {
      return ResponseData(
        success: false,
        message: 'Erreur inconnue',
        data: null,
        status: 500,
        emailNotVerified: false,
      );
    }
  }

  Future<ResponseData> payAbonnementWaveSn({
    required String token,
    required String offreId,
    required String invoiceToken,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
  }) {
    return _abonnementPaydunyaSoftPay(
      token: token,
      offreId: offreId,
      invoiceToken: invoiceToken,
      prenom: prenom,
      nom: nom,
      telephone: telephone,
      email: email,
      endpointSegment: 'wave',
    );
  }

  Future<ResponseData> payAbonnementOrangeMoneySn({
    required String token,
    required String offreId,
    required String invoiceToken,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
  }) {
    return _abonnementPaydunyaSoftPay(
      token: token,
      offreId: offreId,
      invoiceToken: invoiceToken,
      prenom: prenom,
      nom: nom,
      telephone: telephone,
      email: email,
      endpointSegment: 'orange-money',
    );
  }

  Future<ResponseData> payAbonnementFreeMoneySn({
    required String token,
    required String offreId,
    required String invoiceToken,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
  }) {
    return _abonnementPaydunyaSoftPay(
      token: token,
      offreId: offreId,
      invoiceToken: invoiceToken,
      prenom: prenom,
      nom: nom,
      telephone: telephone,
      email: email,
      endpointSegment: 'free-money',
    );
  }

  /// Abonnement actif du prestataire (`null` si aucun).
  Future<ResponseData> getAbonnementCourant(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          message: "Utilisateur non authentifié",
          data: null,
          status: 401,
          emailNotVerified: false,
        );
      }
      final response = await dio.get(
        "/abonnements/courant",
        options: Options(
          headers: {"Authorization": "Bearer $token"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final payload =
          raw is Map && raw['data'] != null ? raw['data'] : raw is Map ? raw : null;
      return ResponseData(
        success: response.statusCode == 200,
        data: payload,
        status: response.statusCode,
        message: raw is Map ? (raw['message'] ?? '') : '',
        emailNotVerified: false,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData(
          success: false,
          data: null,
          status: e.response!.statusCode,
          message: e.response?.data is Map
              ? (e.response!.data['message'] ?? "Erreur serveur")
              : "Erreur serveur",
          emailNotVerified: false,
        );
      }
      return ResponseData(
        success: false,
        message: "Erreur réseau",
        data: null,
        status: 500,
        emailNotVerified: false,
      );
    } catch (_) {
      return ResponseData(
        success: false,
        message: "Erreur inconnue",
        data: null,
        status: 500,
        emailNotVerified: false,
      );
    }
  }

  /// Indique si l’IPN PayDunya a enregistré le paiement pour ce [invoiceToken] (abonnement).
  Future<ResponseData> isAbonnementPaydunyaInvoicePaid({
    required String? token,
    required String invoiceToken,
  }) async {
    try {
      if (token == null || token.isEmpty) {
        return ResponseData(
          success: false,
          message: "Utilisateur non authentifié",
          data: null,
          status: 401,
          emailNotVerified: false,
        );
      }
      final response = await dio.get(
        "/abonnements/souscrire/paydunya/invoice-paid",
        queryParameters: {"invoiceToken": invoiceToken},
        options: Options(
          headers: {"Authorization": "Bearer $token"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      Map<String, dynamic>? map;
      if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      }
      final inner = map != null && map['data'] != null && map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : map;
      return ResponseData(
        success: response.statusCode == 200,
        data: inner,
        status: response.statusCode,
        message: map != null ? (map['message']?.toString() ?? '') : '',
        emailNotVerified: false,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        return ResponseData(
          success: false,
          data: null,
          status: e.response!.statusCode,
          message: e.response?.data is Map
              ? (e.response!.data['message'] ?? "Erreur serveur")
              : "Erreur serveur",
          emailNotVerified: false,
        );
      }
      return ResponseData(
        success: false,
        message: "Erreur réseau",
        data: null,
        status: 500,
        emailNotVerified: false,
      );
    } catch (_) {
      return ResponseData(
        success: false,
        message: "Erreur inconnue",
        data: null,
        status: 500,
        emailNotVerified: false,
      );
    }
  }
}
