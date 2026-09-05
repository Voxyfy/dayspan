import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calendar/calendar_service.dart';
import 'notifications.dart';
import '../data/db/database.dart';
import '../features/habits/habit_status.dart';

/// Testlerde bellek içi veritabanıyla değiştirilir.
final databaseProvider = Provider<DayspanDatabase>((ref) {
  final db = DayspanDatabase();
  ref.onDispose(db.close);
  return db;
});

/// `main()` içinde `initialize` çağrılmış tek örnek; testlerde sessiz kalır.
final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);

final calendarServiceProvider = Provider<CalendarService>(
  (_) => CalendarService(),
);

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(databaseProvider).watchHabits(),
);

/// Son yedi günün kayıtları (bugün dahil); karo noktaları için.
final weekLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return ref
      .watch(databaseProvider)
      .watchLogs(monday, monday.add(const Duration(days: 7)));
});

/// Ayrıntı sayfası için tek alışkanlık ve tüm geçmişi.
final habitProvider = StreamProvider.family<Habit?, int>(
  (ref, id) => ref.watch(databaseProvider).watchHabit(id),
);

final habitLogsProvider = StreamProvider.family<List<HabitLog>, int>(
  (ref, id) => ref.watch(databaseProvider).watchHabitLogs(id),
);

final todayTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(databaseProvider).watchTasksOn(DateTime.now()),
);

/// Günün takvim etkinlikleri. İzin yoksa boş liste; ekran "takvimini bağla"
/// kartını gösterir. Burada izin **istenmez**, yalnızca var mı diye bakılır:
/// sistem uyarısı ilk açılışta, ne için olduğu anlaşılmadan çıkarsa
/// reddediliyor ve iOS o hakkı bir daha vermiyor.
final todayEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final service = ref.watch(calendarServiceProvider);
  if (!await service.hasPermission()) return const [];
  return service.eventsOn(DateTime.now());
});

/// Bugün panoda bekleyen iş + alışkanlık sayısı ve panonun boş olup olmadığı.
/// Kutlama bu sayının sıfıra **düşmesini** izler; Today başlığı "Day complete"
/// yazmak için okur. İki yer ayrı hesaplasa biri kutlar diğeri "2 left" derdi.
final todayPendingProvider = Provider<({int pending, bool empty})>((ref) {
  final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const <Task>[];
  final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
  final logs = ref.watch(weekLogsProvider).valueOrNull ?? const <HabitLog>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = [
    for (final h in habits) HabitStatus.compute(h, logs, today),
  ].where((s) => s.isDueOn(today));
  final pending =
      tasks.where((t) => !t.done).length +
      due.where((s) => !s.doneToday).length;
  return (pending: pending, empty: tasks.isEmpty && due.isEmpty);
});
