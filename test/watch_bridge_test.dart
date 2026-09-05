import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:dayspan/core/watch_bridge.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/features/habits/habit_status.dart';
import 'package:dayspan/l10n/app_localizations.dart';

/// Saat köprüsü: pano yükü ve saatten gelen eylemlerin veritabanına
/// uygulanması. Kanalın kendisi test edilmez; iki ucun anlaştığı JSON edilir.
void main() {
  late DayspanDatabase db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUp(() => db = DayspanDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'pano: işler, beklenen alışkanlıklar ve dokunuşta gidecek sayı',
    () async {
      final habitId = await db.addHabit(
        HabitsCompanion.insert(name: 'Water', target: const Value(8)),
      );
      // Çarşambaya bağlı haftalık alışkanlık: bugün çarşamba değilse panoda yok.
      final wednesday = HabitStatus.maskFromDays([2]);
      await db.addHabit(
        HabitsCompanion.insert(
          name: 'Gym',
          goal: const Value(1),
          weekdays: Value(wednesday),
        ),
      );
      await db.setHabitCount(habitId, today, 3);
      final taskId = await db.addTask(
        TasksCompanion.insert(title: 'Call', dueOn: today),
      );

      final habits = await db.watchHabits().first;
      final logs = await db
          .watchLogs(today, today.add(const Duration(days: 1)))
          .first;
      final tasks = await db.watchTasksOn(today).first;
      final board = WatchBridge.buildBoard(
        tasks: tasks,
        habits: [for (final h in habits) HabitStatus.compute(h, logs, today)],
        today: today,
        l: lookupL10n(const Locale('tr')),
      );

      final strings = board['strings'] as Map;
      expect(strings['today'], 'Bugün');
      expect(
        strings['left'],
        '2 kaldı',
        reason: 'bir iş, bir alışkanlık bekliyor',
      );

      final t = (board['tasks'] as List).single as Map;
      expect(t['id'], taskId);
      expect(t['title'], 'Call');
      expect(t['done'], false);
      expect(t['time'], isNull);

      final hs = board['habits'] as List;
      final water = hs.cast<Map>().singleWhere((h) => h['name'] == 'Water');
      expect(water['count'], 3);
      expect(water['target'], 8);
      expect(water['done'], false);
      expect(water['next'], 4, reason: 'saat dokunuşta 4 gönderir');
      final gymShown = hs.cast<Map>().any((h) => h['name'] == 'Gym');
      expect(gymShown, today.weekday == DateTime.wednesday);
    },
  );

  test(
    'eylem: habit sayıyı yazar, task bitirir, bilinmeyen tip geçilir',
    () async {
      final habitId = await db.addHabit(HabitsCompanion.insert(name: 'Read'));
      final taskId = await db.addTask(
        TasksCompanion.insert(title: 'Call', dueOn: today),
      );

      await WatchBridge.applyAction(db, {
        'type': 'habit',
        'id': habitId,
        'count': 1,
      });
      await WatchBridge.applyAction(db, {
        'type': 'task',
        'id': taskId,
        'done': true,
      });
      await WatchBridge.applyAction(db, {'type': 'nope', 'id': 1});
      await WatchBridge.applyAction(db, {'type': 'task'});

      final logs = await db.select(db.habitLogs).get();
      expect(logs.single.count, 1);
      final task = await db.select(db.tasks).getSingle();
      expect(task.done, isTrue);
    },
  );
}
