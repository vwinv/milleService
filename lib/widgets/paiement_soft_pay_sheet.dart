import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:url_launcher/url_launcher.dart';

/// Résultat UI aligné sur la doc PayDunya SoftPay (`message`, `url`, `other_url`).
class SoftPayUiResult {
  const SoftPayUiResult({
    required this.message,
    this.primaryUrl,
    this.omAppUrl,
    this.maxitUrl,
    this.returnUrl,
    this.paydunyaCheckoutUrl,
    this.fees,
    this.currency,
  });

  final String message;
  final String? primaryUrl;
  final String? omAppUrl;
  final String? maxitUrl;
  final String? returnUrl;
  final String? paydunyaCheckoutUrl;
  final num? fees;
  final String? currency;

  bool get hasAnyLaunchableUrl =>
      _nonEmpty(primaryUrl) != null ||
      _nonEmpty(omAppUrl) != null ||
      _nonEmpty(maxitUrl) != null ||
      _nonEmpty(paydunyaCheckoutUrl) != null;

  static String? _nonEmpty(String? s) {
    final t = s?.trim();
    return t != null && t.isNotEmpty ? t : null;
  }
}

SoftPayUiResult? softPayUiResultFromApiMap(Map<String, dynamic> map) {
  final sp = map['softPay'];
  if (sp is! Map) return null;
  final m = Map<String, dynamic>.from(sp);
  var msg = m['message']?.toString().trim() ?? '';
  if (msg.isEmpty) {
    msg =
        'Suivez les instructions pour finaliser le paiement dans votre opérateur.';
  }

  String? pu = m['url']?.toString().trim();
  if (pu?.isEmpty ?? true) pu = null;

  String? om;
  String? mx;
  final ou = m['other_url'];
  if (ou is Map) {
    om = ou['om_url']?.toString().trim();
    if (om?.isEmpty ?? true) om = null;
    mx = ou['maxit_url']?.toString().trim();
    if (mx?.isEmpty ?? true) mx = null;
  }

  final ru = m['return_url']?.toString().trim();
  final feesRaw = m['fees'];
  final fees = feesRaw is num ? feesRaw : num.tryParse('$feesRaw');
  final cur = m['currency']?.toString().trim();
  final currency = cur != null && cur.isNotEmpty
      ? cur
      : (fees != null ? 'XOF' : null);

  return SoftPayUiResult(
    message: msg,
    primaryUrl: pu,
    omAppUrl: om,
    maxitUrl: mx,
    returnUrl: ru != null && ru.isNotEmpty ? ru : null,
    paydunyaCheckoutUrl: null,
    fees: fees,
    currency: currency,
  );
}

/// Bottom sheet : coordonnées + choix Wave / OM / Free, puis liens SoftPay.
///
/// [onSoftPay] doit appeler l’API adaptée (prestation ou abonnement) selon le [method].
///
/// Si [verifyBeforeComplete] est défini, le bouton « Terminer » (après SoftPay) n’appelle
/// [Navigator.pop](true) que lorsque ce Future renvoie `true` (ex. abonnement actif en base).
class PaiementSoftPaySheet extends StatefulWidget {
  /// Rayon des coins supérieurs (gauche / droite) — à réutiliser sur [showModalBottomSheet.shape].
  static const BorderRadius topBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
  );

  const PaiementSoftPaySheet({
    super.key,
    required this.invoiceToken,
    required this.checkoutUrlFallback,
    required this.initialPrenom,
    required this.initialNom,
    required this.initialTelephone,
    required this.montantLabel,
    required this.onSoftPay,
    this.email,
    this.verifyBeforeComplete,
  });

  final String invoiceToken;
  final String checkoutUrlFallback;
  final String initialPrenom;
  final String initialNom;
  final String initialTelephone;
  final String montantLabel;
  final String? email;

  /// `method` : `wave_sn` | `orange_money_sn` | `free_money_sn`
  final Future<ResponseData> Function({
    required String method,
    required String prenom,
    required String nom,
    required String telephone,
    String? email,
  }) onSoftPay;

  /// Ex. abonnement : interroger l’API jusqu’à ce qu’un abonnement actif existe.
  final Future<bool> Function()? verifyBeforeComplete;

  @override
  State<PaiementSoftPaySheet> createState() => _PaiementSoftPaySheetState();
}

class _PaiementSoftPaySheetState extends State<PaiementSoftPaySheet> {
  static const Color _payGreen = Color(0xFF3FC823);
  static const Color _waveBlue = Color(0xFF0066FF);
  static const Color _omBlack = Color(0xFF1A1A1A);
  static const Color _freeRed = Color(0xFFE30613);
  static const String _assetWave = 'assets/images/wave.png';
  static const String _assetOm = 'assets/images/om.png';
  static const String _assetFree = 'assets/images/free.png';

  /// Le [context] du [State] est *au-dessus* du contenu du sheet : sans ceci,
  /// [ScaffoldMessenger.maybeOf] renvoie souvent null et aucun message ne s’affiche.
  final GlobalKey<ScaffoldMessengerState> _sheetMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final TextEditingController _prenom;
  late final TextEditingController _nom;
  late final TextEditingController _tel;
  String? _method;
  bool _loading = false;
  bool _verifyingTerminer = false;
  SoftPayUiResult? _softResult;

  @override
  void initState() {
    super.initState();
    _prenom = TextEditingController(text: widget.initialPrenom);
    _nom = TextEditingController(text: widget.initialNom);
    _tel = TextEditingController(text: widget.initialTelephone);
  }

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    _tel.dispose();
    super.dispose();
  }

  String _primarySoftPayButtonLabel() {
    switch (_method) {
      case 'wave_sn':
        return 'Ouvrir Wave';
      case 'orange_money_sn':
        return 'Voir le QR code (navigateur)';
      case 'free_money_sn':
        return 'Ouvrir le lien de paiement';
      default:
        return 'Compléter le paiement';
    }
  }

  Future<void> _openPaymentUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      if (!mounted) return;
      _showSnack('Lien de paiement invalide.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      _showSnack("Impossible d'ouvrir le lien. Réessayez.");
    }
  }

  void _showSnack(String text) {
    final local = _sheetMessengerKey.currentState;
    if (local != null) {
      local.clearSnackBars();
      local.showSnackBar(SnackBar(content: Text(text)));
      return;
    }
    final root = ScaffoldMessenger.maybeOf(context);
    if (root != null) {
      root.clearSnackBars();
      root.showSnackBar(SnackBar(content: Text(text)));
    } else {
      debugPrint('[PaiementSoftPaySheet] $text');
    }
  }

  void _onPaymentMethodSelected(String id) {
    if (_loading || _verifyingTerminer) return;
    setState(() => _method = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || _softResult != null) return;
      final prenom = _prenom.text.trim();
      final nom = _nom.text.trim();
      final tel = _tel.text.trim().replaceAll(RegExp(r'\s+'), '');
      if (prenom.isNotEmpty && nom.isNotEmpty && tel.length >= 8) {
        unawaited(_onPayer());
      }
    });
  }

  double _actionButtonHeight() =>
      math.max(52.0, SizeConfig.blockSizeVertical * 6);

  double _secondaryButtonHeight() =>
      math.max(48.0, SizeConfig.blockSizeVertical * 5.2);

  Widget _payUrlButton({
    required String label,
    required String url,
    required bool filled,
  }) {
    final h = _secondaryButtonHeight();
    if (filled) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: h,
          width: double.infinity,
          child: FilledButton(
            onPressed: () => unawaited(_openPaymentUrl(url)),
            style: FilledButton.styleFrom(
              backgroundColor: _payGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.5,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => unawaited(_openPaymentUrl(url)),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(
                SizeConfig.blockSizeHorizontal * 3.4,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onPayer() async {
    final prenom = _prenom.text.trim();
    final nom = _nom.text.trim();
    final tel = _tel.text.trim().replaceAll(RegExp(r'\s+'), '');
    final method = _method;
    if (prenom.isEmpty || nom.isEmpty) {
      _showSnack('Renseignez le prénom et le nom.');
      return;
    }
    if (tel.length < 8) {
      _showSnack('Numéro de téléphone invalide.');
      return;
    }
    if (method == null) {
      _showSnack('Choisissez un moyen de paiement.');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await widget.onSoftPay(
        method: method,
        prenom: prenom,
        nom: nom,
        telephone: tel,
        email: widget.email,
      );
      if (!mounted) return;

      if (res.success != true || res.data is! Map) {
        _showSnack(
          res.message?.toString().isNotEmpty == true
              ? res.message.toString()
              : 'Paiement refusé. Réessayez.',
        );
        return;
      }

      final map = Map<String, dynamic>.from(res.data as Map);
      var ui = softPayUiResultFromApiMap(map);
      ui ??= const SoftPayUiResult(
        message:
            'Demande enregistrée. Finalisez le paiement depuis votre téléphone.',
      );

      final fb = widget.checkoutUrlFallback.trim();
      final hadSoftPayUrls = ui.hasAnyLaunchableUrl;
      if (!hadSoftPayUrls && fb.isNotEmpty) {
        ui = SoftPayUiResult(
          message: ui.message,
          primaryUrl: ui.primaryUrl,
          omAppUrl: ui.omAppUrl,
          maxitUrl: ui.maxitUrl,
          returnUrl: ui.returnUrl,
          paydunyaCheckoutUrl: fb,
          fees: ui.fees,
          currency: ui.currency,
        );
      }

      if (!mounted) return;
      setState(() => _softResult = ui);
    } catch (e, st) {
      debugPrint('PaiementSoftPaySheet onSoftPay error: $e\n$st');
      if (mounted) {
        _showSnack('Une erreur est survenue. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTerminerTap() async {
    if (_verifyingTerminer) return;
    final verify = widget.verifyBeforeComplete;
    if (verify != null) {
      setState(() => _verifyingTerminer = true);
      try {
        final ok = await verify();
        if (!mounted) return;
        setState(() => _verifyingTerminer = false);
        if (ok) {
          Navigator.of(context).pop(true);
        } else {
          final text = 'abonnement_payment_not_confirmed'.tr();
          final messenger = ScaffoldMessenger.maybeOf(context);
          Navigator.of(context).pop(false);
          messenger?.clearSnackBars();
          messenger?.showSnackBar(SnackBar(content: Text(text)));
        }
      } catch (e, st) {
        debugPrint('PaiementSoftPaySheet verifyBeforeComplete: $e\n$st');
        if (mounted) {
          setState(() => _verifyingTerminer = false);
          final text = 'abonnement_payment_not_confirmed'.tr();
          final messenger = ScaffoldMessenger.maybeOf(context);
          Navigator.of(context).pop(false);
          messenger?.clearSnackBars();
          messenger?.showSnackBar(SnackBar(content: Text(text)));
        }
      }
    } else {
      Navigator.of(context).pop(true);
    }
  }

  InputDecoration _fieldDecoration(String label) {
    final r = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: Utilities().colorBlueDark, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(minHeight: 48),
    );
  }

  Widget _paymentMethodTile({
    required String id,
    required String label,
    required String assetPath,
    required Color brandColor,
  }) {
    final selected = _method == id;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (_loading || _verifyingTerminer)
            ? null
            : () => _onPaymentMethodSelected(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color: brandColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: selected ? 3 : 0,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? brandColor.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.07),
                blurRadius: selected ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  assetPath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.white24,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.payment_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.05,
                  ),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: Colors.white.withValues(alpha: 0.95),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final mq = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom;
    final safeBottom = mq.viewPadding.bottom;
    final result = _softResult;
    return ScaffoldMessenger(
      key: _sheetMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            const Spacer(),
            ClipRRect(
              borderRadius: PaiementSoftPaySheet.topBorderRadius,
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottom),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        10,
                        20,
                        math.max(safeBottom, 12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Paiement',
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 5,
                    ),
                    fontWeight: FontWeight.w800,
                    color: Utilities().colorBlueDark,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDCEBFF)),
                  ),
                  child: Text(
                    widget.montantLabel,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.5,
                      ),
                      color: Utilities().colorBlueDark,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (result == null) ...[
                  const SizedBox(height: 22),
                  TextField(
                    controller: _prenom,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration('Prénom'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nom,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration('Nom'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tel,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldDecoration('Téléphone'),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Moyen de paiement',
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.65,
                      ),
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _paymentMethodTile(
                          id: 'wave_sn',
                          label: 'Wave',
                          assetPath: _assetWave,
                          brandColor: _waveBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _paymentMethodTile(
                          id: 'orange_money_sn',
                          label: 'Orange Money',
                          assetPath: _assetOm,
                          brandColor: _omBlack,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _paymentMethodTile(
                          id: 'free_money_sn',
                          label: 'Free Money',
                          assetPath: _assetFree,
                          brandColor: _freeRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Si prénom, nom et téléphone sont remplis, toucher un moyen lance le paiement. Sinon, complétez puis appuyez sur Payer.',
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 2.85,
                      ),
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: _actionButtonHeight(),
                    child: FilledButton(
                      onPressed: (_loading || _verifyingTerminer) ? null : _onPayer,
                      style: FilledButton.styleFrom(
                        backgroundColor: _payGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Payer',
                              style: TextStyle(
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 3.8,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  Text(
                    'Étape suivante',
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.6,
                      ),
                      fontWeight: FontWeight.w600,
                      color: Utilities().colorBlueDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    result.message,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.35,
                      ),
                      height: 1.35,
                      color: Colors.black87,
                    ),
                  ),
                  if (result.fees != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Frais opérateur estimés : ${result.fees} ${result.currency ?? 'XOF'}',
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.1,
                        ),
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (result.primaryUrl != null &&
                            result.primaryUrl!.isNotEmpty) ...[
                          Expanded(
                            child: SizedBox(
                              height: _actionButtonHeight(),
                              child: FilledButton(
                                onPressed: _verifyingTerminer
                                    ? null
                                    : () => unawaited(
                                          _openPaymentUrl(
                                            result.primaryUrl!,
                                          ),
                                        ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Utilities().colorBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _primarySoftPayButtonLabel(),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: SizeConfig.fontSize(
                                      SizeConfig.blockSizeHorizontal * 3.2,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: SizedBox(
                            height: _actionButtonHeight(),
                            child: FilledButton(
                              onPressed: _verifyingTerminer
                                  ? null
                                  : () => unawaited(_onTerminerTap()),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _verifyingTerminer
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(
                                          width:
                                              SizeConfig.blockSizeHorizontal,
                                        ),
                                        Flexible(
                                          child: Text(
                                            'abonnement_verifying'.tr(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: SizeConfig.fontSize(
                                                SizeConfig.blockSizeHorizontal *
                                                    3.4,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'Terminer',
                                      style: TextStyle(
                                        fontSize: SizeConfig.fontSize(
                                          SizeConfig.blockSizeHorizontal *
                                              3.8,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (result.omAppUrl != null && result.omAppUrl!.isNotEmpty)
                    _payUrlButton(
                      label: 'Ouvrir Orange Money',
                      url: result.omAppUrl!,
                      filled:
                          result.primaryUrl == null ||
                          result.primaryUrl!.isEmpty,
                    ),
                  if (result.maxitUrl != null && result.maxitUrl!.isNotEmpty)
                    _payUrlButton(
                      label: 'Ouvrir Max It',
                      url: result.maxitUrl!,
                      filled:
                          (result.primaryUrl == null ||
                              result.primaryUrl!.isEmpty) &&
                          (result.omAppUrl == null || result.omAppUrl!.isEmpty),
                    ),
                  if (result.paydunyaCheckoutUrl != null &&
                      result.paydunyaCheckoutUrl!.isNotEmpty)
                    _payUrlButton(
                      label: 'Ouvrir la page PayDunya',
                      url: result.paydunyaCheckoutUrl!,
                      filled:
                          result.primaryUrl == null ||
                          result.primaryUrl!.isEmpty,
                    ),
                  if (!result.hasAnyLaunchableUrl)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Si vous n’avez pas de bouton, vérifiez vos SMS ou l’application de votre opérateur pour valider le paiement.',
                        style: TextStyle(
                          fontSize: SizeConfig.fontSize(
                            SizeConfig.blockSizeHorizontal * 3,
                          ),
                          color: Colors.black45,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
            ),
          ),
        ),
      ),
      ),
          ],
        ),
      ),
    );
  }
}
