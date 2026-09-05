import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarms.dart';
import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../data/db/tables.dart';

/// Düzenleyicilerdeki "Hatırlatıcı" seçici: Kapalı / Bildir, yanında
/// düzenleyiciye özgü ek çipler (iş: ne kadar önce; alışkanlık: saat).
///
/// Bildir seçilirken bildirim izni istenir; verilmezse seçim geri düşer ve
/// yol gösteren mesaj çıkar. Açık görünen ama hiç gelmeyen bir hatırlatıcı,
/// en kötü sonuç. "Alarm" çipi yalnızca AlarmKit destekleniyorsa (iOS 26+)
/// çizilir; onun izni ayrı istenir.
class ReminderField extends ConsumerWidget {
  const ReminderField({
    required this.mode,
    required this.onChanged,
    required this.hint,
    this.extras = const [],
    super.key,
  });

  final ReminderMode mode;
  final ValueChanged<ReminderMode> onChanged;

  /// Seçime göre alt açıklama.
  final String hint;

  /// Bildir açıkken çiplerin sağına eklenen düzenleyiciye özgü çipler.
  final List<Widget> extras;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    ReminderMode m,
  ) async {
    if (m == mode) return;
    final l = context.l10n;
    final granted = switch (m) {
      ReminderMode.off => true,
      ReminderMode.notify =>
        await ref.read(notificationServiceProvider).requestPermission(),
      ReminderMode.alarm =>
        await ref.read(alarmServiceProvider).requestAuthorization(),
    };
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            m == ReminderMode.alarm ? l.alarmsDenied : l.notificationsDenied,
          ),
        ),
      );
      return;
    }
    onChanged(m);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final alarms = ref.watch(alarmsSupportedProvider).valueOrNull ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Text(l.fieldReminder, style: text.labelSmall),
        ),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ReminderChip(
              key: const Key('reminder-off'),
              label: l.reminderOff,
              selected: mode == ReminderMode.off,
              onTap: () => _pick(context, ref, ReminderMode.off),
            ),
            ReminderChip(
              key: const Key('reminder-notify'),
              label: l.reminderNotify,
              selected: mode == ReminderMode.notify,
              onTap: () => _pick(context, ref, ReminderMode.notify),
            ),
            if (alarms)
              ReminderChip(
                key: const Key('reminder-alarm'),
                label: l.reminderAlarm,
                selected: mode == ReminderMode.alarm,
                onTap: () => _pick(context, ref, ReminderMode.alarm),
              ),
            if (mode != ReminderMode.off) ...extras,
          ],
        ),
        const SizedBox(height: Gap.xs),
        Text(hint, style: text.bodySmall),
      ],
    );
  }
}

/// Düzenleyicilerdeki hap çipin aynısı; iki dosyada kopya durmasın diye
/// buraya alındı, ikisi de bunu kullanır.
class ReminderChip extends StatelessWidget {
  const ReminderChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
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
