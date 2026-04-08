import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/prestationsProvider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/edit_infos.dart';
import 'package:milleservices/screens/historique.dart';
import 'package:milleservices/screens/prestataire/wallet.dart';
import 'package:milleservices/screens/welcome.dart';
import 'package:milleservices/services/device_location_service.dart';
import 'package:milleservices/services/app_locale.dart';
import 'package:milleservices/services/image_helper.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:milleservices/widgets/prestataire_catalogue_bottom_sheet.dart';
import 'package:milleservices/widgets/prestataire_catalogue_photo_viewer.dart';
import 'package:milleservices/screens/notification_list.dart';
import 'package:provider/provider.dart';

class HomePrestataire extends StatefulWidget {
  const HomePrestataire({super.key});

  @override
  State<HomePrestataire> createState() => _HomePrestataireState();
}

class _HomePrestataireState extends State<HomePrestataire> {
  bool _hasNewNotifications = true;
  bool _isUploadingAvatar = false;
  bool _isUploadingCataloguePhoto = false;
  bool _languageOpen = false;
  int? _prestationsEnAttente;
  int? _prestationsTerminees;
  Timer? _statsTimer;
  Timer? _locationTimer;
  final ImagePicker _picker = ImagePicker();
  final Authcontroller _authController = Authcontroller();
  final PrestatairesController _prestatairesController =
      PrestatairesController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrestationStats();
      _loadCataloguePhotos();
      unawaited(_syncPrestataireGps());
    });
    _statsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _loadPrestationStats();
      }
    });
    _locationTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) unawaited(_syncPrestataireGps());
    });
  }

  Future<void> _syncPrestataireGps() async {
    final ll = await DeviceLocationService.getCurrentLatLngOrNull();
    if (!mounted || ll == null) return;
    if (!mounted) return;
    final up = context.read<UserProvider>();
    await up.pushMyDeviceLocation(ll.latitude, ll.longitude);
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrestationStats() async {
    final userProvider = context.read<UserProvider>();
    var res = await _prestatairesController.getPrestationStats(
      userProvider.token,
    );
    if (res.status == 401) {
      await userProvider.refreshToken();
      if (userProvider.token != null && mounted) {
        res = await _prestatairesController.getPrestationStats(
          userProvider.token,
        );
      }
    }
    if (!mounted) return;
    if (res.success == true && res.data is Map) {
      final data = res.data as Map;
      setState(() {
        _prestationsEnAttente = _parseInt(data['enAttente']);
        _prestationsTerminees = _parseInt(data['terminee']);
      });
    }
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Ouvre l'historique avec la liste filtrée (en_attente ou terminee).
  Future<void> _openHistoriqueWithFilter(String filter) async {
    final prestationsProvider = context.read<PrestationsProvider>();
    final userProvider = context.read<UserProvider>();
    await prestationsProvider.loadMyPrestations(userProvider);
    if (!mounted) return;
    if (prestationsProvider.error != null &&
        prestationsProvider.myPrestations.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        prestationsProvider.error!.isNotEmpty
            ? prestationsProvider.error!
            : 'profil_load_error'.tr(),
      );
      return;
    }
    List<Prestation> list;
    if (filter == 'en_attente') {
      list = prestationsProvider.myPrestations
          .where((p) => p.isEnAttente)
          .toList();
    } else {
      list = prestationsProvider.myPrestations
          .where((p) => p.isTerminee || p.isPayee)
          .toList();
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Historique(prestations: list)),
    ).then((value) {
      if (value == true && mounted) _loadPrestationStats();
    });
  }

  Future<void> _loadCataloguePhotos() async {
    final userProvider = context.read<UserProvider>();
    final prestatairesProvider = context.read<PrestatairesProvider>();
    await prestatairesProvider.loadMyPhotos(userProvider);
  }

  Future<void> _changeProfilePhoto() async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null) return;
    try {
      final XFile? picked = await ImageHelper.pickImageWithChoice(
        context,
        _picker,
      );
      if (picked == null || !mounted) return;
      setState(() => _isUploadingAvatar = true);
      var res = await _authController.uploadPhoto(picked.path, token);
      if (res.status == 401) {
        await userProvider.refreshToken();
        if (userProvider.token != null && mounted) {
          res = await _authController.uploadPhoto(
            picked.path,
            userProvider.token,
          );
        }
      }
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      if (res.success == true && res.data != null) {
        String? url;
        if (res.data is String) {
          url = res.data as String?;
        } else if (res.data is Map && (res.data as Map).containsKey('url')) {
          url = (res.data as Map)['url'] as String?;
        }
        if (url != null && url.isNotEmpty) {
          final saved = await userProvider.updateAvatarUrl(url);
          if (!mounted) return;
          if (saved) {
            Utilities().showMesage(
              context,
              'success',
              'presta_photo_updated'.tr(),
            );
          } else {
            Utilities().showMesage(
              context,
              'error',
              'presta_avatar_save_failed'.tr(),
            );
          }
        } else {
          Utilities().showMesage(context, 'error', 'confirm_invalid_response'.tr());
        }
      } else {
        Utilities().showMesage(
          context,
          'error',
          res.message ?? 'presta_upload_failed'.tr(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        Utilities().showMesage(
          context,
          'error',
          'presta_photo_change_error'.tr(),
        );
      }
    }
  }

  Future<void> _addCataloguePhoto() async {
    if (_isUploadingCataloguePhoto) return;
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null) return;
    final prestatairesProvider = context.read<PrestatairesProvider>();
    try {
      final XFile? picked = await ImageHelper.pickImageWithChoice(
        context,
        _picker,
      );
      if (picked == null || !mounted) return;
      setState(() => _isUploadingCataloguePhoto = true);
      var res = await _authController.uploadPhoto(picked.path, token);
      if (res.status == 401) {
        await userProvider.refreshToken();
        if (userProvider.token != null && mounted) {
          res = await _authController.uploadPhoto(
            picked.path,
            userProvider.token,
          );
        }
      }
      if (!mounted) return;
      setState(() => _isUploadingCataloguePhoto = false);
      if (res.success == true && res.data != null) {
        String? url;
        if (res.data is String) {
          url = res.data as String?;
        } else if (res.data is Map && (res.data as Map).containsKey('url')) {
          url = (res.data as Map)['url'] as String?;
        }
        if (url != null && url.isNotEmpty) {
          final ok = await prestatairesProvider.addPhotoToMyCatalogue(
            url: url,
            userProvider: userProvider,
          );
          if (ok) {
            Utilities().showMesage(
              context,
              'success',
              'presta_photo_added'.tr(),
            );
          } else {
            Utilities().showMesage(
              context,
              'error',
              'presta_catalog_failed'.tr(),
            );
          }
        } else {
          Utilities().showMesage(context, 'error', 'confirm_invalid_response'.tr());
        }
      } else {
        Utilities().showMesage(
          context,
          'error',
          res.message ?? 'presta_upload_failed'.tr(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isUploadingCataloguePhoto = false);
        Utilities().showMesage(
          context,
          'error',
          'presta_photo_add_error'.tr(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final avatarUrl = userProvider.avatarUrlForDisplay;
    final settings = context.watch<SettingsProvider>();
    final currentCode =
        settings.selectedLocale?.languageCode ?? context.locale.languageCode;
    final currentLabel = currentCode == 'en' ? 'profil_lang_en'.tr() : 'profil_lang_fr'.tr();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        title: Row(
          children: [
            Image.asset(
              '${Utilities().imagePath}logo.png',
              height: SizeConfig.blockSizeVertical * 5,
              fit: BoxFit.contain,
            ),
            SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
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
        ],
      ),
      backgroundColor: Colors.white,
      body: SizedBox(
        width: SizeConfig.blockSizeHorizontal * 100,
        height: SizeConfig.blockSizeVertical * 100,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: SizeConfig.blockSizeHorizontal * 2,
                children: [
                  Text(
                    'details_welcome'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 5.5,
                      ),
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '${user?.nom ?? ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 5.5,
                      ),
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Builder(
                      builder: (context) {
                        final side =
                            SizeConfig.blockSizeHorizontal * 30;
                        final radius =
                            SizeConfig.blockSizeHorizontal * 8;
                        final hasPhoto = avatarUrl != null &&
                            avatarUrl.toString().trim().isNotEmpty;
                        return Container(
                          width: side,
                          height: side,
                          decoration: BoxDecoration(
                            color: Utilities().colorGreyLightDark,
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasPhoto
                              ? Image.network(
                                  avatarUrl.toString(),
                                  width: side,
                                  height: side,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(
                                      Icons.person,
                                      size:
                                          SizeConfig.blockSizeHorizontal * 14,
                                      color: Utilities().colorGreyDark,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    Icons.person,
                                    size:
                                        SizeConfig.blockSizeHorizontal * 14,
                                    color: Utilities().colorGreyDark,
                                  ),
                                ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 4,
                      right: -5,
                      child: GestureDetector(
                        onTap: _isUploadingAvatar ? null : _changeProfilePhoto,
                        child: CircleAvatar(
                          radius: SizeConfig.blockSizeHorizontal * 3.5,
                          backgroundColor: Utilities().colorBlue,
                          child: _isUploadingAvatar
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              Center(
                child: Column(
                  children: [
                    Text(
                      ' ${user?.nom ?? ''}'.trim(),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 4.2,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                    if (user?.telephone != null)
                      Text(
                        user?.telephone?.toString() ?? '',
                        style: TextStyle(
                          color: Utilities().colorGreyDark,
                          fontSize: SizeConfig.fontSize(
                            SizeConfig.blockSizeHorizontal * 3.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                ),
                child: Text(
                  'presta_tasks'.tr(),
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.5,
                    ),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: SizeConfig.blockSizeHorizontal * 5,
                  top: SizeConfig.blockSizeVertical * 1,
                ),
                child: Row(
                  spacing: SizeConfig.blockSizeHorizontal * 2,
                  children: [
                    CustomButton(
                      onTap: () => _openHistoriqueWithFilter('en_attente'),
                      title: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_prestationsEnAttente ?? 0}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 5,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'presta_pending'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 3.5,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      color: Utilities().colorBlue,
                      borderColor: Utilities().colorBlue,
                      width: SizeConfig.blockSizeHorizontal * 44,
                      height: SizeConfig.blockSizeVertical * 10,
                      borderRadius: SizeConfig.blockSizeHorizontal * 2,
                    ),
                    CustomButton(
                      onTap: () => _openHistoriqueWithFilter('terminee'),
                      title: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_prestationsTerminees ?? 0}',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 5,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'presta_completed'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 3.5,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      color: Utilities().colorBlueLightDark,
                      borderColor: Utilities().colorBlueLightDark,
                      width: SizeConfig.blockSizeHorizontal * 44,
                      height: SizeConfig.blockSizeVertical * 10,
                      borderRadius: SizeConfig.blockSizeHorizontal * 2,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: SizeConfig.blockSizeHorizontal * 5,
                  right: SizeConfig.blockSizeHorizontal * 5,
                  top: SizeConfig.blockSizeVertical * 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'presta_catalog'.tr(),
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.5,
                        ),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final prestatairesProvider = context
                            .watch<PrestatairesProvider>();
                        final photos = prestatairesProvider.myPhotos;
                        if (photos.length > 4) {
                          return GestureDetector(
                            onTap: () {
                              showPrestataireCatalogueBottomSheet(
                                context,
                                photos,
                              );
                            },
                            child: Text(
                              'presta_see_more'.tr(),
                              style: TextStyle(
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 3,
                                ),
                                color: Utilities().colorBlue,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: Utilities().colorBlue,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: SizeConfig.blockSizeHorizontal * 5,
                  right: SizeConfig.blockSizeHorizontal * 5,
                  top: SizeConfig.blockSizeVertical * 1.5,
                  bottom: SizeConfig.blockSizeVertical * 2,
                ),
                child: Builder(
                  builder: (context) {
                    final prestatairesProvider = context
                        .watch<PrestatairesProvider>();
                    final photos = prestatairesProvider.myPhotos;
                    final width = SizeConfig.blockSizeHorizontal * 22;
                    final height = SizeConfig.blockSizeVertical * 10;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (index) {
                        final hasPhoto = index < photos.length;
                        if (hasPhoto) {
                          final photo = photos[index];
                          return GestureDetector(
                            onTap: () => showPrestataireCataloguePhotoViewer(
                              context,
                              photos,
                              initialIndex: index,
                            ),
                            child: Container(
                              width: width,
                              height: height,
                              decoration: BoxDecoration(
                                color: Utilities().colorGreyLightDark,
                                borderRadius: BorderRadius.circular(
                                  SizeConfig.blockSizeHorizontal * 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                photo.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.image_not_supported,
                                  color: Utilities().colorGreyDark,
                                ),
                              ),
                            ),
                          );
                        } else {
                          return CustomButton(
                            onTap: _isUploadingCataloguePhoto
                                ? () {}
                                : _addCataloguePhoto,
                            title: Center(
                              child: _isUploadingCataloguePhoto
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Utilities().colorBlue,
                                      ),
                                    )
                                  : Icon(
                                      Icons.add,
                                      color: Colors.black,
                                      size: SizeConfig.fontSize(
                                        SizeConfig.blockSizeHorizontal * 6,
                                      ),
                                    ),
                            ),
                            color: Utilities().colorGreyLightDark,
                            borderColor: Utilities().colorGreyLightDark,
                            width: width,
                            height: height,
                            borderRadius: SizeConfig.blockSizeHorizontal * 2,
                          );
                        }
                      }),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                  vertical: SizeConfig.blockSizeVertical * 1,
                ),
                child: CustomButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditInfos()),
                    );
                  },
                  title: Row(
                    spacing: SizeConfig.blockSizeHorizontal * 2,
                    children: [
                      SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                      Icon(
                        Icons.settings,
                        size: SizeConfig.blockSizeHorizontal * 6,
                      ),
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal * 65,
child: Text(
                        'profil_personal_info'.tr(),
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 4,
                            ),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_ios,
                        size: SizeConfig.blockSizeHorizontal * 4,
                      ),
                    ],
                  ),
                  color: Utilities().colorGreyLightDark,
                  borderColor: Utilities().colorGreyLightDark,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                  width: SizeConfig.blockSizeHorizontal * 90,
                  height: SizeConfig.blockSizeVertical * 6,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                  vertical: SizeConfig.blockSizeVertical * 1,
                ),
                child: CustomButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Wallet()),
                    );
                  },
                  title: Row(
                    spacing: SizeConfig.blockSizeHorizontal * 1,
                    children: [
                      SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                      Icon(
                        Icons.wallet,
                        size: SizeConfig.blockSizeHorizontal * 6,
                      ),
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal * 65,
child: Text(
                        'presta_wallet'.tr(),
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 4,
                            ),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_ios,
                        size: SizeConfig.blockSizeHorizontal * 4,
                      ),
                    ],
                  ),
                  color: Utilities().colorGreyLightDark,
                  borderColor: Utilities().colorGreyLightDark,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                  width: SizeConfig.blockSizeHorizontal * 90,
                  height: SizeConfig.blockSizeVertical * 6,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  right: SizeConfig.blockSizeHorizontal * 5,
                  left: SizeConfig.blockSizeHorizontal * 5,
                  top: SizeConfig.blockSizeVertical * 1,
                ),
                child: CustomButton(
                  onTap: () async {
                    final prestationsProvider = context
                        .read<PrestationsProvider>();
                    final userProvider = context.read<UserProvider>();
                    await prestationsProvider.loadMyPrestations(userProvider);
                    if (!mounted) return;
                    if (prestationsProvider.error != null &&
                        prestationsProvider.myPrestations.isEmpty) {
                      Utilities().showMesage(
                        context,
                        'error',
                        prestationsProvider.error!.isNotEmpty
                            ? prestationsProvider.error!
                            : 'profil_load_error'.tr(),
                      );
                      return;
                    }
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Historique(
                          prestations: List<Prestation>.from(
                            prestationsProvider.myPrestations,
                          ),
                        ),
                      ),
                    );
                  },
                  title: Row(
                    spacing: SizeConfig.blockSizeHorizontal * 2,
                    children: [
                      SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                      Icon(
                        Icons.history,
                        size: SizeConfig.blockSizeHorizontal * 6,
                      ),
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal * 65,
child: Text(
                        'profil_history'.tr(),
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 4,
                            ),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_ios,
                        size: SizeConfig.blockSizeHorizontal * 4,
                      ),
                    ],
                  ),
                  color: Utilities().colorGreyLightDark,
                  borderColor: Utilities().colorGreyLightDark,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                  width: SizeConfig.blockSizeHorizontal * 90,
                  height: SizeConfig.blockSizeVertical * 6,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              Padding(
                padding: EdgeInsets.only(
                  right: SizeConfig.blockSizeHorizontal * 5,
                  left: SizeConfig.blockSizeHorizontal * 5,
                  bottom: SizeConfig.blockSizeVertical * 1,
                ),
                child: _buildLanguageAccordion(
                  currentLabel: currentLabel,
                  currentCode: currentCode,
                  settings: settings,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                  vertical: SizeConfig.blockSizeVertical * 1,
                ),
                child: CustomButton(
                  onTap: () async {
                    final res = await userProvider.becomeParticulier();
                    if (!mounted) return;
                    if (res.success == true) {
                      Utilities().showMesage(
                        context,
                        'success',
                        'presta_become_client_success'.tr(),
                      );
                      await userProvider.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => Welcome()),
                        (route) => false,
                      );
                    } else {
                      Utilities().showMesage(
                        context,
                        'error',
                        res.message ??
                            'presta_operation_failed'.tr(),
                      );
                    }
                  },
                  title: Row(
                    spacing: SizeConfig.blockSizeHorizontal * 2,
                    children: [
                      SizedBox(width: SizeConfig.blockSizeHorizontal * 2),

                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal * 65,
                        child: Text(
                          'presta_become_client'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 4,
                            ),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_ios,
                        size: SizeConfig.blockSizeHorizontal * 4,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  color: Utilities().colorBlueDark,
                  borderColor: Utilities().colorBlueDark,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                  width: SizeConfig.blockSizeHorizontal * 90,
                  height: SizeConfig.blockSizeVertical * 6,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              Center(
                child: TextButton(
                  onPressed: () {
                    userProvider.logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const Welcome()),
                      (route) => false,
                    );
                  },
                  child: Text(
                    'profil_logout'.tr(),
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.4,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageAccordion({
    required String currentLabel,
    required String currentCode,
    required SettingsProvider settings,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Utilities().colorGreyLightDark,
        borderRadius: BorderRadius.circular(
          SizeConfig.blockSizeHorizontal * 10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(
              SizeConfig.blockSizeHorizontal * 5,
            ),
            onTap: () {
              setState(() {
                _languageOpen = !_languageOpen;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.blockSizeHorizontal * 4,
                vertical: SizeConfig.blockSizeVertical * 1.8,
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, color: Colors.black),
                  SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
                  Expanded(
                    child: Text(
                      'profil_language'.tr(namedArgs: {'label': currentLabel}),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.5,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _languageOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
          if (_languageOpen) const Divider(height: 1),
          if (_languageOpen)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.blockSizeHorizontal * 4,
                vertical: SizeConfig.blockSizeVertical * 1.5,
              ),
              child: Column(
                children: [
                  _buildLanguageRow(
                    flag: '🇫🇷',
                    label: 'profil_lang_fr'.tr(),
                    selected: currentCode == 'fr',
                    onTap: () async {
                      await applyAppLanguage(context, settings, 'fr');
                    },
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 1.2),
                  _buildLanguageRow(
                    flag: '🇬🇧',
                    label: 'profil_lang_en'.tr(),
                    selected: currentCode == 'en',
                    onTap: () async {
                      await applyAppLanguage(context, settings, 'en');
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageRow({
    required String flag,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            flag,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 4),
            ),
          ),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.5,
                ),
              ),
            ),
          ),
          Radio<bool>(
            value: true,
            groupValue: selected,
            onChanged: (_) => onTap(),
            activeColor: Colors.black,
          ),
        ],
      ),
    );
  }
}
