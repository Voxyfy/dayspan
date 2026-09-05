import 'package:flutter_test/flutter_test.dart';

import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/features/habits/habit_history.dart';

/// Isı haritası ve seri hesabının saf mantığı.
void main() {
  final today = DateTime(2026, 9, 5); // Cumartesi
  DateTime ago(int days) => today.subtract(Duration(days: days));

  Habit habit({int goal = 0, int target = 1}) => Habit(
    id: 1,
    name: 'x',
    icon: 'check',
    colorIndex: 0,
    goal: goal,
    target: target,
    weekdays: 0,
    sortOrder: 0,
    reminder: 0,
    createdAt: today,
  );

  HabitLog log(DateTime day, [int count = 1, int habitId = 1]) =>
      HabitLog(habitId: habitId, day: day, count: count);

  test('kayıt yoksa her şey sıfır', () {
    final h = HabitHistory.compute(habit(), const [], today);
    expect(h.streak, 0);
    expect(h.bestStreak, 0);
    expect(h.total, 0);
    expect(h.levelOn(today), 0);
  });

  test('daily: bugün dahil ardışık günler seri sayılır', () {
    final h = HabitHistory.compute(habit(), [
      log(today),
      log(ago(1)),
      log(ago(2)),
      log(ago(4)), // bir gün boşluk: 3'lük seri burada biter
    ], today);
    expect(h.streak, 3);
    expect(h.bestStreak, 3);
    expect(h.total, 4);
  });

  test('daily: bugün henüz yapılmadıysa seri dünden sayılır, kırılmaz', () {
    final h = HabitHistory.compute(habit(), [log(ago(1)), log(ago(2))], today);
    expect(h.streak, 2);
  });

  test('daily: iki gün önce biten seri güncel değildir ama en iyidir', () {
    final h = HabitHistory.compute(habit(), [
      log(ago(2)),
      log(ago(3)),
      log(ago(4)),
      log(ago(5)),
    ], today);
    expect(h.streak, 0);
    expect(h.bestStreak, 4);
  });

  test('daily çoklu hedef: yarım gün kısmi yoğunluk, seriye girmez', () {
    final h = HabitHistory.compute(habit(target: 8), [
      log(today, 4),
      log(ago(1), 8),
    ], today);
    expect(h.levelOn(today), 0.5);
    expect(h.levelOn(ago(1)), 1);
    expect(h.total, 1, reason: 'yalnızca dolu gün sayılır');
    expect(h.streak, 1, reason: 'bugün yarım: dünden sayılır');
  });

  test(
    'weekly: hedefi tutan ardışık haftalar seri, bu hafta eksikse geçen haftadan',
    () {
      // Bu hafta pazartesi 31 Ağustos. Geçen hafta (24-30) ve önceki (17-23)
      // hedefi (2) tuttu; bu hafta 1 gün var, henüz tutmadı.
      final h = HabitHistory.compute(habit(goal: 1, target: 2), [
        log(DateTime(2026, 9, 1)),
        log(DateTime(2026, 8, 24)),
        log(DateTime(2026, 8, 26)),
        log(DateTime(2026, 8, 17)),
        log(DateTime(2026, 8, 20)),
        log(DateTime(2026, 8, 3)), // hedefi tutmayan tek günlük hafta
      ], today);
      expect(h.streak, 2);
      expect(h.bestStreak, 2);
      expect(h.total, 6);
    },
  );

  test('weekly: bu hafta hedefi tuttuysa seriye dahil', () {
    final h = HabitHistory.compute(habit(goal: 1, target: 2), [
      log(DateTime(2026, 9, 1)),
      log(DateTime(2026, 9, 3)),
      log(DateTime(2026, 8, 25)),
      log(DateTime(2026, 8, 27)),
    ], today);
    expect(h.streak, 2);
  });

  test('başka alışkanlığın kayıtları karışmaz', () {
    final h = HabitHistory.compute(habit(), [log(today, 1, 2)], today);
    expect(h.total, 0);
  });
}
