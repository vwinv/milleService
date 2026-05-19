import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/home_content_provider.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/router/app_redirect.dart';
import 'package:milleservices/router/app_routes.dart';
import 'package:milleservices/router/route_extras.dart';
import 'package:provider/provider.dart';

/// API de navigation métier (go_router).
abstract final class AppNavigation {
  static void goWelcome(BuildContext context) {
    context.go(AppRoutes.welcome);
  }

  static void goLogin(BuildContext context) => context.go(AppRoutes.login);

  static void goSignUp(BuildContext context) => context.go(AppRoutes.signup);

  static void goHome(BuildContext context) {
    final user = context.read<UserProvider>();
    final settings = context.read<SettingsProvider>();
    context.go(homePathForUser(userProvider: user, settingsProvider: settings));
  }

  /// Accueil particulier (carte + favoris).
  static void goParticulierHome(BuildContext context) {
    try {
      context.read<HomeContentProvider>().goToFavoris();
    } catch (_) {}
    context.go(AppRoutes.particulierHome);
  }

  static Future<T?> pushParticulierSearch<T>(BuildContext context) {
    return context.push<T>(AppRoutes.particulierSearch);
  }

  static Future<T?> pushPrestataireDetails<T>(
    BuildContext context,
    Prestataire prestataire,
  ) {
    return context.push<T>(
      AppRoutes.particulierPrestataire(prestataire.id),
      extra: prestataire,
    );
  }

  static Future<T?> pushConfirmPrestation<T>(
    BuildContext context,
    ConfirmPrestationExtra extra,
  ) {
    return context.push<T>(
      AppRoutes.particulierConfirm(extra.prestataire.id),
      extra: extra,
    );
  }

  static void goParticulierPrestation(
    BuildContext context,
    Prestation prestation,
  ) {
    context.go(
      AppRoutes.particulierPrestation(prestation.id),
      extra: prestation,
    );
  }

  static Future<T?> pushParticulierPrestation<T>(
    BuildContext context,
    Prestation prestation,
  ) {
    return context.push<T>(
      AppRoutes.particulierPrestation(prestation.id),
      extra: prestation,
    );
  }

  static void goPrestatairePrestation(
    BuildContext context,
    Prestation prestation,
  ) {
    context.go(
      AppRoutes.prestatairePrestation(prestation.id),
      extra: prestation,
    );
  }

  static Future<T?> pushPrestatairePrestation<T>(
    BuildContext context,
    Prestation prestation,
  ) {
    return context.push<T>(
      AppRoutes.prestatairePrestation(prestation.id),
      extra: prestation,
    );
  }

  static Future<T?> pushPrestataireConfirmPrestation<T>(
    BuildContext context,
    Prestation prestation,
  ) {
    return context.push<T>(
      AppRoutes.prestataireConfirmPrestation,
      extra: PrestataireConfirmPrestationExtra(prestation: prestation),
    );
  }

  static Future<T?> pushHistorique<T>(
    BuildContext context,
    List<Prestation> prestations,
  ) {
    return context.push<T>(
      AppRoutes.historique,
      extra: HistoriqueExtra(prestations: prestations),
    );
  }

  static Future<T?> pushProfil<T>(BuildContext context) =>
      context.push<T>(AppRoutes.profil);

  static Future<T?> pushNotifications<T>(BuildContext context) =>
      context.push<T>(AppRoutes.notifications);

  static Future<T?> pushEditInfos<T>(BuildContext context) =>
      context.push<T>(AppRoutes.editInfos);

  static Future<T?> pushWallet<T>(BuildContext context) =>
      context.push<T>(AppRoutes.prestataireWallet);

  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    if (context.canPop()) {
      context.pop(result);
    } else {
      goHome(context);
    }
  }
}
