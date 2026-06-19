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
    if (userProvider.hasRefusedPrestataireDocument &&
        matchedLocation != AppRoutes.prestataireDocumentsRefused &&
        AppRoutes.isPrestataireRouteRequiringActiveAbonnement(matchedLocation)) {
      return AppRoutes.prestataireDocumentsRefused;
    }
    if (!userProvider.hasAbonnementValide &&
        AppRoutes.isPrestataireRouteRequiringActiveAbonnement(matchedLocation)) {
      return AppRoutes.prestataireAbonnement;
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

String _prestataireShellPath(UserProvider userProvider) {
  final statutVerif =
      userProvider.user!.statutVerification?.toString().toUpperCase() ?? '';
  if (statutVerif == 'NON_VERIFIE' || statutVerif == 'EN_ATTENTE') {
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
