import '../../data/db/database.dart';
import '../../data/db/tables.dart';

/// Bir alışkanlığın bugünkü ve bu haftaki durumu; karo bunu çizer.
///
/// Hesap tek yerde: Habits ızgarası ile Today'deki karolar aynı sayıyı
/// göstermeli. İki ekranın kendi hesabını yapması, birinde 2/3 diğerinde
/// 3/3 yazmasıyla biterdi.
class HabitStatus {
  const HabitStatus({
    required this.habit,
    required this.week,
    required this.todayCount,
  });

  factory HabitStatus.compute(
    Habit habit,
    Iterable<HabitLog> logs,
    DateTime today,
  ) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final mine = logs.where((l) => l.habitId == habit.id).toList();
    final goal = HabitGoal.values[habit.goal];
    // Günün "sayıldı" eşiği: daily'de gün içi hedef (8 bardak), weekly'de 1.
    final threshold = goal == HabitGoal.daily ? habit.target : 1;

    final week = List<bool>.generate(7, (d) {
      final day = monday.add(Duration(days: d));
      return mine.any((l) => l.day == day && l.count >= threshold);
    });
    final todayLog = mine.where((l) => l.day == today).firstOrNull;

    return HabitStatus(
      habit: habit,
      week: week,
      todayCount: todayLog?.count ?? 0,
    );
  }

  final Habit habit;

  /// Pazartesiden pazara: o gün sayıldı mı.
  final List<bool> week;
  final int todayCount;

  HabitGoal get goal => HabitGoal.values[habit.goal];

  /// Haftalık hedefte seçili günler (0 = pazartesi). Boşsa "herhangi gün".
  Set<int> get scheduledDays => daysFromMask(habit.weekdays);

  /// Karoda hangi günlerin beklendiği; gün seçilmemişse hepsi.
  List<bool> get scheduled => List.generate(
    7,
    (d) => scheduledDays.isEmpty || scheduledDays.contains(d),
  );

  /// Bugün bu alışkanlık bekleniyor mu? Günlükte ve gün seçilmemiş
  /// haftalıkta her gün; gün seçilmiş haftalıkta yalnızca o günlerde.
  bool isDueOn(DateTime day) =>
      goal == HabitGoal.daily ||
      scheduledDays.isEmpty ||
      scheduledDays.contains(day.weekday - 1);

  static Set<int> daysFromMask(int mask) => {
    for (var d = 0; d < 7; d++)
      if (mask & (1 << d) != 0) d,
  };

  static int maskFromDays(Iterable<int> days) =>
      days.fold(0, (m, d) => m | (1 << d));

  int get weekDone => week.where((w) => w).length;

  bool get doneToday =>
      todayCount >= (goal == HabitGoal.daily ? habit.target : 1);

  /// Daireye dokununca yeni sayı. Daily'de hedefe kadar birer artar
  /// (su: 1, 2, ... 8), dolduysa sıfırlanır; weekly'de aç/kapa.
  int nextCount() {
    if (goal == HabitGoal.daily && habit.target > 1) {
      return todayCount >= habit.target ? 0 : todayCount + 1;
    }
    return doneToday ? 0 : 1;
  }
}
