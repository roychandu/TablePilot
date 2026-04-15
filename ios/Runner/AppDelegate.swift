import UIKit
import Flutter
import Firebase
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    // Enable edge-to-edge display for iOS devices with notches
    if #available(iOS 11.0, *) {
      UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}