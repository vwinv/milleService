import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/router/app_redirect.dart';
import 'package:milleservices/router/app_routes.dart';
import 'package:milleservices/router/route_extras.dart';
import 'package:milleservices/screens/authentification/forgot_password.dart';
import 'package:milleservices/screens/authentification/login.dart';
import 'package:milleservices/screens/authentification/signup.dart';
import 'package:milleservices/screens/deroulement_prestation.dart';
import 'package:milleservices/screens/edit_infos.dart';
import 'package:milleservices/screens/historique.dart';
import 'package:milleservices/screens/notification_list.dart';
import 'package:milleservices/screens/particulier/confirm_prestation.dart';
import 'package:milleservices/screens/particulier/details_prestataire.dart';
import 'package:milleservices/screens/particulier/home_particulier.dart';
import 'package:milleservices/screens/particulier/list_prestataire.dart';
import 'package:milleservices/screens/particulier/profil_particulier.dart';
import 'package:milleservices/screens/prestataire/home_abonnement.dart';
import 'package:milleservices/screens/prestataire/home_prestataire.dart';
import 'package:milleservices/screens/prestataire/prestataire_confirm_prestation.dart';
import 'package:milleservices/screens/prestataire/prestataire_upload_documents.dart';
import 'package:milleservices/screens/prestataire/prestataire_validate_profil.dart';
import 'package:milleservices/screens/prestataire/wallet.dart';
import 'package:milleservices/screens/settings.dart';
import 'package:milleservices/screens/welcome.dart';
import 'package:milleservices/services/navigation.dart';

/// Référence globale au routeur (notifs FCM, etc.).
abstract final class AppRouterHolder {
  static GoRouter? instance;
}

GoRouter createAppRouter({
  required UserProvider userProvider,
  required SettingsProvider settingsProvider,
}) {
  final router = GoRouter(
    navigatorKey: NavigationService.navigatorKey,
    initialLocation: AppRoutes.loading,
    refreshListenable: Listenable.merge([userProvider, settingsProvider]),
    redirect: (context, state) => resolveAppRedirect(
      userProvider: userProvider,
      settingsProvider: settingsProvider,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (_, __) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, __) => const Welcome(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => Login(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) => SignUp(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const Settings(),
      ),
      GoRoute(
        path: AppRoutes.particulierHome,
        builder: (_, __) => const HomeParticulier(),
      ),
      GoRoute(
        path: AppRoutes.particulierSearch,
        builder: (_, __) => ListPrestataire(),
      ),
      GoRoute(
        path: '/particulier/prestataires/:id',
        builder: (context, state) {
          final prestataire = state.extra as Prestataire?;
          if (prestataire == null) {
            return const _RouteErrorScreen(
              message: 'Prestataire introuvable (navigation).',
            );
          }
          return DetailsPrestataire(prestataire: prestataire);
        },
      ),
      GoRoute(
        path: '/particulier/prestataires/:id/confirm',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ConfirmPrestationExtra) {
            return ConfirmPrestation(
              prestataire: extra.prestataire,
              prestataireServiceId: extra.prestataireServiceId,
              serviceLibelle: extra.serviceLibelle,
              adresseParticulier: extra.adresseParticulier,
            );
          }
          return const _RouteErrorScreen(
            message: 'Données de confirmation manquantes.',
          );
        },
      ),
      GoRoute(
        path: '/particulier/prestations/:id',
        builder: (context, state) {
          final prestation = state.extra as Prestation?;
          if (prestation == null) {
            return const _RouteErrorScreen(
              message: 'Prestation introuvable (navigation).',
            );
          }
          return DeroulementPrestation(prestation: prestation);
        },
      ),
      GoRoute(
        path: AppRoutes.prestataireHome,
        builder: (_, __) => const HomePrestataire(),
      ),
      GoRoute(
        path: AppRoutes.prestataireDocuments,
        builder: (_, __) => const PrestataireUploadDocuments(),
      ),
      GoRoute(
        path: AppRoutes.prestataireValidation,
        builder: (_, __) => const PrestataireValidateProfil(),
      ),
      GoRoute(
        path: AppRoutes.prestataireDocumentsRefused,
        builder: (_, __) => const PrestataireDocumentsRefuses(),
      ),
      GoRoute(
        path: AppRoutes.prestataireAbonnement,
        builder: (_, __) => const HomeAbonnement(),
      ),
      GoRoute(
        path: '/prestataire/prestations/:id',
        builder: (context, state) {
          final prestation = state.extra as Prestation?;
          if (prestation == null) {
            return const _RouteErrorScreen(
              message: 'Prestation introuvable (navigation).',
            );
          }
          return DeroulementPrestation(prestation: prestation);
        },
      ),
      GoRoute(
        path: AppRoutes.prestataireConfirmPrestation,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is PrestataireConfirmPrestationExtra) {
            return PrestataireConfirmPrestation(
              prestation: extra.prestation,
            );
          }
          return const _RouteErrorScreen(
            message: 'Prestation introuvable (navigation).',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.prestataireWallet,
        builder: (_, __) => Wallet(),
      ),
      GoRoute(
        path: AppRoutes.profil,
        builder: (_, __) => ProfilParticulier(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationListScreen(),
      ),
      GoRoute(
        path: AppRoutes.editInfos,
        builder: (_, __) => const EditInfos(),
      ),
      GoRoute(
        path: AppRoutes.historique,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is HistoriqueExtra) {
            return Historique(prestations: extra.prestations);
          }
          return const Historique(prestations: []);
        },
      ),
    ],
  );
  AppRouterHolder.instance = router;
  return router;
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(message)),
    );
  }
}
