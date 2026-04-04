import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/providers/home_content_provider.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/services/dynamic_translation_service.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';

class FavorisContent extends StatelessWidget {
  const FavorisContent({super.key});

  @override
  Widget build(BuildContext context) {
    final prestatairesProvider = context.watch<PrestatairesProvider>();
    final homeContent = context.read<HomeContentProvider>();
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.blockSizeHorizontal * 5,
              vertical: SizeConfig.blockSizeVertical * 3,
            ),
            child: CustomButton(
              onTap: () => homeContent.goToDemanderService(),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: SizeConfig.blockSizeHorizontal * 5,
                children: [
                  Text(
                    "favoris_demand_button".tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 4,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 4,
                    ),
                  ),
                ],
              ),
              color: Utilities().colorBlueDark,
              borderColor: Utilities().colorBlueDark,
              width: SizeConfig.blockSizeHorizontal * 90,
              height: SizeConfig.blockSizeVertical * 6,
              borderRadius: SizeConfig.blockSizeHorizontal * 10,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.blockSizeHorizontal * 5,
              vertical: SizeConfig.blockSizeVertical * 1,
            ),
            child: Text(
              "favoris_title_week".tr(),
              style: TextStyle(
                color: Utilities().colorGreyDark,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 5,
                ),
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          if (prestatairesProvider.favorisListeProximite &&
              !prestatairesProvider.isLoading)
            Padding(
              padding: EdgeInsets.only(
                left: SizeConfig.blockSizeHorizontal * 5,
                right: SizeConfig.blockSizeHorizontal * 5,
                bottom: SizeConfig.blockSizeVertical * 1,
              ),
              child: Text(
                "favoris_near_you_hint".tr(),
                style: TextStyle(
                  color: Utilities().colorGreyDark.withOpacity(0.85),
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.6,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (prestatairesProvider.isLoading)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: SizeConfig.blockSizeVertical * 10,
                horizontal: SizeConfig.blockSizeHorizontal * 3,
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (prestatairesProvider.error != null)
            Padding(
              padding: EdgeInsets.all(SizeConfig.blockSizeVertical * 3),
              child: Text(
                prestatairesProvider.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            )
          else if (prestatairesProvider.favoris.isEmpty)
            Padding(
              padding: EdgeInsets.all(SizeConfig.blockSizeVertical * 3),
              child: Column(
                spacing: SizeConfig.blockSizeVertical * 3,
                children: [
                  Container(
                    width: SizeConfig.blockSizeHorizontal * 20,
                    height: SizeConfig.blockSizeVertical * 8,
                    decoration: BoxDecoration(
                      color: Utilities().colorBlueLight,
                      borderRadius: BorderRadius.circular(
                        SizeConfig.blockSizeHorizontal * 5,
                      ),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Utilities().colorBlueDark,
                      size: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 10,
                      ),
                    ),
                  ),
                  Text(
                    "favoris_empty".tr(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 4,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: SizeConfig.blockSizeHorizontal * 5,
                right: SizeConfig.blockSizeHorizontal * 5,
                bottom: SizeConfig.blockSizeVertical * 4,
              ),
              itemCount: prestatairesProvider.favoris.length,
              itemBuilder: (context, index) {
                final p = prestatairesProvider.favoris[index];
                final colors = [
                  Utilities().colorBlueDark,
                  Utilities().colorBlue,
                  Utilities().colorBlueLight,
                ];
                return FavoriCard(prestataire: p, color: colors[index % 3]);
              },
            ),
        ],
      ),
    );
  }
}

class FavoriCard extends StatelessWidget {
  final Prestataire prestataire;
  final Color color;

  const FavoriCard({super.key, required this.prestataire, required this.color});

  bool get _isDark =>
      color == Utilities().colorBlueDark || color == Utilities().colorBlue;

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final textColor = _isDark ? Colors.white : Utilities().colorBlueDark;
    final subtitleColor = _isDark
        ? Colors.white.withOpacity(0.9)
        : Utilities().colorGreyDark;

    return Container(
      margin: EdgeInsets.only(bottom: SizeConfig.blockSizeVertical * 2),
      padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 2),
        border: Border.all(color: Utilities().colorBlueDark, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prestataire.nom,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: SizeConfig.fontSize(
                SizeConfig.blockSizeHorizontal * 4.2,
              ),
              color: textColor,
            ),
          ),
          SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
          Text(
            "${prestataire.distanceAffichage} / ${prestataire.adresse}",
            style: TextStyle(
              fontSize: SizeConfig.fontSize(
                SizeConfig.blockSizeHorizontal * 3.5,
              ),
              color: subtitleColor,
            ),
          ),

          if (prestataire.services.isNotEmpty) ...[
            SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
            FutureBuilder<String>(
              future: DynamicTranslationService.instance.translate(
                context,
                prestataire.services
                    .map((s) => s.libelle)
                    .where((l) => l.isNotEmpty)
                    .join(' / '),
                sourceLang: 'fr',
              ),
              builder: (context, snapshot) {
                final text = snapshot.data ??
                    prestataire.services
                        .map((s) => s.libelle)
                        .where((l) => l.isNotEmpty)
                        .join(' / ');
                return Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 2.8,
                    ),
                    color: Colors.grey[700],
                  ),
                );
              },
            ),
          ],
          SizedBox(height: SizeConfig.blockSizeVertical * 1),
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < prestataire.noteMoyenne.round();
                return Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: SizeConfig.blockSizeHorizontal * 4,
                  color: Utilities().colorYellow,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
