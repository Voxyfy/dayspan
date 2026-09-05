import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dayspan/core/providers.dart';
import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/features/habits/habit_detail_screen.dart';
import 'package:dayspan/l10n/app_localizations.dart';

/// Ayrıntı sayfası: ad, hedef, harita ve seriler; menü düzenlemeyi açar;
/// alışkanlık silinince sayfa kendini kapatır.
///
/// Veritabanı yazımları `runAsync` içinde: drift akışı sahte zaman düzleminde
/// teslim edilmiyor (bkz. celebration_test). Düzenleyici açıldıktan sonra
/// `pumpAndSettle` yok: odaklı metin alanının imleci hiç oturmuyor.
void main() {
  late DayspanDatabase db;

  setUp(() => db = DayspanDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<int> addHabit(
    WidgetTester tester,
    String name, {
    int color = 0,
  }) async => (await tester.runAsync(
    () => db.addHabit(
      HabitsCompanion.insert(name: name, colorIndex: Value(color)),
    ),
  ))!;

  Future<void> pumpDetail(WidgetTester tester, int id) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/habit/:id',
          builder: (_, s) =>
              HabitDetailScreen(habitId: int.parse(s.pathParameters['id']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: L10n.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    router.push('/habit/$id');
    await settle(tester);
  }

  testWidgets('ad, hedef, harita ve seri görünür', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final id = await addHabit(tester, 'Read', color: 5);
    await tester.runAsync(() async {
      await db.setHabitCount(id, today, 1);
      await db.setHabitCount(id, today.subtract(const Duration(days: 1)), 1);
    });

    await pumpDetail(tester, id);

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Once a day.'), findsOneWidget);
    expect(find.byKey(const Key('habit-heatmap')), findsOneWidget);
    expect(find.text('2 days'), findsNWidgets(2), reason: 'seri ve en iyi');
    expect(find.text('2'), findsOneWidget, reason: 'toplam');
    await unmount(tester);
  });

  testWidgets('menüden Düzenle düzenleyiciyi açar', (tester) async {
    final id = await addHabit(tester, 'Walk');
    await pumpDetail(tester, id);

    await tester.tap(find.byKey(const Key('habit-more')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('habit-edit')));
    await settle(tester);

    expect(find.text('Edit habit'), findsOneWidget);
    await unmount(tester);
  });

  /// Göz kontrolü: `DAYSPAN_SHOT=1 DAYSPAN_SHOT_DIR=... flutter test
  /// test/habit_detail_test.dart` altı aylık dolu bir haritayı PNG basar.
  testWidgets('çekim: altı aylık geçmiş', (tester) async {
    if (Platform.environment['DAYSPAN_SHOT'] != '1') return;
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final id = await addHabit(tester, 'Read 20 pages', color: 9);
    await tester.runAsync(() async {
      for (var d = 0; d < 180; d++) {
        // Düzensiz ama okunur bir desen: hafta içi çoğu gün, hafta sonu seyrek.
        final day = today.subtract(Duration(days: d));
        final weekend = day.weekday >= 6;
        if ((d * 7 + day.weekday) % (weekend ? 3 : 5) != 0) {
          await db.setHabitCount(id, day, 1);
        }
      }
    });
    await pumpDetail(tester, id);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${Platform.environment['DAYSPAN_SHOT_DIR']}/habit-detail.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
    });
    await unmount(tester);
  });

  testWidgets('alışkanlık silinince sayfa kapanır', (tester) async {
    final id = await addHabit(tester, 'Walk');
    await pumpDetail(tester, id);
    expect(find.text('Walk'), findsOneWidget);

    await tester.runAsync(() => db.deleteHabit(id));
    await settle(tester);

    expect(find.text('home'), findsOneWidget);
    expect(find.text('Walk'), findsNothing);
    await unmount(tester);
  });
}
