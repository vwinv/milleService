import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/services/utilities.dart';

void _paiementLog(String message) {
  debugPrint('[MilleServices][Paiement] $message');
}

String _maskInvoiceToken(String? token) {
  final t = token?.trim() ?? '';
  if (t.isEmpty) return '(vide)';
  if (t.length <= 8) return '***';
  return '${t.substring(0, 6)}…';
}

String _maskPhoneForLog(String phone) {
  final d = phone.replaceAll(RegExp(r'\s'), '');
  if (d.length <= 2) return '***';
  return '***${d.substring(d.length - 2)}';
}

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

  /// Wave Sénégal — POST …/paiement/paydunya/wave (PayDunya `wave-senegal`).
  Future<ResponseData> payWithWaveSn({
    required String token,
    required String prestationId,
    required String invoiceToken,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
  }) {
    return _prestationPaydunyaSoftPay(
      token: token,
      prestationId: prestationId,
      invoiceToken: invoiceToken,
      prenom: prenom,
      nom: nom,
      telephone: telephone,
      email: email,
      endpointSegment: 'wave',
      logName: 'payWithWave',
    );
  }

  /// Orange Money Sénégal — POST …/paiement/paydunya/orange-money.
  Future<ResponseData> payWithOrangeMoneySn({
    required String token,
    required String prestationId,
    required String invoiceToken,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
  }) {
    return _prestationPaydunyaSoftPay(
      token: token,
      prestationId: prestationId,
      invoiceToken: invoiceToken,
      prenom: prenom,
      nom: nom,
      telephone: telephone,
      email: email,
      endpointSegment: 'orange-money',
      logName: 'payWithOrangeMoney',
    );
  }

  /// Free Money Sénégal — POST …/paiement/paydunya/free-money.
  Future<ResponseData> payWithFreeMoneySn({
    required String token,
    required String prestationId,
    required String invoiceToken,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
  }) {
    return _prestationPaydunyaSoftPay(
      token: token,
      prestationId: prestationId,
      invoiceToken: invoiceToken,
      prenom: prenom,
      nom: nom,
      telephone: telephone,
      email: email,
      endpointSegment: 'free-money',
      logName: 'payWithFreeMoney',
    );
  }

  /// Paiement mobile (legacy) — POST …/paiement/paydunya/softpay avec `method` dans le corps.
  Future<ResponseData> softPayPrestation({
    required String token,
    required String prestationId,
    required String invoiceToken,
    required String method,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
  }) {
    return _prestationPaydunyaSoftPay(
      token: token,
      prestationId: prestationId,
      invoiceToken: invoiceToken,
      prenom: prenom,
      nom: nom,
      telephone: telephone,
      email: email,
      endpointSegment: 'softpay',
      softpayMethod: method,
      logName: 'softPay(method=$method)',
    );
  }

  Future<ResponseData> _prestationPaydunyaSoftPay({
    required String token,
    required String prestationId,
    required String invoiceToken,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
    required String endpointSegment,
    String? softpayMethod,
    required String logName,
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
      final path =
          '/prestations/$prestationId/paiement/paydunya/$endpointSegment';
      final body = <String, dynamic>{
        'invoiceToken': invoiceToken.trim(),
        'prenom': prenom,
        'nom': nom,
        'telephone': telephone,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (softpayMethod != null) 'method': softpayMethod,
      };
      _paiementLog(
        '$logName → POST $path '
        'invoiceToken=${_maskInvoiceToken(invoiceToken)} '
        'tel=${_maskPhoneForLog(telephone)}',
      );
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
      String? softMsg;
      bool? hasUrl;
      if (data is Map && data['softPay'] is Map) {
        final sp = data['softPay'] as Map;
        softMsg = sp['message']?.toString();
        final u = sp['url']?.toString();
        final ou = sp['other_url'];
        hasUrl = (u != null && u.isNotEmpty) ||
            (ou is Map &&
                ((ou['om_url']?.toString().isNotEmpty == true) ||
                    (ou['maxit_url']?.toString().isNotEmpty == true)));
      }
      final msgShort = softMsg == null
          ? ''
          : (softMsg.length > 100
              ? '${softMsg.substring(0, 100)}…'
              : softMsg);
      final urlPart = hasUrl == null ? '' : ' hasPayUrl=$hasUrl';
      _paiementLog(
        '$logName ← status=${response.statusCode} success=$ok'
        '${msgShort.isEmpty ? '' : ' message=$msgShort'}'
        '$urlPart',
      );
      return ResponseData.fromJson({
        'success': ok,
        'data': data,
        'message': raw is Map ? (raw['message'] ?? '') : '',
        'status': response.statusCode,
        'emailNotVerified': false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        _paiementLog(
          '$logName ✗ Dio status=${e.response!.statusCode} '
          '${e.response?.data is Map ? 'message=${e.response!.data['message']}' : ''}',
        );
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
      _paiementLog('$logName ✗ réseau sans réponse');
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      _paiementLog('$logName ✗ exception $e');
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Vérifie chez PayDunya si la facture est payée et enregistre en base (repli IPN).
  Future<ResponseData> checkPaydunyaInvoicePaid({
    required String token,
    required String prestationId,
    required String invoiceToken,
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
      _paiementLog(
        'invoice-paid → GET /prestations/$prestationId/paiement/paydunya/invoice-paid',
      );
      final response = await dio.get(
        '/prestations/$prestationId/paiement/paydunya/invoice-paid',
        queryParameters: {'invoiceToken': invoiceToken},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
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
      final ok = response.statusCode == 200;
      final paid = inner?['paid'] == true;
      _paiementLog(
        'invoice-paid ← status=${response.statusCode} paid=$paid',
      );
      return ResponseData(
        success: ok,
        data: inner,
        status: response.statusCode,
        message: map != null ? (map['message']?.toString() ?? '') : '',
        emailNotVerified: false,
      );
    } on DioException catch (e) {
      _paiementLog('invoice-paid ✗ Dio ${e.response?.statusCode}');
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': e.response?.statusCode ?? 500,
        'message': e.response?.data is Map
            ? (e.response!.data['message'] ?? 'Erreur serveur')
            : 'Erreur serveur',
        'emailNotVerified': false,
      });
    } catch (e) {
      _paiementLog('invoice-paid ✗ exception $e');
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Prépare un paiement PayDunya pour une prestation terminée. POST …/paiement/paydunya/init
  Future<ResponseData> initPaydunyaPaiement(
    String token,
    String prestationId,
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
      _paiementLog(
        'init → POST /prestations/$prestationId/paiement/paydunya/init',
      );
      final response = await dio.post(
        '/prestations/$prestationId/paiement/paydunya/init',
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
      num? amountFcfa;
      if (data is Map && data['amountFcfa'] != null) {
        amountFcfa = num.tryParse(data['amountFcfa'].toString());
      }
      final invTok = data is Map
          ? data['invoiceToken']?.toString()
          : null;
      final hasCheckout =
          data is Map && data['checkoutUrl']?.toString().isNotEmpty == true;
      _paiementLog(
        'init ← status=${response.statusCode} success=$ok '
        'amountFcfa=${amountFcfa ?? '?'} '
        'invoiceToken=${_maskInvoiceToken(invTok)} hasCheckoutUrl=$hasCheckout',
      );
      return ResponseData.fromJson({
        'success': ok,
        'data': data,
        'message': raw is Map ? (raw['message'] ?? '') : '',
        'status': response.statusCode,
        'emailNotVerified': false,
      });
    } on DioException catch (e) {
      if (e.response != null) {
        _paiementLog(
          'init ✗ Dio status=${e.response!.statusCode} '
          '${e.response?.data is Map ? 'message=${e.response!.data['message']}' : ''}',
        );
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
      _paiementLog('init ✗ réseau sans réponse');
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur réseau',
        'emailNotVerified': false,
      });
    } catch (e) {
      _paiementLog('init ✗ exception $e');
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
