import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/circle_button.dart';
import '../../core/widgets/heatmap.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../l10n/app_localizations.dart';
import 'habit_editor_sheet.dart';
import 'habit_history.dart';
import 'habit_icons.dart';
import 'habit_subtitle.dart';

/// Tek alışkanlığın sayfası: kimlik kartı, altı aylık ısı haritası, seriler.
///
/// Geçmişe bakan tek ekran burası. Today "şu an ne var" sorusuna, Habits
/// ızgarası "nelerim var" sorusuna cevap verir; "sürdürüyor muyum" sorusu
/// ikisini de bozmadan yalnızca buraya sığar.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({required this.habitId, super.key});

  final int habitId;

  /// Harita genişliği: 26 hafta, yaklaşık altı ay.
  static const weeks = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitAsync = ref.watch(habitProvider(habitId));
    final logs = ref.watch(habitLogsProvider(habitId)).valueOrNull ?? const [];
    final habit = habitAsync.valueOrNull;

    // Silindi ya da arşivlendi ve akış null'a düştü: sayfa kendini kapatır.
    // Menüdeki eylemden sonra elle pop yapmak yeterli değil; alışkanlık başka
    // yerden de silinebilir (sıfırlama).
    if (habitAsync.hasValue && habit == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
    }

    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      body: SafeArea(
        child: habit == null
            ? const SizedBox.shrink()
            : _Body(
                habit: habit,
                history: HabitHistory.compute(habit, logs, today),
                today: today,
                l: l,
                text: text,
                onMore: () => _showActions(context, ref, habit),
              ),
      ),
    );
  }

  /// Sağ üst menü: düzenle, arşivle, sil. Habits ızgarasından buraya taşındı;
  /// karo artık doğrudan bu sayfayı açıyor.
  void _showActions(BuildContext context, WidgetRef ref, Habit habit) {
    final l = context.l10n;
    final db = ref.read(databaseProvider);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.sm),
            ListTile(
              key: const Key('habit-edit'),
              leading: const Icon(PhosphorIconsRegular.pencilSimple),
              title: Text(l.edit),
              onTap: () {
                Navigator.of(sheet).pop();
                HabitEditorSheet.show(context, existing: habit);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.archive),
              title: Text(l.archive),
              subtitle: Text(l.archiveHint),
              onTap: () {
                Navigator.of(sheet).pop();
                // Arşiv akışı null'a düşürmez (satır durur); sayfa elle kapanır.
                db.archiveHabit(habit.id);
                if (context.canPop()) context.pop();
              },
            ),
            ListTile(
              leading: const Icon(
                PhosphorIconsRegular.trash,
                color: AppColors.overdue,
              ),
              title: Text(
                l.delete,
                style: const TextStyle(color: AppColors.overdue),
              ),
              subtitle: Text(l.deleteHabitHint),
              onTap: () async {
                Navigator.of(sheet).pop();
                final ok = await showDialog<bool>(
                  context: context,
                  useRootNavigator: true,
                  builder: (d) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    title: Text(l.deleteConfirmTitle(habit.name)),
                    content: Text(l.cannotBeUndone),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(false),
                        child: Text(l.cancel),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.overdue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 44),
                        ),
                        onPressed: () => Navigator.of(d).pop(true),
                        child: Text(l.delete),
                      ),
                    ],
                  ),
                );
                if (ok == true) await db.deleteHabit(habit.id);
              },
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.habit,
    required this.history,
    required this.today,
    required this.l,
    required this.text,
    required this.onMore,
  });

  final Habit habit;
  final HabitHistory history;
  final DateTime today;
  final L10n l;
  final TextTheme text;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final color = TilePalette.at(habit.colorIndex);
    final streakText = history.goal == HabitGoal.daily
        ? l.streakDays(history.streak)
        : l.streakWeeks(history.streak);
    final bestText = history.goal == HabitGoal.daily
        ? l.streakDays(history.bestStreak)
        : l.streakWeeks(history.bestStreak);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.xxl),
      children: [
        Row(
          children: [
            CircleButton(
              key: const Key('habit-back'),
              icon: PhosphorIconsRegular.arrowLeft,
              tooltip: l.back,
              onTap: () => context.pop(),
            ),
            const Spacer(),
            CircleButton(
              key: const Key('habit-more'),
              icon: PhosphorIconsRegular.dotsThree,
              tooltip: l.more,
              onTap: onMore,
            ),
          ],
        ),
        const SizedBox(height: Gap.xxl),

        // Kimlik kartı: karonun büyütülmüş hâli. Renk yalnızca burada ve
        // haritanın hücrelerinde; sayfanın geri kalanı nötr.
        Container(
          padding: const EdgeInsets.all(Gap.xl),
          decoration: BoxDecoration(
            color: color.fill,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                HabitIcons.of(habit.icon),
                size: IconSize.xl,
                color: color.ink,
              ),
              const SizedBox(height: Gap.lg),
              Text(
                habit.name,
                style: text.headlineMedium?.copyWith(color: color.ink),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                habitGoalText(l, habit),
                style: text.bodyMedium?.copyWith(
                  color: color.ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.section),

        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(l.history, style: text.titleLarge)),
            Text(
              l.lastMonths(6),
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heatmap(
                key: const Key('habit-heatmap'),
                levelOn: history.levelOn,
                color: color.mark,
                today: today,
                dayLetters: l.dayLetters,
                weeks: HabitDetailScreen.weeks,
                semanticsLabel: l.historyLabel(history.total),
              ),
              if (history.total == 0) ...[
                const SizedBox(height: Gap.md),
                Text(
                  l.historyEmpty,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),

        Row(
          children: [
            _Stat(label: l.streak, value: streakText),
            const SizedBox(width: Gap.md),
            _Stat(label: l.bestStreak, value: bestText),
            const SizedBox(width: Gap.md),
            _Stat(label: l.totalDone, value: '${history.total}'),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleLarge,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              label,
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
