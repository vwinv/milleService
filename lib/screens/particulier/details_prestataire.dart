import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/models/prestataire_photo.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/particulier/confirm_prestation.dart';
import 'package:milleservices/screens/particulier/profil_particulier.dart';
import 'package:milleservices/services/app_map.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:milleservices/widgets/prestataire_catalogue_bottom_sheet.dart';
import 'package:milleservices/widgets/prestataire_catalogue_photo_viewer.dart';
import 'package:provider/provider.dart';

class DetailsPrestataire extends StatefulWidget {
  final Prestataire prestataire;
  const DetailsPrestataire({super.key, required this.prestataire});

  @override
  State<DetailsPrestataire> createState() => _DetailsPrestataireState();
}

class _DetailsPrestataireState extends State<DetailsPrestataire> {
  bool _hasNewNotifications = true;
  List<PrestatairePhoto> _cataloguePhotos = [];
  bool _catalogueLoading = true;

  static const List<Color> _avisCircleColors = [
    Color(0xFFB4DBFF),
    Color(0xFFFF9131),
    Color(0xFF05C916),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrestatairesProvider>().loadAvisPrestataire(
        widget.prestataire.id,
      );
      _loadCatalogue();
    });
  }

  Future<void> _loadCatalogue() async {
    final list = await context
        .read<PrestatairesProvider>()
        .fetchPrestatairePhotos(widget.prestataire.id);
    if (!mounted) return;
    list.sort((a, b) => a.ordre.compareTo(b.ordre));
    setState(() {
      _cataloguePhotos = list;
      _catalogueLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final prenom = user?.prenom?.toString() ?? '';

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
            onPressed: () {},
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
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.blockSizeHorizontal * 5,
              vertical: SizeConfig.blockSizeVertical * 2,
            ),
            child: Row(
              spacing: SizeConfig.blockSizeHorizontal * 2,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.black,
                    size: SizeConfig.blockSizeHorizontal * 5,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.prestataire.nom,
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 4.5,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  SizedBox(
                    height: SizeConfig.blockSizeVertical * 30,
                    child:
                        (widget.prestataire.latitude != null &&
                            widget.prestataire.longitude != null)
                        ? AppMap(
                            center: LatLng(
                              widget.prestataire.latitude!,
                              widget.prestataire.longitude!,
                            ),
                            zoom: 15,
                            markers: [
                              Marker(
                                point: LatLng(
                                  widget.prestataire.latitude!,
                                  widget.prestataire.longitude!,
                                ),
                                width: SizeConfig.blockSizeHorizontal * 40,
                                height: SizeConfig.blockSizeVertical * 10,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            SizeConfig.blockSizeHorizontal * 3,
                                        vertical:
                                            SizeConfig.blockSizeVertical * 0.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        border: Border.all(
                                          color: Colors.green,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        widget.prestataire.nom,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.green[800],
                                          fontSize: SizeConfig.fontSize(
                                            SizeConfig.blockSizeHorizontal *
                                                3.2,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height:
                                          SizeConfig.blockSizeVertical * 0.5,
                                    ),
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                      size: SizeConfig.fontSize(
                                        SizeConfig.blockSizeHorizontal * 7,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Text(
                              'details_address_unavailable'.tr(),
                              style: TextStyle(
                                color: Utilities().colorGreyDark,
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 3.2,
                                ),
                              ),
                            ),
                          ),
                  ),
                  Container(
                    margin: EdgeInsets.only(
                      top: SizeConfig.blockSizeVertical * 25,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                          SizeConfig.blockSizeHorizontal * 15,
                        ),
                        topRight: Radius.circular(
                          SizeConfig.blockSizeHorizontal * 15,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: SizeConfig.blockSizeVertical * 20,
                          width: SizeConfig.blockSizeHorizontal * 100,

                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                SizeConfig.blockSizeHorizontal * 10,
                              ),
                              topRight: Radius.circular(
                                SizeConfig.blockSizeHorizontal * 10,
                              ),
                            ),
                            child: widget.prestataire.avatarUrl == null
                                ? Image.asset(
                                    '${Utilities().imagePath}ouvrier2.jpeg',
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    widget.prestataire.avatarUrl!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        SizedBox(
                          height: SizeConfig.blockSizeVertical * 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: EdgeInsetsGeometry.only(
                                  left: SizeConfig.blockSizeHorizontal * 5,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.prestataire.nom,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                        fontSize: SizeConfig.fontSize(
                                          SizeConfig.blockSizeHorizontal * 3.5,
                                        ),
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(
                                      height:
                                          SizeConfig.blockSizeVertical * 0.5,
                                    ),
                                    Text(
                                      widget.prestataire.adresse != null &&
                                              widget
                                                  .prestataire
                                                  .adresse!
                                                  .isNotEmpty
                                          ? '${widget.prestataire.distanceAffichage} / ${widget.prestataire.adresse}'
                                          : widget
                                                .prestataire
                                                .distanceAffichage,
                                      style: TextStyle(
                                        fontSize: SizeConfig.fontSize(
                                          SizeConfig.blockSizeHorizontal * 3,
                                        ),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    if (widget
                                        .prestataire
                                        .services
                                        .isNotEmpty) ...[
                                      SizedBox(
                                        height:
                                            SizeConfig.blockSizeVertical * 0.5,
                                      ),
                                      Text(
                                        widget.prestataire.services
                                            .map((s) => s.libelle)
                                            .where((l) => l.isNotEmpty)
                                            .join(' / '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: SizeConfig.fontSize(
                                            SizeConfig.blockSizeHorizontal *
                                                2.8,
                                          ),
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsGeometry.only(
                                  right: SizeConfig.blockSizeHorizontal * 5,
                                ),
                                child: SizedBox(
                                  width: SizeConfig.blockSizeHorizontal * 15,
                                  child: ListView.builder(
                                    itemCount: 5,
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (context, index) {
                                      if (index <
                                          widget.prestataire.noteMoyenne
                                              .toInt()) {
                                        return Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Utilities().colorYellow,
                                        );
                                      } else {
                                        return Icon(
                                          Icons.star_border,
                                          size: 16,
                                          color: Utilities().colorGreyDark,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(
                            vertical: SizeConfig.blockSizeVertical * 1,
                            horizontal: SizeConfig.blockSizeHorizontal * 5,
                          ),
                          child: Text(
                            widget.prestataire.tarifMinimum != null
                                ? 'details_labor_from'.tr(
                                    namedArgs: {
                                      'amount': widget.prestataire.tarifMinimum!
                                          .toStringAsFixed(0),
                                    },
                                  )
                                : 'details_rates_on_request'.tr(),
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.7,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(
                            vertical: SizeConfig.blockSizeVertical * 0.5,
                            horizontal: SizeConfig.blockSizeHorizontal * 5,
                          ),
                          child: Text(
                            'details_about'.tr().toUpperCase(),
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.5,
                              ),
                              color: Utilities().colorGreyDark,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(
                            vertical: SizeConfig.blockSizeVertical * 0.5,
                            horizontal: SizeConfig.blockSizeHorizontal * 5,
                          ),
                          child: Text(
                            widget.prestataire.bio != null &&
                                    widget.prestataire.bio!.isNotEmpty
                                ? widget.prestataire.bio!
                                : 'details_no_info'.tr(),
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.5,
                              ),
                              color: Colors.black,
                            ),
                          ),
                        ),
                        _buildCatalogueSection(),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(
                            vertical: SizeConfig.blockSizeVertical * 1.5,
                            horizontal: SizeConfig.blockSizeHorizontal * 5,
                          ),
                          child: Text(
                            'details_reviews'.tr().toUpperCase(),
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.5,
                              ),
                              color: Utilities().colorGreyDark,
                            ),
                          ),
                        ),
                        _buildAvisList(),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(
                            vertical: SizeConfig.blockSizeVertical * 2,
                            horizontal: SizeConfig.blockSizeHorizontal * 6,
                          ),
                          child: CustomButton(
                            title: Center(
                              child: Text(
                                'details_choose_provider'.tr(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.5,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            color: Utilities().colorBlueDark,
                            borderColor: Utilities().colorBlueDark,
                            borderRadius: SizeConfig.blockSizeHorizontal * 10,
                            width: SizeConfig.blockSizeHorizontal * 80,
                            height: SizeConfig.blockSizeVertical * 5,
                            onTap: _onChoisirPrestataire,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogueSection() {
    if (_catalogueLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.blockSizeHorizontal * 5,
          vertical: SizeConfig.blockSizeVertical * 2,
        ),
        child: SizedBox(
          height: SizeConfig.blockSizeVertical * 10,
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_cataloguePhotos.isEmpty) {
      return const SizedBox.shrink();
    }

    final photos = _cataloguePhotos;
    final width = SizeConfig.blockSizeHorizontal * 22;
    final height = SizeConfig.blockSizeVertical * 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: SizeConfig.blockSizeHorizontal * 5,
            right: SizeConfig.blockSizeHorizontal * 5,
            top: SizeConfig.blockSizeVertical * 1,
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
              if (photos.length > 4)
                GestureDetector(
                  onTap: () =>
                      showPrestataireCatalogueBottomSheet(context, photos),
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
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: SizeConfig.blockSizeHorizontal * 5,
            right: SizeConfig.blockSizeHorizontal * 5,
            top: SizeConfig.blockSizeVertical * 1.5,
            bottom: SizeConfig.blockSizeVertical * 1,
          ),
          child: Row(
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
              }
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Utilities().colorGreyLightDark,
                  borderRadius: BorderRadius.circular(
                    SizeConfig.blockSizeHorizontal * 2,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Future<void> _onChoisirPrestataire() async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        Utilities().showMesage(context, 'error', 'details_need_login'.tr());
      }
      return;
    }
    final services = widget.prestataire.services;
    final firstService = services.isNotEmpty ? services.first : null;
    final prestataireServiceId = firstService?.prestataireServiceId;
    if (firstService == null ||
        prestataireServiceId == null ||
        prestataireServiceId.isEmpty) {
      if (mounted) {
        Utilities().showMesage(context, 'error', 'details_no_service'.tr());
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ConfirmPrestation(
          prestataire: widget.prestataire,
          prestataireServiceId: prestataireServiceId,
          serviceLibelle: firstService.libelle,
          adresseParticulier: userProvider.user?.adresse?.toString(),
        ),
      ),
    );
  }

  Widget _buildAvisList() {
    final provider = context.watch<PrestatairesProvider>();
    if (provider.avisLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: SizeConfig.blockSizeVertical * 2,
          horizontal: SizeConfig.blockSizeHorizontal * 5,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final avis = provider.prestataireAvis;
    if (avis.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: SizeConfig.blockSizeVertical * 2,
          horizontal: SizeConfig.blockSizeHorizontal * 5,
        ),
        child: Text(
          'details_no_reviews'.tr(),
          style: TextStyle(
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3.5),
            color: Utilities().colorGreyDark,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        left: SizeConfig.blockSizeHorizontal * 5,
        right: SizeConfig.blockSizeHorizontal * 5,
        bottom: SizeConfig.blockSizeVertical * 3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: avis.asMap().entries.map((entry) {
          final index = entry.key;
          final a = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: SizeConfig.blockSizeVertical * 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: SizeConfig.blockSizeHorizontal * 12,
                  height: SizeConfig.blockSizeHorizontal * 12,
                  decoration: BoxDecoration(
                    color: _avisCircleColors[index % _avisCircleColors.length]
                        .withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: _avisCircleColors[index % _avisCircleColors.length],
                    size: SizeConfig.blockSizeHorizontal * 8,
                  ),
                ),
                SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.nomClient,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: SizeConfig.fontSize(
                            SizeConfig.blockSizeHorizontal * 3.5,
                          ),
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < a.note ? Icons.star : Icons.star_border,
                            size: 18,
                            color: i < a.note
                                ? Utilities().colorYellow
                                : Utilities().colorGreyDark,
                          );
                        }),
                      ),
                      if (a.commentaire != null &&
                          a.commentaire!.trim().isNotEmpty) ...[
                        SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                        Text(
                          a.commentaire!,
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 3.2,
                            ),
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
