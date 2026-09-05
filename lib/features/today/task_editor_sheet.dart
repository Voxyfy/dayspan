import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/circle_button.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../reminders/reminder_field.dart';

/// Görev ekleme / düzenleme.
///
/// Üç alan: başlık, gün, isteğe bağlı saat ve süre. Saat verilirse görev
/// akışta takvim etkinlikleri arasında blok olur; verilmezse günün
/// "işler" listesinde durur. Not alanı var ama katlanmış: yoğun insan görevi
/// üç saniyede girer, not istisnadır.
///
/// Kaydet boş başlıkta sessiz kalmaz; görünür hata verir.
class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({this.existing, this.initialDay, super.key});

  final Task? existing;
  final DateTime? initialDay;

  static Future<int?> show(
    BuildContext context, {
    Task? existing,
    DateTime? day,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => TaskEditorSheet(existing: existing, initialDay: day),
    );
  }

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _day = _dateOnly(
    widget.existing?.dueOn ?? widget.initialDay ?? DateTime.now(),
  );
  late TimeOfDay? _time = widget.existing?.startAt == null
      ? null
      : TimeOfDay.fromDateTime(widget.existing!.startAt!);
  late int _duration = widget.existing?.durationMinutes ?? 30;
  late ReminderMode _reminder =
      ReminderMode.values[widget.existing?.reminder ?? 0];
  late int _lead = widget.existing?.reminderLeadMinutes ?? 0;
  bool _noteOpen = false;
  String? _titleError;
  bool _saving = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _noteOpen = (widget.existing?.note ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = context.l10n.taskTitleError);
      HapticFeedback.mediumImpact();
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    final startAt = _time == null
        ? null
        : DateTime(_day.year, _day.month, _day.day, _time!.hour, _time!.minute);
    final note = _note.text.trim();
    final patch = TasksCompanion(
      title: Value(title),
      note: Value(note.isEmpty ? null : note),
      dueOn: Value(_day),
      startAt: Value(startAt),
      durationMinutes: Value(_time == null ? null : _duration),
      // Saat kaldırılırsa hatırlatıcı da düşer; saatsiz işe bildirim kurulamaz.
      reminder: Value(_time == null ? ReminderMode.off.index : _reminder.index),
      reminderLeadMinutes: Value(_lead),
    );

    final db = ref.read(databaseProvider);
    final int id;
    if (widget.existing == null) {
      id = await db.addTask(patch);
    } else {
      id = widget.existing!.id;
      await db.updateTask(id, patch);
    }
    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _day = _dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));

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
                    widget.existing == null ? l.newTask : l.editTask,
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

            TextField(
              key: const Key('task-title'),
              controller: _title,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              onChanged: (_) => setState(() => _titleError = null),
              onSubmitted: (_) => _save(),
              style: text.bodyMedium,
              decoration: _fieldDecoration(l.taskTitleHint, error: _titleError),
            ),
            const SizedBox(height: Gap.xl),

            _Label(l.fieldDay),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                _Chip(
                  label: l.dayToday,
                  selected: _day == today,
                  onTap: () => setState(() => _day = today),
                ),
                _Chip(
                  label: l.dayTomorrow,
                  selected: _day == tomorrow,
                  onTap: () => setState(() => _day = tomorrow),
                ),
                _Chip(
                  icon: PhosphorIconsRegular.calendarBlank,
                  label: _day == today || _day == tomorrow
                      ? l.pickDate
                      : DateFormat('EEE, d MMM').format(_day),
                  selected: _day != today && _day != tomorrow,
                  onTap: _pickDay,
                ),
              ],
            ),
            const SizedBox(height: Gap.xl),

            _Label(l.fieldTime),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Chip(
                  label: l.anytime,
                  selected: _time == null,
                  onTap: () => setState(() => _time = null),
                ),
                _Chip(
                  icon: PhosphorIconsRegular.clock,
                  label: _time == null ? l.setTime : _time!.format(context),
                  selected: _time != null,
                  onTap: _pickTime,
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(
              _time == null ? l.anytimeHint : l.timedHint,
              style: text.bodySmall,
            ),
            if (_time != null) ...[
              const SizedBox(height: Gap.xl),
              // Süre yalnızca saat verilmişse anlamlı: akıştaki bloğun boyu.
              _Label(l.fieldDuration),
              _DurationChips(
                value: _duration,
                onChanged: (v) => setState(() => _duration = v),
              ),
              const SizedBox(height: Gap.xl),
              ReminderField(
                mode: _reminder,
                onChanged: (m) => setState(() => _reminder = m),
                hint: switch (_reminder) {
                  ReminderMode.off => l.reminderOffHint,
                  ReminderMode.notify => l.reminderTaskHint,
                  ReminderMode.alarm => l.reminderAlarmHint,
                },
                extras: [
                  for (final m in const [0, 10, 30])
                    ReminderChip(
                      key: Key('reminder-lead-$m'),
                      label: m == 0 ? l.leadAtTime : l.leadMinutesBefore(m),
                      selected: _lead == m,
                      onTap: () => setState(() => _lead = m),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Gap.xl),

            if (!_noteOpen)
              GestureDetector(
                onTap: () => setState(() => _noteOpen = true),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.plus,
                      size: IconSize.sm,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(l.addNote, style: text.bodySmall),
                  ],
                ),
              )
            else ...[
              _Label(l.fieldNote),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: text.bodyMedium,
                decoration: _fieldDecoration(l.noteHint),
              ),
            ],
            const SizedBox(height: Gap.section),

            FilledButton(
              key: const Key('task-save'),
              onPressed: _saving ? null : _save,
              child: Text(widget.existing == null ? l.addTask : l.save),
            ),
            // Kaydırma hareketi panoda yok (ızgara), bu yüzden ikincil
            // eylemler burada: yarına al ve sil.
            if (widget.existing != null) ...[
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const Key('task-tomorrow'),
                      onPressed: () async {
                        await ref
                            .read(databaseProvider)
                            .pushTaskToTomorrow(widget.existing!.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        PhosphorIconsRegular.arrowBendUpRight,
                        size: IconSize.sm,
                      ),
                      label: Text(l.moveToTomorrow),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      key: const Key('task-delete'),
                      onPressed: () async {
                        await ref
                            .read(databaseProvider)
                            .deleteTask(widget.existing!.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        PhosphorIconsRegular.trash,
                        size: IconSize.sm,
                      ),
                      label: Text(l.delete),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.overdue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: Text(text, style: Theme.of(context).textTheme.labelSmall),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? AppColors.onAccent : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: IconSize.sm, color: ink),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "15 min" / "1.5 h" — dil dosyasından; ondalık ayracı da dile göre
/// ("1.5" / "1,5").
String _durationLabel(BuildContext context, int minutes) {
  final l = context.l10n;
  if (minutes < 60) return l.durationMinutes(minutes);
  final hours = minutes / 60;
  final text = hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : NumberFormat(
          '0.#',
          Localizations.localeOf(context).toString(),
        ).format(hours);
  return l.durationHours(text);
}

class _DurationChips extends StatelessWidget {
  const _DurationChips({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    // Beş seçenek tek satırda, eşit genişlikte. Wrap ile son çip alt satıra
    // tek başına düşüyordu; hap seçici yarım kalmış gibi duruyordu.
    return Row(
      children: [
        for (final (i, m) in _options.indexed) ...[
          if (i > 0) const SizedBox(width: Gap.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: Motion.quick,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == m ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text(
                  _durationLabel(context, m),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: value == m
                        ? AppColors.onAccent
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
