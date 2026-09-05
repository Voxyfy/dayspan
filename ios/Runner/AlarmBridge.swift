import Flutter
import Foundation
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit
#endif

/// Dart ile AlarmKit arasındaki köprü (`dayspan/alarms` kanalı).
///
/// AlarmKit iOS 26 ile geldi: üçüncü parti uygulama Saat uygulaması gibi
/// gerçek alarm kurabiliyor; sessiz modu ve Odak'ı deler, kilit ekranında
/// tam ekran çalar. Uygulama iOS 16'yı hedeflediği için her çağrı
/// `#available` ile korunur; eski sürümde `isSupported` false döner ve Dart
/// tarafı yalnızca bildirim sunar.
///
/// Kimlik: Dart tarafı veritabanı id'sinden türetilmiş sabit UUID gönderir;
/// böylece "yeniden kur" işlemi aynı alarmın üstüne yazar.
final class AlarmBridge: NSObject {
  static let channelName = "dayspan/alarms"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let bridge = AlarmBridge()
    channel.setMethodCallHandler { call, result in
      bridge.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task { @MainActor in
        do {
          result(try await self.dispatch(call))
        } catch {
          result(FlutterError(code: "alarmkit", message: "\(error)", details: nil))
        }
      }
      return
    }
    #endif
    // iOS 26 altı: destek yok, geri kalan çağrılar sessizce başarısız.
    switch call.method {
    case "isSupported": result(false)
    case "requestAuthorization": result(false)
    default: result(nil)
    }
  }

  #if canImport(AlarmKit)
  @available(iOS 26.0, *)
  @MainActor
  private func dispatch(_ call: FlutterMethodCall) async throws -> Any? {
    let manager = AlarmManager.shared
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "isSupported":
      return true

    case "authorizationState":
      return Self.name(of: manager.authorizationState)

    case "requestAuthorization":
      // Zaten cevaplanmışsa sistem penceresi bir daha çıkmaz; durumu döndür.
      let state = manager.authorizationState == .notDetermined
        ? try await manager.requestAuthorization()
        : manager.authorizationState
      return state == .authorized

    case "schedule":
      guard let idText = args["id"] as? String, let id = UUID(uuidString: idText),
            let title = args["title"] as? String else {
        throw BridgeError.badArguments
      }
      let schedule: Alarm.Schedule
      if let epochMs = args["at"] as? Double {
        schedule = .fixed(Date(timeIntervalSince1970: epochMs / 1000))
      } else if let hour = args["hour"] as? Int, let minute = args["minute"] as? Int {
        // weekdays: 1 = pazartesi … 7 = pazar (ISO); boş liste = her gün.
        let iso = (args["weekdays"] as? [Int]) ?? []
        let days: [Locale.Weekday] = (iso.isEmpty ? Array(1...7) : iso).compactMap(Self.weekday)
        schedule = .relative(
          Alarm.Schedule.Relative(time: .init(hour: hour, minute: minute), repeats: .weekly(days))
        )
      } else {
        throw BridgeError.badArguments
      }

      let stopText = (args["stop"] as? String) ?? "Stop"
      let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: title),
        stopButton: AlarmButton(
          text: LocalizedStringResource(stringLiteral: stopText),
          textColor: Color(red: 0.043, green: 0.043, blue: 0.051),
          systemImageName: "checkmark"
        )
      )
      let attributes = AlarmAttributes<DayspanAlarmMetadata>(
        presentation: AlarmPresentation(alert: alert),
        metadata: DayspanAlarmMetadata(),
        tintColor: .white
      )
      let config = AlarmManager.AlarmConfiguration.alarm(schedule: schedule, attributes: attributes)
      // Üstüne yazmak için önce iptal; AlarmKit aynı id ile ikinci schedule'ı
      // hata sayabiliyor.
      try? manager.cancel(id: id)
      _ = try await manager.schedule(id: id, configuration: config)
      return true

    case "cancel":
      guard let idText = args["id"] as? String, let id = UUID(uuidString: idText) else {
        throw BridgeError.badArguments
      }
      try? manager.cancel(id: id)
      return nil

    case "cancelAll":
      // Yalnızca bizim kurduğumuz alarmlar var; AlarmKit uygulama başına
      // ayrı liste tutar.
      let existing = (try? manager.alarms) ?? []
      for alarm in existing {
        try? manager.cancel(id: alarm.id)
      }
      return existing.count

    default:
      throw BridgeError.unknownMethod(call.method)
    }
  }

  @available(iOS 26.0, *)
  private static func name(of state: AlarmManager.AuthorizationState) -> String {
    switch state {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
  }

  private static func weekday(_ iso: Int) -> Locale.Weekday? {
    switch iso {
    case 1: return .monday
    case 2: return .tuesday
    case 3: return .wednesday
    case 4: return .thursday
    case 5: return .friday
    case 6: return .saturday
    case 7: return .sunday
    default: return nil
    }
  }
  #endif

  enum BridgeError: Error {
    case badArguments
    case unknownMethod(String)
  }
}

#if canImport(AlarmKit)
/// AlarmKit üstveri protokolü boş bir tip ister; taşıdığımız veri yok.
@available(iOS 26.0, *)
struct DayspanAlarmMetadata: AlarmMetadata {}
#endif
