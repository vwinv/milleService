import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:milleservices/controllers/geocodingController.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/services/device_location_service.dart';
import 'package:milleservices/services/utilities.dart';
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
    _error = null;
    _favorisListeProximite = false;
    notifyListeners();
    // Quand le mode temps reel est desactive, on ignore toute coordonnee GPS entrante.
    double? gpsLat = Utilities.useRealtimeLocation ? lat : null;
    double? gpsLng = Utilities.useRealtimeLocation ? lng : null;
    if (Utilities.useRealtimeLocation && (gpsLat == null || gpsLng == null)) {
      final device = await DeviceLocationService.getCurrentLatLngOrNull();
      if (device != null) {
        gpsLat = device.latitude;
        gpsLng = device.longitude;
      }
    }
    final user = userProvider.user;
    double? baseLat = gpsLat ?? _toDoubleOrNull(user?.latitude);
    double? baseLng = gpsLng ?? _toDoubleOrNull(user?.longitude);
    if (!Utilities.useRealtimeLocation) {
      final byAddress = await _resolveProfileAddressLatLng(userProvider);
      if (byAddress != null) {
        baseLat = byAddress.lat;
        baseLng = byAddress.lng;
      }
    }
    try {
      var result = await _controller.getFavoris(
        lat: gpsLat,
        lng: gpsLng,
        token: userProvider.token,
      );

      if (result.status == 401) {
        await userProvider.refreshToken();
        result = await _controller.getFavoris(
          lat: gpsLat,
          lng: gpsLng,
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
            .map(
              (p) =>
                  _computeDistanceIfMissing(p, userLat: baseLat, userLng: baseLng),
            )
            .toList();
        _error = null;
      } else {
        _favoris = [];
        _favorisListeProximite = false;
        final msg = result.message;
        _error = msg != null && msg.toString().trim().isNotEmpty
            ? msg.toString()
            : 'Impossible de charger les favoris. Vérifiez votre connexion.';
      }
    } catch (_) {
      _favoris = [];
      _favorisListeProximite = false;
      _error = 'Impossible de charger les favoris. Vérifiez votre connexion.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

    double? searchLat;
    double? searchLng;
    if (Utilities.useRealtimeLocation) {
      final device = await DeviceLocationService.getCurrentLatLngOrNull();
      if (device != null) {
        searchLat = device.latitude;
        searchLng = device.longitude;
      }
    }
    if (searchLat == null || searchLng == null) {
      final u = userProvider.user;
      if (u?.latitude != null && u?.longitude != null) {
        searchLat = (u!.latitude as num).toDouble();
        searchLng = (u.longitude as num).toDouble();
      }
    }
    if (!Utilities.useRealtimeLocation) {
      final byAddress = await _resolveProfileAddressLatLng(userProvider);
      if (byAddress != null) {
        searchLat = byAddress.lat;
        searchLng = byAddress.lng;
      }
    }

    var result = await _controller.searchPrestataires(
      serviceId: serviceId,
      tarifMin: tarifMin,
      tarifMax: tarifMax,
      date: date,
      lat: searchLat,
      lng: searchLng,
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
        lat: searchLat,
        lng: searchLng,
        token: userProvider.token,
      );
    }

    if (result.success == true && result.data != null) {
      final list = result.data as List<dynamic>;
      _searchResults = list
          .map((e) => Prestataire.fromJson(e))
          .map(
            (p) => _computeDistanceIfMissing(
              p,
              userLat: searchLat,
              userLng: searchLng,
            ),
          )
          .toList();
    } else {
      _searchError = result.message;
    }

    _searchLoading = false;
    notifyListeners();
  }

  Prestataire _computeDistanceIfMissing(
    Prestataire p, {
    double? userLat,
    double? userLng,
  }) {
    if (p.distanceMetres > 0) return p;
    if (userLat == null || userLng == null) return p;
    if (p.latitude == null || p.longitude == null) return p;
    final meters = _haversineMeters(userLat, userLng, p.latitude!, p.longitude!);
    if (meters <= 0) return p;
    return Prestataire(
      id: p.id,
      nom: p.nom,
      telephone: p.telephone,
      bio: p.bio,
      avatarUrl: p.avatarUrl,
      adresse: p.adresse,
      zoneIntervention: p.zoneIntervention,
      statutVerification: p.statutVerification,
      noteMoyenne: p.noteMoyenne,
      noteSur: p.noteSur,
      nbAvis: p.nbAvis,
      distanceMetres: meters.round(),
      latitude: p.latitude,
      longitude: p.longitude,
      services: p.services,
    );
  }

  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLng = (lng2 - lng1) * (math.pi / 180);
    final lat1Rad = lat1 * (math.pi / 180);
    final lat2Rad = lat2 * (math.pi / 180);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double? _toDoubleOrNull(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  Future<({double lat, double lng})?> _resolveProfileAddressLatLng(
    UserProvider userProvider,
  ) async {
    final address = userProvider.user?.adresse?.toString().trim() ?? '';
    if (address.length < 3) return null;
    return GeocodingController().geocode(address);
  }
}
