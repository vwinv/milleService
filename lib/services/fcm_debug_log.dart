import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

/// Diagnostic push : filtre la console / logcat sur **`[FCM app]`**.
///
/// - **RÉCEPTION** : le message a bien atteint Firebase Messaging sur l’app.
/// - **AFFICHAGE** : tentative d’afficher le bandeau in-app (ou raison du skip).
/// - **CONFIG** : init, token, enregistrement backend.
void fcmAppLog(String category, String message) {
  final line = '[FCM app] $category — $message';
  dev.log(line, name: 'MilleServices.FCM');
  debugPrint(line);
  // Toujours afficher dans logcat Android sous I/flutter (les filtres IDE masquent souvent dev.log).
  print(line);
}
