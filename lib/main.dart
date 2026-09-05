import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/locale.dart';
import 'core/notifications.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/watch_bridge.dart';
import 'core/widget_bridge.dart';
import 'features/brief/morning_brief.dart';
import 'features/onboarding/onboarding_state.dart';
import 'features/reminders/reminder_scheduler.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // Türkçe ay ve gün adları için; İngilizce zaten yüklü.
  await initializeDateFormatting('tr');

  // Servisler yalnızca burada uyandırılır; testler sessiz örnekle çalışır.
  final notifications = NotificationService();
  await notifications.initialize();
  await WidgetBridge.setup();
  final onboarded = await OnboardingState.isDone();

  runApp(
    ProviderScope(
      overrides: [notificationServiceProvider.overrideWithValue(notifications)],
      child: DayspanApp(onboarded: onboarded),
    ),
  );
}

class DayspanApp extends ConsumerStatefulWidget {
  const DayspanApp({required this.onboarded, super.key});

  final bool onboarded;

  @override
  ConsumerState<DayspanApp> createState() => _DayspanAppState();
}

class _DayspanAppState extends ConsumerState<DayspanApp> {
  // Yönlendirici bir kez kurulur; her yeniden çizimde kurulsa gezinti
  // geçmişi sıfırlanırdı.
  late final router = buildRouter(onboarded: widget.onboarded);

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    // İki yan etki sağlayıcısı: veri değişince widget'ı yazar ve sabah
    // özetini yeniden kurar. Burada izlenmeleri hayatta kalmalarını sağlar.
    ref.watch(widgetPublisherProvider);
    ref.watch(watchPublisherProvider);
    ref.watch(morningBriefSchedulerProvider);
    ref.watch(reminderSchedulerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppLocales.all,
      localizationsDelegates: L10n.localizationsDelegates,
      routerConfig: router,
    );
  }
}
