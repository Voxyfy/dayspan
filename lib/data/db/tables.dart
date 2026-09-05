import 'package:drift/drift.dart';

/// Alışkanlık: her gün ya da haftada N kez yapılan, karo olarak görünen iş.
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// Phosphor ikon adı; ikon eşlemesi `HabitIcons` içinde.
  TextColumn get icon => text().withDefault(const Constant('check'))();

  /// `TilePalette` içindeki sıra.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// Hedef: `HabitGoal` enum sırası. daily = her gün 1, weekly = haftada N.
  IntColumn get goal => integer().withDefault(const Constant(0))();

  /// weekly hedefinde haftalık sayı; daily'de gün içi tekrar (su: 8).
  IntColumn get target => integer().withDefault(const Constant(1))();

  /// Haftalık hedefte seçili günler, bit maskesi: bit 0 pazartesi, bit 6
  /// pazar. 0 = gün seçilmedi, haftada `target` kez herhangi gün. Ayrı tablo
  /// yerine maske: yedi bitlik sabit bir küme için satır açmak fazla.
  IntColumn get weekdays => integer().withDefault(const Constant(0))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// `ReminderMode` sırası. Bildirim, alışkanlığın beklendiği günlerde
  /// [remindAtMinutes] saatinde çalar.
  IntColumn get reminder => integer().withDefault(const Constant(0))();

  /// Gece yarısından itibaren dakika (09:30 = 570). Saat yerine dakika:
  /// tek tam sayı, saat dilimi taşımaz; alışkanlık her gün "yerel 09:30".
  IntColumn get remindAtMinutes => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

/// Alışkanlığın bir gündeki kaydı. Gün başına tek satır; `count` gün içi
/// tekrarı tutar (8 bardak su = count 8).
class HabitLogs extends Table {
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get day => dateTime()();
  IntColumn get count => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {habitId, day};
}

/// Görev: tarihli, tek seferlik iş.
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get dueOn => dateTime()();

  /// İsteğe bağlı saat; verilirse akışta blok olarak görünür.
  DateTimeColumn get startAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer().nullable()();

  /// `ReminderMode` sırası; yalnızca [startAt] verilmişse anlamlı.
  IntColumn get reminder => integer().withDefault(const Constant(0))();

  /// Bildirim başlangıçtan kaç dakika önce: 0, 10, 30.
  IntColumn get reminderLeadMinutes =>
      integer().withDefault(const Constant(0))();

  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

enum HabitGoal { daily, weekly }

/// Hatırlatma biçimi. `alarm` şimdilik yalnızca yer tutucu: iOS 26 AlarmKit
/// köprüsü gelince açılır; sıra sabit kalsın diye bugünden tanımlı.
enum ReminderMode { off, notify, alarm }
