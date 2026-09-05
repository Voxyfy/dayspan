import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// Desteklenen diller. Varsayılan İngilizce: uygulama global kitleye
/// çıkıyor, cihaz dili Türkçe olsa bile ilk açılış İngilizce; kullanıcı
/// Ayarlar'dan değiştirir. Cihaz dilini izlemek daha "doğru" görünse de
/// mağaza karelerinin ve ilk izlenimin tek dilde olması tercih edildi.
abstract final class AppLocales {
  static const english = Locale('en');
  static const turkish = Locale('tr');
  static const all = [english, turkish];
  static const fallback = english;

  /// Tercih anahtarı; sıfırlama bu anahtarı korur.
  static const key = 'locale';

  /// Dilin okunan adı, kendi dilinde: seçici her zaman "English / Türkçe"
  /// yazar, çevrilmez.
  static String nativeName(Locale l) => switch (l.languageCode) {
    'tr' => 'Türkçe',
    _ => 'English',
  };
}

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    _load();
    return AppLocales.fallback;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(AppLocales.key);
    if (code == null) return;
    final found = AppLocales.all
        .where((l) => l.languageCode == code)
        .firstOrNull;
    if (found != null) _apply(found);
  }

  Future<void> set(Locale locale) async {
    _apply(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppLocales.key, locale.languageCode);
  }

  void _apply(Locale locale) {
    // Tarih biçimleri de aynı dili konuşsun: "Thursday, 3 September" ile
    // "Perşembe, 3 Eylül" aynı anahtardan gelmeli.
    Intl.defaultLocale = locale.toString();
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// Karo paletindeki rengin çevrilmiş adı; palet sırasıyla eşleşir.
String tileColorName(L10n l, int index) => switch (index % 10) {
  0 => l.colorGraphite,
  1 => l.colorMagenta,
  2 => l.colorUltraviolet,
  3 => l.colorLemon,
  4 => l.colorCoral,
  5 => l.colorAzure,
  6 => l.colorLilac,
  7 => l.colorMint,
  8 => l.colorAmber,
  _ => l.colorCyan,
};

/// Kısa erişim: `context.l10n.save`.
extension L10nX on BuildContext {
  L10n get l10n => L10n.of(this);
}
