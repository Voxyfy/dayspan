import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dayspan/core/locale.dart';
import 'package:dayspan/core/providers.dart';
import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/data/db/database.dart';
import 'package:dayspan/features/habits/habit_editor_sheet.dart';
import 'package:dayspan/features/settings/settings_screen.dart';
import 'package:dayspan/l10n/app_localizations.dart';

/// Dil: varsayılan İngilizce, seçim kalıcı, ekranlar Türkçeye döner.
void main() {
  late DayspanDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = DayspanDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Widget app(Widget home) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        theme: AppTheme.dark(),
        locale: ref.watch(localeProvider),
        supportedLocales: AppLocales.all,
        localizationsDelegates: L10n.localizationsDelegates,
        home: home,
      ),
    ),
  );

  testWidgets('varsayılan dil İngilizce', (tester) async {
    await tester.pumpWidget(app(const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets(
    'Türkçe seçilince ekran ve hata metni Türkçeye döner, seçim saklanır',
    (tester) async {
      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lang-tr')));
      await tester.pumpAndSettle();

      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.text('Dil'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'tr');

      // Aynı ProviderScope içinde düzenleyici de Türkçe konuşmalı.
      await tester.pumpWidget(app(const Scaffold(body: HabitEditorSheet())));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('habit-save')));
      await tester.tap(find.byKey(const Key('habit-save')));
      await tester.pumpAndSettle();
      expect(find.text('Alışkanlığa bir ad ver.'), findsOneWidget);
    },
  );
}
