import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The Google Maps iOS SDK must be initialised before any map is created.
    // We read the key from the bundled .env (GOOGLE_MAPS_API_KEY) so it stays a
    // single source of truth with the Dart side and out of source control.
    if let key = Self.googleMapsAPIKey(), !key.isEmpty {
      GMSServices.provideAPIKey(key)
    } else {
      NSLog("[Maps] GOOGLE_MAPS_API_KEY not found in .env — the map will not render.")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Reads GOOGLE_MAPS_API_KEY from the `.env` file bundled as a Flutter asset.
  private static func googleMapsAPIKey() -> String? {
    // Flutter bundles assets under `flutter_assets`, which on iOS lives inside
    // App.framework. Try the common locations before giving up.
    var envPath: String?
    if let p = Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "flutter_assets") {
      envPath = p
    } else if let frameworksURL = Bundle.main.privateFrameworksURL {
      let p = frameworksURL
        .appendingPathComponent("App.framework/flutter_assets/.env").path
      if FileManager.default.fileExists(atPath: p) { envPath = p }
    }

    guard let path = envPath,
          let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
      return nil
    }

    for rawLine in contents.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      guard line.hasPrefix("GOOGLE_MAPS_API_KEY"),
            let eq = line.firstIndex(of: "=") else { continue }
      return String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
    }
    return nil
  }
}
