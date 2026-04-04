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
  bool _initialLoadDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFavoris());
    }
  }

  void _loadFavoris() {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    double? lat;
    double? lng;
    if (user?.latitude != null && user?.longitude != null) {
      lat = (user!.latitude as num).toDouble();
      lng = (user.longitude as num).toDouble();
    }
    context.read<PrestatairesProvider>().loadFavoris(
          lat: lat,
          lng: lng,
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
            child: _HomeMap(user: user, favoris: prestatairesProvider.favoris),
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

class _HomeMap extends StatelessWidget {
  final dynamic user;
  final List<Prestataire> favoris;

  const _HomeMap({required this.user, required this.favoris});

  @override
  Widget build(BuildContext context) {
    final center =
        user != null && user.latitude != null && user.longitude != null
        ? LatLng(
            (user.latitude as num).toDouble(),
            (user.longitude as num).toDouble(),
          )
        : const LatLng(48.8566, 2.3522);

    final markers = <Marker>[];

    if (user != null && user.latitude != null && user.longitude != null) {
      markers.add(
        Marker(
          point: LatLng(
            (user.latitude as num).toDouble(),
            (user.longitude as num).toDouble(),
          ),
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

    for (final p in favoris) {
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
      center: center,
      zoom: 15,
      markers: markers,
    );
  }
}
