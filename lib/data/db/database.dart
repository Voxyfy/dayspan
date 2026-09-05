import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// Uygulamanın tek veritabanı. Cihazda, hesapsız.
///
/// Sorgular burada başlar; bir özelliğin yüzeyi büyüyünce kendi DAO'suna
/// taşınır. Ritim'de aynı düzen 20 test dosyasını taşıdı.
@DriftDatabase(tables: [Habits, HabitLogs, Tasks])
class DayspanDatabase extends _$DayspanDatabase {
  DayspanDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'dayspan'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(habits, habits.weekdays);
      if (from < 3) {
        await m.addColumn(habits, habits.reminder);
        await m.addColumn(habits, habits.remindAtMinutes);
        await m.addColumn(tasks, tasks.reminder);
        await m.addColumn(tasks, tasks.reminderLeadMinutes);
      }
    },
  );

  /// Her şeyi siler; "baştan başla" için. Tablolar tek işlemde boşaltılır,
  /// yarıda kalan bir sıfırlama yarım bir uygulama bırakmasın.
  Future<void> resetAll() => transaction(() async {
    await delete(habitLogs).go();
    await delete(habits).go();
    await delete(tasks).go();
  });

  // ---- Alışkanlıklar ----

  Stream<List<Habit>> watchHabits() =>
      (select(habits)
            ..where((h) => h.archivedAt.isNull())
            ..orderBy([(h) => OrderingTerm.asc(h.sortOrder)]))
          .watch();

  Future<int> addHabit(HabitsCompanion habit) => into(habits).insert(habit);

  /// Tek alışkanlık; silinirse akış null verir, ayrıntı sayfası kapanır.
  Stream<Habit?> watchHabit(int id) =>
      (select(habits)..where((h) => h.id.equals(id))).watchSingleOrNull();

  /// Bir alışkanlığın tüm kayıtları; ısı haritası ve seriler buradan. Aralık
  /// yok: gün başına tek satır, bir yılda en fazla 365; sınırlamak fazla.
  Stream<List<HabitLog>> watchHabitLogs(int habitId) =>
      (select(habitLogs)..where((l) => l.habitId.equals(habitId))).watch();

  Future<void> updateHabit(int id, HabitsCompanion patch) =>
      (update(habits)..where((h) => h.id.equals(id))).write(patch);

  /// Arşivler, silmez: kayıtlar durur, karo ızgaradan kalkar. Kullanıcı bir
  /// ay sonra "o alışkanlığı geri istiyorum" derse geçmişi kaybolmamış olur.
  Future<void> archiveHabit(int id) =>
      updateHabit(id, HabitsCompanion(archivedAt: Value(DateTime.now())));

  /// Kalıcı silme; kayıtlar cascade ile gider.
  Future<void> deleteHabit(int id) =>
      (delete(habits)..where((h) => h.id.equals(id))).go();

  Future<int> nextHabitSortOrder() async {
    final row = await (selectOnly(
      habits,
    )..addColumns([habits.sortOrder.max()])).getSingle();
    return (row.read(habits.sortOrder.max()) ?? -1) + 1;
  }

  /// Günün kaydını değiştirir. `count` 0 olursa satır silinir; yanlışlıkla
  /// dokunma cezasız kalır.
  Future<void> setHabitCount(int habitId, DateTime day, int count) async {
    final d = DateTime(day.year, day.month, day.day);
    if (count <= 0) {
      await (delete(
        habitLogs,
      )..where((l) => l.habitId.equals(habitId) & l.day.equals(d))).go();
      return;
    }
    await into(habitLogs).insertOnConflictUpdate(
      HabitLogsCompanion.insert(habitId: habitId, day: d, count: Value(count)),
    );
  }

  /// Verilen aralıktaki tüm kayıtlar; karo üstündeki yedi nokta buradan.
  Stream<List<HabitLog>> watchLogs(DateTime from, DateTime to) =>
      (select(habitLogs)..where(
            (l) =>
                l.day.isBiggerOrEqualValue(from) & l.day.isSmallerThanValue(to),
          ))
          .watch();

  // ---- Görevler ----

  Stream<List<Task>> watchTasksOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(tasks)
          ..where(
            (t) =>
                t.dueOn.isBiggerOrEqualValue(start) &
                t.dueOn.isSmallerThanValue(end),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.startAt),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  /// Hatırlatıcısı açık, bitmemiş, saatli işler; planlayıcı bunları izler.
  /// Geçmiş işler de gelir (filtre planlayıcıda): "geçmiş" sınırı her
  /// dakika kayar, sorguyu ona bağlamak akışı hiç güncellemezdi.
  Stream<List<Task>> watchReminderTasks() =>
      (select(tasks)
            ..where(
              (t) =>
                  t.reminder.isBiggerThanValue(0) &
                  t.done.equals(false) &
                  t.startAt.isNotNull(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.startAt)]))
          .watch();

  Future<int> addTask(TasksCompanion task) => into(tasks).insert(task);

  Future<void> setTaskDone(int id, {required bool done}) => (update(
    tasks,
  )..where((t) => t.id.equals(id))).write(TasksCompanion(done: Value(done)));

  Future<void> updateTask(int id, TasksCompanion patch) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(patch);

  Future<void> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  /// Bitmeyen işi bir gün ileri alır; saat varsa aynı saate.
  Future<void> pushTaskToTomorrow(int id) async {
    final t = await (select(tasks)..where((t) => t.id.equals(id))).getSingle();
    await updateTask(
      id,
      TasksCompanion(
        dueOn: Value(t.dueOn.add(const Duration(days: 1))),
        startAt: Value(t.startAt?.add(const Duration(days: 1))),
      ),
    );
  }
}
