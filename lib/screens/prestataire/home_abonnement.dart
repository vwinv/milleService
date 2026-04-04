import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/models/offre.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/prestataire_home_resolver.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/services/sizeConfig.dart';

class HomeAbonnement extends StatefulWidget {
  const HomeAbonnement({super.key});

  @override
  State<HomeAbonnement> createState() => _HomeAbonnementState();
}

class _HomeAbonnementState extends State<HomeAbonnement> {
  bool _localLoading = false;
  String? _error;
  Offre? _selectedOffre;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadOffres);
  }

  /// Pré-sélectionne la première offre si la liste est déjà dispo (ex. cache).
  void _ensureFirstSelected(List<Offre> offres) {
    if (offres.isNotEmpty && _selectedOffre == null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedOffre == null) {
          setState(() => _selectedOffre = offres.first);
        }
      });
    }
  }

  Future<void> _loadOffres() async {
    setState(() {
      _localLoading = true;
      _error = null;
      _selectedOffre = null;
    });
    final userProvider = context.read<UserProvider>();
    final res = await userProvider.fetchAbonnementOffres();
    if (!mounted) return;
    if (res.success != true) {
      setState(() {
        _error = res.message ?? 'abonnement_load_error'.tr();
      });
    } else {
      final offres = userProvider.offres;
      if (offres.isNotEmpty) {
        setState(() => _selectedOffre = offres.first);
      }
    }
    setState(() {
      _localLoading = false;
    });
  }

  String _subtitleForOffre(Offre o) {
    final d = o.dureeMois;
    if (d == null) return '';
    if (d == 12) return 'abonnement_per_year'.tr();
    if (d == 1) return 'abonnement_per_month'.tr();
    if (d == 3) return 'abonnement_per_3months'.tr();
    if (d < 1) return 'abonnement_per_week'.tr();
    return 'abonnement_per_n_months'.tr(namedArgs: {'n': d.toString()});
  }

  String _formatPrix(dynamic prix) {
    if (prix == null) return '0';
    final n = prix is num ? prix.toInt() : int.tryParse(prix.toString()) ?? 0;
    if (n >= 1000) {
      final s = n.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return n.toString();
  }

  Future<void> _commencer() async {
    final selected = _selectedOffre;
    if (selected == null) return;
    final userProvider = context.read<UserProvider>();
    setState(() => _localLoading = true);
    final res = await userProvider.souscrireAbonnement(selected.id);
    if (!mounted) return;
    setState(() => _localLoading = false);
    if (res.success == true) {
      await userProvider.refreshVerificationStatus();
      final settings = context.read<SettingsProvider>();
      final statutVerif =
          userProvider.user?.statutVerification?.toString().toUpperCase() ?? '';
      Utilities().showMesage(
        context,
        'success',
        'abonnement_success'.tr(namedArgs: {'libelle': selected.libelle ?? ''}),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => resolvePrestataireHome(
            statutVerificationRaw: statutVerif,
            settings: settings,
            userProvider: userProvider,
          ),
        ),
      );
    } else {
      Utilities().showMesage(
        context,
        'error',
        res.message ?? 'abonnement_failed'.tr(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final offres = userProvider.offres;
    final utils = Utilities();
    _ensureFirstSelected(offres);

    return Scaffold(
      backgroundColor: Colors.white,

      body: _localLoading && offres.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadOffres,
                    child: Text('abonnement_retry'.tr()),
                  ),
                ],
              ),
            )
          : offres.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'abonnement_empty'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOffres,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: SizeConfig.blockSizeVertical * 15,
                        right: SizeConfig.blockSizeHorizontal * 10,
                      ),
                      child: Text(
                        'abonnement_title'.tr(),
                        style: TextStyle(
                          fontSize: SizeConfig.blockSizeHorizontal * 6,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 3),
                    ...offres.map((offre) {
                      final selected = _selectedOffre?.id == offre.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? utils.colorBlueLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: utils.colorGreyLightDark,
                              width: 1,
                            ),
                          ),

                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedOffre = offre);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: offre.id,
                                    groupValue: _selectedOffre?.id,
                                    onChanged: (_) {
                                      setState(() => _selectedOffre = offre);
                                    },
                                    activeColor: utils.colorBlueDark,
                                  ),
                                  Expanded(
                                    child: Text(
                                      offre.libelle ?? '',
                                      style: TextStyle(
                                        fontSize:
                                            SizeConfig.blockSizeHorizontal * 4,
                                        fontWeight: FontWeight.w600,
                                        color: utils.colorBlueDark,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${_formatPrix(offre.prix)} FCFA',
                                        style: TextStyle(
                                          fontSize:
                                              SizeConfig.blockSizeHorizontal *
                                              3.8,
                                          fontWeight: FontWeight.bold,
                                          color: utils.colorBlueDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _subtitleForOffre(offre),
                                        style: TextStyle(
                                          fontSize:
                                              SizeConfig.blockSizeHorizontal *
                                              2.8,
                                          color: utils.colorGreyDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: SizeConfig.blockSizeVertical * 2),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: utils.colorBlueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'abonnement_you_get'.tr(),
                            style: TextStyle(
                              fontSize: SizeConfig.blockSizeHorizontal * 3.8,
                              fontWeight: FontWeight.bold,
                              color: utils.colorGreyDark,
                            ),
                          ),
                          SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
                          ..._buildDescriptionLines(utils),
                        ],
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 4),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _localLoading || _selectedOffre == null
                            ? null
                            : _commencer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: utils.colorBlueDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'abonnement_start'.tr(),
                          style: TextStyle(
                            fontSize: SizeConfig.blockSizeHorizontal * 4,
                            fontWeight: FontWeight.w600,
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

  /// Affiche la description de l'abonnement sélectionné dans "Vous obtiendrez".
  List<Widget> _buildDescriptionLines(Utilities utils) {
    final desc = _selectedOffre?.description;
    final text = desc is String ? desc : (desc?.toString() ?? '');
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return [_benefitRow(utils, 'abonnement_no_desc'.tr())];
    }
    final lines = trimmed
        .split(RegExp(r'[\n;]'))
        .where((s) => s.trim().isNotEmpty);
    return lines.map((line) => _benefitRow(utils, line.trim())).toList();
  }

  Widget _benefitRow(Utilities utils, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star, size: 18, color: utils.colorBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                color: utils.colorGreyDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
