import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/providers/prestationsProvider.dart';
import 'package:milleservices/providers/home_content_provider.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/screens/welcome.dart';
import 'package:milleservices/screens/particulier/home_particulier.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/fcm_background_handler.dart';
import 'package:milleservices/services/fcm_debug_log.dart';
import 'package:milleservices/services/navigation.dart';
import 'package:milleservices/services/notificationService.dart';
import 'package:milleservices/services/prestataire_home_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('en')],
      path: 'assets/langues',
      fallbackLocale: const Locale('fr'),
      useOnlyLangCode: true,

      /// Même clé que [SettingsProvider] : au redémarrage / après déconnexion, pas de retour à la langue système.
      startLocale: easyStartLocale,
      saveLocale: false,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => PrestatairesProvider()),
          ChangeNotifierProvider(create: (_) => PrestationsProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  SettingsProvider? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sp = context.read<SettingsProvider>();
    if (!identical(_settings, sp)) {
      _settings?.removeListener(_syncEasyLocaleWithSettings);
      _settings = sp;
      _settings!.addListener(_syncEasyLocaleWithSettings);
      _syncEasyLocaleWithSettings();
    }
  }

  @override
  void dispose() {
    _settings?.removeListener(_syncEasyLocaleWithSettings);
    super.dispose();
  }

  /// Ne pas appeler EasyLocalization depuis le [build] (risque « wrong build scope »).
  void _syncEasyLocaleWithSettings() {
    if (!mounted) return;
    final sp = _settings;
    if (sp == null || !sp.isLoaded) return;
    final desired = sp.locale;
    if (desired == null) return;
    if (!context.mounted || context.locale == desired) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      if (context.locale == desired) return;
      context.setLocale(desired);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return MaterialApp(
          title: 'Mille Services',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          navigatorKey: NavigationService.navigatorKey,
          localizationsDelegates:
              context.localizationDelegates, // ✅ EasyLocalization
          supportedLocales: context.supportedLocales, // ✅ EasyLocalization
          locale: settingsProvider.locale ?? context.locale,
          home: const MyHomePage(title: 'Mille Services'),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _notificationsInitialized = false;
  Future<Map<String, dynamic>?>? _prestataireVerificationFuture;

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Consumer2<UserProvider, SettingsProvider>(
      builder: (context, userProvider, settings, _) {
        if (!userProvider.initialLoadDone || !settings.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (userProvider.isAuthenticated && userProvider.user != null) {
          if (!_notificationsInitialized) {
            _notificationsInitialized = true;
            // Permissions + listeners onMessage + enregistrement token backend
            WidgetsBinding.instance.addPostFrameCallback((_) {
              fcmAppLog(
                'CONFIG',
                'MyHomePage → initializeWithContext (utilisateur connecté)',
              );
              NotificationService().initializeWithContext(context);
            });
          }
          final role = userProvider.user!.role?.toString().toUpperCase() ?? '';
          if (role == 'PARTICULIER') {
            // Particulier : garder le comportement existant (HomeParticulier).
            return ChangeNotifierProvider(
              create: (_) => HomeContentProvider(),
              child: const HomeParticulier(),
            );
          }
          // Prestataire :
          // Avant de décider de l'écran, on récupère toujours
          // le statut de vérification depuis le backend.
          _prestataireVerificationFuture ??= userProvider
              .refreshVerificationStatus();
          return FutureBuilder<Map<String, dynamic>?>(
            future: _prestataireVerificationFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final statutVerif =
                  userProvider.user!.statutVerification
                      ?.toString()
                      .toUpperCase() ??
                  '';

              // - si documents en attente de validation -> écran d'attente
              // - si un document a été refusé -> écran de resoumission
              // - sinon, si aucun abonnement -> HomeAbonnement
              // - sinon, si langue non définie -> Settings
              // - sinon -> HomePrestataire

              return resolvePrestataireHome(
                statutVerificationRaw: statutVerif,
                settings: settings,
                userProvider: userProvider,
              );
            },
          );
        }
        return const Welcome();
      },
    );
  }
}
