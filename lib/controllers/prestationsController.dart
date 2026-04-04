import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/services/utilities.dart';

class PrestationsController {
  PrestationsController._instantiate();
  PrestationsController();
  static final PrestationsController instance =
      PrestationsController._instantiate();

  final dio = Dio(
    BaseOptions(
      baseUrl: Utilities().baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on TimeoutException catch (_) {
      return false;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Crée une prestation (particulier). Retourne la prestation créée ou null en cas d'échec.
  Future<ResponseData> createPrestation({
    required String token,
    required String prestataireId,
    required String prestataireServiceId,
    String? typeDeTache,
    String? description,
    String? imageUrl,
    double? budget,
    String? adresse,
    String? codePostal,
    String? ville,
    String? noteParticulier,
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
        '/prestations',
        data: {
          'prestataireId': prestataireId,
          'prestataireServiceId': prestataireServiceId,
          if (typeDeTache != null && typeDeTache.isNotEmpty) 'typeDeTache': typeDeTache,
          if (description != null && description.isNotEmpty) 'description': description,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          if (budget != null) 'budget': budget,
          if (adresse != null && adresse.isNotEmpty) 'adresse': adresse,
          if (codePostal != null && codePostal.isNotEmpty) 'codePostal': codePostal,
          if (ville != null && ville.isNotEmpty) 'ville': ville,
          if (noteParticulier != null && noteParticulier.isNotEmpty)
            'noteParticulier': noteParticulier,
        },
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
      return ResponseData.fromJson({
        'success': response.statusCode == 201 || response.statusCode == 200,
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
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Récupère une prestation par ID (avec coordonnées prestataire/particulier).
  /// Réservé au particulier ou au prestataire concerné.
  Future<ResponseData> getPrestationById(String token, String prestationId) async {
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
      final response = await dio.get(
        '/prestations/$prestationId',
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
      return ResponseData.fromJson({
        'success': response.statusCode == 200,
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
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Marque la prestation comme payée (particulier). PATCH /prestations/:id/payer
  /// [montant] : montant réellement payé (FCFA), requis côté UX lorsque le service a un tarif catalogue.
  Future<ResponseData> marquerPayee(
    String token,
    String prestationId, {
    double? montant,
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
      final body = <String, dynamic>{
        if (montant != null) 'montant': montant,
      };
      final response = await dio.patch(
        '/prestations/$prestationId/payer',
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
      final data = raw is Map && raw['data'] != null ? raw['data'] : raw is Map ? raw : null;
      return ResponseData.fromJson({
        'success': response.statusCode == 200,
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
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Démarre une prestation (prestataire arrivé chez le client). PATCH /prestations/:id/demarrer
  Future<ResponseData> demarrer(String token, String prestationId) async {
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
      final response = await dio.patch(
        '/prestations/$prestationId/demarrer',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final data =
          raw is Map && raw['data'] != null ? raw['data'] : raw is Map ? raw : null;
      return ResponseData.fromJson({
        'success': response.statusCode == 200,
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
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Accepter une prestation (prestataire). PATCH /prestations/:id/accepter
  Future<ResponseData> accepter(String token, String prestationId) async {
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
      final response = await dio.patch(
        '/prestations/$prestationId/accepter',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final data = raw is Map && raw['data'] != null ? raw['data'] : raw is Map ? raw : null;
      return ResponseData.fromJson({
        'success': response.statusCode == 200,
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
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Refuser une prestation (prestataire). PATCH /prestations/:id/refuser
  Future<ResponseData> refuser(String token, String prestationId) async {
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
      final response = await dio.patch(
        '/prestations/$prestationId/refuser',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final data = raw is Map && raw['data'] != null ? raw['data'] : raw is Map ? raw : null;
      return ResponseData.fromJson({
        'success': response.statusCode == 200,
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
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Terminer une prestation (prestataire). PATCH /prestations/:id/terminer
  Future<ResponseData> terminer(String token, String prestationId) async {
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
      final response = await dio.patch(
        '/prestations/$prestationId/terminer',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final data =
          raw is Map && raw['data'] != null ? raw['data'] : raw is Map ? raw : null;
      return ResponseData.fromJson({
        'success': response.statusCode == 200,
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
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Liste des prestations de l'utilisateur connecté (particulier ou prestataire).
  /// Retourne un tableau d'objets prestation (bruts) en `data`.
  Future<ResponseData> getMyPrestations(String token) async {
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
      final response = await dio.get(
        '/prestations/me',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final raw = response.data;
      final list = raw is List
          ? raw
          : raw is Map && raw['data'] is List
              ? raw['data'] as List
              : <dynamic>[];
      return ResponseData.fromJson({
        'success': response.statusCode == 200,
        'data': list,
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
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }
}
