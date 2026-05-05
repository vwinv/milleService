import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/controllers/walletController.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';

class Wallet extends StatefulWidget {
  const Wallet({super.key});

  @override
  State<Wallet> createState() => _WalletState();
}

class _WalletState extends State<Wallet> {
  bool _obscureBalance = true;
  double _balance = 0;
  bool _loadingBalance = true;
  bool _balanceLoadFailed = false;
  bool _isRequestingWithdrawal = false;

  String get _formattedBalance => '${_balance.toStringAsFixed(0)} FCFA';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallet());
  }

  Future<void> _loadWallet() async {
    final userProvider = context.read<UserProvider>();
    var token = userProvider.token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingBalance = false;
          _balanceLoadFailed = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingBalance = true;
        _balanceLoadFailed = false;
      });
    }

    var res = await WalletController.instance.getMyWallet(token: token);
    if (res.status == 401 && mounted) {
      await userProvider.refreshToken();
      token = userProvider.token;
      if (token != null && token.isNotEmpty) {
        res = await WalletController.instance.getMyWallet(token: token);
      }
    }

    if (!mounted) return;

    if (res.success == true && res.data != null) {
      final parsed = WalletController.instance.parseWalletPayload(res.data);
      setState(() {
        _balance = parsed.wallet?.balance ?? 0;
        _loadingBalance = false;
        _balanceLoadFailed = parsed.wallet == null;
      });
    } else {
      setState(() {
        _loadingBalance = false;
        _balanceLoadFailed = true;
      });
    }
  }

  String _withdrawalMethodFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('orange')) return 'ORANGE_MONEY';
    if (n.contains('wave')) return 'WAVE';
    if (n.contains('free')) return 'FREE_MONEY';
    return 'RIB';
  }

  String _methodLabelFr(String method) {
    switch (method) {
      case 'ORANGE_MONEY':
        return 'Orange Money';
      case 'WAVE':
        return 'Wave';
      case 'FREE_MONEY':
        return 'Free Money';
      case 'RIB':
        return 'RIB / virement';
      default:
        return method;
    }
  }

  double? _parseMontant(String raw) {
    if (raw.trim().isEmpty) return null;
    final cleaned = raw
        .replaceAll(RegExp(r'[\s\u00A0]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  Future<double?> _showRetraitMontantDialog({
    required String method,
    required double soldeMax,
  }) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RetraitMontantDialog(
        methodLabel: _methodLabelFr(method),
        soldeMax: soldeMax,
        parseMontant: _parseMontant,
      ),
    );
  }

  Future<void> _onRequestWithdrawal({
    required BuildContext context,
    required String method,
  }) async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'Session expirée. Veuillez vous reconnecter.',
      );
      return;
    }

    if (_loadingBalance) {
      Utilities().showMesage(context, 'infos', 'Chargement du solde…');
      return;
    }

    if (_balance <= 0) {
      Utilities().showMesage(
        context,
        'error',
        'Solde insuffisant pour une demande de retrait.',
      );
      return;
    }

    final montant = await _showRetraitMontantDialog(
      method: method,
      soldeMax: _balance,
    );
    if (!mounted || montant == null) return;

    setState(() => _isRequestingWithdrawal = true);
    var res = await WalletController.instance.requestWithdrawal(
      token: token,
      method: method,
      amount: montant,
    );
    if (res.status == 401 && mounted) {
      await userProvider.refreshToken();
      final newToken = userProvider.token;
      if (newToken != null && newToken.isNotEmpty) {
        res = await WalletController.instance.requestWithdrawal(
          token: newToken,
          method: method,
          amount: montant,
        );
      }
    }
    if (!mounted) return;
    setState(() => _isRequestingWithdrawal = false);

    if (res.success == true) {
      Utilities().showMesage(
        context,
        'success',
        'Votre demande a été prise en compte. Nous vous reviendrons sous un délai de 48h',
      );
      await _loadWallet();
    } else {
      Utilities().showMesage(
        context,
        'error',
        res.message?.toString().trim().isNotEmpty == true
            ? res.message!
            : 'Impossible d\'enregistrer la demande de retrait.',
      );
    }
  }

  List<Map<String, dynamic>> paiementBlocs = [
    {
      'logo': 'om.png',
      'color': Colors.black,
      'borderColor': Colors.black,
      'textColor': Colors.white,
      'name': 'orange money',
    },
    {
      'logo': 'wave.png',
      'color': Color(0xFF1DC8FF),
      'borderColor': Color(0xFF1DC8FF),
      'textColor': Colors.white,
      'name': 'wave',
    },
    {
      'logo': 'free.png',
      'color': Colors.white,
      'borderColor': Colors.red,
      'textColor': Colors.red,
      'name': 'free money',
    },
  ];

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'presta_wallet'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 5),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadingBalance ? null : _loadWallet,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                  vertical: SizeConfig.blockSizeVertical * 2,
                ),
                child: Container(
                  height: SizeConfig.blockSizeVertical * 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Utilities().colorBlueDark, Utilities().colorBlue],
                    ),
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 5,
                    ),
                  ),
                  child: Center(
                    child: _loadingBalance
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Solde disponible',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.5,
                                  ),
                                ),
                              ),
                              SizedBox(height: SizeConfig.blockSizeVertical * 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: SizeConfig.blockSizeHorizontal * 2,
                                children: [
                                  Text(
                                    _balanceLoadFailed
                                        ? '—'
                                        : (_obscureBalance
                                              ? '**************'
                                              : _formattedBalance),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: SizeConfig.fontSize(
                                        SizeConfig.blockSizeHorizontal * 7,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!_balanceLoadFailed)
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscureBalance = !_obscureBalance;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureBalance
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.white,
                                        size:
                                            SizeConfig.blockSizeHorizontal * 6,
                                      ),
                                    ),
                                ],
                              ),
                              if (_balanceLoadFailed)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: SizeConfig.blockSizeVertical * 1,
                                  ),
                                  child: TextButton(
                                    onPressed: _loadWallet,
                                    child: const Text(
                                      'Réessayer',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                  vertical: SizeConfig.blockSizeVertical * 2,
                ),
                child: Wrap(
                  spacing: SizeConfig.blockSizeHorizontal * 2,
                  runSpacing: SizeConfig.blockSizeVertical * 2,
                  children: paiementBlocs
                      .map(
                        (paiementBloc) => InkWell(
                          onTap: _isRequestingWithdrawal || _loadingBalance
                              ? null
                              : () => _onRequestWithdrawal(
                                  context: context,
                                  method: _withdrawalMethodFromName(
                                    paiementBloc['name'].toString(),
                                  ),
                                ),
                          borderRadius: BorderRadius.circular(
                            SizeConfig.blockSizeHorizontal * 5,
                          ),
                          child: Container(
                            width: SizeConfig.blockSizeHorizontal * 28,
                            height: SizeConfig.blockSizeVertical * 22,
                            padding: EdgeInsets.symmetric(
                              horizontal: SizeConfig.blockSizeHorizontal * 2,
                              vertical: SizeConfig.blockSizeVertical * 2,
                            ),
                            decoration: BoxDecoration(
                              color: paiementBloc['color'],
                              borderRadius: BorderRadius.circular(
                                SizeConfig.blockSizeHorizontal * 5,
                              ),
                              border: Border.all(
                                color: paiementBloc['borderColor'],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/${paiementBloc['logo']}',
                                  width: SizeConfig.blockSizeHorizontal * 15,
                                  height: SizeConfig.blockSizeVertical * 7,
                                  fit: BoxFit.cover,
                                ),
                                Text(
                                  "Demande un retrait avec ${paiementBloc['name']}",
                                  style: TextStyle(
                                    color: paiementBloc['textColor'],
                                    fontSize: SizeConfig.fontSize(
                                      SizeConfig.blockSizeHorizontal * 3.5,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                  vertical: SizeConfig.blockSizeVertical * 2,
                ),
                child: InkWell(
                  onTap: _isRequestingWithdrawal || _loadingBalance
                      ? null
                      : () => _onRequestWithdrawal(context: context, method: 'RIB'),
                  borderRadius: BorderRadius.circular(
                    SizeConfig.blockSizeHorizontal * 5,
                  ),
                  child: Container(
                    height: SizeConfig.blockSizeVertical * 7,
                    padding: EdgeInsets.symmetric(
                      horizontal: SizeConfig.blockSizeHorizontal * 5,
                      vertical: SizeConfig.blockSizeVertical * 2,
                    ),
                    decoration: BoxDecoration(
                      color: Utilities().colorBlueDark,
                      borderRadius: BorderRadius.circular(
                        SizeConfig.blockSizeHorizontal * 5,
                      ),
                    ),
                    child: Row(
                      spacing: SizeConfig.blockSizeHorizontal * 2,
                      children: [
                        Icon(
                          Icons.credit_card,
                          color: Colors.white,
                          size: SizeConfig.blockSizeHorizontal * 6,
                        ),
                        Text(
                          "Demande un retrait avec un RIB",
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _ParseMontant = double? Function(String raw);

class _RetraitMontantDialog extends StatefulWidget {
  const _RetraitMontantDialog({
    required this.methodLabel,
    required this.soldeMax,
    required this.parseMontant,
  });

  final String methodLabel;
  final double soldeMax;
  final _ParseMontant parseMontant;

  @override
  State<_RetraitMontantDialog> createState() => _RetraitMontantDialogState();
}

class _RetraitMontantDialogState extends State<_RetraitMontantDialog> {
  late final TextEditingController _controller;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxStr = widget.soldeMax.toStringAsFixed(0);
    return AlertDialog(
      title: Text('Retrait — ${widget.methodLabel}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Solde disponible : $maxStr FCFA',
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.2,
                ),
                color: Colors.black54,
              ),
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
            TextFormField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Montant à retirer',
                suffixText: 'FCFA',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                constraints: BoxConstraints(minHeight: 48),
              ),
              validator: (value) {
                final n = widget.parseMontant(value ?? '');
                if (n == null || n <= 0) {
                  return 'Saisissez un montant valide.';
                }
                if (n > widget.soldeMax) {
                  return 'Le montant ne peut pas dépasser votre solde ($maxStr FCFA).';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            final n = widget.parseMontant(_controller.text);
            if (n == null || n <= 0 || n > widget.soldeMax) return;
            Navigator.of(context).pop(n);
          },
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}
