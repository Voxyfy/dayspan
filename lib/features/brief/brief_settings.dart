import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sabah özeti ayarı: açık mı, saat kaçta.
///
/// Varsayılan **kapalı**. Bildirim izni istemek ilk açılışta değil, kullanıcı
/// "sabah özeti istiyorum" dediği anda; o an ne için istendiği açık.
class BriefSettings {
  const BriefSettings({required this.enabled, required this.hour});

  /// 08:00: çoğu insanın güne başladığı ama ilk toplantıdan önceki saat.
  static const initial = BriefSettings(enabled: false, hour: 8);

  final bool enabled;
  final int hour;

  BriefSettings copyWith({bool? enabled, int? hour}) =>
      BriefSettings(enabled: enabled ?? this.enabled, hour: hour ?? this.hour);
}

class BriefSettingsController extends Notifier<BriefSettings> {
  static const _enabledKey = 'brief.enabled';
  static const _hourKey = 'brief.hour';

  @override
  BriefSettings build() {
    _load();
    return BriefSettings.initial;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = BriefSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? BriefSettings.initial.hour,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> setHour(int hour) async {
    state = state.copyWith(hour: hour);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
  }
}

final briefSettingsProvider =
    NotifierProvider<BriefSettingsController, BriefSettings>(
      BriefSettingsController.new,
    );
