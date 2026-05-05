import 'package:flutter/foundation.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/controllers/userController.dart';
import 'package:milleservices/models/abonnement.dart';
import 'package:milleservices/models/offre.dart';
import 'package:milleservices/models/prestataire_document.dart';
import 'package:milleservices/models/user.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/services/live_location_foreground_service.dart';
import 'package:milleservices/services/live_location_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  final Authcontroller authcontroller = Authcontroller();
  final UserController userController = UserController();

  String? _token;
  String? get token => _token;
  String? _Rtoken;
  String? get Rtoken => _Rtoken;

  User? _user;
  User? get user => _user;

  Abonnement? _abonnement;
  Abonnement? get abonnement => _abonnement;

  /// URL de la photo de profil mise à jour côté client (après upload).
  String? _avatarUrlOverride;

  /// URL à afficher pour l'avatar (override ou celle du user).
  String? get avatarUrlForDisplay => _avatarUrlOverride ?? _user?.avatarUrl;

  List<Offre> _offres = [];
  List<Offre> get offres => _offres;

  /// Documents attachés au profil prestataire (CNI, casier, etc.).
  List<PrestataireDocument> _prestataireDocuments = [];
  List<PrestataireDocument> get prestataireDocuments => _prestataireDocuments;

  bool get isAuthenticated => _token != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingG = false;
  bool get isLoadingG => _isLoadingG;

  bool _initialLoadDone = false;
  bool get initialLoadDone => _initialLoadDone;

  bool _emailNotVerified = false;
  bool get emailNotVerified => _emailNotVerified;

  UserProvider() {
    loadUser();
  }

  /// Rafraîchit le statut de vérification du prestataire connecté
  /// ainsi que l'état de ses documents, à partir du backend.
  /// Retourne les données brutes { statutVerification, documents: [...] } ou null en cas d'erreur.
  Future<Map<String, dynamic>?> refreshVerificationStatus() async {
    if (_token == null) {
      return null;
    }
    try {
      final res =
          await PrestatairesController.instance.getMyVerificationStatus(_token);
      if (res.success == true && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final statut = data['statutVerification']?.toString();
        final docsRaw = data['documents'];

        if (docsRaw is List) {
          _prestataireDocuments = docsRaw
              .whereType<Map>()
              .map((e) =>
                  PrestataireDocument.fromJson(e.cast<String, dynamic>()))
              .toList();
        } else {
          _prestataireDocuments = [];
        }

        if (_user != null && statut != null) {
          final u = _user!;
          _user = User(
            id: u.id,
            telephone: u.telephone,
            prenom: u.prenom,
            nom: u.nom,
            avatarUrl: u.avatarUrl,
            adresse: u.adresse,
            email: u.email,
            emailVerified: u.emailVerified,
            bio: u.bio,
            zoneIntervention: u.zoneIntervention,
            statutVerification: statut,
            createdAt: u.createdAt,
            updatedAt: u.updatedAt,
            role: u.role,
            latitude: u.latitude,
            longitude: u.longitude,
            statutVerificationPrestataire: u.statutVerificationPrestataire,
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("user", User.encode(_user!));
        }

        notifyListeners();
        return data;
      }
    } catch (_) {
      // silencieux, on laisse l'écran gérer l'affichage "en attente"
    }
    return null;
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setLoadingG(bool value) {
    _isLoadingG = value;
    notifyListeners();
  }

  void setEmailNotVerify(bool value) {
    _emailNotVerified = value;
    notifyListeners();
  }

  Future<ResponseData> login(String email, String password, {required String role}) async {
    setLoading(true);
    final data = await authcontroller.singIn(email, password, role: role);
    if (data.success == true) {
      final payload = data.data ?? {};
      _user = User.fromJson(payload['user']);
      final aboJson = payload['abonnement'];
      _abonnement = aboJson != null ? Abonnement.fromJson(aboJson) : null;
      _token = payload['access_token'];
      _Rtoken = payload['refresh_token'];

      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", _token!);
      await prefs.setString("Rtoken", _Rtoken!);
      await prefs.setString("user", User.encode(user!));
      if (_abonnement != null) {
        await prefs.setString("abonnement", Abonnement.encode(_abonnement!));
      } else {
        await prefs.remove("abonnement");
      }
      await LiveLocationForegroundService.startIfAuthenticated(_user, _token);
    }
    setLoading(false);
    return data;
  }

  Future<ResponseData> signUp(
    User usr,
    String password, {
    List<Map<String, String>>? documents,
    List<String>? serviceIds,
    bool manageLoading = true,
  }) async {
    if (manageLoading) setLoading(true);
    try {
      final data = await authcontroller.singUp(
        usr,
        password,
        documents: documents,
        serviceIds: serviceIds,
      );
      print("data: ${data.data}");
      if (data.success == true) {
        final payload = data.data ?? {};
        _user = User.fromJson(payload['user']);
        final aboJson = payload['abonnement'];
        _abonnement = aboJson != null ? Abonnement.fromJson(aboJson) : null;
        _token = payload['access_token'];
        _Rtoken = payload['refresh_token'];

        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user", User.encode(user!));
        await prefs.setString("token", _token!);
        await prefs.setString("Rtoken", _Rtoken!);
        if (_abonnement != null) {
          await prefs.setString("abonnement", Abonnement.encode(_abonnement!));
        } else {
          await prefs.remove("abonnement");
        }
        await LiveLocationForegroundService.startIfAuthenticated(_user, _token);
      }
      return data;
    } finally {
      if (manageLoading) setLoading(false);
    }
  }

  Future<ResponseData> forgotPassword({
    required String email,
    required String telephone,
    required String newPassword,
  }) async {
    setLoading(true);
    final data = await authcontroller.forgotPassword(
      email: email,
      telephone: telephone,
      newPassword: newPassword,
    );
    setLoading(false);
    return data;
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString("token");
    _Rtoken = prefs.getString("Rtoken");
    final usr = prefs.getString("user");
    _user = usr == null ? null : User.decode(usr);
    final aboStr = prefs.getString("abonnement");
    _abonnement = aboStr == null ? null : Abonnement.decode(aboStr);
    _avatarUrlOverride = prefs.getString("avatarUrl");
    _initialLoadDone = true;
    notifyListeners();
    await LiveLocationForegroundService.startIfAuthenticated(_user, _token);
  }

  /// Enregistre l’URL de photo sur le backend puis dans le [User] local.
  /// Retourne `false` si l’API échoue (l’override local est quand même posé pour l’affichage).
  Future<bool> updateAvatarUrl(String url) async {
    if (_token == null || _user == null) {
      _avatarUrlOverride = url;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("avatarUrl", url);
      return false;
    }

    final role = _user!.role?.toString().toUpperCase() ?? '';
    Future<ResponseData> patch() {
      if (role == 'PRESTATAIRE') {
        return userController.updatePrestataireMe(
          token: _token!,
          avatarUrl: url,
        );
      }
      return userController.updateParticulierMe(
        token: _token!,
        avatarUrl: url,
      );
    }

    var res = await patch();
    if (res.status == 401) {
      await refreshToken();
      if (_token != null) {
        res = await patch();
      }
    }

    if (res.success == true) {
      _avatarUrlOverride = null;
      final u = _user!;
      _user = User(
        id: u.id,
        telephone: u.telephone,
        prenom: u.prenom,
        nom: u.nom,
        avatarUrl: url,
        adresse: u.adresse,
        email: u.email,
        emailVerified: u.emailVerified,
        bio: u.bio,
        zoneIntervention: u.zoneIntervention,
        statutVerification: u.statutVerification,
        createdAt: u.createdAt,
        updatedAt: u.updatedAt,
        role: u.role,
        latitude: u.latitude,
        longitude: u.longitude,
        statutVerificationPrestataire: u.statutVerificationPrestataire,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user", User.encode(_user!));
      await prefs.remove("avatarUrl");
      notifyListeners();
      return true;
    }

    _avatarUrlOverride = url;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("avatarUrl", url);
    return false;
  }

  Future<void> logout() async {
    await LiveLocationForegroundService.stop();
    _token = null;
    _user = null;
    _Rtoken = null;
    _abonnement = null;
    _avatarUrlOverride = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("Rtoken");
    await prefs.remove("user");
    await prefs.remove("abonnement");
    await prefs.remove("avatarUrl");
  }

  Future<void> refreshToken() async {
    if (_Rtoken == null) {
      print('UserProvider: Refresh token null, impossible de rafraîchir');
      return;
    }

    try {
      print('UserProvider: Tentative de refresh token');
      final data = await authcontroller.refreshToken(_Rtoken!);

      if (data.success == true && data.data != null) {
        final raw = data.data;
        // Certains backends renvoient { success, data: { access_token, ... } }
        // d'autres directement { access_token, ... }.
        Map<String, dynamic>? payload;
        if (raw is Map<String, dynamic>) {
          if (raw.containsKey('access_token') || raw.containsKey('user')) {
            payload = raw;
          } else if (raw['data'] is Map<String, dynamic>) {
            payload = raw['data'] as Map<String, dynamic>;
          }
        }
        if (payload == null) {
          print(
            'UserProvider: payload de refresh invalide: ${data.data.toString()}',
          );
          await logout();
          return;
        }

        _token = payload['access_token'];
        if (_token == null || (_token is String && _token!.isEmpty)) {
          print(
            'UserProvider: Refresh sans access_token, réponse: ${payload.toString()}',
          );
          await logout();
          return;
        }
        // Ne pas écraser _Rtoken si absent
        final newRefreshToken = payload['refresh_token'];
        if (newRefreshToken != null) {
          _Rtoken = newRefreshToken;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        if (_Rtoken != null) {
          await prefs.setString("Rtoken", _Rtoken!);
        }
        final userJson = payload['user'];
        if (userJson != null) {
          _user = User.fromJson(userJson);
          await prefs.setString("user", User.encode(_user!));
        }
        final aboJson = payload['abonnement'];
        _abonnement = aboJson != null ? Abonnement.fromJson(aboJson) : null;
        if (_abonnement != null) {
          await prefs.setString("abonnement", Abonnement.encode(_abonnement!));
        } else {
          await prefs.remove("abonnement");
        }
        notifyListeners();
        print('UserProvider: Token rafraîchi avec succès');
      } else {
        print('UserProvider: Échec du refresh token: ${data.message}');
        await logout();
      }
    } catch (e) {
      print('UserProvider: Erreur lors du refresh token: $e');
      await logout();
    }
  }

  /// Charge la liste des offres d'abonnement disponibles pour les prestataires.
  Future<ResponseData> fetchAbonnementOffres() async {
    setLoadingG(true);
    try {
      var data = await authcontroller.getAbonnementOffres(_token);
      if (data.status == 401) {
        await refreshToken();
        if (_token != null) {
          data = await authcontroller.getAbonnementOffres(_token);
        }
      }
      if (data.success == true && data.data != null) {
        final list = data.data as List<dynamic>;
        _offres = list.map((e) => Offre.fromJson(e)).toList();
        notifyListeners();
      }
      return data;
    } finally {
      setLoadingG(false);
    }
  }

  /// Souscrit à une offre d'abonnement pour le prestataire connecté.
  Future<ResponseData> souscrireAbonnement(String offreId) async {
    setLoading(true);
    try {
      var data = await authcontroller.souscrireAbonnement(offreId, _token);
      if (data.status == 401) {
        await refreshToken();
        if (_token != null) {
          data = await authcontroller.souscrireAbonnement(offreId, _token);
        }
      }
      if (data.success == true && data.data != null) {
        final aboJson = data.data;
        _abonnement = Abonnement.fromJson(aboJson);
        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("abonnement", Abonnement.encode(_abonnement!));
      }
      return data;
    } finally {
      setLoading(false);
    }
  }

  /// Prépare le paiement PayDunya pour l’abonnement (retourne `checkoutUrl` + `invoiceToken` dans `data`).
  Future<ResponseData> initPaydunyaAbonnement(String offreId) async {
    setLoading(true);
    try {
      var data = await authcontroller.initPaydunyaAbonnement(offreId, _token);
      if (data.status == 401) {
        await refreshToken();
        if (_token != null) {
          data = await authcontroller.initPaydunyaAbonnement(offreId, _token);
        }
      }
      return data;
    } finally {
      setLoading(false);
    }
  }

  /// Applique le JSON « abonnement courant » (ex. renvoyé avec invoice-paid) sans second GET.
  Future<void> applyAbonnementCourantPayload(dynamic payload) async {
    if (payload == null) {
      _abonnement = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("abonnement");
      notifyListeners();
      return;
    }
    _abonnement = Abonnement.fromJson(payload);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("abonnement", Abonnement.encode(_abonnement!));
    notifyListeners();
  }

  /// Resynchronise l’abonnement courant depuis l’API (après retour PayDunya / IPN).
  Future<void> refreshAbonnementCourant() async {
    if (_token == null || _token!.isEmpty) return;
    var res = await authcontroller.getAbonnementCourant(_token);
    if (res.status == 401) {
      await refreshToken();
      if (_token != null && _token!.isNotEmpty) {
        res = await authcontroller.getAbonnementCourant(_token);
      }
    }
    if (res.success == true) {
      if (res.data != null) {
        _abonnement = Abonnement.fromJson(res.data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("abonnement", Abonnement.encode(_abonnement!));
      } else {
        _abonnement = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove("abonnement");
      }
      notifyListeners();
    }
  }

  /// Envoie la position GPS au backend (particulier ou prestataire), sans loader global.
  /// Utilisé sur les cartes pour le niveau 2 ; limité par [LiveLocationSync].
  Future<void> pushMyDeviceLocation(double lat, double lng) async {
    if (_token == null || _user == null) return;
    final role = _user!.role?.toString();
    if (role != 'PARTICULIER' && role != 'PRESTATAIRE') return;
    if (!await LiveLocationSync.shouldSendToServer()) return;

    Future<ResponseData> send(String token) async {
      if (role == 'PRESTATAIRE') {
        return userController.updatePrestataireMe(
          token: token,
          latitude: lat,
          longitude: lng,
        );
      }
      return userController.updateParticulierMe(
        token: token,
        latitude: lat,
        longitude: lng,
      );
    }

    var data = await send(_token!);
    if (data.status == 401) {
      await refreshToken();
      if (_token != null) {
        data = await send(_token!);
      }
    }

    if (data.success == true && _user != null) {
      await LiveLocationSync.markServerSuccess();
      final u = _user!;
      _user = User(
        id: u.id,
        telephone: u.telephone,
        prenom: u.prenom,
        nom: u.nom,
        avatarUrl: u.avatarUrl,
        adresse: u.adresse,
        email: u.email,
        emailVerified: u.emailVerified,
        bio: u.bio,
        zoneIntervention: u.zoneIntervention,
        statutVerification: u.statutVerification,
        createdAt: u.createdAt,
        updatedAt: u.updatedAt,
        role: u.role,
        latitude: lat,
        longitude: lng,
        statutVerificationPrestataire: u.statutVerificationPrestataire,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user", User.encode(_user!));
    }
  }

  Future<ResponseData> changePassword(currentMdp, newMdp) async {
    setLoading(true);

    var data = await authcontroller.changePassword(
      currentMdp,
      newMdp,
      user!.id,
      _token,
    );
    if (data.status == 401) {
      await refreshToken();
      await Future.delayed(Duration(seconds: 2));
      data = await authcontroller.changePassword(
        currentMdp,
        newMdp,
        user!.id,
        _token,
      );
    }
    notifyListeners();
    setLoading(false);
    return data;
  }

  /// Met à jour les informations du profil prestataire connecté
  /// (nom entreprise, téléphone, adresse texte, bio).
  Future<ResponseData> updatePrestataireInfos({
    String? nomEntreprise,
    String? telephone,
    String? adresse,
    String? bio,
    List<String>? serviceIds,
  }) async {
    if (_token == null) {
      return ResponseData(
        success: false,
        message: "Utilisateur non authentifié",
        data: null,
        status: 401,
        emailNotVerified: false,
      );
    }

    setLoading(true);
    try {
      var data = await userController.updatePrestataireMe(
        token: _token!,
        nom: nomEntreprise,
        telephone: telephone,
        adresse: adresse,
        bio: bio,
        serviceIds: serviceIds,
      );
      if (data.status == 401) {
        await refreshToken();
        if (_token != null) {
          data = await userController.updatePrestataireMe(
            token: _token!,
            nom: nomEntreprise,
            telephone: telephone,
            adresse: adresse,
            bio: bio,
            serviceIds: serviceIds,
          );
        }
      }

      if (data.success == true && _user != null) {
        final u = _user!;
        _user = User(
          id: u.id,
          telephone: telephone ?? u.telephone,
          prenom: u.prenom,
          nom: nomEntreprise ?? u.nom,
          avatarUrl: u.avatarUrl,
          adresse: adresse ?? u.adresse,
          email: u.email,
          emailVerified: u.emailVerified,
          bio: bio ?? u.bio,
          zoneIntervention: u.zoneIntervention,
          statutVerification: u.statutVerification,
          createdAt: u.createdAt,
          updatedAt: u.updatedAt,
          role: u.role,
          latitude: u.latitude,
          longitude: u.longitude,
          statutVerificationPrestataire: u.statutVerificationPrestataire,
        );
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user", User.encode(_user!));
      }

      return data;
    } finally {
      setLoading(false);
    }
  }

  /// Met à jour les informations du profil particulier connecté
  /// (nom, prénom, téléphone, adresse texte).
  Future<ResponseData> updateParticulierInfos({
    String? nom,
    String? prenom,
    String? telephone,
    String? adresse,
  }) async {
    if (_token == null) {
      return ResponseData(
        success: false,
        message: "Utilisateur non authentifié",
        data: null,
        status: 401,
        emailNotVerified: false,
      );
    }

    setLoading(true);
    try {
      var data = await userController.updateParticulierMe(
        token: _token!,
        nom: nom,
        prenom: prenom,
        telephone: telephone,
        adresse: adresse,
      );
      if (data.status == 401) {
        await refreshToken();
        if (_token != null) {
          data = await userController.updateParticulierMe(
            token: _token!,
            nom: nom,
            prenom: prenom,
            telephone: telephone,
            adresse: adresse,
          );
        }
      }

      if (data.success == true && _user != null) {
        final u = _user!;
        _user = User(
          id: u.id,
          telephone: telephone ?? u.telephone,
          prenom: prenom ?? u.prenom,
          nom: nom ?? u.nom,
          avatarUrl: u.avatarUrl,
          adresse: adresse ?? u.adresse,
          email: u.email,
          emailVerified: u.emailVerified,
          bio: u.bio,
          zoneIntervention: u.zoneIntervention,
          statutVerification: u.statutVerification,
          createdAt: u.createdAt,
          updatedAt: u.updatedAt,
          role: u.role,
          latitude: u.latitude,
          longitude: u.longitude,
          statutVerificationPrestataire: u.statutVerificationPrestataire,
        );
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user", User.encode(_user!));
      }

      return data;
    } finally {
      setLoading(false);
    }
  }

  /// Crée un profil PRESTATAIRE à partir d'un compte PARTICULIER
  /// et bascule le rôle côté backend.
  Future<ResponseData> becomePrestataire() async {
    if (_token == null) {
      return ResponseData(
        success: false,
        message: "Utilisateur non authentifié",
        data: null,
        status: 401,
        emailNotVerified: false,
      );
    }

    setLoading(true);
    try {
      var data = await userController.becomePrestataire(_token!);
      if (data.status == 401) {
        await refreshToken();
        if (_token != null) {
          data = await userController.becomePrestataire(_token!);
        }
      }

      if (data.success == true && data.data != null) {
        final payload = data.data as Map<String, dynamic>;
        _user = User.fromJson(payload['user']);
        final aboJson = payload['abonnement'];
        _abonnement = aboJson != null ? Abonnement.fromJson(aboJson) : null;
        _token = payload['access_token'];
        _Rtoken = payload['refresh_token'];

        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("Rtoken", _Rtoken!);
        await prefs.setString("user", User.encode(_user!));
        if (_abonnement != null) {
          await prefs.setString("abonnement", Abonnement.encode(_abonnement!));
        } else {
          await prefs.remove("abonnement");
        }
        await LiveLocationForegroundService.startIfAuthenticated(_user, _token);
      }

      return data;
    } finally {
      setLoading(false);
    }
  }

  /// Crée un profil PARTICULIER à partir d'un compte PRESTATAIRE
  /// et bascule le rôle côté backend.
  Future<ResponseData> becomeParticulier() async {
    if (_token == null) {
      return ResponseData(
        success: false,
        message: "Utilisateur non authentifié",
        data: null,
        status: 401,
        emailNotVerified: false,
      );
    }

    setLoading(true);
    try {
      var data = await userController.becomeParticulier(_token!);
      if (data.status == 401) {
        await refreshToken();
        if (_token != null) {
          data = await userController.becomeParticulier(_token!);
        }
      }

      if (data.success == true && data.data != null) {
        final payload = data.data as Map<String, dynamic>;
        _user = User.fromJson(payload['user']);
        _abonnement = null;
        _token = payload['access_token'];
        _Rtoken = payload['refresh_token'];

        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("Rtoken", _Rtoken!);
        await prefs.setString("user", User.encode(_user!));
        await prefs.remove("abonnement");
        await LiveLocationForegroundService.startIfAuthenticated(_user, _token);
      }

      return data;
    } finally {
      setLoading(false);
    }
  }

  Future<ResponseData> deleteAccount() async {
    setLoading(true);
    var data = await authcontroller.deactivateMyAccount(_token!);
    if (data.status == 401) {
      await refreshToken();
      if (_token != null) {
        await Future.delayed(const Duration(seconds: 1));
        data = await authcontroller.deactivateMyAccount(_token!);
      }
    }
    if (data.success == true) {
      await logout();
    }
    setLoading(false);
    return data;
  }
}
