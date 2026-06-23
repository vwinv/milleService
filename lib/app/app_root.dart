import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/providers/auth_resume_provider.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/router/app_router.dart';
import 'package:milleservices/services/app_bootstrap.dart';
import 'package:milleservices/services/fcm_debug_log.dart';
import 'package:milleservices/services/notificationService.dart';
import 'package:milleservices/widgets/keyboard_dismiss.dart';
import 'package:provider/provider.dart';

/// Racine UI : [MaterialApp.router] + initialisation FCM une fois connecté.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  GoRouter? _router;
  bool _fcmInitialized = false;
  final AppBootstrapNotifier _appBootstrap = AppBootstrapNotifier();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.read<UserProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final authResumeProvider = context.read<AuthResumeProvider>();
    _router ??= createAppRouter(
      refreshListenable: Listenable.merge([
        userProvider,
        settingsProvider,
        authResumeProvider,
        _appBootstrap,
      ]),
      userProvider: userProvider,
      settingsProvider: settingsProvider,
      authResumeProvider: authResumeProvider,
      appBootstrap: _appBootstrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final userProvider = context.watch<UserProvider>();
    final router = _router!;

    if (userProvider.isAuthenticated &&
        userProvider.user != null &&
        !_fcmInitialized) {
      _fcmInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        fcmAppLog(
          'CONFIG',
          'AppRoot → initializeWithContext (utilisateur connecté)',
        );
        NotificationService().initializeWithContext(context);
      });
    }
    if (!userProvider.isAuthenticated && _fcmInitialized) {
      _fcmInitialized = false;
    }

    return MaterialApp.router(
      title: 'Mille Services',
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: settingsProvider.locale ?? context.locale,
      builder: (context, child) => KeyboardDismissOnTap(
        child: WithForegroundTask(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
