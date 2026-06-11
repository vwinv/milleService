import Flutter
import FirebaseCore
import GoogleMaps
import UIKit
import flutter_foreground_task

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let mapsApiKey = Self.resolveGoogleMapsApiKey() {
      GMSServices.provideAPIKey(mapsApiKey)
    }

    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Lit GMSApiKey depuis Info.plist (injectée via GOOGLE_MAPS_API_KEY dans xcconfig).
  private static func resolveGoogleMapsApiKey() -> String? {
    let raw = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty, !raw.contains("$(") else {
      NSLog(
        "[Mille Services] Google Maps: clé absente. Copiez ios/Flutter/MapsKeys.local.xcconfig.example vers MapsKeys.local.xcconfig puis rebuild."
      )
      return nil
    }
    return raw
  }
}
