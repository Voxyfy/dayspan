@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dayspan/core/providers.dart';
import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/data/calendar/calendar_service.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/main.dart';

/// App Store ekran görüntülerini çeken düzenek.
///
/// Bu bir test değil, bir **çekim aracı**; doğrulama yapmaz, PNG üretir.
/// Ritim'deki düzenin aynısı: gerçek widget ağacı tam çözünürlükte kurulur,
/// kareler uygulamanın kendisinden çıkar, montaj değil. Olağan koşuda
/// kendini eler. Çalıştırmak için:
///
///     DAYSPAN_SHOTS=1 flutter test test/screenshot_capture_test.dart --tags screenshots
///     python3 tool/flatten_screenshots.py
///
/// Yazı tipi: uygulama sistem yazı tipini (SF Pro) kullanır, test motoru
/// ise yalnızca ölçüm amaçlı yer tutucu yükler ve her metin kutu çıkar.
/// Bu yüzden `test/fonts/` altındaki Inter (OFL) **"Roboto" adıyla** yüklenir:
/// test ortamında Material tipografisinin varsayılan ailesi Roboto'dur ve
/// aile belirtmeyen her metin oraya düşer. Inter yalnızca çekimde var,
/// uygulamaya paketlenmez.
void main() {
  const devices = <_Device>[
    // iPhone 16/17 Pro Max: zorunlu olan tek iPhone yuvası.
    _Device(name: 'ios-6.9', logical: Size(440, 956), scale: 3), // 1320x2868
    // iPhone 14/15 Pro Max, 15/16 Plus.
    _Device(name: 'ios-6.7', logical: Size(430, 932), scale: 3), // 1290x2796
    // iPhone 11 Pro Max, XS Max.
    _Device(name: 'ios-6.5', logical: Size(414, 896), scale: 3), // 1242x2688
  ];

  late DayspanDatabase db;

  setUpAll(() async {
    await initializeDateFormatting('en');
    await _loadFonts();
  });

  setUp(() {
    db = DayspanDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'onboarding.done': true,
      'locale': 'en',
    });
  });
  tearDown(() => db.close());

  for (final device in devices) {
    testWidgets(
      '${device.name} screenshots',
      skip: Platform.environment['DAYSPAN_SHOTS'] != '1',
      (tester) async {
        // Tohumlama gerçek zaman kipinde: drift sahte saat altında akış
        // teslim etmiyor.
        await tester.runAsync(() => _seed(db));

        final root = GlobalKey();
        tester.view.physicalSize = device.logical * device.scale.toDouble();
        tester.view.devicePixelRatio = device.scale.toDouble();
        addTearDown(tester.view.reset);

        Future<void> mount({required bool onboarded}) async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: root,
              child: ProviderScope(
                overrides: [
                  databaseProvider.overrideWithValue(db),
                  calendarServiceProvider.overrideWithValue(_FakeCalendar()),
                ],
                // Anahtar: aynı tipteki widget yeniden kurulunca State ve
                // içindeki yönlendirici korunuyor; onboarding karesi Settings
                // çıkıyordu.
                child: DayspanApp(
                  key: ValueKey(onboarded),
                  onboarded: onboarded,
                  theme: AppTheme.dark(fontFamily: 'Roboto'),
                ),
              ),
            ),
          );
          await _settle(tester);
        }

        Future<void> shot(String file) => _writePng(
          tester,
          root,
          'screenshots/${device.name}/$file.png',
          device.scale.toDouble(),
        );

        Future<void> tab(String name) async {
          await tester.tap(find.byKey(Key('tab-$name')));
          await _settle(tester);
        }

        await mount(onboarded: true);
        await shot('01-today');

        // Mevcut iş: düzenleyici saat, süre ve notla dolu açılır.
        await tester.tap(find.text('Send the proposal'));
        await _settle(tester);
        await shot('04-task');
        await tester.tap(find.byKey(const Key('editor-close')));
        await _settle(tester);

        await tab('habits');
        await shot('02-habits');

        await tester.tap(find.text('Read 20 pages'));
        await _settle(tester);
        await shot('03-habit');
        await tester.tap(find.byKey(const Key('habit-back')));
        await _settle(tester);

        await tab('settings');
        await shot('06-settings');

        // Onboarding ayrı ağaç: başlangıç konumu kurulumda seçiliyor.
        await mount(onboarded: false);
        await shot('05-welcome');

        // Ağaç gövde biterken sökülür; addTearDown geç kalıyor ve drift'in
        // sıfır süreli zamanlayıcısı koşuyu kırmızıya boyuyor.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}

class _Device {
  const _Device({
    required this.name,
    required this.logical,
    required this.scale,
  });
  final String name;
  final Size logical;
  final int scale;
}

/// Odaklı metin alanı `pumpAndSettle`'ı asıyor; sınırlı döngü.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Takvim izni var ve günün etkinlikleri dolu. Gerçek eklenti test ortamında
/// kanal bulamaz; kare "takvimini bağla" kartı değil dolu bir gün göstermeli.
class _FakeCalendar extends CalendarService {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<List<CalendarEvent>> eventsOn(DateTime day) async {
    final d = DateTime(day.year, day.month, day.day);
    CalendarEvent ev(String id, String title, int h, int m, int minutes) =>
        CalendarEvent(
          id: id,
          title: title,
          start: d.add(Duration(hours: h, minutes: m)),
          end: d.add(Duration(hours: h, minutes: m + minutes)),
          allDay: false,
          calendarName: 'Work',
        );
    return [
      ev('1', 'Standup', 9, 30, 30),
      ev('2', 'Design review', 11, 0, 60),
      ev('3', 'Lunch with Ece', 13, 0, 60),
      ev('4', 'Investor call', 16, 0, 45),
    ];
  }
}

Future<void> _writePng(
  WidgetTester tester,
  GlobalKey root,
  String path,
  double scale,
) async {
  final boundary =
      root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: scale);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path)..parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

/// Phosphor manifestten, metin yazı tipi Inter "Roboto" adıyla (bkz. dosya başı).
Future<void> _loadFonts() async {
  final raw = await rootBundle.loadString('FontManifest.json');
  for (final family in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  final text = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('test/fonts/Inter-$f.ttf').readAsBytesSync();
    text.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await text.load();
}

/// Gerçekçi bir gün: saatli ve saatsiz işler, biri bitmiş; dört alışkanlık,
/// biri bitmiş, biri yarım; "Read" için altı ay geçmiş (ısı haritası).
Future<void> _seed(DayspanDatabase db) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  await db.addTask(
    TasksCompanion.insert(
      title: 'Send the proposal',
      dueOn: today,
      startAt: Value(today.add(const Duration(hours: 10))),
      durationMinutes: const Value(30),
      note: const Value('Attach the revised budget. Cc Mert.'),
      reminder: const Value(1),
      reminderLeadMinutes: const Value(10),
    ),
  );
  await db.addTask(TasksCompanion.insert(title: 'Call the bank', dueOn: today));
  await db.addTask(
    TasksCompanion.insert(
      title: 'Book flights',
      dueOn: today,
      done: const Value(true),
    ),
  );

  Future<int> habit(
    String name,
    String icon,
    int color, {
    int target = 1,
    int goal = 0,
  }) => db.addHabit(
    HabitsCompanion.insert(
      name: name,
      icon: Value(icon),
      colorIndex: Value(color),
      goal: Value(goal),
      target: Value(target),
    ),
  );
  final read = await habit('Read 20 pages', 'bookOpen', 9);
  final water = await habit('Drink water', 'drop', 5, target: 8);
  final walk = await habit('Walk', 'personSimpleWalk', 3);
  await habit('Meditate', 'brain', 6);
  await habit('Gym', 'barbell', 4, goal: 1, target: 3);

  await db.setHabitCount(water, today, 3);
  await db.setHabitCount(walk, today, 1);

  // Read: 180 gün, hafta içi çoğu gün, hafta sonu seyrek; bugün dahil bir
  // seri var ki ayrıntı sayfası "streak" göstersin.
  for (var d = 0; d < 180; d++) {
    final day = today.subtract(Duration(days: d));
    final weekend = day.weekday >= 6;
    final skip = d > 4 && (d * 7 + day.weekday) % (weekend ? 3 : 6) == 0;
    if (!skip) await db.setHabitCount(read, day, 1);
  }
  // Bu haftanın izleri diğer karolarda da görünsün.
  for (var d = 1; d < 4; d++) {
    await db.setHabitCount(walk, today.subtract(Duration(days: d)), 1);
    await db.setHabitCount(water, today.subtract(Duration(days: d)), 8);
  }
}
