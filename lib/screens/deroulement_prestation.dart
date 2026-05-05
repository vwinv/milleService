import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:milleservices/controllers/prestationsController.dart';
import 'package:milleservices/controllers/geocodingController.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/providers/prestationsProvider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/notification_list.dart';
import 'package:milleservices/screens/particulier/profil_particulier.dart';
import 'package:milleservices/services/device_location_service.dart';
import 'package:milleservices/services/map_style.dart';
import 'package:milleservices/services/google_route_service.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/paiement_soft_pay_sheet.dart';
import 'package:provider/provider.dart';

class DeroulementPrestation extends StatefulWidget {
  final Prestation prestation;

  const DeroulementPrestation({super.key, required this.prestation});

  @override
  State<DeroulementPrestation> createState() => _DeroulementPrestationState();
}

class _DeroulementPrestationState extends State<DeroulementPrestation> {
  bool _hasNewNotifications = true;
  PrestationsProvider? _prestationsProvider;
  LatLng? _deviceLatLng;
  Timer? _gpsTimer;
  Timer? _elapsedUiTimer;
  GoogleMapController? _mapController;
  bool _didCenterOnFirstGps = false;
  LatLng? _lastDisplayedParticulier;
  LatLng? _lastDisplayedPrestataire;
  LatLng? _storedParticulierLatLng;
  LatLng? _storedPrestataireLatLng;
  String? _storedAddressKey;
  bool _mapInitialLoading = true;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    final prestationsProvider = context.read<PrestationsProvider>();
    _prestationsProvider = prestationsProvider;
    // Rafraîchir souvent : la position du prestataire (profil / GPS) est lue côté API à chaque poll.
    prestationsProvider.startListeningPrestation(
      widget.prestation.id,
      userProvider,
      pollInterval: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Utilities.useRealtimeLocation) {
        unawaited(_refreshMyGps());
        _gpsTimer = Timer.periodic(
          const Duration(seconds: 35),
          (_) => unawaited(_refreshMyGps()),
        );
      }
      _elapsedUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  Future<void> _refreshMyGps() async {
    if (!Utilities.useRealtimeLocation) return;
    final ll = await DeviceLocationService.getCurrentLatLngOrNull();
    if (!mounted || ll == null) return;
    setState(() => _deviceLatLng = ll);
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    await userProvider.pushMyDeviceLocation(ll.latitude, ll.longitude);
    if (!_didCenterOnFirstGps && mounted) {
      _didCenterOnFirstGps = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(ll, 15));
        }
      });
    }
  }

  Future<void> _refreshStoredAddressPositions(Prestation prestation) async {
    if (Utilities.useRealtimeLocation) return;
    final particulierAddress = (prestation.adresse ?? '').trim();
    final prestataireAddress = (prestation.prestataire?.adresse ?? '').trim();
    final key = '$particulierAddress|$prestataireAddress';
    if (_storedAddressKey == key) return;
    _storedAddressKey = key;

    final geocoding = GeocodingController();
    final part = particulierAddress.length >= 3
        ? await geocoding.geocode(particulierAddress)
        : null;
    final prest = prestataireAddress.length >= 3
        ? await geocoding.geocode(prestataireAddress)
        : null;
    if (!mounted || _storedAddressKey != key) return;
    setState(() {
      _storedParticulierLatLng = part != null
          ? LatLng(part.lat, part.lng)
          : null;
      _storedPrestataireLatLng = prest != null
          ? LatLng(prest.lat, prest.lng)
          : null;
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _elapsedUiTimer?.cancel();
    _mapController?.dispose();
    _prestationsProvider?.stopListeningPrestation(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final prenom = user?.prenom?.toString() ?? '';

    final stream = context.read<PrestationsProvider>().prestationStream;

    return StreamBuilder<Prestation>(
      stream: stream,
      initialData: widget.prestation,
      builder: (context, snapshot) {
        final prestation = snapshot.data ?? widget.prestation;
        if (!Utilities.useRealtimeLocation) {
          unawaited(_refreshStoredAddressPositions(prestation));
        }

        final user = context.watch<UserProvider>().user;
        final role = user?.role?.toString() ?? '';
        final isPrestataireView = role == 'PRESTATAIRE';

        final userLat = prestation.particulier?.latitude;
        final userLng = prestation.particulier?.longitude;
        final prestLat = prestation.prestataire?.latitude;
        final prestLng = prestation.prestataire?.longitude;

        final remoteParticulier = (userLat != null && userLng != null)
            ? LatLng(userLat, userLng)
            : null;
        final remotePrestataire = (prestLat != null && prestLng != null)
            ? LatLng(prestLat, prestLng)
            : null;

        /// Particulier : marqueur prestataire = lat/lng du profil prestataire (API), rafraîchis au poll → position live poussée par l’app prestataire.
        /// Prestataire : soi = GPS local ; client = coords particulier (API).
        final LatLng? displayParticulier = isPrestataireView
            ? (Utilities.useRealtimeLocation
                  ? remoteParticulier
                  : (_storedParticulierLatLng ?? remoteParticulier))
            : (Utilities.useRealtimeLocation
                  ? (_deviceLatLng ?? remoteParticulier)
                  : (_storedParticulierLatLng ?? remoteParticulier));
        final LatLng? displayPrestataire = isPrestataireView
            ? (Utilities.useRealtimeLocation
                  ? (_deviceLatLng ?? remotePrestataire)
                  : (_storedPrestataireLatLng ?? remotePrestataire))
            : (Utilities.useRealtimeLocation
                  ? remotePrestataire
                  : (_storedPrestataireLatLng ?? remotePrestataire));
        _lastDisplayedParticulier = displayParticulier;
        _lastDisplayedPrestataire = displayPrestataire;

        const LatLng defaultCenter = LatLng(14.7167, -17.4677);
        LatLng center;
        if (isPrestataireView && displayPrestataire != null) {
          center = displayPrestataire;
        } else if (!isPrestataireView && displayParticulier != null) {
          center = displayParticulier;
        } else if (displayPrestataire != null) {
          center = displayPrestataire;
        } else if (displayParticulier != null) {
          center = displayParticulier;
        } else {
          center = defaultCenter;
        }

        final markers = <Marker>{};
        if (displayPrestataire != null) {
          markers.add(
            Marker(
              markerId: MarkerId(
                'prest_${displayPrestataire.latitude}_${displayPrestataire.longitude}',
              ),
              position: displayPrestataire,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: const InfoWindow(title: 'Prestataire'),
            ),
          );
        }
        if (displayParticulier != null) {
          markers.add(
            Marker(
              markerId: MarkerId(
                'part_${displayParticulier.latitude}_'
                '${displayParticulier.longitude}',
              ),
              position: displayParticulier,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: const InfoWindow(title: 'Particulier'),
            ),
          );
        }

        return Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leadingWidth: 0,
                leading: const SizedBox.shrink(),
                title: Row(
                  children: [
                    Image.asset(
                      '${Utilities().imagePath}logo.png',
                      height: SizeConfig.blockSizeVertical * 4,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                    Expanded(
                      child: Text(
                        prenom.isNotEmpty
                            ? 'details_welcome_name'.tr(
                                namedArgs: {'name': prenom},
                              )
                            : 'details_welcome'.tr(),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: SizeConfig.fontSize(
                            SizeConfig.blockSizeHorizontal * 4,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications),
                        if (_hasNewNotifications)
                          Positioned(
                            top: 3,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Utilities().colorYellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    color: Colors.black,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationListScreen(),
                        ),
                      );
                    },
                  ),
                  isPrestataireView
                      ? SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.person),
                          color: Colors.black,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfilParticulier(),
                              ),
                            );
                          },
                        ),
                ],
              ),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: _DeroulementMap(
                      center: center,
                      markers: markers,
                      from: displayParticulier,
                      to: displayPrestataire,
                      onMapCreated: (controller) => _mapController = controller,
                      onRouteReady: () {
                        if (!mounted || !_mapInitialLoading) return;
                        setState(() => _mapInitialLoading = false);
                      },
                    ),
                  ),
                  Container(
                    height: SizeConfig.blockSizeVertical * 58,
                    width: SizeConfig.blockSizeHorizontal * 95,
                    margin: EdgeInsets.only(
                      left: SizeConfig.blockSizeHorizontal * 2.5,
                      right: SizeConfig.blockSizeHorizontal * 2.5,
                      top: SizeConfig.blockSizeVertical * 35,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                          SizeConfig.blockSizeHorizontal * 8,
                        ),
                        topRight: Radius.circular(
                          SizeConfig.blockSizeHorizontal * 8,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: _buildContentForStatut(
                      prestation,
                      displayParticulier: displayParticulier,
                      displayPrestataire: displayPrestataire,
                    ),
                  ),
                  Positioned(
                    right: SizeConfig.blockSizeHorizontal * 4,
                    top: SizeConfig.blockSizeVertical * 28,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter_particulier_btn',
                      backgroundColor: Colors.white,
                      foregroundColor: Utilities().colorBlueDark,
                      elevation: 3,
                      onPressed: () {
                        final target = _lastDisplayedParticulier;
                        if (target == null) {
                          Utilities().showMesage(
                            context,
                            'error',
                            'Position du particulier indisponible',
                          );
                          return;
                        }
                        final other = _lastDisplayedPrestataire;
                        if (other != null) {
                          _fitCameraToPoints(target, other);
                        } else {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(target, 15),
                          );
                        }
                      },
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),
            if (_mapInitialLoading)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.22),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: SizeConfig.blockSizeHorizontal * 6,
                          vertical: SizeConfig.blockSizeVertical * 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(
                            SizeConfig.blockSizeHorizontal * 4,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Utilities().colorBlueDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static const Color _green = Color(0xFF3FC823);
  static const Color _orange = Color(0xFFFF8C00);
  static const Color _greyInactive = Color(0xFF939191);
  static const Color _red = Color(0xFFE53935);

  Widget _buildContentForStatut(
    Prestation prestation, {
    LatLng? displayParticulier,
    LatLng? displayPrestataire,
  }) {
    final user = context.watch<UserProvider>().user;
    final role = user?.role?.toString() ?? '';
    final isPrestataire = role == 'PRESTATAIRE';
    final isEnAttente = prestation.isEnAttente;
    final isAcceptee = prestation.isAcceptee;
    final isEnCours = prestation.isEnCours;
    final isTerminee = prestation.isTerminee;
    final isPayee = prestation.isPayee;
    final isRefusee = prestation.isRefusee || prestation.isAnnulee;

    final accepteVert = !isEnAttente && !isRefusee;
    // En cours : vert si terminé/payé, orange si accepté/en cours, gris sinon
    final enCoursVert = isTerminee || isPayee;
    final enCoursOrange = (isAcceptee || isEnCours) && !enCoursVert;
    final enCoursChecked = enCoursVert || enCoursOrange;
    // Payé : coché (vert) uniquement si terminé ou payé (jamais en attente)
    final termineVert = !isEnAttente && (isTerminee || isPayee);

    final showRouteAndSummary = isAcceptee;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPrestataireCard(prestation, isPrestataireView: isPrestataire),
          SizedBox(height: SizeConfig.blockSizeVertical * 2),
          _buildStatusRow(
            accepteVert: accepteVert,
            enCoursVert: enCoursVert,
            enCoursOrange: enCoursOrange,
            enCoursChecked: enCoursChecked,
            termineVert: termineVert,
          ),
          SizedBox(height: SizeConfig.blockSizeVertical * 1),
          if (showRouteAndSummary) ...[
            _buildRouteCard(prestation),
            SizedBox(height: SizeConfig.blockSizeVertical * 1),
            _buildSummaryCard(
              prestation,
              displayParticulier: displayParticulier,
              displayPrestataire: displayPrestataire,
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.blockSizeHorizontal * 5,
              vertical: SizeConfig.blockSizeVertical * 1,
            ),
            child: _buildMessageAndButton(
              prestation: prestation,
              isEnAttente: isEnAttente,
              isAcceptee: isAcceptee,
              isEnCours: isEnCours,
              isTerminee: isTerminee,
              isPayee: isPayee,
              isRefusee: isRefusee,
              isPrestataire: isPrestataire,
            ),
          ),
        ],
      ),
    );
  }

  /// Carte trajet : point de prise en charge + destination (statut Acceptée / En cours).
  Widget _buildRouteCard(Prestation prestation) {
    final destination = prestation.adresse?.isNotEmpty == true
        ? prestation.adresse!
        : (prestation.ville?.isNotEmpty == true
              ? prestation.ville!
              : 'deroulement_place'.tr());

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 5,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 4,
        vertical: SizeConfig.blockSizeVertical * 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: SizeConfig.blockSizeHorizontal * 6,
                height: SizeConfig.blockSizeHorizontal * 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _red,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: SizeConfig.blockSizeHorizontal * 2,
                    height: SizeConfig.blockSizeHorizontal * 2,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 6,
                height: SizeConfig.blockSizeVertical * 4,
                child: CustomPaint(
                  painter: _DashedLinePainter(color: _greyInactive),
                ),
              ),
              Icon(Icons.location_on, color: Colors.blue.shade700, size: 28),
            ],
          ),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                Text(
                  prestation.prestataire?.adresse ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.5,
                    ),
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'deroulement_provider_on_way'.tr(),
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3,
                    ),
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: SizeConfig.blockSizeVertical * 2.5),
                Text(
                  destination,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.5,
                    ),
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte récap : distance prestataire↔particulier, temps estimé, prix (données dynamiques).
  Widget _buildSummaryCard(
    Prestation prestation, {
    LatLng? displayParticulier,
    LatLng? displayPrestataire,
  }) {
    final partLat =
        displayParticulier?.latitude ?? prestation.particulier?.latitude;
    final partLng =
        displayParticulier?.longitude ?? prestation.particulier?.longitude;
    final prestLat =
        displayPrestataire?.latitude ?? prestation.prestataire?.latitude;
    final prestLng =
        displayPrestataire?.longitude ?? prestation.prestataire?.longitude;

    final distanceKm =
        (partLat != null &&
            partLng != null &&
            prestLat != null &&
            prestLng != null)
        ? _haversineKm(partLat, partLng, prestLat, prestLng)
        : null;
    final distanceText = distanceKm != null
        ? (distanceKm >= 1
              ? '${distanceKm.toStringAsFixed(1)} km'
              : '${(distanceKm * 1000).round()} m')
        : '—';
    // Temps estimé : ~25 km/h en ville → temps (min) = distance_km / 25 * 60
    final tempsMin = distanceKm != null ? (distanceKm / 25 * 60).round() : null;
    final tempsText = tempsMin != null
        ? (tempsMin < 60 ? '$tempsMin min' : '${tempsMin ~/ 60} h')
        : '—';

    final tarif = prestation.service?.tarifHoraire;
    final prixText = tarif != null ? '${tarif.toStringAsFixed(0)} FCFA' : '—';

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 5,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 4,
        vertical: SizeConfig.blockSizeVertical * 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('deroulement_distance'.tr(), distanceText),
          _summaryItem('deroulement_arrival'.tr(), tempsText),
          _summaryItem('deroulement_price'.tr(), prixText),
        ],
      ),
    );
  }

  /// Distance en km (formule de Haversine) entre deux points lat/lng.
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295; // pi/180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lng2 - lng1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2*R*asin (R=6371 km)
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3.5),
            color: Colors.black87,
          ),
        ),
        SizedBox(height: SizeConfig.blockSizeVertical * 0.3),
        Text(
          label,
          style: TextStyle(
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 2.8),
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPrestataireCard(
    Prestation prestation, {
    required bool isPrestataireView,
  }) {
    // Si l'utilisateur est un prestataire, on affiche les infos du particulier (client),
    // sinon on affiche celles du prestataire.
    final nom = isPrestataireView
        ? (prestation.particulier?.displayName ?? '—')
        : (prestation.prestataire?.nom ?? '—');
    final avatarUrl = isPrestataireView
        ? null
        : prestation.prestataire?.avatarUrl;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 4,
        vertical: SizeConfig.blockSizeVertical * 1.5,
      ),
      decoration: BoxDecoration(
        color: Utilities().colorBlueDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(SizeConfig.blockSizeHorizontal * 5),
          topRight: Radius.circular(SizeConfig.blockSizeHorizontal * 5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: SizeConfig.blockSizeHorizontal * 4,
            ),
          ),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
          avatarUrl == null || avatarUrl.toString().isEmpty
              ? CircleAvatar(
                  radius: SizeConfig.blockSizeHorizontal * 8,
                  backgroundColor: Colors.white24,
                  backgroundImage: AssetImage(
                    '${Utilities().imagePath}ouvrier2.jpeg',
                  ),
                )
              : CircleAvatar(
                  radius: SizeConfig.blockSizeHorizontal * 8,
                  backgroundColor: Colors.white24,
                  backgroundImage: NetworkImage(avatarUrl.toString()),
                ),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nom,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 4,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: SizeConfig.blockSizeVertical * 0.3),
                Row(
                  children: [
                    Icon(Icons.star, color: Utilities().colorYellow, size: 16),
                    SizedBox(width: SizeConfig.blockSizeHorizontal * 0.5),
                    Text(
                      '4.9',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Utilities().colorYellow,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => _onCallPressed(prestation, isPrestataireView),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 2),
                child: const Icon(Icons.phone, color: Colors.white),
              ),
            ),
          ),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 1.5),
          Material(
            color: Colors.green[700]!,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {
                _onChatPressed(prestation, isPrestataireView);
              },
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 2),
                child: const Icon(Icons.chat_bubble, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required bool accepteVert,
    required bool enCoursVert,
    required bool enCoursOrange,
    required bool enCoursChecked,
    required bool termineVert,
  }) {
    Color c1 = accepteVert ? _green : _greyInactive;
    Color c2 = enCoursChecked
        ? (enCoursVert ? _green : _orange)
        : _greyInactive;
    Color c3 = termineVert ? _green : _greyInactive;

    Widget step(String label, Color color, IconData icon) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: SizeConfig.blockSizeVertical * 0.3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 2.8,
                ),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        step('deroulement_accepted'.tr(), c1, Icons.check_circle),
        step('deroulement_in_progress'.tr(), c2, Icons.schedule),
        step('deroulement_paid'.tr(), c3, Icons.check_circle),
      ],
    );
  }

  Widget _buildMessageAndButton({
    required Prestation prestation,
    required bool isEnAttente,
    required bool isAcceptee,
    required bool isEnCours,
    required bool isTerminee,
    required bool isPayee,
    required bool isRefusee,
    required bool isPrestataire,
  }) {
    String title;
    String body;
    Color titleColor = Colors.black87;
    IconData? titleIcon;

    if (isRefusee) {
      title = 'deroulement_refused_title'.tr();
      body = 'deroulement_refused_body'.tr();
      titleColor = _red;
      titleIcon = Icons.cancel;
    } else if (isEnAttente) {
      title = 'presta_pending'.tr();
      body = 'deroulement_waiting_body'.tr();
    } else if (isAcceptee && isPrestataire) {
      title = '';
      body = '';
    } else if (isEnCours) {
      title = 'deroulement_ongoing_title'.tr();
      body = 'deroulement_ongoing_body'.tr();
    } else if (isTerminee) {
      title = 'deroulement_completed_title'.tr();
      body = isPrestataire
          ? 'deroulement_completed_client'.tr()
          : 'deroulement_completed_you'.tr();
    } else if (isPayee) {
      title = 'deroulement_paid_title'.tr();
      body = 'deroulement_paid_body'.tr();
    } else {
      title = '';
      body = '';
    }

    final shouldShowExecutionTimer =
        !isEnAttente && !isRefusee && !isTerminee && !isPayee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (titleIcon != null) ...[
                Icon(titleIcon, color: titleColor, size: 28),
                SizedBox(width: SizeConfig.blockSizeHorizontal * 1.5),
              ],
              title.isNotEmpty
                  ? Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 4.2,
                        ),
                        color: titleColor,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : SizedBox.shrink(),
            ],
          ),
        ),
        body.isNotEmpty
            ? SizedBox(height: SizeConfig.blockSizeVertical * 1)
            : SizedBox.shrink(),
        body.isNotEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.blockSizeHorizontal * 2,
                  ),
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.5,
                      ),
                      color: isRefusee ? Colors.black87 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : SizedBox.shrink(),
        if (shouldShowExecutionTimer) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 1),
          Center(
            child: Text(
              'Durée prestation: ${_formatElapsedExecution(prestation)}',
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.5,
                ),
                fontWeight: FontWeight.w600,
                color: Utilities().colorBlueDark,
              ),
            ),
          ),
        ],
        if (isTerminee && !isPrestataire) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 1),
          Center(
            child: Text(
              'Montant à payer: ${_money(_computedMontantAPayer(prestation))}',
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.6,
                ),
                fontWeight: FontWeight.w700,
                color: Utilities().colorBlueDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (isPrestataire && isAcceptee) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 1),
          Center(
            child: SizedBox(
              height: SizeConfig.blockSizeVertical * 6,
              child: ElevatedButton(
                onPressed: () => _onArriveADestination(prestation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 3,
                    ),
                  ),
                ),
                child: Text(
                  'deroulement_arrived'.tr(),
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.8,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ] else if (isPrestataire && isEnCours) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 1),
          Center(
            child: SizedBox(
              height: SizeConfig.blockSizeVertical * 6,
              child: ElevatedButton(
                onPressed: () => _onTerminerPrestation(prestation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 3,
                    ),
                  ),
                ),
                child: Text(
                  'deroulement_finish'.tr(),
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.8,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ] else if (isTerminee && !isPrestataire) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 2.5),
          Center(
            child: SizedBox(
              height: SizeConfig.blockSizeVertical * 6,
              child: ElevatedButton(
                onPressed: () => _onPayerIci(prestation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 3,
                    ),
                  ),
                ),
                child: Text(
                  'deroulement_pay_here'.tr(),
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.8,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (isRefusee) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 2.5),
          Center(
            child: SizedBox(
              height: SizeConfig.blockSizeVertical * 6,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 3,
                    ),
                  ),
                ),
                child: Text(
                  'deroulement_new_request'.tr(),
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.8,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _onPayerIci(Prestation prestation) async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'deroulement_session_expired'.tr(),
      );
      return;
    }
    final montant = _computedMontantAPayer(prestation);
    if (montant <= 0) {
      Utilities().showMesage(
        context,
        'error',
        'Montant de paiement indisponible pour cette prestation.',
      );
      return;
    }
    await _waitForNextFrame();
    if (!mounted) return;
    final init = await PrestationsController.instance.initPaydunyaPaiement(
      token,
      prestation.id,
    );
    if (!mounted) return;
    if (init.success != true || init.data is! Map) {
      Utilities().showMesage(
        context,
        'error',
        init.message?.toString().isNotEmpty == true
            ? init.message.toString()
            : 'deroulement_mark_paid_error'.tr(),
      );
      return;
    }
    final initMap = Map<String, dynamic>.from(init.data as Map);
    final invoiceToken = initMap['invoiceToken']?.toString().trim();
    final checkoutUrlFallback = initMap['checkoutUrl']?.toString().trim();
    if (invoiceToken == null || invoiceToken.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'Facture PayDunya indisponible. Réessayez.',
      );
      return;
    }
    final user = userProvider.user;
    final ctl = PrestationsController.instance;
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: PaiementSoftPaySheet.topBorderRadius,
      ),
      builder: (ctx) => PaiementSoftPaySheet(
        invoiceToken: invoiceToken,
        checkoutUrlFallback: checkoutUrlFallback ?? '',
        initialPrenom: user?.prenom?.toString() ?? '',
        initialNom: user?.nom?.toString() ?? '',
        initialTelephone: user?.telephone?.toString() ?? '',
        email: user?.email?.toString(),
        montantLabel: _money(montant),
        onSoftPay:
            ({
              required String method,
              required String prenom,
              required String nom,
              required String telephone,
              String? email,
            }) async {
              switch (method) {
                case 'wave_sn':
                  return ctl.payWithWaveSn(
                    token: token,
                    prestationId: prestation.id,
                    invoiceToken: invoiceToken,
                    prenom: prenom,
                    nom: nom,
                    telephone: telephone,
                    email: email,
                  );
                case 'orange_money_sn':
                  return ctl.payWithOrangeMoneySn(
                    token: token,
                    prestationId: prestation.id,
                    invoiceToken: invoiceToken,
                    prenom: prenom,
                    nom: nom,
                    telephone: telephone,
                    email: email,
                  );
                case 'free_money_sn':
                  return ctl.payWithFreeMoneySn(
                    token: token,
                    prestationId: prestation.id,
                    invoiceToken: invoiceToken,
                    prenom: prenom,
                    nom: nom,
                    telephone: telephone,
                    email: email,
                  );
                default:
                  return ResponseData(
                    success: false,
                    message: 'Moyen inconnu',
                    data: null,
                    status: 400,
                    emailNotVerified: false,
                  );
              }
            },
      ),
    );
    if (!mounted || paid != true) return;
    Utilities().showMesage(
      context,
      'success',
      'La prestation passera en « payée » après confirmation PayDunya.',
    );
    await _pollPrestationPayeeOrTimeout(prestation.id, token);
  }

  Future<void> _pollPrestationPayeeOrTimeout(
    String prestationId,
    String token,
  ) async {
    final provider = context.read<PrestationsProvider>();
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      final res = await PrestationsController.instance.getPrestationById(
        token,
        prestationId,
      );
      if (res.success == true && res.data is Map) {
        final p = Prestation.fromJson(
          Map<String, dynamic>.from(res.data as Map),
        );
        if (p.isPayee) {
          await provider.fetchPrestationOnceAndEmit(prestationId, token);
          if (!mounted) return;
          Utilities().showMesage(
            context,
            'success',
            'deroulement_marked_paid'.tr(),
          );
          return;
        }
      }
    }
    if (mounted) {
      await provider.fetchPrestationOnceAndEmit(prestationId, token);
      if (!mounted) return;
      Utilities().showMesage(
        context,
        'error',
        'Paiement non confirmé dans le délai. Réessayez ou actualisez.',
      );
    }
  }

  DateTime? _durationStart(Prestation p) {
    return p.acceptedAt ?? p.createdAt;
  }

  double _executionHours(Prestation p) {
    final start = _durationStart(p);
    if (start == null) return 1.0;
    final isClosed = p.isTerminee || p.isPayee || p.isRefusee || p.isAnnulee;
    final end = (isClosed && p.completedAt != null)
        ? p.completedAt!
        : DateTime.now();
    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) return 1.0;
    return minutes / 60.0;
  }

  /// Tarif catalogue (FCFA/h) × durée (h) + frais de service + frais de déplacement (aligné backend).
  double _computedMontantAPayer(Prestation p) {
    final tarif = p.service?.tarifHoraire;
    if (tarif == null || tarif <= 0) return 0;
    return computePrestationBilling(
      tarifHoraireFcfa: tarif,
      executionHours: _executionHours(p),
    ).totalToPayFcfa;
  }

  String _money(double value) {
    final n = value.round();
    return '${n.toString()} FCFA';
  }

  String _formatElapsedExecution(Prestation p) {
    final start = _durationStart(p);
    if (start == null) return '00:00:00';
    final isClosed = p.isTerminee || p.isPayee || p.isRefusee || p.isAnnulee;
    final end = (isClosed && p.completedAt != null)
        ? p.completedAt!
        : DateTime.now();
    var elapsed = end.difference(start);
    if (elapsed.isNegative) elapsed = Duration.zero;
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _onArriveADestination(Prestation prestation) async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'deroulement_session_expired'.tr(),
      );
      return;
    }
    final res = await PrestationsController.instance.demarrer(
      token,
      prestation.id,
    );
    if (!mounted) return;
    if (res.success != true) {
      Utilities().showMesage(
        context,
        'error',
        res.message?.isNotEmpty == true
            ? res.message!
            : 'deroulement_start_error'.tr(),
      );
      return;
    }
    // Le polling de PrestationsProvider mettra à jour l'écran automatiquement.
    Utilities().showMesage(context, 'success', 'deroulement_now_ongoing'.tr());
  }

  Future<void> _onCallPressed(
    Prestation prestation,
    bool isPrestataireView,
  ) async {
    // Côté particulier : on appelle le prestataire.
    // Côté prestataire : on appelle le particulier.
    final phone = isPrestataireView
        ? prestation.particulier?.telephone?.toString()
        : prestation.prestataire?.telephone?.toString();
    if (phone == null || phone.trim().isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'deroulement_phone_unavailable'.tr(),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (!await canLaunchUrl(uri)) {
      Utilities().showMesage(
        context,
        'error',
        'deroulement_phone_app_error'.tr(),
      );
      return;
    }
    await launchUrl(uri);
  }

  Future<void> _onChatPressed(
    Prestation prestation,
    bool isPrestataireView,
  ) async {
    // Chat en temps réel non encore implémenté.
    // On affiche un message d'information pour l'instant.
    Utilities().showMesage(context, 'infos', 'deroulement_messaging_soon'.tr());
  }

  Future<void> _onTerminerPrestation(Prestation prestation) async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'deroulement_session_expired'.tr(),
      );
      return;
    }
    final res = await PrestationsController.instance.terminer(
      token,
      prestation.id,
    );
    if (!mounted) return;
    if (res.success != true) {
      Utilities().showMesage(
        context,
        'error',
        res.message?.isNotEmpty == true
            ? res.message!
            : 'deroulement_finish_error'.tr(),
      );
      return;
    }
    Utilities().showMesage(
      context,
      'success',
      'deroulement_marked_completed'.tr(),
    );
  }

  Future<void> _fitCameraToPoints(LatLng a, LatLng b) async {
    final controller = _mapController;
    if (controller == null) return;
    final minLat = math.min(a.latitude, b.latitude);
    final maxLat = math.max(a.latitude, b.latitude);
    final minLng = math.min(a.longitude, b.longitude);
    final maxLng = math.max(a.longitude, b.longitude);
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          70,
        ),
      );
    } catch (_) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(a, 15));
    }
  }
}

class _DeroulementMap extends StatefulWidget {
  final LatLng center;
  final Set<Marker> markers;
  final LatLng? from;
  final LatLng? to;
  final void Function(GoogleMapController controller)? onMapCreated;
  final VoidCallback? onRouteReady;

  const _DeroulementMap({
    required this.center,
    required this.markers,
    required this.from,
    required this.to,
    this.onMapCreated,
    this.onRouteReady,
  });

  @override
  State<_DeroulementMap> createState() => _DeroulementMapState();
}

class _DeroulementMapState extends State<_DeroulementMap> {
  List<LatLng>? _routePoints;
  String? _routeKey;
  DateTime? _lastRouteFetchAt;
  LatLng? _lastFromForFetch;
  LatLng? _lastToForFetch;
  GoogleMapController? _internalMapController;
  Timer? _routeThrottleTimer;
  Timer? _routeRetryTimer;
  bool _routeReadyNotified = false;
  static const Duration _minRouteFetchInterval = Duration(seconds: 20);
  static const Duration _routeRetryDelay = Duration(seconds: 8);
  static const double _minMoveMetersForRouteRefresh = 120;

  @override
  void initState() {
    super.initState();
    _fetchRouteIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _DeroulementMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.from != widget.from || oldWidget.to != widget.to) {
      _fetchRouteIfNeeded();
      _fitCameraToRouteOrPoints();
    }
  }

  @override
  void dispose() {
    _routeThrottleTimer?.cancel();
    _routeRetryTimer?.cancel();
    _internalMapController?.dispose();
    super.dispose();
  }

  bool _movedEnoughSinceLastFetch(LatLng from, LatLng to) {
    final prevFrom = _lastFromForFetch;
    final prevTo = _lastToForFetch;
    if (prevFrom == null || prevTo == null) return true;
    final fromMoved = _distanceMeters(prevFrom, from);
    final toMoved = _distanceMeters(prevTo, to);
    return fromMoved >= _minMoveMetersForRouteRefresh ||
        toMoved >= _minMoveMetersForRouteRefresh;
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (math.pi / 180);
    final dLng = (b.longitude - a.longitude) * (math.pi / 180);
    final lat1 = a.latitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  Future<void> _fetchRouteIfNeeded() async {
    final from = widget.from;
    final to = widget.to;
    if (from == null || to == null) {
      setState(() => _routePoints = null);
      return;
    }
    final key =
        '${from.latitude},${from.longitude};${to.latitude},${to.longitude}';
    if (_routeKey == key && _routePoints != null) return;
    final keyChanged = _routeKey != key;

    final movedEnough = _movedEnoughSinceLastFetch(from, to);
    final now = DateTime.now();
    final lastAt = _lastRouteFetchAt;
    final canFetchNow =
        lastAt == null || now.difference(lastAt) >= _minRouteFetchInterval;
    if (!keyChanged && !movedEnough && !canFetchNow) return;

    if (!keyChanged && !canFetchNow) {
      final wait = _minRouteFetchInterval - now.difference(lastAt);
      _routeThrottleTimer?.cancel();
      _routeThrottleTimer = Timer(wait, () {
        if (mounted) _fetchRouteIfNeeded();
      });
      return;
    }

    _routeRetryTimer?.cancel();
    _lastRouteFetchAt = now;
    _lastFromForFetch = from;
    _lastToForFetch = to;
    final points = await GoogleRouteService.fetchDrivingRoute(from, to);
    if (!mounted) return;
    if (points != null && points.length >= 2) {
      _routeKey = key;
      setState(() => _routePoints = points);
      _fitCameraToRouteOrPoints();
      if (!_routeReadyNotified) {
        _routeReadyNotified = true;
        widget.onRouteReady?.call();
      }
      return;
    }
    // Ne pas figer l'état sur un échec ponctuel : on retente.
    _routeKey = null;
    _routeRetryTimer = Timer(_routeRetryDelay, () {
      if (mounted) _fetchRouteIfNeeded();
    });
  }

  Future<void> _fitCameraToRouteOrPoints() async {
    final controller = _internalMapController;
    if (controller == null) return;
    final line = _routePoints;
    final points = (line != null && line.length >= 2)
        ? line
        : <LatLng>[
            if (widget.from != null) widget.from!,
            if (widget.to != null) widget.to!,
          ];
    if (points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          70,
        ),
      );
    } catch (_) {
      // Peut échouer avant le layout complet de la map: on ignore silencieusement.
    }
  }

  @override
  Widget build(BuildContext context) {
    List<LatLng>? line = _routePoints;
    if (line != null &&
        line.length >= 2 &&
        widget.from != null &&
        widget.to != null) {
      // Assure un raccord visuel exact aux marqueurs source/destination.
      line = <LatLng>[widget.from!, ...line, widget.to!];
    }
    final polylines = <Polyline>{};
    if (line != null && line.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('main_route'),
          points: line,
          width: 5,
          color: _routePoints != null ? Colors.blue : Colors.red,
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.center, zoom: 15),
      style: kGrayMapStyle,
      onMapCreated: (controller) {
        _internalMapController = controller;
        widget.onMapCreated?.call(controller);
        _fitCameraToRouteOrPoints();
      },
      markers: widget.markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}

/// Peint une ligne verticale en pointillés.
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({this.color = Colors.grey});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashHeight = 4.0;
    const gap = 3.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashHeight),
        paint,
      );
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
