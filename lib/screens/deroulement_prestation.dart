import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:milleservices/controllers/prestationsController.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/prestationsProvider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/notification_list.dart';
import 'package:milleservices/screens/particulier/profil_particulier.dart';
import 'package:milleservices/services/device_location_service.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/road_route_polyline_layer.dart';
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
  final MapController _mapController = MapController();
  bool _didCenterOnFirstGps = false;

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
      unawaited(_refreshMyGps());
      _gpsTimer = Timer.periodic(
        const Duration(seconds: 35),
        (_) => unawaited(_refreshMyGps()),
      );
    });
  }

  Future<void> _refreshMyGps() async {
    final ll = await DeviceLocationService.getCurrentLatLngOrNull();
    if (!mounted || ll == null) return;
    setState(() => _deviceLatLng = ll);
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    await userProvider.pushMyDeviceLocation(ll.latitude, ll.longitude);
    if (!_didCenterOnFirstGps && mounted) {
      _didCenterOnFirstGps = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(ll, 15);
      });
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _mapController.dispose();
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
            ? remoteParticulier
            : (_deviceLatLng ?? remoteParticulier);
        final LatLng? displayPrestataire = isPrestataireView
            ? (_deviceLatLng ?? remotePrestataire)
            : remotePrestataire;

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

        final markers = <Marker>[];
        if (displayPrestataire != null) {
          markers.add(
            Marker(
              key: ValueKey(
                'prest_${displayPrestataire.latitude}_${displayPrestataire.longitude}',
              ),
              point: displayPrestataire,
              width: SizeConfig.blockSizeHorizontal * 8,
              height: SizeConfig.blockSizeHorizontal * 8,
              child: const Icon(Icons.home_repair_service, color: Colors.red),
            ),
          );
        }
        if (displayParticulier != null) {
          markers.add(
            Marker(
              key: ValueKey(
                'part_${displayParticulier.latitude}_'
                '${displayParticulier.longitude}',
              ),
              point: displayParticulier,
              width: SizeConfig.blockSizeHorizontal * 8,
              height: SizeConfig.blockSizeHorizontal * 8,
              child: const Icon(Icons.person_pin_circle, color: Colors.blue),
            ),
          );
        }

        return Scaffold(
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
                    prenom.isNotEmpty ? 'details_welcome_name'.tr(namedArgs: {'name': prenom}) : 'details_welcome'.tr(),
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
                            border: Border.all(color: Colors.white, width: 1),
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
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: center, initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'milleservices',
                    ),
                    if (displayParticulier != null && displayPrestataire != null)
                      RoadRoutePolylineLayer(
                        key: ValueKey(
                          'route_${prestation.id}_${displayParticulier.latitude}_${displayParticulier.longitude}_${displayPrestataire.latitude}_${displayPrestataire.longitude}',
                        ),
                        from: displayParticulier,
                        to: displayPrestataire,
                        color: Colors.red,
                        strokeWidth: 4,
                      ),
                    if (markers.isNotEmpty) MarkerLayer(markers: markers),
                  ],
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
                      color: Colors.black.withOpacity(0.1),
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
            ],
          ),
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
    final partLat = displayParticulier?.latitude ??
        prestation.particulier?.latitude;
    final partLng = displayParticulier?.longitude ??
        prestation.particulier?.longitude;
    final prestLat = displayPrestataire?.latitude ??
        prestation.prestataire?.latitude;
    final prestLng = displayPrestataire?.longitude ??
        prestation.prestataire?.longitude;

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

  Future<double?> _showMontantPaiementDialog(Prestation prestation) {
    final tarif = prestation.service?.tarifHoraire;
    final budget = prestation.budget;
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MontantPaiementDialog(tarif: tarif, budget: budget),
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
    final token = context.read<UserProvider>().token;
    if (token == null || token.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'deroulement_session_expired'.tr(),
      );
      return;
    }
    final montant = await _showMontantPaiementDialog(prestation);
    if (!mounted || montant == null) return;
    // Évite « dirty widget / wrong build scope » : laisser la route se fermer
    // avant notifyListeners (stream prestation) + suite du build parent.
    await _waitForNextFrame();
    if (!mounted) return;
    final result = await context
        .read<PrestationsProvider>()
        .marquerPayeeEtRafraichir(
          prestation.id,
          token,
          montant: montant,
        );
    if (!mounted) return;
    if (result.success) {
      Utilities().showMesage(
        context,
        'success',
        'deroulement_marked_paid'.tr(),
      );
    } else {
      Utilities().showMesage(
        context,
        'error',
        result.message?.isNotEmpty == true
            ? result.message!
            : 'deroulement_mark_paid_error'.tr(),
      );
    }
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
    Utilities().showMesage(
      context,
      'success',
      'deroulement_now_ongoing'.tr(),
    );
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
    Utilities().showMesage(
      context,
      'infos',
      'deroulement_messaging_soon'.tr(),
    );
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
}

String _formatMontantPaiementDefault(double value) {
  final r = value.round();
  if ((value - r).abs() < 1e-6) return r.toString();
  return value.toStringAsFixed(2);
}

double? _parseMontantPaiementField(String raw) {
  if (raw.trim().isEmpty) return null;
  final cleaned = raw
      .replaceAll(RegExp(r'[\s\u00A0]'), '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned);
}

/// Dialogue montant : [TextEditingController] possédé par un State (dispose sûr).
class _MontantPaiementDialog extends StatefulWidget {
  const _MontantPaiementDialog({this.tarif, this.budget});

  final double? tarif;
  final double? budget;

  @override
  State<_MontantPaiementDialog> createState() => _MontantPaiementDialogState();
}

class _MontantPaiementDialogState extends State<_MontantPaiementDialog> {
  late final TextEditingController _controller;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final suggestion = widget.budget ?? widget.tarif;
    final hasSuggestion =
        suggestion != null && suggestion > 0 && !suggestion.isNaN;
    _controller = TextEditingController(
      text: hasSuggestion ? _formatMontantPaiementDefault(suggestion) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tarif = widget.tarif;
    final hint = tarif != null && tarif > 0
        ? 'deroulement_pay_amount_tarif_ref'.tr(
            namedArgs: {'tarif': tarif.toStringAsFixed(0)},
          )
        : 'deroulement_pay_amount_no_tarif'.tr();

    return AlertDialog(
      title: Text('deroulement_pay_amount_title'.tr()),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hint,
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.2,
                ),
                color: Colors.black54,
              ),
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
            TextFormField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'deroulement_pay_amount_label'.tr(),
                suffixText: 'FCFA',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final n = _parseMontantPaiementField(value ?? '');
                if (n == null || n <= 0) {
                  return 'deroulement_pay_amount_invalid'.tr();
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('deroulement_pay_cancel'.tr()),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            final n = _parseMontantPaiementField(_controller.text);
            if (n == null || n <= 0) return;
            Navigator.of(context).pop(n);
          },
          child: Text('deroulement_pay_confirm'.tr()),
        ),
      ],
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
