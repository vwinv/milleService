import 'package:flutter/material.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/particulier/home_particulier.dart';
import 'package:milleservices/screens/prestataire/home_abonnement.dart';
import 'package:milleservices/screens/prestataire/home_prestataire.dart';
import 'package:milleservices/screens/prestataire/prestataire_upload_documents.dart';
import 'package:milleservices/screens/prestataire/prestataire_validate_profil.dart';
import 'package:milleservices/screens/settings.dart';

/// Affiche un chargement puis l’écran d’accueil approprié.
///
/// Pour un prestataire, [UserProvider.refreshVerificationStatus] est attendu
/// **avant** de choisir l’écran (documents / validation / abonnement / home).
/// Sinon, juste après l’inscription, la liste des documents est encore vide
/// et l’app renvoie à tort vers [PrestataireUploadDocuments].
Widget resolveHome({
  required SettingsProvider settings,
  required UserProvider userProvider,
}) {
  return _ResolvedHomeGate(settings: settings, userProvider: userProvider);
}

class _ResolvedHomeGate extends StatefulWidget {
  const _ResolvedHomeGate({required this.settings, required this.userProvider});

  final SettingsProvider settings;
  final UserProvider userProvider;

  @override
  State<_ResolvedHomeGate> createState() => _ResolvedHomeGateState();
}

class _ResolvedHomeGateState extends State<_ResolvedHomeGate> {
  Widget? _home;

  @override
  void initState() {
    super.initState();
    final role = widget.userProvider.user?.role.toLowerCase() ?? '';
    if (role == 'prestataire') {
      _preparePrestataire();
    } else {
      _home = _resolveHomeSync(
        settings: widget.settings,
        userProvider: widget.userProvider,
      );
    }
  }

  Future<void> _preparePrestataire() async {
    await widget.userProvider.refreshVerificationStatus();
    if (!mounted) return;
    setState(() {
      _home = _resolveHomeSync(
        settings: widget.settings,
        userProvider: widget.userProvider,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_home == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _home!;
  }
}

/// Résout l’écran d’accueil à partir de l’état déjà à jour du provider
/// (appeler après [UserProvider.refreshVerificationStatus] pour les prestataires).
Widget _resolveHomeSync({
  required SettingsProvider settings,
  required UserProvider userProvider,
}) {
  final statutVerif =
      userProvider.user!.statutVerification?.toString().toUpperCase() ?? '';
  if (userProvider.user?.role.toLowerCase() == 'prestataire') {
    if (statutVerif == 'NON_VERIFIE' || statutVerif == 'EN_ATTENTE') {
      if (userProvider.prestataireDocuments.isEmpty) {
        return const PrestataireUploadDocuments();
      }
      return const PrestataireValidateProfil();
    }
    if (statutVerif == 'REFUSE') {
      return const PrestataireDocumentsRefuses();
    }
    if (userProvider.abonnement == null) {
      return const HomeAbonnement();
    }
    if (settings.locale == null) {
      return const Settings();
    }

    return const HomePrestataire();
  } else {
    if (settings.locale == null) {
      return const Settings();
    }
    return const HomeParticulier();
  }
}
