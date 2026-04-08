import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:milleservices/controllers/prestationsController.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/userProvider.dart';

/// Provider pour gérer les prestations de l'utilisateur connecté
/// (particulier ou prestataire).
class PrestationsProvider extends ChangeNotifier {
  final PrestationsController _controller = PrestationsController.instance;

  final List<Prestation> _myPrestations = [];
  List<Prestation> get myPrestations => List.unmodifiable(_myPrestations);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Stream pour l'écran déroulement : écoute GET /prestations/:id en continu
  StreamController<Prestation>? _prestationStreamController;
  static const Duration _defaultPollInterval = Duration(seconds: 4);
  bool _listening = false;
  String? _listeningPrestationId;
  Duration _pollInterval = _defaultPollInterval;

  /// Stream de la prestation en cours d'écoute (pour StreamBuilder sur l'écran déroulement).
  Stream<Prestation>? get prestationStream => _prestationStreamController?.stream;

  /// Démarre l'écoute de l'endpoint GET /prestations/:id (polling, 4 s par défaut).
  /// [pollInterval] : sur le déroulement, intervalle plus court pour suivre la position live du prestataire.
  void startListeningPrestation(
    String prestationId,
    UserProvider userProvider, {
    Duration pollInterval = _defaultPollInterval,
  }) {
    if (prestationId.isEmpty) return;
    if (_listening &&
        _listeningPrestationId == prestationId &&
        _pollInterval == pollInterval) {
      return;
    }

    stopListeningPrestation(notify: false);
    _prestationStreamController = StreamController<Prestation>.broadcast();
    _listeningPrestationId = prestationId;
    _pollInterval = pollInterval;
    _listening = true;
    _pollLoop(userProvider);
  }

  Future<void> _pollLoop(UserProvider userProvider) async {
    final id = _listeningPrestationId!;
    final interval = _pollInterval;
    // Laisser le build en cours se terminer avant la première émission (évite setState pendant build).
    await Future.delayed(Duration.zero);
    while (_listening && _prestationStreamController != null) {
      final token = userProvider.token;
      if (token == null || token.isEmpty) break;

      final res = await _controller.getPrestationById(token, id);
      if (!_listening || _prestationStreamController == null) return;

      if (res.success == true && res.data != null && res.data is Map) {
        final prestation = Prestation.fromJson(
          Map<String, dynamic>.from(res.data as Map),
        );
        _prestationStreamController!.add(prestation);
      }

      await Future.delayed(interval);
    }
  }

  /// Arrête l'écoute et ferme le stream.
  /// [notify] : false quand appelé depuis startListeningPrestation ou dispose pour éviter setState pendant/après dispose.
  void stopListeningPrestation({bool notify = false}) {
    _listening = false;
    _listeningPrestationId = null;
    final controller = _prestationStreamController;
    _prestationStreamController = null;
    if (controller != null) {
      // Fermer après le frame pour éviter setState/markNeedsBuild quand l'arbre est verrouillé.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        controller.close();
      });
    }
    if (notify) notifyListeners();
  }

  /// Un seul fetch GET /prestations/:id puis émission dans le stream.
  Future<void> fetchPrestationOnceAndEmit(String prestationId, String token) async {
    if (prestationId.isEmpty || _prestationStreamController == null) return;
    final res = await _controller.getPrestationById(token, prestationId);
    if (res.success == true && res.data != null && res.data is Map) {
      _prestationStreamController?.add(
        Prestation.fromJson(Map<String, dynamic>.from(res.data as Map)),
      );
    }
  }

  /// Marque la prestation comme payée puis rafraîchit le stream (fetch once + emit).
  /// Retourne (success, message d'erreur éventuel).
  Future<({bool success, String? message})> marquerPayeeEtRafraichir(
    String prestationId,
    String token, {
    double? montant,
  }) async {
    final res = await _controller.marquerPayee(
      token,
      prestationId,
      montant: montant,
    );
    if (res.success == true) {
      await fetchPrestationOnceAndEmit(prestationId, token);
      return (success: true, message: null);
    }
    return (success: false, message: res.message?.toString());
  }

  /// Charge les prestations de l'utilisateur connecté (particulier ou prestataire).
  Future<void> loadMyPrestations(UserProvider userProvider) async {
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      _error = 'Non authentifié';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    var res = await _controller.getMyPrestations(token);
    if (res.status == 401) {
      await userProvider.refreshToken();
      if (userProvider.token != null && userProvider.token!.isNotEmpty) {
        res = await _controller.getMyPrestations(userProvider.token!);
      }
    }

    _myPrestations.clear();

    if (res.success == true && res.data is List) {
      final rawList = res.data as List;
      for (final item in rawList) {
        if (item is Map) {
          _myPrestations.add(
            Prestation.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    } else {
      _error = res.message?.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}

