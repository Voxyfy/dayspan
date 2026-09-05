import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kutlama (gün tamamlanınca konfeti) açık mı. Varsayılan açık: günde en
/// fazla bir kez çıkıyor, ilk karşılaşmada sürpriz olsun; istemeyen kapatır.
class CelebrationController extends Notifier<bool> {
  static const _key = 'celebrations.enabled';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final celebrationsProvider = NotifierProvider<CelebrationController, bool>(
  CelebrationController.new,
);
