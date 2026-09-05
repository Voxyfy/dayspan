import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayspan/core/providers.dart';
import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/l10n/app_localizations.dart';
import 'package:dayspan/features/today/task_editor_sheet.dart';

void main() {
  late DayspanDatabase db;

  setUp(() => db = DayspanDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    Task? existing,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: L10n.localizationsDelegates,
          home: Scaffold(body: TaskEditorSheet(existing: existing)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('task-save')));
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('başlık boşken kaydet görünür hata verir, kayıt açmaz', (
    tester,
  ) async {
    await pump(tester);
    await save(tester);

    expect(find.text('What needs doing?'), findsOneWidget);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  testWidgets('varsayılan: bugün, saatsiz', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const Key('task-title')),
      'Call the bank',
    );
    await save(tester);

    final rows = await db.select(db.tasks).get();
    final now = DateTime.now();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Call the bank');
    expect(rows.single.dueOn, DateTime(now.year, now.month, now.day));
    expect(rows.single.startAt, isNull);
    expect(rows.single.durationMinutes, isNull);
  });

  testWidgets('yarın seçilir, mevcut görev düzenlenir', (tester) async {
    final id = await db.addTask(
      TasksCompanion.insert(title: 'Draft', dueOn: DateTime(2026, 9, 3)),
    );
    final existing = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id))).getSingle();
    await pump(tester, existing: existing);

    await tester.enterText(find.byKey(const Key('task-title')), 'Draft v2');
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    await save(tester);

    final rows = await db.select(db.tasks).get();
    final now = DateTime.now();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Draft v2');
    expect(rows.single.dueOn, DateTime(now.year, now.month, now.day + 1));
  });

  testWidgets('saatli işte süre çipleri dilde: 15 dk, 1 sa, 1,5 sa', (
    tester,
  ) async {
    final id = await db.addTask(
      TasksCompanion.insert(
        title: 'Toplantı',
        dueOn: DateTime(2026, 9, 3),
        startAt: Value(DateTime(2026, 9, 3, 9, 30)),
        durationMinutes: const Value(30),
      ),
    );
    final existing = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id))).getSingle();
    await pump(tester, existing: existing, locale: const Locale('tr'));

    expect(find.text('Süre'), findsOneWidget);
    expect(find.text('15 dk'), findsOneWidget);
    expect(find.text('1 sa'), findsOneWidget);
    expect(find.text('1,5 sa'), findsOneWidget);
  });

  testWidgets('saatsiz işte süre satırı yok', (tester) async {
    await pump(tester);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('15 min'), findsNothing);
  });
}
