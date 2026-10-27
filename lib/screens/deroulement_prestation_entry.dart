import 'dart:async';

import 'package:flutter/material.dart';
import 'package:milleservices/controllers/prestationsController.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/deroulement_prestation.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:provider/provider.dart';

/// Entrée déroulement : utilise [initial] si fourni (go_router `extra`),
/// sinon recharge la prestation via GET `/prestations/:id`.
///
/// Nécessaire car `refreshListenable` (ex. GPS → UserProvider) peut reconstruire
/// la route sans `extra` et affichait « Prestation introuvable ».
class DeroulementPrestationEntry extends StatefulWidget {
  final String prestationId;
  final Prestation? initial;

  const DeroulementPrestationEntry({
    super.key,
    required this.prestationId,
    this.initial,
  });

  @override
  State<DeroulementPrestationEntry> createState() =>
      _DeroulementPrestationEntryState();
}

class _DeroulementPrestationEntryState extends State<DeroulementPrestationEntry> {
  Prestation? _prestation;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prestation = widget.initial;
    if (_prestation == null) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_load());
      });
    }
  }

  @override
  void didUpdateWidget(covariant DeroulementPrestationEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != null &&
        widget.initial!.id == widget.prestationId &&
        (_prestation == null || _prestation!.id != widget.initial!.id)) {
      setState(() {
        _prestation = widget.initial;
        _error = null;
        _loading = false;
      });
      return;
    }
    if (widget.prestationId != oldWidget.prestationId) {
      _prestation = widget.initial;
      _error = null;
      if (_prestation == null) {
        _loading = true;
        unawaited(_load());
      } else {
        _loading = false;
      }
      setState(() {});
    }
  }

  Future<void> _load() async {
    final id = widget.prestationId.trim();
    if (id.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Prestation introuvable.';
      });
      return;
    }

    final token = context.read<UserProvider>().token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Session expirée. Reconnectez-vous.';
      });
      return;
    }

    final res = await PrestationsController.instance.getPrestationById(
      token,
      id,
    );
    if (!mounted) return;

    if (res.success == true && res.data is Map) {
      setState(() {
        _prestation = Prestation.fromJson(
          Map<String, dynamic>.from(res.data as Map),
        );
        _error = null;
        _loading = false;
      });
      return;
    }

    final msg = res.message?.toString().trim();
    setState(() {
      _loading = false;
      _error = (msg != null && msg.isNotEmpty)
          ? msg
          : 'Prestation introuvable.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final prestation = _prestation;
    if (prestation != null) {
      return DeroulementPrestation(
        key: ValueKey('deroulement-${prestation.id}'),
        prestation: prestation,
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: _loading
            ? CircularProgressIndicator(color: Utilities().colorBlueDark)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Prestation introuvable.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        unawaited(_load());
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
