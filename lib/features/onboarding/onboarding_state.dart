import 'package:shared_preferences/shared_preferences.dart';

/// İlk açılış akışının görülüp görülmediği.
///
/// Tek bayrak, `SharedPreferences` üzerinde; veritabanına yazılmadı çünkü
/// akış veriden bağımsız ve testlerde bellek içi veritabanıyla karışmamalı.
/// `main()` uygulamayı kurmadan önce okur, yönlendirici başlangıç konumunu
/// buna göre seçer; böylece Today bir an bile parlayıp kaybolmaz.
abstract final class OnboardingState {
  static const _key = 'onboarding.done';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
