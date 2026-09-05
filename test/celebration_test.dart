import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dayspan/core/providers.dart';
import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/features/today/today_screen.dart';
import 'package:dayspan/l10n/app_localizations.dart';

/// Kutlama: günün son karosu bitince konfeti, ayar kapalıysa yok, açılan
/// tamamlanmış gün kutlamaz.
void main() {
  late DayspanDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = DayspanDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: const TodayScreen(),
    ),
  );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Karodaki tamamla dairesi: `checked` semantiği taşıyan tek düğüm.
  /// InkWell kendi GestureDetector'ını taşıdığı için tipe göre aranmaz.
  Finder doneCircle(int taskId) => find.descendant(
    of: find.byKey(ValueKey('task-tile-$taskId')),
    matching: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.checked != null,
    ),
  );

  Future<int> addTask(WidgetTester tester, String title) async {
    final now = DateTime.now();
    return (await tester.runAsync(
      () => db.addTask(
        TasksCompanion.insert(
          title: title,
          dueOn: DateTime(now.year, now.month, now.day),
        ),
      ),
    ))!;
  }

  testWidgets('son iş bitince konfeti ve "Day complete"', (tester) async {
    final a = await addTask(tester, 'A');
    final b = await addTask(tester, 'B');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(doneCircle(a));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('confetti')), findsNothing);

    await tester.tap(doneCircle(b));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('confetti')), findsOneWidget);
    expect(find.text('Day complete. Nothing left.'), findsOneWidget);

    // Kendini kaldırır.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('confetti')), findsNothing);
    await unmount(tester);
  });

  testWidgets('ayar kapalıysa konfeti yok', (tester) async {
    SharedPreferences.setMockInitialValues({'celebrations.enabled': false});
    final a = await addTask(tester, 'A');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(doneCircle(a));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('confetti')), findsNothing);
    expect(find.text('Day complete. Nothing left.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tamamlanmış günü açmak kutlamaz', (tester) async {
    final a = await addTask(tester, 'A');
    await tester.runAsync(() => db.setTaskDone(a, done: true));
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('confetti')), findsNothing);
    await unmount(tester);
  });
}
