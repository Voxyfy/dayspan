<img src="docs/icon.png" width="96" alt="Dayspan" align="left" hspace="16" vspace="4">

# Dayspan

**Bugün ne var?** Tek bir koyu ekran cevaplıyor: takvim etkinliklerin,
işlerin ve alışkanlık karoların, bir arada.

<br clear="left">

[English](README.md) · **Türkçe**

![Flutter](https://img.shields.io/badge/Flutter-3.41-0468D7?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/platform-iOS%20%C2%B7%20Android-lightgrey)
![Tests](https://img.shields.io/badge/tests-48%20passing-34C759)
![License](https://img.shields.io/badge/license-MIT-F2F22A)

Dayspan, gün boyu takvimini açıp kapatan yoğun insan için. Bakılacak bir
uygulama daha eklemek yerine telefondaki takvimleri okur ve günün
etkinliklerinin yanına takvimin taşıyamadığı iki şeyi koyar: yetişmen gereken
işler ve sürdürmeye çalıştığın alışkanlıklar.

Hesap yok, bulut yok, reklam yok. Her şey cihazda kalır. Kod açık; bunu
kendin doğrulayabilirsin.

> **Durum:** 1.0 için özellikler tamam, ilk App Store gönderimi hazırlanıyor.
> Android derleniyor ama henüz yayınlanmadı.
> Web sitesi · [Destek](https://voxyfy.github.io/dayspan/support.html) ·
> [Gizlilik](https://voxyfy.github.io/dayspan/privacy.html)

## İçindekiler

[Neden](#neden) · [Özellikler](#özellikler) · [Tasarım ilkeleri](#tasarım-ilkeleri) ·
[Teknoloji](#teknoloji) · [Kurulum](#kurulum) · [Proje yapısı](#proje-yapısı) ·
[Yerelleştirme](#yerelleştirme) · [Testler](#testler) · [Gizlilik](#gizlilik) · [Ekran görüntüleri](#ekran-görüntüleri) ·
[Yayın](#yayın) · [Katkı](#katkı) · [Üçüncü taraf varlıklar](#üçüncü-taraf-varlıklar) ·
[Lisans](#lisans)

## Neden

Takvim uygulamaları toplantıda iyi, geri kalan her şeyde kötü. Görev
uygulamaları seni listeye boğar. Alışkanlık uygulamaları kendi dünyasında
yaşar, gününü hiç görmez. Sonuç: kahvaltıdan önce açık üç uygulama.

Dayspan üçünü tek ekrana indirmek için üç karar verir:

1. **Takvim okunur, asla kopyalanmaz.** Etkinliklerin tek doğru kaynak;
   Dayspan onları gösterir ve aradan çekilir.
2. **Tek pano, bölüm yok.** İşler ve alışkanlıklar aynı ızgarada karodur.
   İşler grafit, alışkanlıklar renkli. Etiket yok, gün içinde sekme yok.
3. **Günün bir sonu var.** Son karo bitince pano söyler ve bir kez kutlar.
   Sonra seni rahat bırakır.

## Özellikler

| Durum | Özellik |
|---|---|
| ✅ | Today panosu: takvim akışı (yalnızca etkinlikler, "Now" rozeti) üstte, altında tek karo ızgarası |
| ✅ | İşler: isteğe bağlı saat, süre ve not; "yarına al"; kaydırarak sil |
| ✅ | Alışkanlık karoları: günlük ya da haftalık hedef, seçili günler, gün içi sayaç (8 bardak su) |
| ✅ | On renkli karo paleti, her rengin kendi mürekkebi; 40'tan fazla Phosphor ikonu |
| ✅ | Alışkanlık sayfası: kimlik kartı, alışkanlığın renginde altı aylık ısı haritası, güncel ve en iyi seri, toplam |
| ✅ | Bitmiş alışkanlık Today panosunda grafite döner; renk yalnızca bekleyeni çağırır |
| ✅ | İş ve alışkanlık başına hatırlatıcı: saatinde ya da önce bildirim, ya da gerçek alarm (iOS 26 AlarmKit) |
| ✅ | Sabah özeti: 08:00'de günün etkinlik, iş ve alışkanlıklarını içeren tek bildirim (varsayılan kapalı) |
| ✅ | Gün tamamlandı: karo renklerinden konfeti, günde bir kez, kapatılabilir |
| ✅ | iOS ana ekran widget'ı (WidgetKit), App Group üzerinden beslenir |
| ✅ | Dört sayfalık onboarding: vaat, takvim izni, hatırlatıcılar, başlangıç alışkanlıkları |
| ✅ | İngilizce ve Türkçe arayüz, Ayarlar'dan seçilir (cihaz dili izlenmez) |
| ✅ | Baştan başla: her alışkanlık, iş ve ayarı siler; dil korunur |
| ✅ | Apple Watch uygulaması: günün karoları bilekte, dokunarak işaretle; hatırlatıcılar bildirim olarak yansır |
| 🔜 | Hazır rutinler ve daha zengin alışkanlık istatistikleri |

## Tasarım ilkeleri

- **Önce koyu.** Uygulama toplantı arasında, yataktan, uyumadan önce
  açılıyor. Siyaha yakın zemin (`#0B0B0D`), grafit yüzeyler, kenar çizgisi yok.
- **Renk karoda yaşar.** Zemin, yüzeyler ve metin nötr. Kimlik taşıyan tek
  renk karonun rengi; karoyu, ikonunu, hafta noktalarını ve ısı haritasını
  boyar. Başka hiçbir şeyi boyamaz.
- **Vurgu beyaz.** Seçim, birincil düğme ve "Now" rozeti beyaz. On karo
  renginin yanında renkli bir vurgu on birinci renk olurdu.
- **Her rengin tek mürekkebi var.** Sarı, lime ve cyan karolar beyaz yazı için
  fazla parlak; paletteki her renk kendi mürekkebini taşır (`TileColor`).
- **Karoda iki dokunma hedefi.** Daire işaretler, geri kalanı sayfayı açar.
  Tek hedef her açmayı yanlışlıkla işaretlemeye çevirirdi.
- **Boş durumlar tek renk.** Çizimler beyaz ve grilere çekilir ki karolarla
  yarışmasın.
- **İzinler bağlamında istenir**, ilk açılışta değil: takvim "Takvimi bağla"ya
  dokununca, bildirim bir hatırlatıcıyı açınca.

## Teknoloji

| | |
|---|---|
| Arayüz | Flutter 3.41 / Dart 3.11 |
| Depo | Drift (SQLite), şema v3 |
| Durum | Riverpod |
| Yönlendirme | go_router, üç sekme için durumlu kabuk |
| Takvim | device_calendar (salt okunur) |
| Bildirim | flutter_local_notifications, timezone |
| Alarm | Küçük bir Swift köprüsüyle AlarmKit (`ios/Runner/AlarmBridge.swift`) |
| Widget | WidgetKit + home_widget, App Group `group.com.batuhanhaymana.dayspan` |
| Saat | SwiftUI watchOS uygulaması + WatchConnectivity köprüsü (`ios/Runner/WatchBridge.swift`) |
| İkon | Phosphor |
| i18n | ARB dosyaları + `flutter gen-l10n` |

## Kurulum

```bash
git clone https://github.com/Voxyfy/dayspan.git
cd dayspan
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift kod üretimi
flutter gen-l10n                                            # ARB → lib/l10n/app_localizations*.dart
flutter run
```

Üretilen dosyalar (`*.g.dart`, `app_localizations*.dart`) depoda tutulmaz.
`lib/data/db/tables.dart` değişince `build_runner`, ARB dosyaları değişince
`gen-l10n` yeniden çalıştırılır.

iOS:

```bash
cd ios && pod install && cd ..
open ios/Runner.xcworkspace   # imzalama Xcode'da ayarlanır
```

Widget uzantısı hedefi Xcode projesine `ruby ios/add_widget_target.rb` ile
eklenir (`xcodeproj` gem gerekir). Betik gerçekten zaman yakan dört tuzağı
taşır: boş kalan `PRODUCT_NAME`, gömme adımının "Thin Binary"den önce gelmesi,
widget hedefinin `Flutter/Generated.xcconfig`'i baz alması (yoksa
`CFBundleVersion` boş kalır ve yükleme reddedilir) ve `containerBackground`
için widget'ın iOS 17 istemesi, uygulama iOS 16'yı hedeflerken.

Saat uygulaması hedefi `ruby ios/add_watch_target.rb` ile eklenir. Hedef
varken `flutter build` ve `flutter run` açık bir `-d <cihaz>` ister; Flutter
eşlik eden saat uygulamasını cihaz belirtilmeden derlemez.

AlarmKit **weak** bağlıdır ve her çağrı `#available(iOS 26)` arkasındadır;
eski sistemlerde "Alarm" seçeneği hiç gösterilmez.

## Proje yapısı

```
lib/
├── core/
│   ├── router.dart            # Rotalar; onboarding ve alışkanlık sayfası sekme kabuğunun dışında
│   ├── providers.dart         # Riverpod sağlayıcıları; ekranlar veritabanına doğrudan dokunmaz
│   ├── locale.dart            # Dil seçimi (SharedPreferences)
│   ├── notifications.dart     # Yerel bildirim servisi
│   ├── alarms.dart            # AlarmKit köprüsünün Dart tarafı
│   ├── widget_bridge.dart     # iOS widget'ı için günün JSON'unu yazar
│   ├── watch_bridge.dart      # Günün panosunu saate yollar, dokunuşlarını uygular
│   ├── theme/                 # Renk token'ları, karo paleti, ölçüler, tema
│   └── widgets/               # HabitTile, TaskTile, Heatmap, Confetti, EmptyState…
├── data/
│   ├── db/                    # Drift tabloları ve DayspanDatabase
│   └── calendar/              # Salt okunur cihaz takvimi servisi
├── features/
│   ├── today/                 # Today panosu ve iş düzenleyici
│   ├── habits/                # Izgara, düzenleyici, alışkanlık sayfası, durum ve geçmiş mantığı
│   ├── reminders/             # Hatırlatıcı alanı ve planlayıcı
│   ├── brief/                 # Sabah özeti
│   ├── onboarding/            # İlk açılış akışı
│   ├── settings/              # Ayarlar, kutlamalar, baştan başla
│   └── shell/                 # Yüzen, yalnızca ikonlu sekme çubuğu
├── l10n/                      # app_en.arb, app_tr.arb
└── main.dart
ios/DayspanWidget/             # WidgetKit uzantısı (Swift)
ios/Runner/AlarmBridge.swift   # AlarmKit köprüsü
ios/DayspanWatch/              # Apple Watch uygulaması (SwiftUI)
ios/Runner/WatchBridge.swift   # WatchConnectivity köprüsü
assets/icon/                   # Uygulama ikonu kaynağı (SVG) ve PNG'ler
assets/illustrations/          # unDraw SVG'leri, tek renge çekilmiş
tool/                          # Çizim paleti ve ekran görüntüsü düzleştirme betikleri
test/                          # Birim ve widget testleri (+ çekim aracı)
test/fonts/                    # Inter, yalnızca çekim aracı kullanır
screenshots/                   # App Store kareleri, boyut sınıfına göre
docs/                          # GitHub Pages: tanıtım, destek, gizlilik
```

Kod tabanının uyduğu kurallar:

- **Renk sabiti yalnızca `lib/core/theme` içinde.** Bir ekranda `Color(0x…)`
  görmek hatadır. Karo renkleri `TilePalette`'ten gelir; palete yalnızca sona
  eklenir, sıra değişirse mevcut kullanıcıların karoları renk değiştirir.
- **Ekranlar sağlayıcılar üzerinden okur**, veritabanını doğrudan tanımaz.
  Testler bellek içi SQLite takar.
- **Durum ve geçmiş tek yerde hesaplanır.** `HabitStatus` (bugün ve bu hafta)
  ile `HabitHistory` (ısı haritası, seriler) her ekranın kullandığı saf
  fonksiyonlardır; ızgara ile pano bir sayıda asla anlaşmazlığa düşmez.
- **Yorumlar *neden*'i anlatır ve elenen alternatifi yazar.** Tanımlayıcılar
  İngilizce, yorumlar Türkçe.

## Yerelleştirme

Kullanıcıya görünen her metin `lib/l10n/app_en.arb` ve `app_tr.arb`
içindedir, kodda `context.l10n.anahtar` ile okunur. Yeni metin eklemek iki
dosyaya da eklemek ve `flutter gen-l10n` çalıştırmak demektir.

Varsayılan dil İngilizce; cihaz dili bilinçli olarak **izlenmez**. Kullanıcı
Ayarlar'dan seçer ve seçim "Baştan başla"dan sonra da korunur. Yeni dil
katkısına açığız: `app_en.arb`'yi kopyala, çevir, yerel ayarı
`supportedLocales`'e ekle.

## Testler

```bash
flutter test
```

Veritabanı testleri bellek içi SQLite kullanır; cihaz ya da simülatör gerekmez.

| Dosya | Ne doğruluyor |
|---|---|
| `habit_status_test.dart` | Bugün/bu hafta mantığı: günlük sayaç, haftalık hedef, seçili günler |
| `habit_history_test.dart` | Isı haritası yoğunlukları, gün ve hafta serileri, en iyi seri |
| `habit_editor_test.dart` | Kaydet hiçbir zaman sessiz kalmaz; doğrulama görünür |
| `habit_detail_test.dart` | Alışkanlık sayfası ad, hedef, harita ve serileri çizer; alışkanlık silinince kapanır |
| `task_editor_test.dart` | İş düzenleyici doğrulaması ve kayıt |
| `reminder_test.dart` | Planlayıcı bütçesi ve veri değişince yeniden kurulum |
| `watch_bridge_test.dart` | Saat pano yükü ve saatten gelen dokunuşların uygulanması |
| `celebration_test.dart` | Bekleyen sıfıra düşünce konfeti bir kez patlar |
| `onboarding_test.dart` | İlk açılış akışı ve yönlendirme |
| `locale_test.dart` | Dil seçimi kalıcı, sıfırlamadan sonra korunur |
| `empty_state_test.dart` | Çizimler yüklenir ve koyu zeminde çizilir |
| `screenshot_capture_test.dart` | Test değil, **çekim aracı** (6 kare × 3 boyut). Olağan koşuda atlanır. |

Widget testlerinde iki tuzak: sahte saat altında drift akışının ilk değerini
bekleme (`watch().first` hiç çözülmez; `get()` kullan) ve her `MaterialApp`'e
`L10n.localizationsDelegates` ver.

## Gizlilik

Dayspan hiçbir ağ isteği yapmaz. Bağımlılık listesinde analitik, çökme
raporlama ya da reklam SDK'sı yoktur; `pubspec.yaml`'dan doğrulayabilirsin.
Takvim salt okunur izinle okunur ve asla saklanmaz. Politikanın tamamı:
[voxyfy.github.io/dayspan/privacy.html](https://voxyfy.github.io/dayspan/privacy.html).

## Ekran görüntüleri

Mağaza kareleri elle çekilmiyor; gerçek widget ağacından üretiliyor:

```bash
DAYSPAN_SHOTS=1 flutter test test/screenshot_capture_test.dart --tags screenshots
python3 tool/flatten_screenshots.py
```

İkinci adım zorunlu: `RepaintBoundary.toImage` her zaman RGBA üretir ve App
Store Connect alfa kanallı görseli reddeder, üstelik bunu ölçü hatası gibi
bildirir.

Uygulama sistem yazı tipini kullanır, test motoru onu yükleyemez; araç bu
yüzden Inter'i (`test/fonts/`, OFL) Material'ın testte düştüğü aile adıyla
yükler. Inter yalnızca çekimde var, uygulamaya paketlenmez. Bileşen
temalarındaki stiller (düğme, snackbar) aileyi zincirden almaz;
`AppTheme.dark(fontFamily:)` oralara elle yazar.

| Klasör | Piksel | App Store yuvası |
|---|---|---|
| `screenshots/ios-6.9/` | 1320 × 2868 | 6.9", zorunlu olan tek iPhone yuvası |
| `screenshots/ios-6.7/` | 1290 × 2796 | 6.7" |
| `screenshots/ios-6.5/` | 1242 × 2688 | 6.5" |

Boyut başına altı kare: Today, Habits, ısı haritalı alışkanlık sayfası, iş
düzenleyici, onboarding, Ayarlar. Veri gerçek veritabanı API'siyle
tohumlanır, üstüne çizilmez.

## Yayın

| | |
|---|---|
| Bundle ID | `com.batuhanhaymana.dayspan` |
| Görünen ad | Dayspan |
| Cihazlar | Yalnızca iPhone (iPad derlemesi yok), Apple Watch eşlik uygulaması |
| En düşük iOS | 16.0 (widget 17.0, alarm 26.0), watchOS 10.0 |
| Destek URL'si | https://voxyfy.github.io/dayspan/support.html |
| Gizlilik URL'si | https://voxyfy.github.io/dayspan/privacy.html |

Mağaza metinleri ve gönderim kontrol listesi
[`docs/app-store.md`](docs/app-store.md) içinde. `docs/` klasörü GitHub Pages
ile yayınlanır (`main` dalı, `/docs`) ve App Store Connect'in istediği destek
ile gizlilik bağlantılarını karşılar. Apple inceleme sırasında ikisini de açar.

```bash
flutter test && flutter analyze
flutter build ipa --release
open build/ios/archive/Runner.xcarchive   # Distribute App → App Store Connect
```

`pubspec.yaml`'daki build numarası (`version: x.y.z+N`) her yüklemede artmak
zorunda; Apple aynı numarayı ikinci kez kabul etmez, yükleme reddedilse bile.

## Katkı

Issue ve pull request'lere açığız.

- PR açmadan `flutter analyze` ve `flutter test` çalıştır; ikisi de temiz olmalı.
- Kullanıcıya görünen yeni metin **iki** ARB dosyasına da girer.
- Renk kuralına uy: `lib/core/theme` dışında renk sabiti yok.
- Yorumlar *ne*'yi değil *neden*'i anlatır ve elenen alternatifi söyler. Açık
  sorular üstü kapalı bırakılmaz, `NOT:` ya da `TODO:` ile işaretlenir.
- Tek pano ilkesini koru: Today ekranına yeni bölüm, etiket ya da sekme yok.

## Üçüncü taraf varlıklar

| Varlık | Kaynak | Lisans |
|---|---|---|
| Boş durum çizimleri (`assets/illustrations/`) | [unDraw](https://undraw.co), Katerina Limpitsouni | unDraw lisansı (ücretsiz, ticari kullanım serbest) |
| İkonlar | [Phosphor Icons](https://phosphoricons.com) | MIT |

Çizimler `python3 tool/snap_illustration_palette.py` ile tek renkli palete çekilir.

## Lisans

[MIT](LICENSE) © 2026 Batuhan Haymana. Lisans kaynak kodu kapsar; App Store
sürümü Apple'ın standart son kullanıcı sözleşmesiyle dağıtılır.
