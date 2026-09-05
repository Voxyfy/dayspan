import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/circle_button.dart';
import '../../core/widgets/habit_tile.dart';
import '../../core/widgets/illustration.dart';
import '../../data/db/database.dart';
import 'habit_editor_sheet.dart';
import 'habit_icons.dart';
import 'habit_status.dart';
import 'habit_subtitle.dart';

/// Karo ızgarası: tüm alışkanlıklar.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final logs = ref.watch(weekLogsProvider).valueOrNull ?? const <HabitLog>[];
    final db = ref.read(databaseProvider);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      body: SafeArea(
        bottom: false,
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
                  children: [
                    Expanded(
                      child: Text(l.allHabits, style: text.headlineLarge),
                    ),
                    CircleButton(
                      icon: PhosphorIconsRegular.plus,
                      onTap: () => HabitEditorSheet.show(context),
                    ),
                  ],
                ),
              ),
            ),
            if (habits.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: _Empty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  0,
                  Gap.page,
                  Gap.listBottom,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Gap.md,
                    crossAxisSpacing: Gap.md,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: habits.length,
                  itemBuilder: (context, i) {
                    final s = HabitStatus.compute(habits[i], logs, today);
                    return HabitTile(
                      name: s.habit.name,
                      icon: HabitIcons.of(s.habit.icon),
                      color: TilePalette.at(s.habit.colorIndex),
                      subtitle: habitSubtitle(l, s),
                      week: s.week,
                      scheduled: s.scheduled,
                      doneToday: s.doneToday,
                      onToggle: () =>
                          db.setHabitCount(s.habit.id, today, s.nextCount()),
                      onOpen: () => context.push(Routes.habitPath(s.habit.id)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: EmptyState(
          illustration: Illustration.noHabits,
          title: l.noHabitsTitle,
          body: l.noHabits,
        ),
      ),
    );
  }
}
