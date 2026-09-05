import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import 'habit_status.dart';

/// Bir alışkanlığın tüm geçmişi: ısı haritasının hücreleri ve seri sayıları.
///
/// [HabitStatus] bugünü ve bu haftayı anlatır; burası aylara bakar. Aynı
/// eşik kullanılır (daily'de gün içi hedef, weekly'de 1), yoksa karo "bitti"
/// derken harita "yarım" gösterirdi.
class HabitHistory {
  const HabitHistory({
    required this.habit,
    required this.levels,
    required this.streak,
    required this.bestStreak,
    required this.total,
  });

  factory HabitHistory.compute(
    Habit habit,
    Iterable<HabitLog> logs,
    DateTime today,
  ) {
    final goal = HabitGoal.values[habit.goal];
    final threshold = goal == HabitGoal.daily ? habit.target : 1;
    final levels = <DateTime, double>{
      for (final l in logs)
        if (l.habitId == habit.id && l.count > 0)
          DateTime(l.day.year, l.day.month, l.day.day): (l.count / threshold)
              .clamp(0.0, 1.0),
    };
    final done = {
      for (final e in levels.entries)
        if (e.value >= 1) e.key,
    };

    final (streak, best) = goal == HabitGoal.daily
        ? _dayStreaks(done, today)
        : _weekStreaks(done, today, habit.target);

    return HabitHistory(
      habit: habit,
      levels: levels,
      streak: streak,
      bestStreak: best,
      total: done.length,
    );
  }

  final Habit habit;

  /// Gün → hedefin ne kadarı yapıldı (0 hariç, 1 = sayıldı). Haritanın hücre
  /// yoğunluğu buradan; 3/8 bardak su soluk, 8/8 dolu.
  final Map<DateTime, double> levels;

  /// Kesintisiz seri: daily'de gün, weekly'de hafta sayısı. Bugün (bu hafta)
  /// henüz yapılmamışsa seri kırılmış sayılmaz; gün bitmedi.
  final int streak;
  final int bestStreak;

  /// Sayılan gün sayısı.
  final int total;

  HabitGoal get goal => HabitGoal.values[habit.goal];

  /// Günün hücre yoğunluğu: 0 boş, (0,1) kısmi, 1 dolu.
  double levelOn(DateTime day) =>
      levels[DateTime(day.year, day.month, day.day)] ?? 0;

  /// (güncel seri, en iyi seri) — gün bazında.
  static (int, int) _dayStreaks(Set<DateTime> done, DateTime today) {
    if (done.isEmpty) return (0, 0);
    // Güncel seri bugünden, bugün boşsa dünden geriye sayılır.
    var cursor = done.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var current = 0;
    while (done.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    // En iyi seri: sıralı günlerde ardışık blokların en uzunu.
    final days = done.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && d.difference(prev).inDays == 1 ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return (current, best);
  }

  /// (güncel seri, en iyi seri) — hafta bazında; bir hafta `target` gün
  /// yapıldıysa sayılır. Bu hafta hedefe ulaşmadıysa seri geçen haftadan
  /// sayılır: hafta bitmedi, kırılmış sayılmaz.
  static (int, int) _weekStreaks(
    Set<DateTime> done,
    DateTime today,
    int target,
  ) {
    if (done.isEmpty) return (0, 0);
    DateTime mondayOf(DateTime d) =>
        DateTime(d.year, d.month, d.day - (d.weekday - 1));
    final perWeek = <DateTime, int>{};
    for (final d in done) {
      perWeek.update(mondayOf(d), (n) => n + 1, ifAbsent: () => 1);
    }
    bool met(DateTime monday) => (perWeek[monday] ?? 0) >= target;

    var cursor = mondayOf(today);
    if (!met(cursor)) cursor = cursor.subtract(const Duration(days: 7));
    var current = 0;
    while (met(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 7));
    }

    final weeks = perWeek.keys.where(met).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final w in weeks) {
      run = prev != null && w.difference(prev).inDays == 7 ? run + 1 : 1;
      if (run > best) best = run;
      prev = w;
    }
    return (current, best);
  }
}
