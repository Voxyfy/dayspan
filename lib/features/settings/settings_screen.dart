import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brief/brief_settings.dart';
import 'celebration_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final locale = ref.watch(localeProvider);
    final brief = ref.watch(briefSettingsProvider);
    final celebrations = ref.watch(celebrationsProvider);
    final briefTime = TimeOfDay(hour: brief.hour, minute: 0).format(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            Gap.listBottom,
          ),
          children: [
            Text(l.settingsTitle, style: text.headlineLarge),
            const SizedBox(height: Gap.xxl),
            _Row(
              icon: PhosphorIconsRegular.calendarBlank,
              title: l.connectCalendar,
              subtitle: l.connectCalendarHint,
              onTap: () async {
                final ok = await ref
                    .read(calendarServiceProvider)
                    .ensurePermission();
                ref.invalidate(todayEventsProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? l.calendarConnected : l.permissionDenied,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: Gap.sm),
            _Row(
              key: const Key('settings-brief'),
              icon: PhosphorIconsRegular.sunHorizon,
              title: l.morningBrief,
              subtitle: brief.enabled
                  ? l.morningBriefAt(briefTime)
                  : l.morningBriefOff,
              trailing: Switch(
                key: const Key('settings-brief-switch'),
                value: brief.enabled,
                activeThumbColor: AppColors.onAccent,
                activeTrackColor: AppColors.accent,
                onChanged: (value) => _toggleBrief(context, ref, value),
              ),
              onTap: brief.enabled
                  ? () => _pickBriefHour(context, ref, brief.hour)
                  : null,
            ),
            const SizedBox(height: Gap.sm),
            _Row(
              icon: PhosphorIconsRegular.squaresFour,
              title: l.homeWidget,
              subtitle: l.homeWidgetHint,
              onTap: null,
            ),
            const SizedBox(height: Gap.sm),
            _Row(
              key: const Key('settings-celebrations'),
              icon: PhosphorIconsRegular.confetti,
              title: l.celebrations,
              subtitle: l.celebrationsHint,
              trailing: Switch(
                key: const Key('settings-celebrations-switch'),
                value: celebrations,
                activeThumbColor: AppColors.onAccent,
                activeTrackColor: AppColors.accent,
                onChanged: (v) =>
                    ref.read(celebrationsProvider.notifier).set(v),
              ),
              onTap: () =>
                  ref.read(celebrationsProvider.notifier).set(!celebrations),
            ),
            const SizedBox(height: Gap.sm),
            _Row(
              key: const Key('settings-language'),
              icon: PhosphorIconsRegular.translate,
              title: l.language,
              subtitle: AppLocales.nativeName(locale),
              onTap: () => _pickLanguage(context, ref, locale),
            ),
            const SizedBox(height: Gap.section),
            _Row(
              key: const Key('settings-reset'),
              icon: PhosphorIconsRegular.arrowCounterClockwise,
              title: l.resetApp,
              subtitle: l.resetAppHint,
              onTap: () => _confirmReset(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// "Baştan başla": onay penceresi, sonra veritabanı ve ayarlar silinir,
  /// uygulama ilk açılış akışına döner. Onay penceresi Ritim'deki düzen:
  /// soluk vazgeç, kırmızı dolu eylem. Takvime dokunulmaz; o veri bizim değil.
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        title: Text(l.resetConfirmTitle),
        content: Text(l.resetConfirmBody),
        actionsPadding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        actions: [
          TextButton(
            key: const Key('reset-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(
              l.cancel,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            key: const Key('reset-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.overdue,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.resetConfirmAction),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(notificationServiceProvider).cancelMorningBrief();
    await ref.read(databaseProvider).resetAll();
    // Dil korunur: kullanıcı Türkçe seçmişse ilk açılış akışı da Türkçe
    // açılmalı. "Baştan başla" veriyi siler, kullanıcının kimliğini değil.
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString(AppLocales.key);
    await prefs.clear();
    if (language != null) await prefs.setString(AppLocales.key, language);
    // Bellekteki özet ayarı da silinen tercihlerle aynı hizaya gelsin.
    ref.invalidate(briefSettingsProvider);
    ref.invalidate(celebrationsProvider);
    if (!context.mounted) return;
    context.go(Routes.onboarding);
  }

  /// Özeti açarken bildirim izni istenir; reddedilirse anahtar geri düşer ve
  /// yol gösteren bir mesaj çıkar. Sessizce açık görünen ama hiç gelmeyen bir
  /// bildirim, en kötü sonuç.
  Future<void> _toggleBrief(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l = context.l10n;
    if (!value) {
      await ref.read(briefSettingsProvider.notifier).setEnabled(false);
      return;
    }
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.notificationsDenied)));
      return;
    }
    await ref.read(briefSettingsProvider.notifier).setEnabled(true);
  }

  Future<void> _pickBriefHour(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current, minute: 0),
    );
    if (picked == null) return;
    await ref.read(briefSettingsProvider.notifier).setHour(picked.hour);
  }

  /// Dil seçici. Diller kendi adıyla yazılır ve çevrilmez: yanlış dile
  /// düşen kullanıcı kendi dilinin adını her durumda tanır.
  void _pickLanguage(BuildContext context, WidgetRef ref, Locale current) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.sm),
            for (final locale in AppLocales.all)
              ListTile(
                key: Key('lang-${locale.languageCode}'),
                title: Text(AppLocales.nativeName(locale)),
                trailing: locale == current
                    ? const Icon(
                        PhosphorIconsBold.check,
                        color: AppColors.accent,
                      )
                    : null,
                onTap: () {
                  Navigator.of(sheet).pop();
                  ref.read(localeProvider.notifier).set(locale);
                },
              ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Sağdaki öğe; boşsa ve satır dokunulabilirse ok çizilir.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Icon(
                      icon,
                      size: IconSize.md,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(
                  PhosphorIconsRegular.caretRight,
                  size: IconSize.md,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
