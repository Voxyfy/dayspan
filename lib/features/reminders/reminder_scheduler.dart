import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/alarms.dart';
import '../../core/locale.dart';
import '../../core/notifications.dart';
import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../l10n/app_localizations.dart';
import '../habits/habit_status.dart';

/// Görev ve alışkanlık hatırlatıcılarını cihazın bildirim kuyruğuna yazar.
///
/// Veri değişince (iş eklendi, bitti, yarına alındı, alışkanlık arşivlendi)
/// önce tüm hatırlatıcılar silinir, sonra hepsi yeniden kurulur. Fark almak
/// yerine sıfırdan kurmak: iOS'ta bekleyen bildirim listesi tek gerçek,
/// uygulama tarafında ayrı bir "neyi kurdum" defteri tutmak gerekmiyor.
///
/// `ReminderMode.notify` bildirim kuyruğuna, `ReminderMode.alarm` AlarmKit'e
/// yazılır (yalnızca iOS 26+; desteklenmeyen cihazda alarm seçilemez, kayıtta
/// kalmış bir alarm varsa bildirime düşer).
final reminderSchedulerProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  if (!service.isReady) return;

  final tasks = ref.watch(reminderTasksProvider).valueOrNull;
  final habits = ref.watch(habitsProvider).valueOrNull;
  final locale = ref.watch(localeProvider);
  final alarmsOk = ref.watch(alarmsSupportedProvider).valueOrNull;
  if (tasks == null || habits == null || alarmsOk == null) return;

  final l = lookupL10n(locale);
  final fmt = DateFormat.Hm();
  final now = DateTime.now();
  final alarms = ref.read(alarmServiceProvider);
  int modeOf(int stored) => stored == ReminderMode.alarm.index && !alarmsOk
      ? ReminderMode.notify.index
      : stored;

  Future<void>(() async {
    try {
      await service.cancelReminders();
      if (alarmsOk) await alarms.cancelAll();
      var budget = NotificationService.maxPendingReminders;

      // Alışkanlıklar önce: tekrarlayan, az sayıda, her gün lazım.
      for (final h in habits) {
        if (budget <= 0) break;
        final mode = modeOf(h.reminder);
        if (mode == ReminderMode.off.index) continue;
        final minutes = h.remindAtMinutes;
        if (minutes == null) continue;
        final days = HabitStatus.daysFromMask(h.weekdays);
        final weekly = HabitGoal.values[h.goal] == HabitGoal.weekly;
        if (mode == ReminderMode.alarm.index) {
          // AlarmKit birden çok günü tek alarmda taşır; bütçeden düşmez.
          await alarms.scheduleRepeating(
            id: alarmUuid(2, h.id),
            title: h.name,
            stopLabel: l.alarmStop,
            hour: minutes ~/ 60,
            minute: minutes % 60,
            weekdays: weekly && days.isNotEmpty
                ? [for (final d in days) d + 1]
                : const [],
          );
          continue;
        }
        if (weekly && days.isNotEmpty) {
          for (final d in days) {
            if (budget-- <= 0) break;
            await service.scheduleRepeating(
              id: habitReminderId(h.id, weekday: d + 1),
              title: h.name,
              body: l.habitReminderBody,
              hour: minutes ~/ 60,
              minute: minutes % 60,
              weekday: d + 1,
            );
          }
        } else {
          budget--;
          await service.scheduleRepeating(
            id: habitReminderId(h.id),
            title: h.name,
            body: l.habitReminderBody,
            hour: minutes ~/ 60,
            minute: minutes % 60,
          );
        }
      }

      // İşler: yalnızca ileri tarihli olanlar, en yakından uzağa.
      for (final t in tasks) {
        if (budget <= 0) break;
        final mode = modeOf(t.reminder);
        if (mode == ReminderMode.off.index) continue;
        final start = t.startAt!;
        final at = start.subtract(Duration(minutes: t.reminderLeadMinutes));
        if (!at.isAfter(now)) continue;
        if (mode == ReminderMode.alarm.index) {
          await alarms.scheduleAt(
            id: alarmUuid(1, t.id),
            title: t.title,
            stopLabel: l.alarmStop,
            at: at,
          );
          continue;
        }
        budget--;
        await service.scheduleAt(
          id: taskReminderId(t.id),
          title: t.title,
          body: t.reminderLeadMinutes == 0
              ? l.taskReminderBodyNow(fmt.format(start))
              : l.taskReminderBodySoon(
                  t.reminderLeadMinutes,
                  fmt.format(start),
                ),
          at: at,
        );
      }
    } catch (e) {
      debugPrint('Reminders not scheduled: $e');
    }
  });
});

/// Hatırlatıcısı açık, bitmemiş, saatli işler.
final reminderTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(databaseProvider).watchReminderTasks(),
);

/// İş bildirimi kimliği: taban + iş id'si.
int taskReminderId(int taskId) => NotificationService.reminderIdBase + taskId;

/// Alışkanlık bildirimi kimliği: ayrı bir bantta, günlükte tek, haftalıkta
/// gün başına bir (1 = pazartesi … 7 = pazar; 0 = günlük).
int habitReminderId(int habitId, {int weekday = 0}) =>
    NotificationService.reminderIdBase + 1000000 + habitId * 10 + weekday;
