import Flutter
import Foundation
import WatchConnectivity

/// Dart ile Apple Watch arasındaki köprü (`dayspan/watch` kanalı).
///
/// Telefon → saat: panonun son hâli `updateApplicationContext` ile gider;
/// WatchConnectivity yalnızca en sonuncuyu tutar, saat uyanınca onu okur.
/// Saat → telefon: dokunuş `sendMessage` (ulaşılabilirse) ya da
/// `transferUserInfo` (kuyruk) ile gelir; ikisi de Dart'a `action` olarak
/// iletilir. Saat eşli değilse her çağrı sessizce geçer; uygulama saat
/// olmadan da tam çalışır.
final class WatchBridge: NSObject, WCSessionDelegate {
  static let channelName = "dayspan/watch"
  private var channel: FlutterMethodChannel?
  private var lastBoard: String?

  static func register(with messenger: FlutterBinaryMessenger) {
    guard WCSession.isSupported() else { return }
    let bridge = WatchBridge()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    bridge.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "publish":
        bridge.publish(call.arguments as? String ?? "")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let session = WCSession.default
    session.delegate = bridge
    session.activate()
  }

  private func publish(_ json: String) {
    lastBoard = json
    let session = WCSession.default
    guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
    // Aynı içerik ikinci kez yazılırsa WatchConnectivity hata döner; yutulur.
    try? session.updateApplicationContext(["board": json])
  }

  private func forward(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      self.channel?.invokeMethod("action", arguments: payload)
    }
  }

  // MARK: WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
    // Saat sonradan eşlenirse ya da uygulaması sonradan kurulursa eldeki
    // son pano gönderilir; aksi hâlde saat ilk değişikliğe kadar boş kalırdı.
    if let board = lastBoard { publish(board) }
  }

  func sessionWatchStateDidChange(_ session: WCSession) {
    if let board = lastBoard { publish(board) }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    forward(message)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    forward(message)
    replyHandler(["ok": true])
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    forward(userInfo)
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
