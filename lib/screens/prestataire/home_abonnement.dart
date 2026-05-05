import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/screens/welcome.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/models/offre.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/home_resolver.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/widgets/paiement_soft_pay_sheet.dart';

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

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _commencer() async {
    final selected = _selectedOffre;
    if (selected == null) return;
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      Utilities().showMesage(context, 'error', 'Session expirée.');
      return;
    }
    await _waitForNextFrame();
    if (!mounted) return;
    setState(() => _localLoading = true);
    final res = await userProvider.initPaydunyaAbonnement(selected.id.toString());
    if (!mounted) return;
    setState(() => _localLoading = false);
    if (res.success != true || res.data is! Map) {
      Utilities().showMesage(
        context,
        'error',
        res.message?.toString().isNotEmpty == true
            ? res.message.toString()
            : 'abonnement_failed'.tr(),
      );
      return;
    }
    final map = Map<String, dynamic>.from(res.data as Map);
    final invoiceToken = map['invoiceToken']?.toString().trim();
    final checkoutUrlFallback = map['checkoutUrl']?.toString().trim() ?? '';
    if (invoiceToken == null || invoiceToken.isEmpty) {
      Utilities().showMesage(context, 'error', 'abonnement_failed'.tr());
      return;
    }
    final user = userProvider.user;
    final settings = context.read<SettingsProvider>();
    final auth = Authcontroller.instance;
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: PaiementSoftPaySheet.topBorderRadius,
      ),
      builder: (ctx) => PaiementSoftPaySheet(
        invoiceToken: invoiceToken,
        checkoutUrlFallback: checkoutUrlFallback,
        initialPrenom: user?.prenom?.toString() ?? '',
        initialNom: user?.nom?.toString() ?? '',
        initialTelephone: user?.telephone?.toString() ?? '',
        email: user?.email?.toString(),
        montantLabel: '${_formatPrix(selected.prix)} FCFA',
        verifyBeforeComplete: () async {
          const maxAttempts = 48;
          const pause = Duration(milliseconds: 500);
          final offreIdAttendu = selected.id.toString();
          for (var i = 0; i < maxAttempts; i++) {
            if (i > 0) await Future<void>.delayed(pause);
            if (!mounted) return false;
            var t = userProvider.token;
            var paidRes = await auth.isAbonnementPaydunyaInvoicePaid(
              token: t,
              invoiceToken: invoiceToken,
            );
            if (paidRes.status == 401) {
              await userProvider.refreshToken();
              if (!mounted) return false;
              t = userProvider.token;
              if (t == null || t.isEmpty) return false;
              paidRes = await auth.isAbonnementPaydunyaInvoicePaid(
                token: t,
                invoiceToken: invoiceToken,
              );
            }
            if (paidRes.success != true || paidRes.data is! Map) continue;
            final dm = Map<String, dynamic>.from(paidRes.data as Map);
            if (dm['paid'] != true) continue;
            final aboRaw = dm['abonnement'];
            if (aboRaw != null) {
              await userProvider.applyAbonnementCourantPayload(aboRaw);
            } else {
              await userProvider.refreshAbonnementCourant();
            }
            if (!mounted) return false;
            final a = userProvider.abonnement;
            if (a != null && a.offreId?.toString() == offreIdAttendu) {
              return true;
            }
          }
          return false;
        },
        onSoftPay: ({
          required String method,
          required String prenom,
          required String nom,
          required String telephone,
          String? email,
        }) async {
          switch (method) {
            case 'wave_sn':
              return auth.payAbonnementWaveSn(
                token: token,
                offreId: selected.id.toString(),
                invoiceToken: invoiceToken,
                prenom: prenom,
                nom: nom,
                telephone: telephone,
                email: email,
              );
            case 'orange_money_sn':
              return auth.payAbonnementOrangeMoneySn(
                token: token,
                offreId: selected.id.toString(),
                invoiceToken: invoiceToken,
                prenom: prenom,
                nom: nom,
                telephone: telephone,
                email: email,
              );
            case 'free_money_sn':
              return auth.payAbonnementFreeMoneySn(
                token: token,
                offreId: selected.id.toString(),
                invoiceToken: invoiceToken,
                prenom: prenom,
                nom: nom,
                telephone: telephone,
                email: email,
              );
            default:
              return ResponseData(
                success: false,
                message: 'Moyen inconnu',
                data: null,
                status: 400,
                emailNotVerified: false,
              );
          }
        },
      ),
    );
    if (!mounted || paid != true) return;
    await userProvider.refreshAbonnementCourant();
    if (!mounted) return;
    final aboApres = userProvider.abonnement;
    if (aboApres == null) return;
    if (aboApres.offreId?.toString() != selected.id.toString()) return;
    Utilities().showMesage(
      context,
      'success',
      'abonnement_success'.tr(
        namedArgs: {'libelle': selected.libelle ?? ''},
      ),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            resolveHome(settings: settings, userProvider: userProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final offres = userProvider.offres;
    final utils = Utilities();
    _ensureFirstSelected(offres);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Déconnexion',
            onPressed: () async {
              await context.read<UserProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Welcome()),
                (route) => false,
              );
            },
          ),
        ],
      ),
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
                        top: SizeConfig.blockSizeVertical * 10,
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
