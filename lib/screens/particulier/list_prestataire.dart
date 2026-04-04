import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/screens/particulier/details_prestataire.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';

class ListPrestataire extends StatelessWidget {
  const ListPrestataire({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'list_title'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 5),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<PrestatairesProvider>(
        builder: (context, provider, _) {
          if (provider.searchLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.searchError != null) {
            return Padding(
              padding: EdgeInsets.all(SizeConfig.blockSizeVertical * 3),
              child: Text(
                provider.searchError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (provider.searchResults.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(SizeConfig.blockSizeVertical * 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    SizedBox(height: SizeConfig.blockSizeVertical * 3),
                    Text(
                      'list_empty'.tr(),
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
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.blockSizeHorizontal * 5,
              vertical: SizeConfig.blockSizeVertical * 2,
            ),
            itemCount: provider.searchResults.length,
            itemBuilder: (context, index) {
              final p = provider.searchResults[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailsPrestataire(prestataire: p),
                    ),
                  );
                },
                child: _PrestataireItem(prestataire: p),
              );
            },
          );
        },
      ),
    );
  }
}

class _PrestataireItem extends StatelessWidget {
  final Prestataire prestataire;

  const _PrestataireItem({required this.prestataire});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return Container(
      margin: EdgeInsets.only(bottom: SizeConfig.blockSizeVertical * 2),
      decoration: BoxDecoration(
        color: Utilities().colorGreyLightDark,
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: SizeConfig.blockSizeVertical * 20,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(SizeConfig.blockSizeHorizontal * 5),
                topRight: Radius.circular(SizeConfig.blockSizeHorizontal * 5),
              ),
              child: prestataire.avatarUrl == null
                  ? Image.asset(
                      '${Utilities().imagePath}ouvrier2.jpeg',
                      fit: BoxFit.cover,
                    )
                  : Image.network(prestataire.avatarUrl!, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              SizeConfig.blockSizeHorizontal * 5,
              SizeConfig.blockSizeVertical * 1.2,
              SizeConfig.blockSizeHorizontal * 5,
              SizeConfig.blockSizeVertical * 1.5,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        prestataire.nom,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: SizeConfig.fontSize(
                            SizeConfig.blockSizeHorizontal * 3.5,
                          ),
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                      Text(
                        prestataire.adresse != null &&
                                prestataire.adresse!.isNotEmpty
                            ? '${prestataire.distanceAffichage} / ${prestataire.adresse}'
                            : prestataire.distanceAffichage,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: SizeConfig.fontSize(
                            SizeConfig.blockSizeHorizontal * 3,
                          ),
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      if (prestataire.services.isNotEmpty) ...[
                        SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                        Text(
                          prestataire.services
                              .map((s) => s.libelle)
                              .where((l) => l.isNotEmpty)
                              .join(' / '),
                          softWrap: true,
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 2.8,
                            ),
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      if (index < prestataire.noteMoyenne.toInt()) {
                        return Icon(
                          Icons.star,
                          size: 16,
                          color: Utilities().colorYellow,
                        );
                      }
                      return Icon(
                        Icons.star_border,
                        size: 16,
                        color: Utilities().colorGreyDark,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
