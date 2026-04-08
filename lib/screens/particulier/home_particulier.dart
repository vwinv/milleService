import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:milleservices/screens/particulier/profil_particulier.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/providers/home_content_provider.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/particulier/pages/demander_service_page.dart';
import 'package:milleservices/screens/particulier/pages/favoris_content.dart';
import 'package:milleservices/services/device_location_service.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/services/app_map.dart';
import 'package:milleservices/screens/notification_list.dart';

class HomeParticulier extends StatefulWidget {
  const HomeParticulier({super.key});

  @override
  State<HomeParticulier> createState() => _HomeParticulierState();
}

class _HomeParticulierState extends State<HomeParticulier> {
  bool _hasNewNotifications = true;
  bool _bootstrapStarted = false;
  LatLng? _deviceLatLng;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapStarted) {
      _bootstrapStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_bootstrapLocationAndFavoris());
      });
    }
  }

  /// GPS (niveau 1) puis favoris avec ces coords ; envoi serveur (niveau 2).
  Future<void> _bootstrapLocationAndFavoris() async {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    final device = await DeviceLocationService.getCurrentLatLngOrNull();
    if (!mounted) return;
    setState(() => _deviceLatLng = device);

    final u = userProvider.user;
    double? lat = device?.latitude;
    double? lng = device?.longitude;
    if (lat == null && u?.latitude != null && u?.longitude != null) {
      lat = (u!.latitude as num).toDouble();
      lng = (u.longitude as num).toDouble();
    }

    await context.read<PrestatairesProvider>().loadFavoris(
          lat: lat,
          lng: lng,
          userProvider: userProvider,
        );

    if (device != null && mounted) {
      unawaited(
        userProvider.pushMyDeviceLocation(device.latitude, device.longitude),
      );
    }
  }

  /// Relecture GPS (ex. émulateur après avoir défini un point dans les réglages).
  Future<void> _refreshDeviceLocationOnly() async {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    final device = await DeviceLocationService.getCurrentLatLngOrNull();
    if (!mounted) return;
    setState(() => _deviceLatLng = device);
    if (device != null) {
      unawaited(
        userProvider.pushMyDeviceLocation(device.latitude, device.longitude),
      );
      await context.read<PrestatairesProvider>().loadFavoris(
            lat: device.latitude,
            lng: device.longitude,
            userProvider: userProvider,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final user = context.watch<UserProvider>().user;
    final prenom = user?.prenom?.toString() ?? '';
    final prestatairesProvider = context.watch<PrestatairesProvider>();

    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.person),
            color: Colors.black,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilParticulier()),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            width: double.infinity,
            height: SizeConfig.blockSizeVertical * 35,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _HomeMap(
                  user: user,
                  favoris: prestatairesProvider.favoris,
                  deviceLatLng: _deviceLatLng,
                ),
                Positioned(
                  right: SizeConfig.blockSizeHorizontal * 2,
                  bottom: SizeConfig.blockSizeVertical * 1,
                  child: Material(
                    elevation: 4,
                    shape: const CircleBorder(),
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: 'Actualiser ma position GPS',
                      icon: Icon(
                        Icons.my_location,
                        color: Utilities().colorBlue,
                      ),
                      onPressed: () {
                        unawaited(_refreshDeviceLocationOnly());
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<HomeContentProvider>(
              builder: (context, homeContent, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    fit: StackFit.passthrough,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: homeContent.isDemanderService
                      ? DemanderServicePage(key: const ValueKey('demander'))
                      : const FavorisContent(key: ValueKey('favoris')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMap extends StatefulWidget {
  final dynamic user;
  final List<Prestataire> favoris;
  final LatLng? deviceLatLng;

  const _HomeMap({
    required this.user,
    required this.favoris,
    required this.deviceLatLng,
  });

  @override
  State<_HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends State<_HomeMap> {
  final MapController _mapController = MapController();
  static const double _zoom = 15;

  LatLng _youPoint() {
    if (widget.deviceLatLng != null) return widget.deviceLatLng!;
    final u = widget.user;
    if (u != null && u.latitude != null && u.longitude != null) {
      return LatLng(
        (u.latitude as num).toDouble(),
        (u.longitude as num).toDouble(),
      );
    }
    return const LatLng(48.8566, 2.3522);
  }

  @override
  void didUpdateWidget(covariant _HomeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPt = oldWidget.deviceLatLng ??
        (oldWidget.user != null &&
                oldWidget.user.latitude != null &&
                oldWidget.user.longitude != null
            ? LatLng(
                (oldWidget.user.latitude as num).toDouble(),
                (oldWidget.user.longitude as num).toDouble(),
              )
            : null);
    final newPt = widget.deviceLatLng ??
        (widget.user != null &&
                widget.user.latitude != null &&
                widget.user.longitude != null
            ? LatLng(
                (widget.user.latitude as num).toDouble(),
                (widget.user.longitude as num).toDouble(),
              )
            : null);
    if (oldPt?.latitude != newPt?.latitude || oldPt?.longitude != newPt?.longitude) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(_youPoint(), _zoom);
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _youPoint();

    final markers = <Marker>[];

    final you = _youPoint();
    if (widget.user != null &&
        (widget.deviceLatLng != null ||
            (widget.user.latitude != null && widget.user.longitude != null))) {
      markers.add(
        Marker(
          point: you,
          width: SizeConfig.blockSizeHorizontal * 50,
          height: SizeConfig.blockSizeVertical * 10,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 3,
                  vertical: SizeConfig.blockSizeVertical * 0.5,
                ),
                decoration: BoxDecoration(
                  color: Utilities().colorBlueLight,
                  border: Border.all(color: Utilities().colorBlue, width: 2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'home_you'.tr(),
                  style: TextStyle(
                    color: Utilities().colorBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Icon(
                Icons.location_on,
                color: Utilities().colorBlue,
                size: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 7),
              ),
            ],
          ),
        ),
      );
    }

    for (final p in widget.favoris) {
      if (p.latitude != null && p.longitude != null) {
        markers.add(
          Marker(
            point: LatLng(p.latitude!, p.longitude!),
            width: SizeConfig.blockSizeHorizontal * 50,
            height: SizeConfig.blockSizeVertical * 10,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.blockSizeHorizontal * 3,
                    vertical: SizeConfig.blockSizeVertical * 0.5,
                  ),
                  decoration: BoxDecoration(
                    color: Utilities().colorBlueLight,
                    border:
                        Border.all(color: Utilities().colorBlue, width: 2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    p.nom,
                    style: TextStyle(
                      color: Utilities().colorBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Icon(
                  Icons.location_on,
                  color: Utilities().colorBlue,
                  size: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 7,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return AppMap(
      mapController: _mapController,
      center: center,
      zoom: _zoom,
      markers: markers,
    );
  }
}
