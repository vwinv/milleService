import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/models/wallet.dart';
import 'package:milleservices/services/utilities.dart';

class WalletController {
  WalletController._instantiate();
  WalletController();
  static final WalletController instance = WalletController._instantiate();

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

  /// Récupère le wallet du prestataire connecté + ses dernières transactions.
  /// Retourne dans `data` un Map { wallet, transactions } (brut),
  /// que l'écran pourra mapper sur `WalletModel` / `WalletTransactionModel`.
  Future<ResponseData> getMyWallet({
    required String token,
    int? limit,
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

      final response = await dio.get(
        '/wallets/me',
        queryParameters: {
          if (limit != null) 'limit': limit,
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
      if (raw is Map<String, dynamic>) {
        return ResponseData.fromJson({
          ...raw,
          'status': raw['status'] ?? response.statusCode,
          'emailNotVerified': false,
        });
      }
      return ResponseData.fromJson({
        'success': response.statusCode == 200,
        'data': null,
        'message': '',
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

  /// Crée une demande de retrait (traitement manuel sous 48h environ).
  /// [method] doit être une valeur de l'enum backend :
  /// ORANGE_MONEY, WAVE, FREE_MONEY ou RIB.
  Future<ResponseData> requestWithdrawal({
    required String token,
    required String method,
    required double amount,
  }) async {
    try {
      final response = await dio.post(
        '/wallets/withdrawals/request',
        data: {
          'method': method,
          'amount': amount,
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
      if (raw is Map<String, dynamic>) {
        return ResponseData.fromJson({
          ...raw,
          'status': raw['status'] ?? response.statusCode,
          'emailNotVerified': false,
        });
      }
      return ResponseData.fromJson({
        'success': response.statusCode == 200 || response.statusCode == 201,
        'data': null,
        'message': '',
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
    } catch (_) {
      return ResponseData.fromJson({
        'success': false,
        'data': null,
        'status': 500,
        'message': 'Erreur inconnue',
        'emailNotVerified': false,
      });
    }
  }

  /// Helper pour parser la réponse en modèles forts (optionnel, utilisable par un Provider).
  /// Renvoie (wallet, transactions) typés ou (null, []) si rien.
  ({WalletModel? wallet, List<WalletTransactionModel> transactions})
      parseWalletPayload(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return (wallet: null, transactions: <WalletTransactionModel>[]);
    }
    final walletJson = payload['wallet'] as Map<String, dynamic>?;
    final listJson = payload['transactions'] as List<dynamic>? ?? const [];
    final wallet =
        walletJson != null ? WalletModel.fromJson(walletJson) : null;
    final transactions = listJson
        .whereType<Map<String, dynamic>>()
        .map(WalletTransactionModel.fromJson)
        .toList();
    return (wallet: wallet, transactions: transactions);
  }
}

