import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/deroulement_prestation.dart';
import 'package:milleservices/screens/prestataire/prestataire_confirm_prestation.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:provider/provider.dart';

/// Page d'historique des prestations.
/// Elle reçoit une liste de prestations et les affiche
/// sous forme de cartes. Carte différente selon le rôle :
/// - PARTICULIER : prestataire, service, date, montant.
/// - PRESTATAIRE : nom client, type de prestation, budget, adresse, icône détail.
class Historique extends StatelessWidget {
  final List<Prestation> prestations;

  /// Appelé quand le prestataire tape sur l'icône œil (optionnel).

  const Historique({super.key, required this.prestations});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final role = user?.role?.toString() ?? '';
    final isParticulier = role == 'PARTICULIER';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'profil_history'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 4),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: prestations.isEmpty
          ? Center(
              child: Text(
                'hist_empty'.tr(),
                style: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.5,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.blockSizeHorizontal * 5,
                vertical: SizeConfig.blockSizeVertical * 2,
              ),
              itemCount: prestations.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
              itemBuilder: (context, index) {
                final p = prestations[index];
                if (isParticulier) {
                  return _buildParticulierCard(context, p);
                }
                return _buildPrestataireCard(context, p);
              },
            ),
    );
  }

  Widget _buildParticulierCard(BuildContext context, Prestation p) {
    final prestataireNom = p.prestataire?.nom ?? '—';
    final serviceLibelle = p.service?.libelle ?? '';
    final date = _formatDate(p.createdAt ?? p.acceptedAt ?? p.completedAt);

    // Pour l'instant, pas de montant dans le modèle de prestation.
    // On affiche un placeholder ou à adapter quand le montant sera disponible.
    const String montant = '— FCFA';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeroulementPrestation(prestation: p),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.blockSizeHorizontal * 4,
          vertical: SizeConfig.blockSizeVertical * 1.5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F9FF),
          borderRadius: BorderRadius.circular(
            SizeConfig.blockSizeHorizontal * 4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: SizeConfig.blockSizeHorizontal * 10,
              height: SizeConfig.blockSizeHorizontal * 10,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Utilities().colorYellow,
                size: SizeConfig.blockSizeHorizontal * 6,
              ),
            ),
            SizedBox(width: SizeConfig.blockSizeHorizontal * 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'hist_provider'.tr(namedArgs: {'name': prestataireNom}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.5,
                      ),
                    ),
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          serviceLibelle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Utilities().colorGreyDark,
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 3,
                            ),
                          ),
                        ),
                      ),
                      if (date.isNotEmpty) ...[
                        SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                        Text(
                          date,
                          style: TextStyle(
                            color: Utilities().colorGreyDark,
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
            Text(
              montant,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carte pour un PRESTATAIRE : client, type de prestation, budget, adresse, icône œil.
  Widget _buildPrestataireCard(BuildContext context, Prestation p) {
    final clientNom = p.particulier?.displayName ?? '—';
    final serviceLibelle = p.service?.libelle ?? '—';
    final adresse =
        p.adresse ?? (p.ville != null && p.ville!.isNotEmpty ? p.ville : '—');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (p.isEnAttente) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PrestataireConfirmPrestation(prestation: p),
              ),
            ).then((value) {
              if (value == true && context.mounted) {
                Navigator.pop(context, true);
              }
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeroulementPrestation(prestation: p),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 4),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.blockSizeHorizontal * 4,
            vertical: SizeConfig.blockSizeVertical * 1.5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F9FF),
            borderRadius: BorderRadius.circular(
              SizeConfig.blockSizeHorizontal * 4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: SizeConfig.blockSizeHorizontal * 10,
                height: SizeConfig.blockSizeHorizontal * 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFB4DBFF).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: const Color(0xFFB4DBFF),
                  size: SizeConfig.blockSizeHorizontal * 6,
                ),
              ),
              SizedBox(width: SizeConfig.blockSizeHorizontal * 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'hist_names'.tr(namedArgs: {'name': clientNom}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.5,
                        ),
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                    Text(
                      'hist_type'.tr(namedArgs: {'type': serviceLibelle}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.2,
                        ),
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                    Text(
                      'hist_status'.tr(namedArgs: {'status': p.statutLibelle}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Utilities().colorBlueDark,
                        fontWeight: FontWeight.w500,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.2,
                        ),
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                    Text(
                      'hist_budget'.tr(namedArgs: {'amount': p.budget?.toStringAsFixed(0) ?? '—'}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w700,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.2,
                        ),
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                    Text(
                      'hist_address'.tr(namedArgs: {'address': adresse ?? '—'}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Utilities().colorGreyDark,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: SizeConfig.blockSizeHorizontal * 2),

              Icon(
                Icons.visibility,
                color: Utilities().colorBlueDark,
                size: SizeConfig.blockSizeHorizontal * 6,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }
}
