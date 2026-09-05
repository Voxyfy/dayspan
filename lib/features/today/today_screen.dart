import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/circle_button.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/habit_tile.dart';
import '../../core/widgets/illustration.dart';
import '../../core/widgets/task_tile.dart';
import '../../data/calendar/calendar_service.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../habits/habit_icons.dart';
import '../habits/habit_status.dart';
import '../habits/habit_subtitle.dart';
import '../settings/celebration_settings.dart';
import 'task_editor_sheet.dart';

/// Günün tek ekranı.
///
/// İki katman, tek kaydırma: üstte takvim akışı (dışarıdan gelen, okunan
/// şeyler), altında pano (kullanıcının kendi eklediği, dokunup bitirdiği
/// şeyler: işler ve alışkanlıklar, tek ızgarada). İlk sürümde işler ayrı bir
/// listeydi; iki ayrı bölüm "iki uygulama yan yana" gibi okunuyordu.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(todayEventsProvider);
    final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const <Task>[];
    final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final logs = ref.watch(weekLogsProvider).valueOrNull ?? const <HabitLog>[];
    final db = ref.read(databaseProvider);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Kutlama: bekleyen sayısı sıfırın üstünden sıfıra düşünce, günde en
    // fazla bir kez (tekrar sıfıra düşmek için önce yeni iş gelmeli). İlk
    // karede önceki değer yok; tamamlanmış günü açmak kutlama başlatmaz.
    // Ayar burada izlenir ki sağlayıcı tercihi erkenden yüklesin; yalnızca
    // tetiklenme anında okunsa ilk değer (açık) ile kutlardı.
    final celebrate = ref.watch(celebrationsProvider);
    ref.listen(todayPendingProvider, (prev, next) {
      if (prev == null || prev.pending == 0 || next.pending != 0) return;
      if (!celebrate) return;
      HapticFeedback.heavyImpact();
      Confetti.burst(context);
    });
    final board0 = ref.watch(todayPendingProvider);

    // Gün seçilmiş haftalık alışkanlık yalnızca o günlerde panoda; yoğun
    // insanın sorusu "bugün ne var", "bu hafta ne var" değil.
    final statuses = [
      for (final h in habits) HabitStatus.compute(h, logs, today),
    ].where((s) => s.isDueOn(today)).toList();
    final habitsLeft = statuses.where((s) => !s.doneToday).length;
    final tasksLeft = tasks.where((t) => !t.done).length;

    // Pano sırası: işler (saatliler saat sırasıyla, saatsizler eklenme
    // sırasıyla), sonra alışkanlıklar. Biten iş yerinde kalır: aşağı inince
    // alışkanlıkla yer değiştiriyor, göz karoyu kaybediyordu (kullanıcı,
    // 4 Eylül 2026). Bitmişliği konum değil renk söyler.
    int byTime(Task a, Task b) {
      if (a.startAt == null && b.startAt == null) {
        return a.createdAt.compareTo(b.createdAt);
      }
      if (a.startAt == null) return 1;
      if (b.startAt == null) return -1;
      return a.startAt!.compareTo(b.startAt!);
    }

    final board = <Object>[...tasks.toList()..sort(byTime), ...statuses];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(todayEventsProvider),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.lg,
                  Gap.page,
                  Gap.xxl,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, d MMMM').format(now),
                              style: text.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(l.todayTitle, style: text.headlineLarge),
                            const SizedBox(height: Gap.sm),
                            Text(
                              // Pano dolu ve hepsi bitmişse kutlama satırı;
                              // özet "0 left" yerine bunu der.
                              !board0.empty && board0.pending == 0
                                  ? l.dayComplete
                                  : _summary(
                                      l,
                                      events: events.valueOrNull?.length ?? 0,
                                      tasksLeft: tasksLeft,
                                      habitsLeft: habitsLeft,
                                    ),
                              style: text.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleButton(
                        key: const Key('today-add-task'),
                        icon: PhosphorIconsRegular.plus,
                        tooltip: l.addTask,
                        onTap: () => TaskEditorSheet.show(context),
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Akış: yalnızca takvim ----
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                sliver: SliverToBoxAdapter(
                  child: events.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => _Notice(l.calendarReadError('$e')),
                    data: (list) => _Timeline(events: list, now: now),
                  ),
                ),
              ),

              // ---- Pano ----
              // Ayrımı renk yapar: iş grafit, alışkanlık renkli. Etiket yok;
              // iki şeyi ayırmak için yazı gerekiyorsa biçim işini yapmıyor
              // demektir.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.md,
                  Gap.page,
                  0,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Gap.md,
                    crossAxisSpacing: Gap.md,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: board.length,
                  itemBuilder: (context, i) => switch (board[i]) {
                    final Task t => TaskTile(
                      key: ValueKey('task-tile-${t.id}'),
                      title: t.title,
                      subtitle: t.startAt == null
                          ? l.anytime
                          : DateFormat.Hm().format(t.startAt!),
                      done: t.done,
                      hasNote: (t.note ?? '').isNotEmpty,
                      onToggle: () => db.setTaskDone(t.id, done: !t.done),
                      onOpen: () => TaskEditorSheet.show(context, existing: t),
                    ),
                    final HabitStatus s => HabitTile(
                      key: ValueKey('habit-tile-${s.habit.id}'),
                      name: s.habit.name,
                      icon: HabitIcons.of(s.habit.icon),
                      color: TilePalette.at(s.habit.colorIndex),
                      subtitle: habitSubtitle(l, s),
                      week: s.week,
                      scheduled: s.scheduled,
                      doneToday: s.doneToday,
                      muteWhenDone: true,
                      onToggle: () =>
                          db.setHabitCount(s.habit.id, today, s.nextCount()),
                      onOpen: () => context.push(Routes.habitPath(s.habit.id)),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),

              if (board.isEmpty && (events.valueOrNull?.isEmpty ?? true))
                const SliverToBoxAdapter(child: _EmptyDay()),

              const SliverToBoxAdapter(child: SizedBox(height: Gap.listBottom)),
            ],
          ),
        ),
      ),
    );
  }

  /// "3 events · 2 tasks · 4 habits left". Sıfırlar yazılmaz; boş gün
  /// "Nothing planned" der.
  static String _summary(
    L10n l, {
    required int events,
    required int tasksLeft,
    required int habitsLeft,
  }) {
    final parts = <String>[
      if (events > 0) l.summaryEvents(events),
      if (tasksLeft > 0) l.summaryTasks(tasksLeft),
      if (habitsLeft > 0) l.summaryHabits(habitsLeft),
    ];
    if (parts.isEmpty) return l.nothingPlanned;
    return l.summaryLeft(parts.join(' · '));
  }
}

/// Saat akışı: yalnızca takvim etkinlikleri, saate göre; tüm gün olanlar
/// üstte. Saatli işler burada değil panoda: iş kullanıcının kendi eklediği,
/// dokunup bitirdiği şey; takvim etkinliği dışarıdan gelen, okunan şey.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events, required this.now});

  final List<CalendarEvent> events;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final sorted = [...events]
      ..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.start.compareTo(b.start);
      });
    final fmt = DateFormat.Hm();

    return Column(
      children: [
        for (final e in sorted) ...[
          _EventBlock(
            title: e.title,
            time: e.allDay
                ? context.l10n.allDay
                : '${fmt.format(e.start)} – ${fmt.format(e.end)}',
            live: !e.allDay && now.isAfter(e.start) && now.isBefore(e.end),
            past: !e.allDay && now.isAfter(e.end),
          ),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }
}

class _EventBlock extends StatelessWidget {
  const _EventBlock({
    required this.title,
    required this.time,
    required this.live,
    required this.past,
  });

  final String title;
  final String time;
  final bool live;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Opacity(
      // Geçmiş etkinlik solar ama kalır: "sabah ne vardı" sorusunun cevabı.
      opacity: past ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(Gap.tile),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: live ? Border.all(color: AppColors.accent, width: 1.5) : null,
        ),
        child: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.calendarBlank,
              size: IconSize.md,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: text.bodySmall),
                ],
              ),
            ),
            if (live)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
                ),
                child: Text(
                  context.l10n.nowBadge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.tile),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// Hiçbir şey yokken: çizim, takvimi bağla ya da ilk işi ekle.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyState(
      illustration: Illustration.emptyDay,
      title: l.emptyDayTitle,
      body: l.emptyDayBody,
    );
  }
}
