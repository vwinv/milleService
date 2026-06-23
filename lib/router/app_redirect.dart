import 'package:milleservices/providers/auth_resume_provider.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/router/app_routes.dart';
import 'package:milleservices/services/app_bootstrap.dart';

/// Redirect central (auth, langue, onboarding prestataire).
String? resolveAppRedirect({
  required UserProvider userProvider,
  required SettingsProvider settingsProvider,
  required AuthResumeProvider authResumeProvider,
  required AppBootstrapNotifier appBootstrap,
  required String matchedLocation,
}) {
  if (!userProvider.initialLoadDone ||
      !settingsProvider.isLoaded ||
      !appBootstrap.minSplashElapsed) {
    return matchedLocation == AppRoutes.loading ? null : AppRoutes.loading;
  }

  // Ne jamais rester bloquée sur le splash une fois l'app prête.
  if (matchedLocation == AppRoutes.loading) {
    return _postBootstrapHome(
      userProvider: userProvider,
      settingsProvider: settingsProvider,
    );
  }

  final authenticated =
      userProvider.isAuthenticated && userProvider.user != null;

  if (!authenticated) {
    if (settingsProvider.locale == null &&
        matchedLocation != AppRoutes.settings) {
      if (AppRoutes.isGuestAccessiblePath(matchedLocation) &&
          matchedLocation != AppRoutes.loading) {
        return null;
      }
      return AppRoutes.welcome;
    }
    if (AppRoutes.isGuestAccessiblePath(matchedLocation) &&
        matchedLocation != AppRoutes.loading) {
      return null;
    }
    return AppRoutes.welcome;
  }

  if (settingsProvider.locale == null &&
      matchedLocation != AppRoutes.settings) {
    if (AppRoutes.isParticulierConfirmPath(matchedLocation)) {
      return null;
    }
    return AppRoutes.settings;
  }

  final role = userProvider.user!.role?.toString().toUpperCase() ?? '';

  if (role == 'PRESTATAIRE') {
    if (userProvider.isPrestataireActif) {
      final shell = _prestataireActifShellPath(userProvider);
      if (!userProvider.hasAbonnementValide) {
        if (matchedLocation == AppRoutes.prestataireAbonnement) return null;
        if (matchedLocation == AppRoutes.settings) return null;
        return AppRoutes.prestataireAbonnement;
      }
      if (_isPrestataireDeepRoute(matchedLocation)) return null;
      if (matchedLocation == AppRoutes.settings) return null;
      if (matchedLocation == AppRoutes.prestataireAbonnement) {
        return AppRoutes.prestataireHome;
      }
      if (matchedLocation != shell) {
        return shell;
      }
      return null;
    }

    final target = _prestataireShellPath(userProvider);
    if (_shouldReplacePrestataireLocation(matchedLocation, target)) {
      return target;
    }
    if (matchedLocation.startsWith('/particulier')) {
      return target;
    }
    if (AppRoutes.isAuthPath(matchedLocation) ||
        matchedLocation == AppRoutes.loading) {
      return target;
    }
    return null;
  }

  if (role == 'PARTICULIER') {
    if (matchedLocation.startsWith('/prestataire')) {
      return AppRoutes.particulierHome;
    }
    if (AppRoutes.isAuthPath(matchedLocation) ||
        matchedLocation == AppRoutes.loading) {
      if (authResumeProvider.hasIntent) {
        return null;
      }
      return AppRoutes.particulierHome;
    }
    return null;
  }

  return AppRoutes.welcome;
}

String homePathForUser({
  required UserProvider userProvider,
  required SettingsProvider settingsProvider,
}) {
  if (!userProvider.isAuthenticated || userProvider.user == null) {
    return AppRoutes.welcome;
  }
  if (settingsProvider.locale == null) {
    return AppRoutes.settings;
  }
  final role = userProvider.user!.role?.toString().toUpperCase() ?? '';
  if (role == 'PRESTATAIRE') {
    return _prestataireShellPath(userProvider);
  }
  if (role == 'PARTICULIER') {
    return AppRoutes.particulierHome;
  }
  return AppRoutes.welcome;
}

/// Prestataire activé en base (`prestataires.actif = true`).
bool isPrestatairePastDocumentValidation(UserProvider userProvider) {
  return userProvider.isPrestataireActif;
}

bool _isPrestataireDeepRoute(String location) {
  if (location == AppRoutes.prestataireCompleteDocuments) return true;
  if (location == AppRoutes.prestataireWallet) return true;
  if (location == AppRoutes.prestataireConfirmPrestation) return true;
  if (location == AppRoutes.profil) return true;
  if (location == AppRoutes.notifications) return true;
  if (location == AppRoutes.editInfos) return true;
  if (location == AppRoutes.historique) return true;
  if (location.startsWith('/prestataire/prestations/')) return true;
  return false;
}

String _prestataireActifShellPath(UserProvider userProvider) {
  if (!userProvider.hasAbonnementValide) {
    return AppRoutes.prestataireAbonnement;
  }
  return AppRoutes.prestataireHome;
}

String _prestataireShellPath(UserProvider userProvider) {
  if (userProvider.isPrestataireActif) {
    return _prestataireActifShellPath(userProvider);
  }

  // actif=false → parcours onboarding documents (inchangé).
  final statutVerif =
      userProvider.user!.statutVerification?.toString().toUpperCase() ?? '';
  if (statutVerif == 'NON_VERIFIE') {
    if (!userProvider.hasAllRequiredPrestataireDocuments) {
      return AppRoutes.prestataireDocuments;
    }
    return AppRoutes.prestataireValidation;
  }
  if (statutVerif == 'EN_ATTENTE') {
    if (!userProvider.hasAllRequiredPrestataireDocuments) {
      return AppRoutes.prestataireDocuments;
    }
    return AppRoutes.prestataireValidation;
  }
  if (statutVerif == 'REFUSE' || userProvider.hasRefusedPrestataireDocument) {
    return AppRoutes.prestataireDocumentsRefused;
  }
  if (!userProvider.hasAbonnementValide) {
    return AppRoutes.prestataireAbonnement;
  }
  return AppRoutes.prestataireHome;
}

bool _shouldReplacePrestataireLocation(String current, String target) {
  if (current == target) return false;
  const onboarding = {
    AppRoutes.prestataireDocuments,
    AppRoutes.prestataireValidation,
    AppRoutes.prestataireDocumentsRefused,
    AppRoutes.prestataireAbonnement,
    AppRoutes.prestataireHome,
  };
  if (!onboarding.contains(current)) return false;
  return current != target;
}

String? _postBootstrapHome({
  required UserProvider userProvider,
  required SettingsProvider settingsProvider,
}) {
  final authenticated =
      userProvider.isAuthenticated && userProvider.user != null;
  if (!authenticated) {
    if (settingsProvider.locale == null) {
      return AppRoutes.welcome;
    }
    return AppRoutes.welcome;
  }
  if (settingsProvider.locale == null) {
    return AppRoutes.settings;
  }
  return homePathForUser(
    userProvider: userProvider,
    settingsProvider: settingsProvider,
  );
}
