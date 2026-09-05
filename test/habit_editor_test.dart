import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayspan/core/providers.dart';
import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/l10n/app_localizations.dart';
import 'package:dayspan/features/habits/habit_editor_sheet.dart';

/// Düzenleyici: kaydet hiçbir durumda sessiz kalmaz.
///
/// Ritim'in ilk gönderimi "Kaydet tepkisiz" diye reddedildi; sebep boş adda
/// sessiz erken dönüştü. Bu dosya aynı hatanın burada doğmasını engeller.
void main() {
  late DayspanDatabase db;

  setUp(() => db = DayspanDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpEditor(
    WidgetTester tester,
    GlobalKey kok, {
    Habit? existing,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: L10n.localizationsDelegates,
          home: RepaintBoundary(
            key: kok,
            child: Scaffold(body: HabitEditorSheet(existing: existing)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ad boşken kaydet görünür hata verir, kayıt açmaz', (
    tester,
  ) async {
    final kok = GlobalKey();
    await pumpEditor(tester, kok);

    await tester.ensureVisible(find.byKey(const Key('habit-save')));
    await tester.tap(find.byKey(const Key('habit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Give the habit a name.'), findsOneWidget);
    expect(await db.select(db.habits).get(), isEmpty);
  });

  testWidgets('ad girilince kaydeder ve seçimleri yazar', (tester) async {
    final kok = GlobalKey();
    await pumpEditor(tester, kok);

    await tester.enterText(
      find.byKey(const Key('habit-name')),
      'Read 20 pages',
    );
    await tester.ensureVisible(find.bySemanticsLabel('Lemon'));
    await tester.tap(find.bySemanticsLabel('Lemon'));
    await tester.ensureVisible(find.text('Weekly'));
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();

    if (Platform.environment['DAYSPAN_SHOT'] == '1') {
      await _png(tester, kok, Platform.environment['DAYSPAN_SHOT_PATH']!);
    }

    await tester.ensureVisible(find.byKey(const Key('habit-save')));
    await tester.tap(find.byKey(const Key('habit-save')));
    await tester.pumpAndSettle();

    final rows = await db.select(db.habits).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Read 20 pages');
    expect(rows.single.colorIndex, 3);
    expect(rows.single.goal, 1);
    expect(rows.single.target, 3);
  });

  testWidgets('mevcut alışkanlığı düzenler, yenisini açmaz', (tester) async {
    final id = await db.addHabit(HabitsCompanion.insert(name: 'Stretch'));
    final existing = await (db.select(
      db.habits,
    )..where((h) => h.id.equals(id))).getSingle();
    final kok = GlobalKey();
    await pumpEditor(tester, kok, existing: existing);

    await tester.enterText(
      find.byKey(const Key('habit-name')),
      'Morning stretch',
    );
    await tester.ensureVisible(find.byKey(const Key('habit-save')));
    await tester.tap(find.byKey(const Key('habit-save')));
    await tester.pumpAndSettle();

    final rows = await db.select(db.habits).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Morning stretch');
  });
  testWidgets(
    'haftalıkta gün seçilince hedef gün sayısı olur ve maske yazılır',
    (tester) async {
      final kok = GlobalKey();
      await pumpEditor(tester, kok);

      await tester.enterText(find.byKey(const Key('habit-name')), 'Gym');
      await tester.ensureVisible(find.text('Weekly'));
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      for (final d in [0, 2, 4]) {
        await tester.ensureVisible(find.byKey(Key('weekday-$d')));
        await tester.tap(find.byKey(Key('weekday-$d')));
      }
      await tester.pumpAndSettle();
      expect(
        find.text('3 days a week, on the days you picked.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('habit-save')));
      await tester.tap(find.byKey(const Key('habit-save')));
      await tester.pumpAndSettle();

      final row = (await db.select(db.habits).get()).single;
      expect(row.goal, 1);
      expect(row.target, 3);
      expect(row.weekdays, (1 << 0) | (1 << 2) | (1 << 4));
    },
  );
}

Future<void> _png(WidgetTester tester, GlobalKey kok, String yol) async {
  final sinir =
      kok.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await sinir.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(yol).writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
  });
}
