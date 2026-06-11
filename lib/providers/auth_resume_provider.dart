import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/router/app_routes.dart';
import 'package:milleservices/router/route_extras.dart';

/// Mémorise où envoyer l'utilisateur après connexion / inscription (parcours interrompu).
class AuthResumeProvider extends ChangeNotifier {
  ConfirmPrestationExtra? _confirmPrestation;

  bool get hasIntent => _confirmPrestation != null;

  void setConfirmPrestation(ConfirmPrestationExtra extra) {
    _confirmPrestation = extra;
    notifyListeners();
  }

  void clear() {
    if (_confirmPrestation == null) return;
    _confirmPrestation = null;
    notifyListeners();
  }

  /// Reprend le parcours en attente ou retourne false si aucun.
  bool navigateAfterAuth(BuildContext context) {
    final extra = _confirmPrestation;
    if (extra == null) return false;
    _confirmPrestation = null;
    notifyListeners();
    context.go(
      AppRoutes.particulierConfirm(extra.prestataire.id),
      extra: extra,
    );
    return true;
  }
}
