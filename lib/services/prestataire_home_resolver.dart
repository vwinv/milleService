import 'package:flutter/material.dart';
import 'package:milleservices/providers/home_content_provider.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/screens/particulier/home_particulier.dart';
import 'package:milleservices/screens/prestataire/home_abonnement.dart';
import 'package:milleservices/screens/prestataire/home_prestataire.dart';
import 'package:milleservices/screens/prestataire/prestataire_upload_documents.dart';
import 'package:milleservices/screens/prestataire/prestataire_validate_profil.dart';
import 'package:milleservices/screens/settings.dart';

/// Résout l'écran d'accueil prestataire en fonction de son statut.
Widget resolvePrestataireHome({
  required String statutVerificationRaw,
  required SettingsProvider settings,
  required UserProvider userProvider,
}) {
  final statutVerif = statutVerificationRaw.toUpperCase();
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
    return ChangeNotifierProvider(
      create: (_) => HomeContentProvider(),
      child: const HomeParticulier(),
    );
  }
}
