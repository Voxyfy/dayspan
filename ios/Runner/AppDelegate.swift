import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Kendi kanalımız eklenti değil; kayıt için bir registrar üstünden
    // mesajlaşma köprüsü alınır.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AlarmBridge") {
      AlarmBridge.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WatchBridge") {
      WatchBridge.register(with: registrar.messenger())
    }
  }
}
