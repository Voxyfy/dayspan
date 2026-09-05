import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayspan/core/alarms.dart';
import 'package:dayspan/core/notifications.dart';
import 'package:dayspan/core/providers.dart';
import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/data/db/tables.dart';
import 'package:dayspan/features/habits/habit_editor_sheet.dart';
import 'package:dayspan/features/reminders/reminder_scheduler.dart';
import 'package:dayspan/features/today/task_editor_sheet.dart';
import 'package:dayspan/l10n/app_localizations.dart';

/// İzin veren sahte servis: gerçek eklenti test ortamında yok, "Bildir"
/// çipi izin alamayınca seçim geri düşer ve test hiçbir şey kaydedemezdi.
class _GrantingNotifications extends NotificationService {
  bool asked = false;

  @override
  Future<bool> requestPermission() async {
    asked = true;
    return true;
  }
}

/// Reddeden sahte servis: seçim geri düşmeli, uyarı çıkmalı.
class _DenyingNotifications extends NotificationService {
  @override
  Future<bool> requestPermission() async => false;
}

/// iOS 26 gibi davranan sahte AlarmKit: destek var, izin verilir, kurulan
/// alarmlar kimlikleriyle tutulur.
class _FakeAlarms extends AlarmService {
  final scheduled = <String>[];

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> requestAuthorization() async => true;

  @override
  Future<void> scheduleAt({
    required String id,
    required String title,
    required String stopLabel,
    required DateTime at,
  }) async => scheduled.add(id);

  @override
  Future<void> cancelAll() async => scheduled.clear();
}

/// Hatırlatıcı: düzenleyicilerde seçilir, veritabanına yazılır, izin
/// reddedilirse açılmaz.
void main() {
  late DayspanDatabase db;

  setUp(() => db = DayspanDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget app(
    Widget home,
    NotificationService notifications, {
    AlarmService? alarms,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(notifications),
      if (alarms != null) alarmServiceProvider.overrideWithValue(alarms),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: L10n.localizationsDelegates,
      home: Scaffold(body: home),
    ),
  );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('saatsiz işte hatırlatıcı satırı yok, saat seçilince gelir', (
    tester,
  ) async {
    final n = _GrantingNotifications();
    await tester.pumpWidget(app(const TaskEditorSheet(), n));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-notify')), findsNothing);

    // Saat seçici yerine mevcut bir işle aç: saat dolu gelir. Ağaç önce
    // sökülür; aynı konumdaki aynı tip widget eski durumunu korurdu.
    await unmount(tester);
    final existing = Task(
      id: 1,
      title: 'Call',
      dueOn: DateTime(2030, 1, 1),
      startAt: DateTime(2030, 1, 1, 14),
      durationMinutes: 30,
      reminder: 0,
      reminderLeadMinutes: 0,
      done: false,
      createdAt: DateTime(2030),
    );
    await tester.pumpWidget(app(TaskEditorSheet(existing: existing), n));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-notify')), findsOneWidget);
    expect(find.byKey(const Key('reminder-lead-10')), findsNothing);
    await unmount(tester);
  });

  testWidgets('iş: Bildir + 10 dk önce kaydedilir, izin bir kez istenir', (
    tester,
  ) async {
    final n = _GrantingNotifications();
    await tester.runAsync(
      () => db.addTask(
        TasksCompanion.insert(
          title: 'Call',
          dueOn: DateTime(2030, 1, 1),
          startAt: Value(DateTime(2030, 1, 1, 14)),
        ),
      ),
    );
    final task = (await tester.runAsync(
      () => db.watchTasksOn(DateTime(2030, 1, 1)).first,
    ))!.single;

    await tester.pumpWidget(app(TaskEditorSheet(existing: task), n));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('reminder-notify')));
    await tester.tap(find.byKey(const Key('reminder-notify')));
    await tester.pumpAndSettle();
    expect(n.asked, isTrue);
    expect(find.byKey(const Key('reminder-lead-10')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder-lead-10')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('task-save')));
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();

    final saved = (await tester.runAsync(
      () => db.watchReminderTasks().first,
    ))!.single;
    expect(saved.reminder, ReminderMode.notify.index);
    expect(saved.reminderLeadMinutes, 10);
    await unmount(tester);
  });

  testWidgets('izin reddedilirse Bildir açılmaz, uyarı çıkar', (tester) async {
    final existing = Task(
      id: 1,
      title: 'Call',
      dueOn: DateTime(2030, 1, 1),
      startAt: DateTime(2030, 1, 1, 14),
      durationMinutes: 30,
      reminder: 0,
      reminderLeadMinutes: 0,
      done: false,
      createdAt: DateTime(2030),
    );
    await tester.pumpWidget(
      app(TaskEditorSheet(existing: existing), _DenyingNotifications()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('reminder-notify')));
    await tester.tap(find.byKey(const Key('reminder-notify')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder-lead-10')), findsNothing);
    expect(find.textContaining('Notifications are off'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('alışkanlık: Bildir varsayılan 09:00 ile kaydedilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const HabitEditorSheet(), _GrantingNotifications()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('habit-name')), 'Water');
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('reminder-notify')));
    await tester.tap(find.byKey(const Key('reminder-notify')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-time')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('habit-save')));
    await tester.tap(find.byKey(const Key('habit-save')));
    await tester.pumpAndSettle();

    final habit = (await tester.runAsync(() => db.watchHabits().first))!.single;
    expect(habit.reminder, ReminderMode.notify.index);
    expect(habit.remindAtMinutes, 9 * 60);
    await unmount(tester);
  });

  testWidgets('alarm çipi yalnızca destek varsa görünür ve kaydedilir', (
    tester,
  ) async {
    final existing = Task(
      id: 1,
      title: 'Call',
      dueOn: DateTime(2030, 1, 1),
      startAt: DateTime(2030, 1, 1, 14),
      durationMinutes: 30,
      reminder: 0,
      reminderLeadMinutes: 0,
      done: false,
      createdAt: DateTime(2030),
    );
    // Varsayılan servis: kanal yok, destek yok, çip yok.
    await tester.pumpWidget(
      app(TaskEditorSheet(existing: existing), _GrantingNotifications()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-alarm')), findsNothing);
    await unmount(tester);

    await tester.runAsync(
      () => db.addTask(
        TasksCompanion.insert(
          title: 'Pills',
          dueOn: DateTime(2030, 1, 1),
          startAt: Value(DateTime(2030, 1, 1, 8)),
        ),
      ),
    );
    final task = (await tester.runAsync(
      () => db.watchTasksOn(DateTime(2030, 1, 1)).first,
    ))!.single;
    final alarms = _FakeAlarms();
    await tester.pumpWidget(
      app(
        TaskEditorSheet(existing: task),
        _GrantingNotifications(),
        alarms: alarms,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('reminder-alarm')));
    await tester.tap(find.byKey(const Key('reminder-alarm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('real alarm'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('task-save')));
    await tester.tap(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();
    final saved = (await tester.runAsync(
      () => db.watchReminderTasks().first,
    ))!.single;
    expect(saved.reminder, ReminderMode.alarm.index);
    await unmount(tester);
  });

  test('alarm kimliği geçerli UUID biçiminde ve türe göre ayrışır', () {
    expect(
      alarmUuid(1, 255),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(alarmUuid(1, 5), isNot(alarmUuid(2, 5)));
    expect(alarmUuid(1, 5), alarmUuid(1, 5));
  });

  test('bildirim kimlikleri çakışmaz', () {
    expect(taskReminderId(5), NotificationService.reminderIdBase + 5);
    expect(habitReminderId(5), greaterThan(taskReminderId(999999)));
    expect(habitReminderId(5, weekday: 7) - habitReminderId(5), 7);
    expect(habitReminderId(6), greaterThan(habitReminderId(5, weekday: 7)));
  });
}
