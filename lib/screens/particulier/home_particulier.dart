import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/providers/home_content_provider.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/particulier/pages/demander_service_page.dart';
import 'package:milleservices/screens/particulier/pages/favoris_content.dart';
import 'package:milleservices/controllers/geocodingController.dart';
import 'package:milleservices/services/device_location_service.dart';
import 'package:milleservices/services/map_marker_badge.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/services/app_map.dart';
import 'package:milleservices/navigation/app_navigation.dart';

class HomeParticulier extends StatefulWidget {
  const HomeParticulier({super.key});

  @override
  State<HomeParticulier> createState() => _HomeParticulierState();
}

class _HomeParticulierState extends State<HomeParticulier> {
  bool _hasNewNotifications = true;
  bool _bootstrapStarted = false;
  LatLng? _deviceLatLng;
  final GlobalKey<_HomeMapState> _homeMapKey = GlobalKey<_HomeMapState>();

  Future<LatLng?> _resolveLocationForFavoris(UserProvider userProvider) async {
    // En mode non temps reel, on ignore les coords profile (souvent maj par GPS)
    // et on passe uniquement par l'adresse enregistree.
    if (!Utilities.useRealtimeLocation) {
      final adresse = userProvider.user?.adresse?.toString().trim() ?? '';
      if (adresse.length >= 3) {
        final geo = await GeocodingController().geocode(adresse);
        if (geo != null) {
          return LatLng(geo.lat, geo.lng);
        }
      }
      return null;
    }

    if (Utilities.useRealtimeLocation) {
      final device = await DeviceLocationService.getCurrentLatLngOrNull();
      if (device != null) return device;
    }

    final u = userProvider.user;
    if (u?.latitude != null && u?.longitude != null) {
      return LatLng(
        (u!.latitude as num).toDouble(),
        (u.longitude as num).toDouble(),
      );
    }

    final adresse = u?.adresse?.toString().trim() ?? '';
    if (adresse.length >= 3) {
      final geo = await GeocodingController().geocode(adresse);
      if (geo != null) {
        return LatLng(geo.lat, geo.lng);
      }
    }
    return null;
  }

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
    final resolved = await _resolveLocationForFavoris(userProvider);
    if (!mounted) return;
    setState(() => _deviceLatLng = resolved);

    await context.read<PrestatairesProvider>().loadFavoris(
      lat: resolved?.latitude,
      lng: resolved?.longitude,
      userProvider: userProvider,
    );

    if (Utilities.useRealtimeLocation && resolved != null && mounted) {
      unawaited(
        userProvider.pushMyDeviceLocation(
          resolved.latitude,
          resolved.longitude,
        ),
      );
    }
  }

  /// Relecture GPS (ex. émulateur après avoir défini un point dans les réglages).
  Future<void> _refreshDeviceLocationOnly() async {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    final resolved = await _resolveLocationForFavoris(userProvider);
    if (!mounted) return;
    setState(() => _deviceLatLng = resolved);
    if (Utilities.useRealtimeLocation && resolved != null) {
      unawaited(
        userProvider.pushMyDeviceLocation(
          resolved.latitude,
          resolved.longitude,
        ),
      );
    }
    await context.read<PrestatairesProvider>().loadFavoris(
      lat: resolved?.latitude,
      lng: resolved?.longitude,
      userProvider: userProvider,
    );
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
                prenom.isNotEmpty
                    ? 'details_welcome_name'.tr(namedArgs: {'name': prenom})
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
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            color: Colors.black,
            onPressed: () {
              AppNavigation.pushNotifications(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            color: Colors.black,
            onPressed: () {
              AppNavigation.pushProfil(context);
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
                  key: _homeMapKey,
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
                        _homeMapKey.currentState?.recenterOnCurrentUser();
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
    super.key,
    required this.user,
    required this.favoris,
    required this.deviceLatLng,
  });

  @override
  State<_HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends State<_HomeMap> {
  GoogleMapController? _mapController;
  static const double _zoom = 15;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  final Set<String> _markerIconsLoading = <String>{};
  final Map<String, LatLng?> _addressGeocodedPositions = {};
  final Set<String> _addressGeocodingInFlight = <String>{};

  LatLng _youPoint() {
    if (!Utilities.useRealtimeLocation) {
      final u = widget.user;
      if (u != null && u.adresse != null) {
        final key = 'user_addr';
        _ensureAddressPosition(
          key: key,
          address: u.adresse.toString(),
        );
        final byAddress = _addressGeocodedPositions[key];
        if (byAddress != null) return byAddress;
      }
    }
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
    final oldPt =
        oldWidget.deviceLatLng ??
        (oldWidget.user != null &&
                oldWidget.user.latitude != null &&
                oldWidget.user.longitude != null
            ? LatLng(
                (oldWidget.user.latitude as num).toDouble(),
                (oldWidget.user.longitude as num).toDouble(),
              )
            : null);
    final newPt =
        widget.deviceLatLng ??
        (widget.user != null &&
                widget.user.latitude != null &&
                widget.user.longitude != null
            ? LatLng(
                (widget.user.latitude as num).toDouble(),
                (widget.user.longitude as num).toDouble(),
              )
            : null);
    if (oldPt?.latitude != newPt?.latitude ||
        oldPt?.longitude != newPt?.longitude) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_youPoint(), _zoom),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void recenterOnCurrentUser() {
    final target = _youPoint();
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, _zoom));
  }

  void _loadMarkerIcon({
    required String key,
    required String label,
    required Color border,
    required Color fill,
    required Color text,
  }) {
    if (_markerIcons.containsKey(key) || _markerIconsLoading.contains(key))
      return;
    _markerIconsLoading.add(key);
    unawaited(
      MapMarkerBadge.create(
            label: label,
            borderColor: border,
            fillColor: fill,
            textColor: text,
          )
          .then((icon) {
            if (!mounted) return;
            setState(() {
              _markerIcons[key] = icon;
            });
          })
          .whenComplete(() {
            _markerIconsLoading.remove(key);
          }),
    );
  }

  void _ensureAddressPosition({
    required String key,
    required String address,
  }) {
    if (_addressGeocodedPositions.containsKey(key)) return;
    if (_addressGeocodingInFlight.contains(key)) return;
    final trimmed = address.trim();
    if (trimmed.length < 3) {
      _addressGeocodedPositions[key] = null;
      return;
    }
    _addressGeocodingInFlight.add(key);
    unawaited(
      GeocodingController()
          .geocode(trimmed)
          .then((geo) {
            if (!mounted) return;
            setState(() {
              _addressGeocodedPositions[key] = geo != null
                  ? LatLng(geo.lat, geo.lng)
                  : null;
            });
          })
          .whenComplete(() {
            _addressGeocodingInFlight.remove(key);
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _youPoint();

    final markers = <Marker>{};

    final you = _youPoint();
    if (widget.user != null &&
        (widget.deviceLatLng != null ||
            (widget.user.latitude != null && widget.user.longitude != null))) {
      const youKey = 'you';
      _loadMarkerIcon(
        key: youKey,
        label: 'home_you'.tr(),
        border: Utilities().colorBlue,
        fill: Utilities().colorBlueLight,
        text: Utilities().colorBlue,
      );
      markers.add(
        Marker(
          markerId: const MarkerId(youKey),
          position: you,
          icon:
              _markerIcons[youKey] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: 'home_you'.tr()),
        ),
      );
    }

    for (final p in widget.favoris) {
      LatLng? point;
      if (Utilities.useRealtimeLocation) {
        if (p.latitude != null && p.longitude != null) {
          point = LatLng(p.latitude!, p.longitude!);
        }
      } else {
        final key = 'fav_addr_${p.id}';
        _ensureAddressPosition(
          key: key,
          address: p.adresse ?? '',
        );
        point = _addressGeocodedPositions[key];
      }

      if (point != null) {
        final markerKey = 'fav_${p.id}';
        _loadMarkerIcon(
          key: markerKey,
          label: p.nom,
          border: Utilities().colorBlue,
          fill: Utilities().colorBlueLight,
          text: Utilities().colorBlue,
        );
        markers.add(
          Marker(
            markerId: MarkerId(markerKey),
            position: point,
            icon:
                _markerIcons[markerKey] ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
            infoWindow: InfoWindow(
              title: p.nom,
              onTap: () {
                AppNavigation.pushPrestataireDetails(context, p);
              },
            ),
          ),
        );
      }
    }

    return AppMap(
      center: center,
      zoom: _zoom,
      markers: markers,
      onMapCreated: (controller) => _mapController = controller,
    );
  }
}
