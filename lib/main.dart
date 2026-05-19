import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/providers/prestationsProvider.dart';
import 'package:milleservices/providers/home_content_provider.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/app/app_root.dart';
import 'package:milleservices/services/fcm_background_handler.dart';
import 'package:milleservices/services/fcm_debug_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(() {
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintPointersEnabled = false;
    debugPaintLayerBordersEnabled = false;
    return true;
  }());
  FlutterForegroundTask.initCommunicationPort();
  await EasyLocalization.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedCode = prefs.getString(kAppSelectedLocalePrefKey);
  final Locale? easyStartLocale = (savedCode != null && savedCode.isNotEmpty)
      ? Locale(savedCode)
      : null;

  try {
    await Firebase.initializeApp();
    fcmAppLog('CONFIG', 'main() Firebase.initializeApp OK');
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
    fcmAppLog(
      'CONFIG',
      'main() onBackgroundMessage enregistré (requis avant runApp)',
    );
  } catch (e, st) {
    fcmAppLog('CONFIG', 'main() Firebase ERREUR: $e');
    debugPrintStack(stackTrace: st);
  }

  runApp(
    buildMilleServicesApp(
      child: const AppRoot(),
      startLocale: easyStartLocale,
    ),
  );
}

/// Arbre racine (providers + localisation). Réutilisé par les tests widget.
Widget buildMilleServicesApp({
  required Widget child,
  Locale? startLocale,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('fr'), Locale('en')],
    path: 'assets/langues',
    fallbackLocale: const Locale('fr'),
    useOnlyLangCode: true,
    startLocale: startLocale,
    saveLocale: false,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => PrestatairesProvider()),
        ChangeNotifierProvider(create: (_) => PrestationsProvider()),
        ChangeNotifierProvider(create: (_) => HomeContentProvider()),
      ],
      child: child,
    ),
  );
}
