import 'package:flutter_test/flutter_test.dart';

import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/features/habits/habit_status.dart';

/// Karo hesabının saf mantığı.
void main() {
  final today = DateTime(2026, 9, 3); // Perşembe
  final monday = DateTime(2026, 8, 31);

  Habit habit({int goal = 0, int target = 1, int weekdays = 0}) => Habit(
    id: 1,
    name: 'x',
    icon: 'check',
    colorIndex: 0,
    goal: goal,
    target: target,
    weekdays: weekdays,
    sortOrder: 0,
    reminder: 0,
    createdAt: today,
  );

  HabitLog log(DateTime day, [int count = 1]) =>
      HabitLog(habitId: 1, day: day, count: count);

  test('daily tek hedef: bugün kayıt varsa bitti, dokunuş sıfırlar', () {
    final s = HabitStatus.compute(habit(), [log(today)], today);
    expect(s.doneToday, isTrue);
    expect(s.week[3], isTrue);

    expect(s.nextCount(), 0);
  });

  test('daily çoklu hedef: sayaç hedefe kadar artar, dolunca sıfırlanır', () {
    var s = HabitStatus.compute(habit(target: 8), [log(today, 3)], today);
    expect(s.doneToday, isFalse);
    expect(s.week[3], isFalse, reason: '3/8 gün sayılmaz');
    expect(s.nextCount(), 4);

    s = HabitStatus.compute(habit(target: 8), [log(today, 8)], today);
    expect(s.doneToday, isTrue);
    expect(s.nextCount(), 0);
  });

  test(
    'weekly: haftanın kayıtlı günleri sayılır, bugün tek dokunuş aç/kapa',
    () {
      final s = HabitStatus.compute(habit(goal: 1, target: 3), [
        log(monday),
        log(monday.add(const Duration(days: 1))),
      ], today);
      expect(s.weekDone, 2);

      expect(s.doneToday, isFalse);
      expect(s.nextCount(), 1);
    },
  );

  test('başka alışkanlığın kayıtları karışmaz', () {
    final s = HabitStatus.compute(habit(), [
      HabitLog(habitId: 2, day: today, count: 1),
    ], today);
    expect(s.doneToday, isFalse);
    expect(s.weekDone, 0);
  });

  test('gün seçilmiş haftalık: yalnızca o günlerde beklenir', () {
    // Pazartesi (0) ve perşembe (3) seçili; bugün perşembe.
    final mask = HabitStatus.maskFromDays({0, 3});
    final s = HabitStatus.compute(
      habit(goal: 1, target: 2, weekdays: mask),
      [],
      today,
    );
    expect(s.scheduledDays, {0, 3});
    expect(s.scheduled, [true, false, false, true, false, false, false]);
    expect(s.isDueOn(today), isTrue);
    expect(
      s.isDueOn(today.add(const Duration(days: 1))),
      isFalse,
      reason: 'cuma seçili değil',
    );
  });

  test('gün seçilmemiş haftalık ve günlük her gün beklenir', () {
    expect(
      HabitStatus.compute(habit(goal: 1, target: 3), [], today).isDueOn(today),
      isTrue,
    );
    expect(
      HabitStatus.compute(habit(goal: 1, target: 3), [], today).scheduled,
      everyElement(isTrue),
    );
    expect(HabitStatus.compute(habit(), [], today).isDueOn(today), isTrue);
  });

  test('maske gidiş dönüş', () {
    for (final days in [
      <int>{},
      {0},
      {6},
      {0, 2, 4},
      {0, 1, 2, 3, 4, 5, 6},
    ]) {
      expect(HabitStatus.daysFromMask(HabitStatus.maskFromDays(days)), days);
    }
  });
}
