/// Chemins [go_router] de l’application.
abstract final class AppRoutes {
  static const loading = '/loading';
  static const welcome = '/welcome';
  static const chooseProfile = '/choose-profile';
  static const login = '/login';
  static const loginParticulier = '/login/particulier';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const settings = '/settings';

  static const particulierHome = '/particulier';
  static const particulierSearch = '/particulier/search';

  static String particulierPrestataire(String prestataireId) =>
      '/particulier/prestataires/$prestataireId';

  static String particulierConfirm(String prestataireId) =>
      '/particulier/prestataires/$prestataireId/confirm';

  static String particulierPrestation(String prestationId) =>
      '/particulier/prestations/$prestationId';

  static const prestataireHome = '/prestataire';
  static const prestataireDocuments = '/prestataire/documents';
  static const prestataireValidation = '/prestataire/validation';
  static const prestataireDocumentsRefused = '/prestataire/documents-refused';
  static const prestataireAbonnement = '/prestataire/abonnement';

  static String prestatairePrestation(String prestationId) =>
      '/prestataire/prestations/$prestationId';

  static const prestataireWallet = '/prestataire/wallet';
  static const prestataireConfirmPrestation = '/prestataire/confirm-prestation';

  static const profil = '/profil';
  static const notifications = '/notifications';
  static const editInfos = '/edit-infos';
  static const historique = '/historique';

  static const authPaths = {
    welcome,
    chooseProfile,
    login,
    loginParticulier,
    signup,
    forgotPassword,
  };

  static const guestPaths = {
    loading,
    welcome,
    chooseProfile,
    settings,
    login,
    loginParticulier,
    signup,
    forgotPassword,
    profil,
  };

  static bool isAuthPath(String location) =>
      authPaths.any((p) => location == p || location.startsWith('$p/'));

  static bool isParticulierPath(String location) =>
      location == particulierHome ||
      location.startsWith('$particulierHome/');

  static bool isParticulierConfirmPath(String location) =>
      RegExp(r'^/particulier/prestataires/[^/]+/confirm').hasMatch(location);

  static bool isGuestAccessiblePath(String location) {
    if (guestPaths.any((p) => location == p || location.startsWith('$p/'))) {
      return true;
    }
    return isParticulierPath(location);
  }
}
