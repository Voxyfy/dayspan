import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// iOS 26 AlarmKit sarmalayıcısı (`ios/Runner/AlarmBridge.swift`).
///
/// Gerçek alarm: sessiz mod ve Odak'ı deler, kilit ekranında tam ekran çalar.
/// Yalnızca iOS 26 ve üstünde var; [isSupported] false ise arayüz alarm
/// seçeneğini hiç göstermez. Android ve eski iOS'ta hatırlatıcı bildirimle
/// sınırlı. Test ortamında kanal yok: her çağrı sessizce "yok" der.
class AlarmService {
  AlarmService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dayspan/alarms');

  final MethodChannel _channel;
  Future<bool>? _supported;

  Future<bool> isSupported() =>
      _supported ??= _call<bool>('isSupported').then((v) => v ?? false);

  /// Alarm izni; verilmişse true. Sistem penceresi yalnızca ilk seferde.
  Future<bool> requestAuthorization() async =>
      await _call<bool>('requestAuthorization') ?? false;

  Future<void> scheduleAt({
    required String id,
    required String title,
    required String stopLabel,
    required DateTime at,
  }) => _call<void>('schedule', {
    'id': id,
    'title': title,
    'stop': stopLabel,
    'at': at.millisecondsSinceEpoch.toDouble(),
  });

  /// Haftalık tekrar; [weekdays] ISO (1 = pazartesi … 7 = pazar), boşsa her gün.
  Future<void> scheduleRepeating({
    required String id,
    required String title,
    required String stopLabel,
    required int hour,
    required int minute,
    List<int> weekdays = const [],
  }) => _call<void>('schedule', {
    'id': id,
    'title': title,
    'stop': stopLabel,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays,
  });

  Future<void> cancelAll() => _call<void>('cancelAll');

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('AlarmKit $method failed: ${e.message}');
      return null;
    }
  }
}

final alarmServiceProvider = Provider<AlarmService>((_) => AlarmService());

/// Arayüz "Alarm" çipini yalnızca bu true ise çizer.
final alarmsSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(alarmServiceProvider).isSupported(),
);

/// Veritabanı id'sinden sabit UUID: aynı iş her kurulumda aynı alarma yazar.
/// Sürüm 4 biçimine uyar ki AlarmKit reddetmesin; [kind] iş (1) ile
/// alışkanlığı (2) ayırır.
String alarmUuid(int kind, int id) {
  final tail = id.toRadixString(16).padLeft(12, '0');
  return '0000000$kind-0000-4000-8000-$tail';
}
