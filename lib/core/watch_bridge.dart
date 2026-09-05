import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/db/database.dart';
import '../features/habits/habit_status.dart';
import '../l10n/app_localizations.dart';
import 'locale.dart';
import 'providers.dart';

/// Apple Watch ile konuşur (`dayspan/watch` kanalı ↔ `WatchBridge.swift`).
///
/// Saat uygulaması veritabanını görmez; telefon her değişimde günün panosunu
/// tek JSON olarak WatchConnectivity "application context"ine yazar
/// (en son hâl, kuyruk yok). Saatte bir karoya dokunulunca saat küçük bir
/// eylem gönderir, burası veritabanına uygular; pano yeniden yayınlanır ve
/// saat de aynı akıştan güncellenir. Saat kendi durumunu tutmaz: tek doğru
/// kaynak telefon, iki tarafın ayrı sayması "saatte bitti, telefonda bitmedi"
/// ile biterdi.
///
/// Test ortamında kanal yok; her çağrı sessizce geçer.
class WatchBridge {
  WatchBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dayspan/watch');

  final MethodChannel _channel;

  /// Saatten gelen eylemleri [db]'ye uygular. Uygulama açıkken kanal canlı;
  /// kapalıyken saat eylemi `transferUserInfo` ile kuyruklar ve telefon
  /// uygulaması bir sonraki açılışta alır.
  void listen(DayspanDatabase db) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return null;
      final raw = call.arguments;
      final map = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      await applyAction(db, map);
      return null;
    });
  }

  Future<void> publish(Map<String, Object?> board) async {
    try {
      await _channel.invokeMethod<void>('publish', jsonEncode(board));
    } on MissingPluginException {
      // Android ya da test: saat yok.
    } catch (e) {
      debugPrint('Watch not updated: $e');
    }
  }

  /// Saat eylemi → veritabanı. `type` habit ise `count` günün yeni sayısı,
  /// task ise `done`. Bilinmeyen tip sessizce geçilir: eski saat sürümü yeni
  /// telefonu çökertmesin.
  static Future<void> applyAction(
    DayspanDatabase db,
    Map<String, dynamic> action,
  ) async {
    final id = (action['id'] as num?)?.toInt();
    if (id == null) return;
    switch (action['type']) {
      case 'habit':
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        await db.setHabitCount(id, today, (action['count'] as num).toInt());
      case 'task':
        await db.setTaskDone(id, done: action['done'] == true);
    }
  }

  /// Panonun saat sürümü. Yalnızca saatin çizdiği alanlar; renk paletteki
  /// sıra (Swift tarafı aynı listeyi taşır).
  ///
  /// Saatin başlık ve boş durum metinleri de burada, telefonun seçili
  /// dilinde. Saat cihaz dilini izleseydi telefon Türkçe, saat İngilizce
  /// olabilirdi; uygulamanın dili tek yerden seçilir.
  static Map<String, Object?> buildBoard({
    required List<Task> tasks,
    required List<HabitStatus> habits,
    required DateTime today,
    required L10n l,
  }) {
    final fmt = DateFormat.Hm();
    final due = habits.where((s) => s.isDueOn(today)).toList();
    final pending =
        tasks.where((t) => !t.done).length +
        due.where((s) => !s.doneToday).length;
    return {
      'date': today.toIso8601String(),
      'strings': {
        'today': l.tabToday,
        'left': pending == 0 ? l.watchDone : l.summaryLeft('$pending'),
        'nothing': l.nothingPlanned,
        'openOnce': l.watchOpenOnce,
      },
      'tasks': [
        for (final t in tasks)
          {
            'id': t.id,
            'title': t.title,
            'time': t.startAt == null ? null : fmt.format(t.startAt!),
            'done': t.done,
          },
      ],
      'habits': [
        for (final s in due)
          {
            'id': s.habit.id,
            'name': s.habit.name,
            'color': s.habit.colorIndex,
            'done': s.doneToday,
            'count': s.todayCount,
            'target': s.goal.index == 0 ? s.habit.target : 1,
            // Saat dokunuşta bu sayıyı gönderir; hesabı telefon yapar.
            'next': s.nextCount(),
          },
      ],
    };
  }
}

final watchBridgeProvider = Provider<WatchBridge>((ref) {
  final bridge = WatchBridge();
  bridge.listen(ref.watch(databaseProvider));
  return bridge;
});

/// Günün panosunu izler, her değişimde saate yazar.
final watchPublisherProvider = Provider<void>((ref) {
  final tasks = ref.watch(todayTasksProvider).valueOrNull;
  final habits = ref.watch(habitsProvider).valueOrNull;
  final logs = ref.watch(weekLogsProvider).valueOrNull;
  if (tasks == null || habits == null || logs == null) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final statuses = [
    for (final h in habits) HabitStatus.compute(h, logs, today),
  ];
  ref
      .watch(watchBridgeProvider)
      .publish(
        WatchBridge.buildBoard(
          tasks: tasks,
          habits: statuses,
          today: today,
          l: lookupL10n(ref.watch(localeProvider)),
        ),
      );
});
