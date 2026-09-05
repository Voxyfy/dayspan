import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/circle_button.dart';
import '../../core/widgets/habit_tile.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../reminders/reminder_field.dart';
import 'habit_icons.dart';
import 'habit_status.dart';

/// Alışkanlık ekleme / düzenleme sayfası.
///
/// Üstte canlı önizleme karosu: kullanıcı renk ve ikonu seçerken sonucu
/// aynı anda görüyor, "kaydet ve bak" döngüsü yok. Alanlar tek sütun, tek
/// kaydet düğmesi.
///
/// Kaydet hiçbir durumda sessizce dönmez. Ad boşsa alan kırmızıya döner ve
/// mesaj çıkar. Ritim 1.0 (3) tam olarak bu yüzden reddedildi: ad boşken
/// "Kaydet" hiçbir şey yapmıyordu ve inceleyici düğmeyi bozuk sandı.
class HabitEditorSheet extends ConsumerStatefulWidget {
  const HabitEditorSheet({this.existing, super.key});

  final Habit? existing;

  /// Kaydedilirse alışkanlık id'sini döndürür.
  static Future<int?> show(BuildContext context, {Habit? existing}) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => HabitEditorSheet(existing: existing),
    );
  }

  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? 'check';
  late int _color = widget.existing?.colorIndex ?? 1;
  late HabitGoal _goal = HabitGoal.values[widget.existing?.goal ?? 0];
  late int _target = widget.existing?.target ?? 1;
  late final Set<int> _days = HabitStatus.daysFromMask(
    widget.existing?.weekdays ?? 0,
  );
  late ReminderMode _reminder =
      ReminderMode.values[widget.existing?.reminder ?? 0];
  // Varsayılan 09:00: sabah özetinden sonra, iş gününden önce.
  late TimeOfDay _remindAt = _fromMinutes(
    widget.existing?.remindAtMinutes ?? 9 * 60,
  );
  String? _nameError;
  bool _saving = false;

  static TimeOfDay _fromMinutes(int m) =>
      TimeOfDay(hour: m ~/ 60, minute: m % 60);

  Future<void> _pickRemindAt() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _remindAt,
    );
    if (picked != null) setState(() => _remindAt = picked);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = context.l10n.habitNameError);
      HapticFeedback.mediumImpact();
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    final patch = HabitsCompanion(
      name: Value(name),
      icon: Value(_icon),
      colorIndex: Value(_color),
      goal: Value(_goal.index),
      // Gün seçildiyse hedef gün sayısıdır; ikisi ayrı sayı olamaz.
      target: Value(
        _goal == HabitGoal.weekly && _days.isNotEmpty ? _days.length : _target,
      ),
      weekdays: Value(
        _goal == HabitGoal.weekly ? HabitStatus.maskFromDays(_days) : 0,
      ),
      reminder: Value(_reminder.index),
      remindAtMinutes: Value(
        _reminder == ReminderMode.off
            ? null
            : _remindAt.hour * 60 + _remindAt.minute,
      ),
    );

    int id;
    if (widget.existing == null) {
      id = await db.addHabit(
        patch.copyWith(sortOrder: Value(await db.nextHabitSortOrder())),
      );
    } else {
      id = widget.existing!.id;
      await db.updateHabit(id, patch);
    }
    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final tile = TilePalette.at(_color);
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            // Kapat düğmesi: sayfa tam yüksekliğe yakın açıldığı için arkadaki
            // perdeye dokunacak yer kalmıyor ve klavye açıkken aşağı kaydırma
            // metin alanına gidiyor. Vazgeçmenin görünür bir yolu olmalı.
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null ? l.newHabit : l.editHabit,
                    style: text.headlineMedium,
                  ),
                ),
                CircleButton(
                  key: const Key('editor-close'),
                  icon: PhosphorIconsRegular.x,
                  tooltip: l.cancel,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            // Önizleme. Genişlik ızgaradaki karoyla aynı olsun diye ekranın
            // yarısı; tam genişlik karo ızgarada hiç görünmeyen bir biçim.
            Center(
              child: SizedBox(
                width: 180,
                height: 200,
                child: HabitTile(
                  name: _name.text.trim().isEmpty
                      ? l.habitNamePlaceholder
                      : _name.text.trim(),
                  icon: HabitIcons.of(_icon),
                  color: tile,
                  subtitle: _goal == HabitGoal.daily
                      ? l.dailyProgress(0, _target)
                      : l.weeklyProgress(0, _target),
                  week: const [true, true, false, false, false, false, false],
                  scheduled: _goal == HabitGoal.weekly && _days.isNotEmpty
                      ? [for (var d = 0; d < 7; d++) _days.contains(d)]
                      : null,
                  doneToday: false,
                  onToggle: () {},
                  onOpen: () {},
                ),
              ),
            ),
            const SizedBox(height: Gap.section),

            _Label(l.fieldName),
            TextField(
              key: const Key('habit-name'),
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              onChanged: (_) => setState(() => _nameError = null),
              onSubmitted: (_) => _save(),
              style: text.bodyMedium,
              decoration: _fieldDecoration(l.habitNameHint, error: _nameError),
            ),
            const SizedBox(height: Gap.xl),

            _Label(l.fieldColor),
            Wrap(
              spacing: Gap.md,
              runSpacing: Gap.md,
              children: [
                for (var i = 0; i < TilePalette.colors.length; i++)
                  _ColorDot(
                    name: tileColorName(l, i),
                    color: TilePalette.colors[i],
                    selected: i == _color,
                    onTap: () => setState(() => _color = i),
                  ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            _Label(l.fieldIcon),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final (name, icon) in HabitIcons.entries)
                  _IconChip(
                    icon: icon,
                    selected: name == _icon,
                    onTap: () => setState(() => _icon = name),
                  ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            _Label(l.fieldGoal),
            Row(
              children: [
                _GoalChip(
                  label: l.goalDaily,
                  selected: _goal == HabitGoal.daily,
                  onTap: () => setState(() {
                    _goal = HabitGoal.daily;
                    _target = 1;
                  }),
                ),
                const SizedBox(width: Gap.sm),
                _GoalChip(
                  label: l.goalWeekly,
                  selected: _goal == HabitGoal.weekly,
                  onTap: () => setState(() {
                    _goal = HabitGoal.weekly;
                    _target = 3;
                  }),
                ),
                const Spacer(),
                // Gün seçildiyse sayaç gizlenir: hedef gün sayısından gelir.
                if (!(_goal == HabitGoal.weekly && _days.isNotEmpty))
                  _Stepper(
                    value: _target,
                    min: 1,
                    max: _goal == HabitGoal.daily ? 20 : 7,
                    onChanged: (v) => setState(() => _target = v),
                  ),
              ],
            ),
            if (_goal == HabitGoal.weekly) ...[
              const SizedBox(height: Gap.md),
              _WeekdayPicker(
                selected: _days,
                onToggle: (d) => setState(() {
                  _days.contains(d) ? _days.remove(d) : _days.add(d);
                  if (_days.isNotEmpty) _target = _days.length;
                }),
              ),
            ],
            const SizedBox(height: Gap.xs),
            Text(
              _goal == HabitGoal.daily
                  ? (_target == 1 ? l.dailyOnce : l.dailyTimes(_target))
                  : (_days.isEmpty
                        ? l.weeklyDays(_target)
                        : l.weeklyPickedDays(_days.length)),
              style: text.bodySmall,
            ),
            const SizedBox(height: Gap.xl),

            ReminderField(
              mode: _reminder,
              onChanged: (m) => setState(() => _reminder = m),
              hint: switch (_reminder) {
                ReminderMode.off => l.reminderOffHint,
                ReminderMode.notify => l.reminderHabitHint,
                ReminderMode.alarm => l.reminderAlarmHint,
              },
              extras: [
                ReminderChip(
                  key: const Key('reminder-time'),
                  icon: PhosphorIconsRegular.clock,
                  label: _remindAt.format(context),
                  selected: false,
                  onTap: _pickRemindAt,
                ),
              ],
            ),
            const SizedBox(height: Gap.section),

            FilledButton(
              key: const Key('habit-save'),
              onPressed: _saving ? null : _save,
              child: Text(widget.existing == null ? l.addHabit : l.save),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, {String? error}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.sm + 4),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      errorText: error,
      counterText: '',
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: 14,
      ),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppColors.accent, 1.5),
      errorBorder: border(AppColors.overdue, 1.5),
      focusedErrorBorder: border(AppColors.overdue, 1.5),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final TileColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: name,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.hairline,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  PhosphorIconsBold.check,
                  size: IconSize.sm,
                  color: color.ink,
                )
              : null,
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: IconSize.md,
          color: selected ? AppColors.onAccent : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onAccent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, bool enabled, int delta) => GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged(value + delta);
            }
          : null,
      child: SizedBox.square(
        dimension: 40,
        child: Center(
          child: Icon(
            icon,
            size: IconSize.md,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(PhosphorIconsRegular.minus, value > min, -1),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AppColors.textPrimary,
              ),
            ),
          ),
          button(PhosphorIconsRegular.plus, value < max, 1),
        ],
      ),
    );
  }
}

/// Haftanın günleri: yedi daire, seçili olan dolu. Hiçbiri seçili değilse
/// "herhangi gün" anlamına gelir; boş küme geçerli bir cevap.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final letters = context.l10n.dayLetters.characters.toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var d = 0; d < 7; d++)
          Semantics(
            key: Key('weekday-$d'),
            selected: selected.contains(d),
            button: true,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(d);
              },
              child: AnimatedContainer(
                duration: Motion.quick,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected.contains(d)
                      ? AppColors.accent
                      : AppColors.surface,
                ),
                alignment: Alignment.center,
                child: Text(
                  d < letters.length ? letters[d] : '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected.contains(d)
                        ? AppColors.onAccent
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
