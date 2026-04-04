import 'package:flutter/foundation.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/models/avis_client.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/models/prestataire_photo.dart';
import 'package:milleservices/models/service_category.dart';
import 'package:milleservices/providers/userProvider.dart';

class PrestatairesProvider extends ChangeNotifier {
  final PrestatairesController _controller = PrestatairesController();

  List<Prestataire> _favoris = [];
  List<Prestataire> get favoris => _favoris;

  /// True quand la liste affichée vient du palier « plus proches » (pas des favoris semaine / note).
  bool _favorisListeProximite = false;
  bool get favorisListeProximite => _favorisListeProximite;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Services (catégories) disponibles
  List<ServiceCategory> _services = [];
  List<ServiceCategory> get services => _services;

  bool _servicesLoading = false;
  bool get servicesLoading => _servicesLoading;

  String? _servicesError;
  String? get servicesError => _servicesError;

  /// IDs des services déjà enregistrés pour le prestataire connecté (pour pré-cocher dans EditInfos).
  List<String> _myServiceIds = [];
  List<String> get myServiceIds => _myServiceIds;

  // Résultats de recherche
  List<Prestataire> _searchResults = [];
  List<Prestataire> get searchResults => _searchResults;

  bool _searchLoading = false;
  bool get searchLoading => _searchLoading;

  String? _searchError;
  String? get searchError => _searchError;

  // Catalogue photos du prestataire connecté
  List<PrestatairePhoto> _myPhotos = [];
  List<PrestatairePhoto> get myPhotos => _myPhotos;

  bool _photosLoading = false;
  bool get photosLoading => _photosLoading;

  String? _photosError;
  String? get photosError => _photosError;

  /// Avis des clients pour un prestataire (page détails).
  List<AvisClient> _prestataireAvis = [];
  List<AvisClient> get prestataireAvis => _prestataireAvis;

  bool _avisLoading = false;
  bool get avisLoading => _avisLoading;

  /// Charge les avis clients pour un prestataire donné.
  Future<void> loadAvisPrestataire(String prestataireId) async {
    _avisLoading = true;
    _prestataireAvis = [];
    notifyListeners();

    final result = await _controller.getAvisPrestataire(prestataireId);
    if (result.success == true && result.data != null) {
      final raw = result.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List) ? raw['data'] as List : <dynamic>[];
      _prestataireAvis = list
          .whereType<Map<String, dynamic>>()
          .map((e) => AvisClient.fromJson(e))
          .toList();
    }
    _avisLoading = false;
    notifyListeners();
  }

  /// Charge les photos du catalogue pour le prestataire connecté.
  Future<void> loadMyPhotos(UserProvider userProvider) async {
    _photosLoading = true;
    _photosError = null;
    notifyListeners();

    var result = await _controller.getMyPhotos(userProvider.token);
    if (result.status == 401) {
      await userProvider.refreshToken();
      result = await _controller.getMyPhotos(userProvider.token);
    }

    if (result.success == true && result.data != null) {
      final raw = result.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
                ? raw['data'] as List
                : <dynamic>[]);
      _myPhotos = list
          .map((e) => PrestatairePhoto.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _photosError = result.message;
    }

    _photosLoading = false;
    notifyListeners();
  }

  /// Ajoute une photo au catalogue du prestataire et recharge la liste.
  Future<bool> addPhotoToMyCatalogue({
    required String url,
    String? titre,
    String? description,
    int? ordre,
    required UserProvider userProvider,
  }) async {
    var result = await _controller.addPhotoToCatalogue(
      url: url,
      titre: titre,
      description: description,
      ordre: ordre,
      token: userProvider.token,
    );
    if (result.status == 401) {
      await userProvider.refreshToken();
      result = await _controller.addPhotoToCatalogue(
        url: url,
        titre: titre,
        description: description,
        ordre: ordre,
        token: userProvider.token,
      );
    }
    final ok = result.success == true;
    if (ok) {
      await loadMyPhotos(userProvider);
    }
    return ok;
  }

  /// Récupère les photos publiques pour un prestataire (profil côté particulier).
  Future<List<PrestatairePhoto>> fetchPrestatairePhotos(
    String prestataireId,
  ) async {
    final result = await _controller.getPrestatairePhotos(prestataireId);
    if (result.success == true && result.data != null) {
      final raw = result.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
                ? raw['data'] as List
                : <dynamic>[]);
      return list
          .map((e) => PrestatairePhoto.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Charge les IDs des services du prestataire connecté (pour pré-cocher dans EditInfos).
  Future<void> loadMyServiceIds(UserProvider userProvider) async {
    var result = await _controller.getMyServiceIds(userProvider.token);
    if (result.status == 401) {
      await userProvider.refreshToken();
      result = await _controller.getMyServiceIds(userProvider.token);
    }
    if (result.success == true && result.data != null) {
      final raw = result.data;
      // Réponse API : { success, data: { serviceIds: [...] } } (enveloppée par l'interceptor)
      List<dynamic>? ids;
      if (raw is Map) {
        if (raw['data'] is Map && (raw['data'] as Map)['serviceIds'] is List) {
          ids = (raw['data'] as Map)['serviceIds'] as List;
        } else if (raw['serviceIds'] is List) {
          ids = raw['serviceIds'] as List;
        }
      }
      _myServiceIds = ids != null
          ? ids.map((e) => e.toString()).toList()
          : <String>[];
    } else {
      _myServiceIds = [];
    }
    notifyListeners();
  }

  Future<void> loadServicesIfNeeded() async {
    if (_services.isNotEmpty || _servicesLoading) return;
    await _loadServices();
  }

  Future<void> _loadServices() async {
    _servicesLoading = true;
    notifyListeners();

    final result = await _controller.getCategories();

    if (result.success == true) {
      var data = result.data as List<dynamic>;
      _services = data
          .map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _servicesLoading = false;
    notifyListeners();
  }

  /// Charge les prestataires favoris de la semaine.
  /// [lat] et [lng] optionnels : position du particulier (depuis UserProvider).
  Future<void> loadFavoris({
    double? lat,
    double? lng,
    required UserProvider userProvider,
  }) async {
    _isLoading = true;
    _favorisListeProximite = false;
    notifyListeners();

    var result = await _controller.getFavoris(
      lat: lat,
      lng: lng,
      token: userProvider.token,
    );

    if (result.status == 401) {
      await userProvider.refreshToken();
      result = await _controller.getFavoris(
        lat: lat,
        lng: lng,
        token: userProvider.token,
      );
    }
    if (result.success == true && result.data != null) {
      final raw = result.data;
      List<dynamic> list;
      if (raw is List) {
        list = raw;
        _favorisListeProximite = false;
      } else if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final nested = m['data'];
        if (nested is Map) {
          m.addAll(Map<String, dynamic>.from(nested));
        }
        final arr = m['prestataires'] ?? m['items'];
        list = arr is List<dynamic> ? arr : <dynamic>[];
        _favorisListeProximite = m['listeProximite'] == true;
      } else {
        list = <dynamic>[];
      }
      _favoris = list
          .whereType<Map<String, dynamic>>()
          .map(Prestataire.fromJson)
          .toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Lance la recherche de prestataires (service, tarif, date si planifier).
  Future<void> loadSearch({
    String? serviceId,
    double? tarifMin,
    double? tarifMax,
    String? date,
    required UserProvider userProvider,
  }) async {
    _searchLoading = true;
    _searchError = null;
    _searchResults = [];
    notifyListeners();

    var result = await _controller.searchPrestataires(
      serviceId: serviceId,
      tarifMin: tarifMin,
      tarifMax: tarifMax,
      date: date,
      token: userProvider.token,
    );

    print(result);
    if (result.status == 401) {
      await userProvider.refreshToken();
      result = await _controller.searchPrestataires(
        serviceId: serviceId,
        tarifMin: tarifMin,
        tarifMax: tarifMax,
        date: date,
        token: userProvider.token,
      );
    }

    if (result.success == true && result.data != null) {
      final list = result.data as List<dynamic>;
      _searchResults = list.map((e) => Prestataire.fromJson(e)).toList();
    } else {
      _searchError = result.message;
    }

    _searchLoading = false;
    notifyListeners();
  }
}
