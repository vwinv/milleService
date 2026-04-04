import 'package:flutter/material.dart';
import 'package:milleservices/controllers/prestationsController.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/deroulement_prestation.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:provider/provider.dart';

/// Récap d'une prestation en attente : le prestataire voit les infos client,
/// type, adresse, budget, description, image(s), et peut Accepter ou Refuser.
/// Accepter → DeroulementPrestation. Refuser → retour à la liste (mise à jour).
class PrestataireConfirmPrestation extends StatefulWidget {
  final Prestation prestation;

  const PrestataireConfirmPrestation({super.key, required this.prestation});

  @override
  State<PrestataireConfirmPrestation> createState() =>
      _PrestataireConfirmPrestationState();
}

class _PrestataireConfirmPrestationState
    extends State<PrestataireConfirmPrestation> {
  static final _prestationsController = PrestationsController.instance;
  bool _isAccepting = false;
  bool _isRefusing = false;
  bool _hasNewNotifications = false;

  Future<void> _accepter() async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'Session expirée. Reconnectez-vous.',
      );
      return;
    }
    setState(() => _isAccepting = true);
    var res = await _prestationsController.accepter(
      token,
      widget.prestation.id,
    );
    if (res.status == 401 && mounted) {
      await userProvider.refreshToken();
      final newToken = userProvider.token;
      if (newToken != null && mounted) {
        res = await _prestationsController.accepter(
          newToken,
          widget.prestation.id,
        );
      }
    }
    if (!mounted) return;
    setState(() => _isAccepting = false);
    if (!res.success) {
      Utilities().showMesage(
        context,
        'error',
        res.message?.isNotEmpty == true
            ? res.message!
            : 'Impossible d\'accepter la prestation.',
      );
      return;
    }
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      Utilities().showMesage(context, 'error', 'Réponse serveur invalide.');
      return;
    }
    final updated = Prestation.fromJson(data);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DeroulementPrestation(prestation: updated),
      ),
    );
  }

  Future<void> _refuser() async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'Session expirée. Reconnectez-vous.',
      );
      return;
    }
    setState(() => _isRefusing = true);
    var res = await _prestationsController.refuser(token, widget.prestation.id);
    if (res.status == 401 && mounted) {
      await userProvider.refreshToken();
      final newToken = userProvider.token;
      if (newToken != null && mounted) {
        res = await _prestationsController.refuser(
          newToken,
          widget.prestation.id,
        );
      }
    }
    if (!mounted) return;
    setState(() => _isRefusing = false);
    if (!res.success) {
      Utilities().showMesage(
        context,
        'error',
        res.message?.isNotEmpty == true
            ? res.message!
            : 'Impossible de refuser la prestation.',
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, true); // true = liste à rafraîchir
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final p = widget.prestation;
    final clientNom = p.particulier?.displayName ?? '—';
    final typeTache = p.typeDeTache ?? p.service?.libelle ?? '—';
    final adresse =
        p.adresse ?? (p.ville != null && p.ville!.isNotEmpty ? p.ville! : '—');
    final budget = p.budget != null
        ? '${p.budget!.toStringAsFixed(0)} FCFA'
        : '— FCFA';
    final description = p.description ?? 'Aucune description.';
    final imageUrl = p.imageUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          clientNom,
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 4),
            fontWeight: FontWeight.w600,
          ),
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
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.blockSizeHorizontal * 5,
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.blockSizeHorizontal * 5,
                vertical: SizeConfig.blockSizeVertical * 5,
              ),
              decoration: BoxDecoration(
                color: Utilities().colorBlueLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(
                  SizeConfig.blockSizeHorizontal * 3,
                ),
                border: Border.all(color: Utilities().colorGreyLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.only(
                      bottom: SizeConfig.blockSizeVertical * 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Utilities().colorGreyDark.withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Noms : $clientNom',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.8,
                              ),
                              color: Colors.black,
                            ),
                          ),
                        ),
                        _contactIcon(
                          Icons.phone,
                          color: Utilities().colorYellow,
                          onTap: () {},
                        ),
                        SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                        _contactIcon(
                          Icons.chat,
                          color: Colors.green[700]!,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.blockSizeVertical * 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Utilities().colorGreyDark.withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: SizeConfig.blockSizeHorizontal * 26,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Type de prestation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.2,
                                  ),

                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                typeTache,
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.2,
                                  ),

                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: SizeConfig.blockSizeHorizontal * 28,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adresse',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.2,
                                  ),
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                adresse,
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.2,
                                  ),
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: SizeConfig.blockSizeHorizontal * 25,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Budget',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.2,
                                  ),
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                budget,
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.2,
                                  ),
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.blockSizeVertical * 2,
                    ),
                    child: Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.5,
                        ),
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(
                      bottom: SizeConfig.blockSizeVertical * 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Utilities().colorGreyDark.withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.2,
                        ),
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.blockSizeVertical * 2,
                    ),
                    child: Text(
                      'Image de la tâche à exécuter',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.5,
                        ),
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        SizeConfig.blockSizeHorizontal * 2,
                      ),
                      child: Image.network(
                        imageUrl,
                        height: SizeConfig.blockSizeVertical * 25,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      ),
                    )
                  else
                    _imagePlaceholder(),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: SizeConfig.blockSizeVertical * 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomButton(
                    title: Center(
                      child: _isAccepting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Accepter',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 3.5,
                                ),
                              ),
                            ),
                    ),
                    color: Utilities().colorBlueDark,
                    borderColor: Utilities().colorBlueDark,
                    borderRadius: SizeConfig.blockSizeHorizontal * 10,
                    width: SizeConfig.blockSizeHorizontal * 40,
                    height: SizeConfig.blockSizeVertical * 6,
                    onTap: _accepter,
                  ),
                  CustomButton(
                    title: Center(
                      child: _isRefusing
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.red.shade400,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Refuser',
                              style: TextStyle(
                                color: Color(0xFFE10606),
                                fontWeight: FontWeight.bold,
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 3.5,
                                ),
                              ),
                            ),
                    ),
                    color: Colors.transparent,
                    borderColor: Color(0xFFE10606),
                    borderRadius: SizeConfig.blockSizeHorizontal * 10,
                    width: SizeConfig.blockSizeHorizontal * 40,
                    height: SizeConfig.blockSizeVertical * 6,
                    onTap: _refuser,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactIcon(
    IconData icon, {
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 2),
          child: Icon(
            icon,
            color: Colors.white,
            size: SizeConfig.blockSizeHorizontal * 5,
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: SizeConfig.blockSizeVertical * 0.8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: SizeConfig.blockSizeHorizontal * 38,
            child: Text(
              '$label : ',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.2,
                ),
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.2,
                ),
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: SizeConfig.blockSizeVertical * 20,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 2),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: SizeConfig.blockSizeHorizontal * 12,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}
