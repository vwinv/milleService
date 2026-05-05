import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/services/fcm_debug_log.dart';
import 'package:milleservices/services/navigation.dart';
import 'package:milleservices/services/sizeConfig.dart';

/// URL du backend Nest (port 3001 par défaut).
///
/// - **Android émulateur** : `10.0.2.2` pointe vers la machine hôte.
/// - **iOS simulateur / macOS** : `127.0.0.1` (éviter `10.0.2.2` sur iOS → connection refused).
/// - **Téléphone physique** : définir l’IP de ton Mac/PC, ex. :
///   `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3001`
String resolveBackendBaseUrl() {
  const env = String.fromEnvironment('API_BASE_URL');
  if (env.isNotEmpty) return env;
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3001';
  }
  return 'http://127.0.0.1:3001';
}

class Utilities {
  /// Toggle global de la source de position:
  /// - true  => position GPS temps reel
  /// - false => position/adresse enregistree (profil/backend)
  static bool useRealtimeLocation = true;

  // Facturation prestation (FCFA)
  static const double serviceFeeFcfa = 500;
  static const double travelFeeFcfa = 2000;

  /// Taux sur le montant « travail » seul ; la plateforme prend aussi les frais de service en intégral (voir [computePrestationBilling]).
  static const double systemCommissionRate = 0.35;

  // Production : décommenter et adapter si besoin
  String get baseUrl => "https://milleservice-backend-aacp.onrender.com";
  //String get baseUrl => resolveBackendBaseUrl();
  String imagePath = "assets/images/";
  Color colorBlueDark = Color(0xFF020B51);
  Color colorBlueLight = Color(0xFFB4DBFF).withOpacity(0.5);
  Color colorYellow = Color(0xFFFDBE00);
  Color colorGreyDark = Color(0xFF939191);
  Color colorGreyLightDark = Color(0xFFEDEDED);
  Color colorGreyLight = Color(0xFFFAFAFA);
  Color colorBlue = Color(0xFF003FA4);
  Color colorBlueLightDark = Color(0xFFACD8F5);
  String telephoneEquipe = "+221783459027";

  /// Configuration pour Microsoft Translator (traduction dynamique).
  ///
  /// Exemple d'URL :
  ///   https://api.cognitive.microsofttranslator.com
  ///
  /// ATTENTION: ne jamais committer de vraie clé en clair dans le repo.
  /// Renseigne ces valeurs via un mécanisme sécurisé (par ex. injection
  /// à la compilation, variables d'environnement, etc.).
  String translatorEndpointBaseUrl =
      "https://api.cognitive.microsofttranslator.com";
  String? translatorSubscriptionKey; // À renseigner par l'intégrateur.
  String? translatorRegion; // ex: "francecentral"

  void showMesage(context, String type, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      // Contexte trop haut dans l'arbre; ignorer silencieusement
      print(
        'Utilities: Aucun ScaffoldMessenger trouvé, message ignoré: ' + message,
      );
      return;
    }
    messenger.clearSnackBars(); // Nettoyer les anciens
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white,
            fontSize: SizeConfig.blockSizeHorizontal * 3.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: type == "success"
            ? Color(0XFF3FC823)
            : (type == "infos"
                  ? Color.fromARGB(255, 55, 142, 255)
                  : Color(0XFFFF0606)),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        margin: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            SizeConfig.blockSizeHorizontal * 2,
          ),
        ),
      ),
    );
  }

  void showTopNotification(BuildContext context, String title, String body) {
    final displayTitle = title.trim().isEmpty ? 'Notification' : title.trim();
    final displayBody = body.trim();
    fcmAppLog(
      'AFFICHAGE',
      'showTopNotification entrée title="$displayTitle" bodyLen=${displayBody.length}',
    );

    // Utiliser l'Overlay global du Navigator si disponible (le plus fiable)
    final globalContext = NavigationService.navigatorKey.currentContext;
    final overlayState =
        NavigationService.navigatorKey.currentState?.overlay ??
        Overlay.maybeOf(globalContext ?? context);

    final double topInset = MediaQuery.of(globalContext ?? context).padding.top;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        fcmAppLog(
          'AFFICHAGE',
          'overlay builder paint (bandeau visible à l’écran)',
        );
        return Positioned(
          top: topInset + 12,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(
              SizeConfig.blockSizeHorizontal * 5,
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  SizeConfig.blockSizeHorizontal * 5,
                ),
                border: Border.all(color: colorBlueDark.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: colorBlueDark.withOpacity(0.18),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notifications_active, color: colorBlueDark),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            color: colorBlueDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.25,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          fcmAppLog(
                            'AFFICHAGE',
                            'overlay fermé par l’utilisateur',
                          );
                          entry.remove();
                        },
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.close,
                            color: colorGreyDark,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (displayBody.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      displayBody,
                      style: TextStyle(
                        color: colorGreyDark,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (overlayState == null) {
      fcmAppLog(
        'AFFICHAGE',
        'SKIP overlay : OverlayState null → fallback SnackBar (problème de hiérarchie Navigator / MaterialApp)',
      );
      showMesage(
        globalContext ?? context,
        'infos',
        displayBody.isNotEmpty ? displayBody : displayTitle,
      );
      return;
    }

    fcmAppLog(
      'AFFICHAGE',
      'overlay.insert() — bandeau devrait apparaître en haut',
    );
    overlayState.insert(entry);
    fcmAppLog('AFFICHAGE', 'overlay.insert terminé OK');

    Future.delayed(const Duration(seconds: 8), () {
      fcmAppLog('AFFICHAGE', 'overlay auto-remove après 8s');
      if (entry.mounted) entry.remove();
    });
  }
}

class PrestationBillingBreakdown {
  final double baseAmountFcfa;
  final double serviceFeeFcfa;
  final double travelFeeFcfa;
  final double totalToPayFcfa;
  final double systemCommissionFcfa;

  const PrestationBillingBreakdown({
    required this.baseAmountFcfa,
    required this.serviceFeeFcfa,
    required this.travelFeeFcfa,
    required this.totalToPayFcfa,
    required this.systemCommissionFcfa,
  });
}

/// Montant à payer = (tarif horaire × durée en heures) + frais de service + frais de déplacement.
PrestationBillingBreakdown computePrestationBilling({
  required double tarifHoraireFcfa,
  required double executionHours,
}) {
  final safeTarif = tarifHoraireFcfa < 0 ? 0.0 : tarifHoraireFcfa;
  final safeHours = executionHours < 0 ? 0.0 : executionHours;
  final base = safeTarif * safeHours;
  final commission =
      base * Utilities.systemCommissionRate + Utilities.serviceFeeFcfa;
  final total = base + Utilities.serviceFeeFcfa + Utilities.travelFeeFcfa;
  return PrestationBillingBreakdown(
    baseAmountFcfa: base,
    serviceFeeFcfa: Utilities.serviceFeeFcfa,
    travelFeeFcfa: Utilities.travelFeeFcfa,
    totalToPayFcfa: total,
    systemCommissionFcfa: commission,
  );
}

class ConnectionNotifier {
  static final ConnectionNotifier _instance = ConnectionNotifier._internal();
  factory ConnectionNotifier() => _instance;
  ConnectionNotifier._internal();

  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext? getContext() => _context;

  void showUnstableConnectionMessage() {
    if (_context != null) {
      Utilities().showMesage(
        _context!,
        "info",
        "Connexion internet instable détectée. L'opération peut prendre plus de temps.",
      );
    }
  }

  void showConnectionTimeoutMessage() {
    if (_context != null) {
      Utilities().showMesage(
        _context!,
        "info",
        "Connexion internet instable. Veuillez vérifier votre connexion.",
      );
    }
  }
}
