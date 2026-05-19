import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/controllers/notificationController.dart';
import 'package:milleservices/controllers/prestationsController.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/services/fcm_debug_log.dart';
import 'package:milleservices/services/push_local_notifications.dart';
import 'package:milleservices/services/navigation.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class NotificationService {
  // Toggle global pour activer/désactiver Firebase Messaging.
  // Tant que la configuration Firebase iOS n'est pas en place,
  // laisser cette valeur à false pour éviter les crashes.
  static const bool _firebaseEnabled = true;
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static const String _notificationKey = 'notifications_enabled';
  static const String _fcmTokenKey = 'fcm_token';
  static final NotificationController notificationController =
      NotificationController();

  // StreamSubscription pour le listener de renouvellement du token
  static StreamSubscription<String>? _tokenRefreshSubscription;

  /// Évite les double abonnements à onMessage / onMessageOpenedApp.
  static bool _messageHandlersAttached = false;

  /// Titre affichable : bloc `notification` FCM puis repli sur `data` (souvent nécessaire sur Android).
  static String titleFromRemoteMessage(RemoteMessage message) {
    final fromBlock = message.notification?.title?.trim();
    if (fromBlock != null && fromBlock.isNotEmpty) return fromBlock;
    final fromData = message.data['title']?.toString().trim();
    if (fromData != null && fromData.isNotEmpty) return fromData;
    return 'Notification';
  }

  /// Corps affichable : même logique que [titleFromRemoteMessage].
  static String bodyFromRemoteMessage(RemoteMessage message) {
    final fromBlock = message.notification?.body?.trim();
    if (fromBlock != null && fromBlock.isNotEmpty) return fromBlock;
    final fromData = message.data['body']?.toString().trim();
    if (fromData != null && fromData.isNotEmpty) return fromData;
    return '';
  }

  /// Initialise: permissions + handlers + enregistrement device
  Future<void> initializeWithContext(BuildContext context) async {
    if (!_firebaseEnabled) {
      print(
        '🔔 NotificationService: Firebase désactivé (configuration manquante), aucune initialisation.',
      );
      return;
    }
    fcmAppLog('CONFIG', 'initializeWithContext() démarré');
    print('🔔 ========== NOTIFICATION SERVICE INIT ==========');
    print('🔔 NotificationService: Début initialisation');

    // S'assurer que Firebase est initialisé avant toute utilisation de FirebaseMessaging.
    try {
      await Firebase.initializeApp();
      print('🔔 Firebase.initializeApp() appelé avec succès');
    } catch (e) {
      print('🔔 Firebase.initializeApp() déjà initialisé ou erreur bénigne: $e');
    }

    try {
      await initPushLocalNotifications();
      fcmAppLog('CONFIG', 'initPushLocalNotifications OK');
    } catch (e) {
      fcmAppLog('CONFIG', 'initPushLocalNotifications erreur: $e');
    }

    try {
      // Toujours configurer les handlers pour capter les messages/data même si permission refusée
      print('🔔 Configuration des handlers...');
      _setupMessageHandlers();

      print('🔔 Configuration des options de notification foreground...');
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      print(
        '🔔 Options foreground configurées: alert=true, badge=true, sound=true',
      );

      print('🔔 Vérification des permissions...');
      final ok = await ensurePermissionGranted();
      print('🔔 Permissions accordées: ${ok ? "✅ OUI" : "❌ NON"}');

      if (ok) {
        print('🔔 Tentative d\'enregistrement du device...');
        await _registerCurrentDevice(context);
      } else {
        print('🔔 ⚠️ Permission non accordée, enregistrement device ignoré');
      }

      // Si l'app a été ouverte via une notification (état terminé)
      print('🔔 Vérification des messages initiaux...');
      try {
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          fcmAppLog(
            'RÉCEPTION',
            'cold-start (getInitialMessage) messageId=${initialMessage.messageId} title=${initialMessage.notification?.title ?? "(pas de bloc notification)"}',
          );
          _handleNotificationTap(initialMessage);
        } else {
          fcmAppLog('RÉCEPTION', 'cold-start : aucun getInitialMessage');
        }
      } catch (e) {
        print('🔔 ❌ Erreur message initial: $e');
      }
      print('🔔 ========== INIT TERMINÉE ==========');
    } catch (e) {
      // Evite un crash si la config Firebase n'est pas encore prête.
      print('🔔 NotificationService: Erreur init FCM: $e');
    }
  }

  /// Vérifie si les notifications sont autorisées au niveau système
  static Future<bool> isSystemPermissionGranted() async {
    if (!_firebaseEnabled) {
      return false;
    }
    try {
      print('🔔 Vérification des permissions système...');
      final settings = await _firebaseMessaging.getNotificationSettings();
      final status = settings.authorizationStatus;
      print('🔔 Statut d\'autorisation: $status');
      print(
        '🔔 - authorized: ${status == AuthorizationStatus.authorized}',
      );
      print('🔔 - denied: ${status == AuthorizationStatus.denied}');
      print('🔔 - notDetermined: ${status == AuthorizationStatus.notDetermined}');
      print('🔔 - provisional: ${status == AuthorizationStatus.provisional}');

      final granted =
          status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
      print(
        '🔔 Permission système: ${granted ? "✅ Accordée" : "❌ Refusée"}',
      );
      return granted;
    } catch (e) {
      print('🔔 ❌ Erreur vérification permissions système: $e');
      return false;
    }
  }

  /// Demande la permission si nécessaire et retourne true si accordée
  static Future<bool> ensurePermissionGranted() async {
    if (!_firebaseEnabled) {
      return false;
    }
    print('🔔 ensurePermissionGranted: Début');

    // Si déjà accordé côté système
    final alreadyGranted = await isSystemPermissionGranted();
    if (alreadyGranted) {
      print('🔔 ✅ Permission déjà accordée, pas besoin de demander');
      return true;
    }

    print('🔔 Permission non accordée, demande en cours...');
    try {
      // iOS: utiliser FCM prompt
      if (Platform.isIOS) {
        print('🔔 Plateforme: iOS - Utilisation de FCM requestPermission');
        final req = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        print('🔔 Résultat iOS: ${req.authorizationStatus}');
        final granted =
            req.authorizationStatus == AuthorizationStatus.authorized ||
            req.authorizationStatus == AuthorizationStatus.provisional;
        print('🔔 Permission iOS: ${granted ? "✅ Accordée" : "❌ Refusée"}');
        return granted;
      }

      // Android 13+: permission_handler
      if (Platform.isAndroid) {
        print(
          '🔔 Plateforme: Android - Utilisation de Permission.notification',
        );
        final status = await Permission.notification.request();
        print('🔔 Statut Android: $status');
        print(
          '🔔 Permission Android: ${status.isGranted ? "✅ Accordée" : "❌ Refusée"}',
        );
        if (!status.isGranted) {
          print('🔔 ⚠️ Raison: ${status.toString()}');
        }
        return status.isGranted;
      }
    } catch (e) {
      print('🔔 ❌ Erreur lors de la demande de permission: $e');
      return false;
    }
    print('🔔 ⚠️ Plateforme non supportée');
    return false;
  }

  /// Ouvre les paramètres de l'application (Android/iOS)
  static Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  /// Configure les handlers de messages Firebase
  static void _setupMessageHandlers() {
    if (_messageHandlersAttached) {
      fcmAppLog(
        'CONFIG',
        '_setupMessageHandlers ignoré (déjà attaché) — onBackgroundMessage reste celui de main()',
      );
      return;
    }
    _messageHandlersAttached = true;

    print('🔔 Configuration des handlers Firebase...');
    fcmAppLog(
      'CONFIG',
      'onMessage + onMessageOpenedApp attachés (onBackgroundMessage = main() uniquement)',
    );

    // Message reçu au premier plan
    print('🔔 - Handler premier plan: configuré');
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification tapée (app en arrière-plan puis retour)
    print('🔔 - Handler notification tapée: configuré');
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      fcmAppLog(
        'RÉCEPTION',
        'onMessageOpenedApp (app ramenée au premier plan depuis la notif système)',
      );
      _handleNotificationTap(m);
    });

    // Listener pour le renouvellement du token FCM
    print('🔔 - Handler renouvellement token: configuré');
    _setupTokenRefreshListener();

    print('🔔 ✅ Tous les handlers configurés avec succès');
  }

  /// Configure le listener pour le renouvellement du token FCM
  /// Ce listener détecte automatiquement quand le token change (expiration, réinstallation, etc.)
  /// Fonctionne pour iOS ET Android
  static void _setupTokenRefreshListener() {
    // Annuler le précédent listener s'il existe
    _tokenRefreshSubscription?.cancel();

    // Écouter les changements de token (iOS et Android)
    _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen(
      (String newToken) async {
        // Détecter la plateforme
        final platform = Platform.isAndroid
            ? 'Android'
            : (Platform.isIOS ? 'iOS' : 'Unknown');

        print('🔔 ========== TOKEN FCM RENOUVELÉ ($platform) ==========');
        print('🔔 Plateforme: $platform');
        print('🔔 Nouveau token FCM reçu: ${newToken.substring(0, 30)}...');

        // Récupérer l'ancien token stocké
        final oldToken = await getSavedFCMToken();
        print(
          '🔔 Ancien token stocké: ${oldToken != null ? oldToken.substring(0, 30) + "..." : "Aucun"}',
        );

        if (oldToken == newToken) {
          print('🔔 ℹ️ Le token est identique, pas besoin de renouvellement');
          return;
        }

        print(
          '🔔 ⚠️ Le token a changé ($platform), réenregistrement nécessaire...',
        );

        // Obtenir le contexte depuis la navigation
        final context = NavigationService.navigatorKey.currentContext;

        if (context == null) {
          print(
            '🔔 ⚠️ Contexte non disponible, tentative de récupération depuis ConnectionNotifier...',
          );
          final ctx = ConnectionNotifier().getContext();
          if (ctx != null) {
            await _reRegisterDeviceWithNewToken(ctx, newToken, oldToken);
          } else {
            print(
              '🔔 ❌ Contexte non disponible, le token sera renouvelé à la prochaine ouverture de l\'app',
            );
            // Sauvegarder quand même le nouveau token pour qu'il soit enregistré plus tard
            await _saveFCMToken(newToken);
          }
        } else {
          await _reRegisterDeviceWithNewToken(context, newToken, oldToken);
        }

        print('🔔 ========== FIN RENOUVELLEMENT TOKEN ==========');
      },
      onError: (error) {
        print('🔔 ❌ Erreur lors du renouvellement du token: $error');
      },
    );

    final platform = Platform.isAndroid
        ? 'Android'
        : (Platform.isIOS ? 'iOS' : 'Unknown');
    print('🔔 ✅ Listener de renouvellement du token configuré ($platform)');
    print('🔔 ℹ️ Ce listener fonctionne pour iOS et Android automatiquement');
  }

  /// Réenregistre le device avec le nouveau token FCM
  static Future<void> _reRegisterDeviceWithNewToken(
    BuildContext context,
    String newToken,
    String? oldToken,
  ) async {
    try {
      print('🔔 Début réenregistrement avec nouveau token...');

      // Récupérer le token utilisateur
      final userProvider = context.read<UserProvider>();
      String? userToken = userProvider.token;

      // Si le token n'est pas disponible, tenter de le charger
      if (userToken == null) {
        print(
          '🔔 ⚠️ Token utilisateur non disponible, tentative de chargement...',
        );
        try {
          await userProvider.loadUser();
          userToken = userProvider.token;
        } catch (e) {
          print('🔔 ❌ Erreur lors du chargement de l\'utilisateur: $e');
        }
      }

      if (userToken == null) {
        print('🔔 ⚠️ Token utilisateur null, enregistrement différé');
        // Sauvegarder le nouveau token quand même
        await _saveFCMToken(newToken);
        return;
      }

      // Vérifier que les notifications sont toujours activées
      final prefs = await SharedPreferences.getInstance();
      final userPref = prefs.getBool(_notificationKey) ?? true;
      final systemGranted = await isSystemPermissionGranted();

      if (!userPref || !systemGranted) {
        print('🔔 ⚠️ Notifications désactivées, réenregistrement ignoré');
        // Sauvegarder le nouveau token quand même
        await _saveFCMToken(newToken);
        return;
      }

      // Obtenir les infos du device (détecte automatiquement iOS ou Android)
      final deviceData = await NotificationService().getDeviceInfo();
      final platform = deviceData["platform"] as String;

      print('🔔 Réenregistrement du device sur le backend...');
      print('🔔 - Plateforme: $platform');
      print('🔔 - Nouveau token: ${newToken.substring(0, 20)}...');
      print('🔔 - Device info: ${deviceData["info"]}');

      // Si on a un ancien token, on peut le supprimer d'abord (optionnel)
      // Sinon, on enregistre directement le nouveau (le backend devrait gérer la mise à jour)

      // Enregistrer le nouveau token
      var response = await notificationController.registerDevice(
        newToken,
        deviceData["platform"],
        deviceData["info"],
        userToken,
      );

      print('🔔 Réponse backend - Status: ${response.status}');
      print('🔔 Réponse backend - Success: ${response.success}');
      print('🔔 Réponse backend - Message: ${response.message}');

      // Gérer le cas d'un token utilisateur expiré (401)
      if (!response.success && response.status == 401) {
        print('🔔 ⚠️ Token utilisateur expiré (401), tentative de refresh...');
        try {
          await userProvider.refreshToken();
          final refreshedToken = userProvider.token;
          if (refreshedToken != null) {
            print('🔔 ✅ Token rafraîchi, retry réenregistrement...');
            response = await notificationController.registerDevice(
              newToken,
              deviceData["platform"],
              deviceData["info"],
              refreshedToken,
            );

            if (response.success) {
              print('🔔 ✅ Device réenregistré avec succès après refresh');
            } else {
              print(
                '🔔 ❌ Échec réenregistrement après refresh: ${response.message}',
              );
            }
          }
        } catch (e) {
          print('🔔 ❌ Erreur lors du refresh token: $e');
        }
      } else if (response.success) {
        print('🔔 ✅ Device réenregistré avec succès');
      } else {
        print('🔔 ❌ Échec réenregistrement: ${response.message}');
      }

      // Sauvegarder le nouveau token localement même si l'enregistrement a échoué
      // pour éviter de perdre le token
      await _saveFCMToken(newToken);
      print('🔔 ✅ Nouveau token sauvegardé localement');

      // Optionnel: Supprimer l'ancien token du backend si différent
      if (oldToken != null && oldToken != newToken && response.success) {
        print('🔔 Suppression de l\'ancien token du backend...');
        try {
          await notificationController.deleteDevice(oldToken, userToken);
          print('🔔 ✅ Ancien token supprimé du backend');
        } catch (e) {
          print('🔔 ⚠️ Erreur lors de la suppression de l\'ancien token: $e');
          // Ne pas échouer si la suppression échoue
        }
      }
    } catch (e, stackTrace) {
      print('🔔 ❌ ERREUR lors du réenregistrement: $e');
      print('🔔 Stack trace: $stackTrace');
      // Sauvegarder quand même le nouveau token
      await _saveFCMToken(newToken);
    }
  }

  /// Sauvegarde le fcmToken FCM
  static Future<void> _saveFCMToken(String fcmToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, fcmToken);
  }

  /// Récupère le fcmToken FCM sauvegardé
  static Future<String?> getSavedFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  /// Active ou désactive les notifications
  Future<void> setNotificationsEnabledWithContext(
    BuildContext context,
    bool enabled,
  ) async {
    print('🔔 ========== SET NOTIFICATIONS ENABLED ==========');
    print('🔔 Nouvelle valeur: ${enabled ? "✅ Activées" : "❌ Désactivées"}');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationKey, enabled);
    print('🔔 Préférence sauvegardée dans SharedPreferences');

    if (!_firebaseEnabled) {
      // On enregistre seulement la préférence locale, sans toucher à Firebase.
      print(
        '🔔 Firebase désactivé, seule la préférence locale de notifications est mise à jour.',
      );
      return;
    }

    if (enabled) {
      print('🔔 Activation des notifications...');
      final ok = await ensurePermissionGranted();
      if (!ok) {
        print('🔔 ❌ Permission refusée, impossible d\'activer');
        return;
      }
      await _registerCurrentDevice(context);
    } else {
      print('🔔 Désactivation des notifications...');
      // Supprimer le fcmToken si les notifications sont désactivées
      final fcmToken = await _firebaseMessaging.getToken();
      final userToken = context.read<UserProvider>().token;
      print('🔔 Token FCM: ${fcmToken != null ? "✅ Présent" : "❌ Null"}');
      print(
        '🔔 Token utilisateur: ${userToken != null ? "✅ Présent" : "❌ Null"}',
      );

      if (fcmToken != null && userToken != null) {
        print('🔔 Suppression du device sur le backend...');
        await notificationController.deleteDevice(fcmToken, userToken);
        print('🔔 Device supprimé du backend');
      }
      print('🔔 Suppression du token FCM...');
      await _firebaseMessaging.deleteToken();
      print('🔔 ✅ Token FCM supprimé');
    }
    print('🔔 ========== FIN SET NOTIFICATIONS ==========');
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    Map<String, dynamic> deviceData = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceData = {
          'platform': 'android',
          'info': "${androidInfo.brand} ${androidInfo.model}",
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceData = {'platform': 'ios', 'info': iosInfo.utsname.machine};
      } else {
        deviceData = {'platform': 'Unknown', 'info': "Unknown"};
      }
    } catch (e) {
      deviceData = {'error': 'Erreur récupération device info: $e'};
    }

    return deviceData;
  }

  /// Enregistre le device et gère le cas 401 (refresh token puis retry)
  Future<void> _registerCurrentDevice(BuildContext context) async {
    print('🔔 ========== ENREGISTREMENT DEVICE ==========');
    try {
      // 1. Vérifier le token utilisateur
      print('🔔 1. Vérification du token utilisateur...');
      final userProvider = context.read<UserProvider>();
      String? userToken = userProvider.token;

      // Si le token n'est pas encore dans le provider, tenter de le charger depuis SharedPreferences
      if (userToken == null) {
        print(
          '🔔 ⚠️ Token non disponible dans UserProvider, tentative de chargement depuis SharedPreferences...',
        );
        try {
          await userProvider.loadUser();
          userToken = userProvider.token;
          if (userToken != null) {
            print(
              '🔔 ✅ Token chargé avec succès depuis SharedPreferences (après loadUser)',
            );
          } else {
            print(
              '🔔 ❌ Après loadUser, token toujours null. L\'utilisateur n\'est probablement pas connecté.',
            );
          }
        } catch (e) {
          print(
            '🔔 ❌ Erreur lors du chargement du token depuis SharedPreferences: $e',
          );
        }
      }

      if (userToken == null) {
        print('🔔 ❌ ERREUR: Token utilisateur null, enregistrement ignoré');
        print(
          '🔔 ⚠️ L\'utilisateur doit être connecté pour recevoir les notifications',
        );
        print(
          '🔔 ℹ️ Le device sera enregistré automatiquement après la prochaine connexion',
        );
        return;
      }
      print('🔔 ✅ Token utilisateur présent: ${userToken.substring(0, 20)}...');

      // 2. Obtenir les infos du device
      print('🔔 2. Récupération des infos du device...');
      final deviceData = await getDeviceInfo();
      print(
        '🔔 ✅ Device info: ${deviceData["platform"]} - ${deviceData["info"]}',
      );

      // 3. Obtenir le token FCM
      print('🔔 3. Récupération du token FCM...');
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken == null) {
        print('🔔 ❌ ERREUR: Token FCM null, enregistrement ignoré');
        print('🔔 ⚠️ Firebase Messaging n\'a pas pu générer de token');
        return;
      }
      print('🔔 ✅ Token FCM obtenu: ${fcmToken.substring(0, 30)}...');
      fcmAppLog(
        'CONFIG',
        'getToken OK longueur=${fcmToken.length} (token complet non loggé)',
      );

      // 3.5. Vérifier si le token a changé par rapport à celui stocké
      final savedToken = await getSavedFCMToken();
      if (savedToken != null && savedToken == fcmToken) {
        print(
          '🔔 ℹ️ Token FCM identique à celui stocké, enregistrement quand même pour s\'assurer qu\'il est à jour...',
        );
      } else if (savedToken != null && savedToken != fcmToken) {
        print(
          '🔔 ⚠️ Token FCM différent de celui stocké (nouveau vs ancien), réenregistrement nécessaire',
        );
      }

      // 4. Vérifier les préférences utilisateur
      print('🔔 4. Vérification des préférences...');
      final prefs = await SharedPreferences.getInstance();
      final userPref = prefs.getBool(_notificationKey) ?? true;
      print(
        '🔔 Préférence utilisateur: ${userPref ? "✅ Activée" : "❌ Désactivée"}',
      );

      final systemGranted = await isSystemPermissionGranted();
      print(
        '🔔 Permission système: ${systemGranted ? "✅ Accordée" : "❌ Refusée"}',
      );

      if (!userPref || !systemGranted) {
        print('🔔 ⚠️ Notifications désactivées, enregistrement ignoré');
        return;
      }

      // 5. Enregistrer le device sur le backend
      print('🔔 5. Enregistrement sur le backend...');
      print('🔔 - Token FCM: ${fcmToken.substring(0, 20)}...');
      print('🔔 - Platform: ${deviceData["platform"]}');
      print('🔔 - Device info: ${deviceData["info"]}');

      var response = await notificationController.registerDevice(
        fcmToken,
        deviceData["platform"],
        deviceData["info"],
        userToken,
      );

      print('🔔 Réponse backend - Status: ${response.status}');
      print('🔔 Réponse backend - Success: ${response.success}');
      print('🔔 Réponse backend - Message: ${response.message}');

      if (!response.success && response.status == 401) {
        print('🔔 ⚠️ Token expiré (401), tentative de refresh...');
        try {
          await userProvider.refreshToken();
          final refreshedToken = userProvider.token;
          if (refreshedToken != null) {
            print('🔔 ✅ Token rafraîchi, retry enregistrement...');
            response = await notificationController.registerDevice(
              fcmToken,
              deviceData["platform"],
              deviceData["info"],
              refreshedToken,
            );
            print('🔔 Réponse après refresh - Status: ${response.status}');
            print('🔔 Réponse après refresh - Success: ${response.success}');
            print('🔔 Réponse après refresh - Message: ${response.message}');

            if (response.success) {
              print('🔔 ✅ Device enregistré avec succès après refresh');
            } else {
              print(
                '🔔 ❌ Échec enregistrement après refresh: ${response.message}',
              );
            }
          } else {
            print('🔔 ❌ Token rafraîchi null');
          }
        } catch (e) {
          print('🔔 ❌ Erreur lors du refresh token: $e');
        }
      } else if (response.success) {
        print('🔔 ✅ Device enregistré avec succès');
      } else {
        print('🔔 ❌ Échec enregistrement: ${response.message}');
        print(
          '🔔 ⚠️ Vérifier que le backend est accessible et que l\'endpoint fonctionne',
        );
      }

      if (response.success) {
        print('🔔 Sauvegarde du token FCM localement...');
        await _saveFCMToken(fcmToken);
        print('🔔 ✅ Token FCM sauvegardé');
      }
    } catch (e, stackTrace) {
      print('🔔 ❌ ERREUR lors de l\'enregistrement du device: $e');
      print('🔔 Stack trace: $stackTrace');
    }
    print('🔔 ========== FIN ENREGISTREMENT ==========');
  }

  /// Vérifie si les notifications sont activées
  static Future<bool> areNotificationsEnabled() async {
    print('🔔 Vérification areNotificationsEnabled...');
    final prefs = await SharedPreferences.getInstance();
    final userPref = prefs.getBool(_notificationKey) ?? true;
    print(
      '🔔 Préférence utilisateur (SharedPreferences): ${userPref ? "✅ Activée" : "❌ Désactivée"}',
    );

    final systemGranted = await isSystemPermissionGranted();
    print(
      '🔔 Permission système: ${systemGranted ? "✅ Accordée" : "❌ Refusée"}',
    );

    final enabled = userPref && systemGranted;
    print(
      '🔔 Résultat final: ${enabled ? "✅ Notifications activées" : "❌ Notifications désactivées"}',
    );
    return enabled;
  }

  /// Gère les messages reçus au premier plan
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final hasNotifBlock = message.notification != null;
    fcmAppLog(
      'RÉCEPTION',
      'premier-plan (onMessage) messageId=${message.messageId} '
      'notificationBloc=${hasNotifBlock ? "oui" : "non"} '
      'titleAff=${titleFromRemoteMessage(message)} '
      'dataKeys=${message.data.keys.join(",")}',
    );
    if (!hasNotifBlock && message.data.isNotEmpty) {
      fcmAppLog(
        'RÉCEPTION',
        'message data-only (pas de title/body notification) : l’OS n’affiche souvent pas de heads-up en premier plan ; vérifie le payload serveur.',
      );
    }

    final bool notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      fcmAppLog(
        'AFFICHAGE',
        'SKIP premier-plan : prefs utilisateur ou permission système = notifications désactivées (le message a bien été RÉCEPTIONné)',
      );
      return;
    }

    // Android : en premier plan FCM n’affiche pas la notification système ; on la duplique localement.
    if (Platform.isAndroid) {
      try {
        await displayPushFromRemoteMessage(message);
        fcmAppLog(
          'AFFICHAGE',
          'notification locale système (Android premier plan) affichée',
        );
      } catch (e) {
        fcmAppLog('AFFICHAGE', 'notification locale Android erreur: $e');
      }
    }

    final ctx =
        NavigationService.navigatorKey.currentContext ??
        ConnectionNotifier().getContext();
    if (ctx == null) {
      fcmAppLog(
        'AFFICHAGE',
        'SKIP premier-plan : aucun BuildContext (navigatorKey / ConnectionNotifier) → impossible d’insérer le bandeau',
      );
      return;
    }

    final title = titleFromRemoteMessage(message);
    final body = bodyFromRemoteMessage(message);
    fcmAppLog(
      'AFFICHAGE',
      'bandeau in-app : appel showTopNotification title="$title"',
    );
    Utilities().showTopNotification(ctx, title, body);
    fcmAppLog(
      'AFFICHAGE',
      'bandeau : showTopNotification retourné (voir logs overlay ci-dessous)',
    );
  }

  /// Gère le tap sur une notification Firebase
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    fcmAppLog(
      'RÉCEPTION',
      'ouverture depuis notif (tap / cold-start) messageId=${message.messageId} data=${message.data}',
    );
    final data = message.data;
    final ctx =
        NavigationService.navigatorKey.currentContext ??
        ConnectionNotifier().getContext();
    if (ctx == null) {
      fcmAppLog(
        'AFFICHAGE',
        'SKIP après tap : pas de contexte pour navigation / bandeau',
      );
      return;
    }

    try {
      // Priorité à un nom de route explicite envoyé dans le payload
      final String? route = (data['route'] is String)
          ? data['route'] as String
          : null;
      if (route != null && route.isNotEmpty) {
        fcmAppLog('AFFICHAGE', 'navigation go_router push route=$route');
        ctx.push(route, extra: data);
        return;
      }

      final String? type = (data['type'] is String)
          ? data['type'] as String
          : null;

      final String? prestationId = data['prestationId'] != null
          ? data['prestationId'].toString()
          : null;
      const particulierPrestationTypes = {
        'prestation_prestataire_arrived',
        'prestation_accepted',
        'prestation_completed',
        'prestation_refused',
      };
      if (prestationId != null &&
          prestationId.isNotEmpty &&
          type != null &&
          particulierPrestationTypes.contains(type)) {
        final userProvider = ctx.read<UserProvider>();
        var token = userProvider.token;
        if (token == null || token.isEmpty) {
          await userProvider.loadUser();
          token = userProvider.token;
        }
        if (token != null && token.isNotEmpty) {
          final res = await PrestationsController.instance.getPrestationById(
            token,
            prestationId,
          );
          if (res.success == true && res.data is Map && ctx.mounted) {
            final map = Map<String, dynamic>.from(res.data as Map);
            final prestation = Prestation.fromJson(map);
            fcmAppLog('AFFICHAGE', 'navigation DeroulementPrestation id=$prestationId type=$type');
            final role =
                userProvider.user?.role?.toString().toUpperCase() ?? '';
            if (role == 'PARTICULIER') {
              AppNavigation.pushParticulierPrestation(ctx, prestation);
            } else {
              AppNavigation.pushPrestatairePrestation(ctx, prestation);
            }
            return;
          }
        }
      }

      // Exemple de routage par type/id métier
      if (type != null && type.toLowerCase().contains('booking')) {
        final String? bookingId = (data['bookingId'] is String)
            ? data['bookingId'] as String
            : null;
        /* `if (bookingId != null && bookingId.isNotEmpty) {
          // Récupérer le token utilisateur
          final userToken = ctx.read<UserProvider>().token;
          if (userToken != null) {
            final resp = await Reservationcontroller.instance.getReservation(
              bookingId,
              userToken,
            );
            if (resp.success == true && resp.data != null) {
              print('resp.data: ${resp.data}');
              final Reservation reservation = Reservation.fromJson(resp.data);
              // Naviguer vers la page de détails de réservation
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => DetailsReservation(reservation: reservation),
                ),
              );
              return;
            }
          }
        }` */
        // Fallback si pas d'id ou d'échec de fetch
        fcmAppLog('AFFICHAGE', 'bandeau (fallback type booking)');
        Utilities().showTopNotification(
          ctx,
          titleFromRemoteMessage(message),
          bodyFromRemoteMessage(message),
        );
        return;
      }

      // Fallback: afficher un bandeau si aucune route claire
      fcmAppLog('AFFICHAGE', 'bandeau (fallback aucune route data)');
      Utilities().showTopNotification(
        ctx,
        titleFromRemoteMessage(message),
        bodyFromRemoteMessage(message),
      );
    } catch (e) {
      fcmAppLog('AFFICHAGE', 'erreur navigation tap → bandeau secours ($e)');
      Utilities().showTopNotification(
        ctx,
        titleFromRemoteMessage(message),
        bodyFromRemoteMessage(message),
      );
    }
  }

  /// Vide le cache de notifications
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationKey);
      await prefs.remove(_fcmTokenKey);
    } catch (e) {
      print('Erreur lors du vidage du cache: $e');
    }
  }
}
