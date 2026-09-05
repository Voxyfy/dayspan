import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'brief_settings.dart';

/// Sabah özetini planlar: "3 events · 2 tasks · first gap at 11:00".
///
/// Bildirim bir sonraki sabah için, yarının verisiyle kurulur. Uygulama her
/// açıldığında ve ayar değiştiğinde yeniden hesaplanır; sabaha kadar veri
/// değişirse bir sonraki açılış düzeltir. Arka planda çalışmak yerine bu
/// kabul edildi: arka plan yenileme iOS'ta güvenilmez ve pil yer.
final morningBriefSchedulerProvider = Provider<void>((ref) {
  final settings = ref.watch(briefSettingsProvider);
  final locale = ref.watch(localeProvider);
  final service = ref.watch(notificationServiceProvider);
  if (!service.isReady) return;

  if (!settings.enabled) {
    service.cancelMorningBrief();
    return;
  }

  Future<void>(() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    // Saat geçmemişse bugün için, geçmişse yarın için.
    final target = now.hour < settings.hour
        ? DateTime(now.year, now.month, now.day)
        : tomorrow;

    final db = ref.read(databaseProvider);
    final calendar = ref.read(calendarServiceProvider);
    final tasks = await db.watchTasksOn(target).first;
    final habits = await db.watchHabits().first;
    final events = await calendar.hasPermission()
        ? await calendar.eventsOn(target)
        : const [];

    final l = lookupL10n(locale);
    final timed = events.where((e) => !e.allDay).toList();
    final parts = <String>[
      if (events.isNotEmpty) l.summaryEvents(events.length),
      if (tasks.isNotEmpty) l.summaryTasks(tasks.length),
      if (habits.isNotEmpty) l.summaryHabits(habits.length),
    ];
    var body = parts.isEmpty ? l.briefEmpty : parts.join(' · ');
    if (timed.isNotEmpty) {
      body +=
          '. ${l.briefFirstEvent(DateFormat.Hm().format(timed.first.start), timed.first.title)}';
    }

    try {
      await service.scheduleMorningBrief(
        hour: settings.hour,
        title: l.briefTitle,
        body: body,
      );
    } catch (e) {
      debugPrint('Morning brief not scheduled: $e');
    }
  });
});
