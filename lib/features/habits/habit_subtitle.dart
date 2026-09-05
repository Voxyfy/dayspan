import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../l10n/app_localizations.dart';
import 'habit_status.dart';

/// Karo alt satırı: "Daily · 3/8" ya da "Weekly · 2/3".
String habitSubtitle(L10n l, HabitStatus s) => s.goal == HabitGoal.daily
    ? l.dailyProgress(s.todayCount, s.habit.target)
    : l.weeklyProgress(s.weekDone, s.habit.target);

/// Hedefin tam cümlesi: "Once a day." / "3 days a week, on the days you picked."
/// Düzenleyicinin önizlemesi ve ayrıntı sayfası aynı cümleyi kurar.
String habitGoalText(L10n l, Habit habit) {
  if (HabitGoal.values[habit.goal] == HabitGoal.daily) {
    return habit.target == 1 ? l.dailyOnce : l.dailyTimes(habit.target);
  }
  final days = HabitStatus.daysFromMask(habit.weekdays);
  return days.isEmpty
      ? l.weeklyDays(habit.target)
      : l.weeklyPickedDays(days.length);
}
