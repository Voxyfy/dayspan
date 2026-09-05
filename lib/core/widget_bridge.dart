import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../features/habits/habit_status.dart';
import 'providers.dart';

/// Ana ekran widget'ına veri yazar.
///
/// Widget uygulamanın veritabanını okuyamaz; App Group üstünden paylaşılan
/// UserDefaults'a tek bir JSON bırakılır ve WidgetKit'e "yenilen" denir.
/// Veri her değişimde yeniden yazılır; widget'ın kendi zaman çizelgesi yok,
/// çünkü sayılar uygulama içindeki eylemlerle değişir.
abstract final class WidgetBridge {
  static const appGroup = 'group.com.batuhanhaymana.dayspan';
  static const iosWidgetName = 'DayspanWidget';
  static const _key = 'summary';

  static Future<void> setup() async {
    try {
      await HomeWidget.setAppGroupId(appGroup);
    } catch (e) {
      debugPrint('Widget bridge unavailable: $e');
    }
  }

  static Future<void> publish(Map<String, Object?> summary) async {
    try {
      await HomeWidget.saveWidgetData<String>(_key, jsonEncode(summary));
      await HomeWidget.updateWidget(iOSName: iosWidgetName);
    } catch (e) {
      debugPrint('Widget not updated: $e');
    }
  }
}

/// Bugünün verisini izler, her değişimde widget'a yazar.
final widgetPublisherProvider = Provider<void>((ref) {
  final tasks = ref.watch(todayTasksProvider).valueOrNull;
  final habits = ref.watch(habitsProvider).valueOrNull;
  final logs = ref.watch(weekLogsProvider).valueOrNull;
  final events = ref.watch(todayEventsProvider).valueOrNull;
  if (tasks == null || habits == null || logs == null) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final statuses = [
    for (final h in habits) HabitStatus.compute(h, logs, today),
  ];
  final fmt = DateFormat.Hm();

  // Widget'a yalnızca gösterilecek kadar veri: sıradaki üç etkinlik, bitmemiş
  // iş sayısı ve karolar. Bütün günü yazmak hem gereksiz hem UserDefaults
  // için ağır.
  final upcoming = (events ?? const [])
      .where((e) => e.allDay || e.end.isAfter(now))
      .take(3)
      .map(
        (e) => {
          'title': e.title,
          'time': e.allDay ? null : fmt.format(e.start),
        },
      )
      .toList();

  WidgetBridge.publish({
    'date': today.toIso8601String(),
    'eventsTotal': events?.length ?? 0,
    'upcoming': upcoming,
    'tasksLeft': tasks.where((t) => !t.done).length,
    'habitsLeft': statuses.where((s) => !s.doneToday).length,
    'habits': [
      for (final s in statuses.take(8))
        {
          'name': s.habit.name,
          'color': s.habit.colorIndex,
          'done': s.doneToday,
        },
    ],
  });
});
