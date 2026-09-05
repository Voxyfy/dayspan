import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/habit_tile.dart';
import '../../core/widgets/task_tile.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../l10n/app_localizations.dart';
import '../brief/brief_settings.dart';
import '../habits/habit_icons.dart';
import 'onboarding_state.dart';

/// İlk açılış: üç sayfa, tek düğme.
///
/// 1. Vaat: günün tek ekranı, hesap yok. Karolar gerçek bileşenlerle
///    çizilir; ekran görüntüsü yerine bileşen, çünkü çeviri ve renk kuralı
///    kendiliğinden geçerli kalır.
/// 2. Takvim izni: sistem penceresi çıkmadan önce ne için istendiği yazılır.
///    İlk açılışta bağlamsız çıkan izin reddediliyor ve iOS bir daha sormuyor.
/// 3. Hatırlatıcılar: örnek bildirim, izin isteği. Takvimle aynı ilke: önce
///    ne için olduğu, sonra sistem penceresi.
/// 4. İlk alışkanlıklar: dört öneri, seçilenler kaydedilir; kullanıcı dolu
///    bir panoyla başlar.
///
/// Her sayfada görünür bir "atla" var: kullanıcı akıştan istediği an çıkar.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 4;

  final _controller = PageController();
  var _page = 0;
  final _picked = <_Suggestion>{};
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      HapticFeedback.selectionClick();
      await _controller.nextPage(duration: Motion.slow, curve: Motion.curve);
      return;
    }
    await _finish();
  }

  /// Takvim izni istenir, sonucu ne olursa olsun akış ilerler. Reddedilirse
  /// Ayarlar'daki "Takvimi bağla" satırı hâlâ orada; burada ısrar etmiyoruz.
  Future<void> _connectCalendar() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(calendarServiceProvider).ensurePermission();
      ref.invalidate(todayEventsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await _next();
  }

  /// Bildirim izni istenir, sonucu ne olursa olsun akış ilerler. Hatırlatıcı
  /// düzenleyicide açılırken izin bir daha kontrol edilir.
  Future<void> _allowNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await _next();
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.l10n;
    final db = ref.read(databaseProvider);
    var order = await db.nextHabitSortOrder();
    for (final s in _Suggestion.values.where(_picked.contains)) {
      await db.addHabit(
        HabitsCompanion.insert(
          name: s.label(l),
          icon: Value(s.icon),
          colorIndex: Value(s.colorIndex),
          goal: Value(HabitGoal.daily.index),
          target: Value(s.target),
          sortOrder: Value(order++),
        ),
      );
    }
    await OnboardingState.markDone();
    if (!mounted) return;
    context.go(Routes.today);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Üst satır: ilerleme noktaları solda, atla sağda. Atla her
            // sayfada aynı yerde; kullanıcı aramaz.
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.sm, 0),
              child: Row(
                children: [
                  _Dots(count: _pageCount, index: _page),
                  const Spacer(),
                  TextButton(
                    key: const Key('onboarding-skip'),
                    onPressed: _busy ? null : _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(l.onboardingSkip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _WelcomePage(),
                  _CalendarPage(busy: _busy, onConnect: _connectCalendar),
                  _RemindersPage(busy: _busy, onAllow: _allowNotifications),
                  _HabitsPage(
                    picked: _picked,
                    onToggle: (s) => setState(() {
                      HapticFeedback.selectionClick();
                      _picked.contains(s) ? _picked.remove(s) : _picked.add(s);
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.lg,
              ),
              child: FilledButton(
                key: const Key('onboarding-next'),
                onPressed: _busy ? null : _next,
                child: Text(switch (_page) {
                  0 => l.onboardingContinue,
                  1 || 2 => l.onboardingNotNow,
                  _ =>
                    _picked.isEmpty
                        ? l.onboardingStart
                        : l.onboardingStartWith(_picked.length),
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.curve,
            width: i == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? AppColors.accent : AppColors.hairline,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
          if (i < count - 1) const SizedBox(width: Gap.xs),
        ],
      ],
    );
  }
}

/// Sayfa iskeleti: üstte görsel alan, altta başlık ve açıklama. Metin altta,
/// çünkü baş parmak düğmeye giderken göz son olarak metni okur.
class _Page extends StatelessWidget {
  const _Page({
    required this.visual,
    required this.title,
    required this.body,
    this.footer,
  });

  final Widget visual;
  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          visual,
          const SizedBox(height: Gap.section),
          Text(title, style: text.headlineMedium),
          const SizedBox(height: Gap.md),
          Text(
            body,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (footer != null) ...[const SizedBox(height: Gap.xl), footer!],
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final week = [true, true, false, true, true, false, false];
    // Dokunulmayan örnek karolar: onboarding'de karoya dokunup "niye
    // işlemedi" denmesin.
    return _Page(
      visual: IgnorePointer(
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Gap.md,
          crossAxisSpacing: Gap.md,
          childAspectRatio: 0.88,
          children: [
            HabitTile(
              name: l.suggestWater,
              icon: HabitIcons.of('drop'),
              color: TilePalette.at(9),
              subtitle: l.dailyProgress(3, 8),
              week: week,
              doneToday: false,
              onToggle: () {},
              onOpen: () {},
            ),
            TaskTile(
              title: l.onboardingSampleTask,
              subtitle: '14:00',
              done: false,
              onToggle: () {},
              onOpen: () {},
            ),
            HabitTile(
              name: l.suggestRead,
              icon: HabitIcons.of('bookOpen'),
              color: TilePalette.at(3),
              subtitle: l.dailyProgress(1, 1),
              week: week,
              doneToday: true,
              onToggle: () {},
              onOpen: () {},
            ),
            HabitTile(
              name: l.suggestWalk,
              icon: HabitIcons.of('personSimpleWalk'),
              color: TilePalette.at(1),
              subtitle: l.dailyProgress(0, 1),
              week: week,
              doneToday: false,
              onToggle: () {},
              onOpen: () {},
            ),
          ],
        ),
      ),
      title: l.onboardingWelcomeTitle,
      body: l.onboardingWelcomeBody,
      footer: _Badge(
        icon: PhosphorIconsRegular.lockSimple,
        text: l.onboardingPrivacy,
      ),
    );
  }
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage({required this.busy, required this.onConnect});

  final bool busy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    return _Page(
      // Takvim akışının kendisi: iki soluk blok, biri "Now" rozetli. Today
      // ekranındaki bloğun aynısı; kullanıcı ne alacağını görüyor.
      visual: Column(
        children: [
          _FakeEvent(title: l.onboardingSampleEvent1, time: '09:30 – 10:00'),
          const SizedBox(height: Gap.md),
          _FakeEvent(
            title: l.onboardingSampleEvent2,
            time: '11:00 – 12:00',
            live: true,
          ),
        ],
      ),
      title: l.onboardingCalendarTitle,
      body: l.onboardingCalendarBody,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('onboarding-connect'),
            onPressed: busy ? null : onConnect,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
            ),
            icon: const Icon(PhosphorIconsRegular.calendarBlank),
            label: Text(l.connectCalendar),
          ),
          const SizedBox(height: Gap.md),
          Text(
            l.onboardingCalendarNote,
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FakeEvent extends StatelessWidget {
  const _FakeEvent({
    required this.title,
    required this.time,
    this.live = false,
  });

  final String title;
  final String time;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
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
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(time, style: text.bodySmall),
              ],
            ),
          ),
          if (live)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}

class _RemindersPage extends ConsumerWidget {
  const _RemindersPage({required this.busy, required this.onAllow});

  final bool busy;
  final VoidCallback onAllow;

  /// Sabah özeti anahtarı: açılırken bildirim izni istenir; verilmezse
  /// anahtar kapalı kalır ve mesaj çıkar (Ayarlar'daki akışın aynısı).
  Future<void> _toggleBrief(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l = context.l10n;
    final brief = ref.read(briefSettingsProvider.notifier);
    if (!value) return brief.setEnabled(false);
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
    await brief.setEnabled(true);
  }

  Future<void> _pickHour(BuildContext context, WidgetRef ref, int hour) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: 0),
    );
    if (picked == null) return;
    await ref.read(briefSettingsProvider.notifier).setHour(picked.hour);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final brief = ref.watch(briefSettingsProvider);
    final briefTime = TimeOfDay(hour: brief.hour, minute: 0).format(context);
    return _Page(
      // Kilit ekranındaki bildirim gibi iki kart: biri iş (saatinden önce),
      // biri alışkanlık. Kullanıcı neye izin vereceğini görüyor.
      visual: Column(
        children: [
          _FakeNotification(
            title: l.onboardingSampleTask,
            body: l.taskReminderBodySoon(10, '14:00'),
          ),
          const SizedBox(height: Gap.md),
          _FakeNotification(title: l.suggestWater, body: l.habitReminderBody),
        ],
      ),
      title: l.onboardingRemindersTitle,
      body: l.onboardingRemindersBody,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sabah özeti: günün tek toplu bildirimi. Varsayılan kapalı, saat
          // 08:00; kullanıcı burada açar ve saatini seçer.
          Container(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.sunHorizon,
                  size: IconSize.md,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.morningBrief,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        key: const Key('onboarding-brief-time'),
                        onTap: () => _pickHour(context, ref, brief.hour),
                        child: Text(
                          l.morningBriefAt(briefTime),
                          style: text.bodySmall?.copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('onboarding-brief-switch'),
                  value: brief.enabled,
                  activeThumbColor: AppColors.onAccent,
                  activeTrackColor: AppColors.accent,
                  onChanged: (v) => _toggleBrief(context, ref, v),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            key: const Key('onboarding-notifications'),
            onPressed: busy ? null : onAllow,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
            ),
            icon: const Icon(PhosphorIconsRegular.bellSimple),
            label: Text(l.allowNotifications),
          ),
          const SizedBox(height: Gap.md),
          Text(
            l.onboardingRemindersNote,
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// iOS bildirim kartının sadeleştirilmiş hâli: sol üstte uygulama karesi,
/// yanında ad ve "şimdi", altında başlık ve gövde.
class _FakeNotification extends StatelessWidget {
  const _FakeNotification({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(Gap.tile),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  PhosphorIconsFill.checkCircle,
                  size: 12,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                l.appName.toUpperCase(),
                style: text.labelSmall?.copyWith(letterSpacing: 0.6),
              ),
              const Spacer(),
              Text(l.onboardingSampleNow, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 2),
          Text(body, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Önerilen ilk alışkanlıklar. Dört tane: ekrana kaydırmasız sığan, herkesin
/// en az birini istediği şeyler. Adlar ARB'den gelir, veritabanına seçili
/// dilde yazılır; kullanıcı sonra düzenleyebilir.
enum _Suggestion {
  water('drop', 9, 8),
  walk('personSimpleWalk', 1, 1),
  read('bookOpen', 3, 1),
  sleep('moon', 2, 1);

  const _Suggestion(this.icon, this.colorIndex, this.target);

  final String icon;
  final int colorIndex;
  final int target;

  /// Çevrilmiş ad. `name` değil: enum'un yerleşik `name` alanı anahtarlarda
  /// kullanılıyor.
  String label(L10n l) => switch (this) {
    water => l.suggestWater,
    walk => l.suggestWalk,
    read => l.suggestRead,
    sleep => l.suggestSleep,
  };
}

class _HabitsPage extends StatelessWidget {
  const _HabitsPage({required this.picked, required this.onToggle});

  final Set<_Suggestion> picked;
  final ValueChanged<_Suggestion> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Page(
      visual: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Gap.md,
        crossAxisSpacing: Gap.md,
        childAspectRatio: 1.4,
        children: [
          for (final s in _Suggestion.values)
            _PickTile(
              key: Key('onboarding-suggest-${s.name}'),
              suggestion: s,
              selected: picked.contains(s),
              onTap: () => onToggle(s),
            ),
        ],
      ),
      title: l.onboardingHabitsTitle,
      body: l.onboardingHabitsBody,
    );
  }
}

/// Seçilebilir öneri karosu. Seçilince renge boyanır, seçilmemişken grafit:
/// karo rengi "bende var" demek, onboarding'de de aynı dili konuşuyor.
class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.suggestion,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _Suggestion suggestion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? TilePalette.at(suggestion.colorIndex)
        : TilePalette.neutral;
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.curve,
      decoration: BoxDecoration(
        color: color.fill,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Padding(
            padding: const EdgeInsets.all(Gap.tile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      HabitIcons.of(suggestion.icon),
                      size: IconSize.lg,
                      color: color.ink,
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsRegular.circle,
                      size: IconSize.lg,
                      color: selected
                          ? color.ink
                          : color.ink.withValues(alpha: 0.35),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  suggestion.label(context.l10n),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: color.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: IconSize.sm, color: AppColors.textTertiary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
