import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dayspan/core/locale.dart';
import 'package:dayspan/core/notifications.dart';
import 'package:dayspan/core/providers.dart';
import 'package:dayspan/core/router.dart';
import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/features/onboarding/onboarding_screen.dart';
import 'package:dayspan/features/onboarding/onboarding_state.dart';
import 'package:dayspan/features/settings/settings_screen.dart';
import 'package:dayspan/l10n/app_localizations.dart';

/// İzin veren sahte bildirim servisi; gerçek eklenti test ortamında yok.
class _GrantingNotifications extends NotificationService {
  @override
  Future<bool> requestPermission() async => true;
}

/// İlk açılış akışı: sayfalar ilerler, seçilen öneriler kaydedilir, bayrak
/// yazılır; sıfırlama her şeyi silip akışa geri döner.
void main() {
  late DayspanDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = DayspanDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  /// Drift sökülürken sıfır süreli zamanlayıcı bırakıyor; ağaç kapatılır.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Gerçek yönlendiriciyle kurulur: akışın sonundaki `go` ve sıfırlamanın
  /// onboarding'e dönüşü rota üzerinden doğrulanır. Sekme ekranları takvim
  /// eklentisine dokunmaz; izin yalnızca sorgulanır ve testte yok sayılır.
  /// Yönlendirici bir kez kurulur (uygulamadaki gibi); dil değişiminde
  /// yeniden kurulsa gezinti sıfırlanır ve sıfırlama testi boşa düşer.
  Widget app({required bool onboarded}) {
    final router = buildRouter(onboarded: onboarded);
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(_GrantingNotifications()),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.dark(),
          locale: ref.watch(localeProvider),
          supportedLocales: AppLocales.all,
          localizationsDelegates: L10n.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('bayrak yokken akış açılır, varken Today', (tester) async {
    await tester.pumpWidget(app(onboarded: false));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.pumpWidget(app(onboarded: true));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byKey(const Key('tab-today')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('dört sayfa ilerler, iki öneri kaydedilir, bayrak yazılır', (
    tester,
  ) async {
    await tester.pumpWidget(app(onboarded: false));
    await tester.pumpAndSettle();
    expect(find.text('Your day, one screen.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Bring your calendar in.'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Never miss the moment.'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-notifications')), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    // Sabah özeti kapalı gelir, varsayılan saat 08:00; açılınca kalır.
    expect(find.text('Every day at 8:00 AM'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-brief-switch')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('onboarding-brief-switch')))
          .value,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Pick a few tiles to start.'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-suggest-water')));
    await tester.tap(find.byKey(const Key('onboarding-suggest-read')));
    await tester.pumpAndSettle();
    expect(find.text('Start with 2 habits'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byKey(const Key('tab-today')), findsOneWidget);
    expect(await OnboardingState.isDone(), isTrue);

    final habits = await tester.runAsync(() => db.watchHabits().first);
    expect(habits!.map((h) => h.name), ['Drink water', 'Read']);
    expect(habits.first.target, 8);
    await unmount(tester);
  });

  testWidgets('atla: hiçbir şey kaydedilmez, yine de biter', (tester) async {
    await tester.pumpWidget(app(onboarded: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(await OnboardingState.isDone(), isTrue);
    expect(await tester.runAsync(() => db.watchHabits().first), isEmpty);
    await unmount(tester);
  });

  testWidgets('sıfırla: onay ister, siler, dili koruyup akışa döner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.done': true,
      'locale': 'tr',
    });
    await tester.runAsync(
      () => db.addHabit(HabitsCompanion.insert(name: 'Su')),
    );
    await tester.pumpWidget(app(onboarded: true));
    await tester.pumpAndSettle();

    // Ayarlar sekmesine geç.
    await tester.tap(find.byKey(const Key('tab-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);

    // Vazgeç: hiçbir şey değişmez.
    await tester.ensureVisible(find.byKey(const Key('settings-reset')));
    await tester.tap(find.byKey(const Key('settings-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Her şey silinsin mi?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset-cancel')));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => db.watchHabits().first), hasLength(1));

    // Onayla: veri ve ayarlar gider, dil kalır, akış Türkçe açılır.
    await tester.tap(find.byKey(const Key('settings-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset-confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Günün, tek ekranda.'), findsOneWidget);
    expect(await tester.runAsync(() => db.watchHabits().first), isEmpty);
    expect(await OnboardingState.isDone(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'tr');
    await unmount(tester);
  });
}
