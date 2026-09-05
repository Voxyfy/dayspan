import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/habits/habit_detail_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/today/today_screen.dart';

abstract final class Routes {
  static const today = '/';
  static const habits = '/habits';
  static const settings = '/settings';

  /// İlk açılış akışı; sekme kabuğunun dışında, tam ekran.
  static const onboarding = '/welcome';

  /// Alışkanlık ayrıntısı; kabuğun dışında, sekme çubuğu görünmez.
  static const habit = '/habit/:id';
  static String habitPath(int id) => '/habit/$id';
}

/// Başlangıç konumu kurulumda seçilir: onboarding görülmemişse oradan
/// başlar. Yönlendirme kuralı (redirect) yerine başlangıç konumu, çünkü akış
/// bittikten sonra bir daha kontrol gerekmiyor ve Today bir an bile
/// parlamamalı.
GoRouter buildRouter({required bool onboarded}) => GoRouter(
  initialLocation: onboarded ? Routes.today : Routes.onboarding,
  routes: [
    GoRoute(
      path: Routes.onboarding,
      pageBuilder: (_, state) => fadePage(const OnboardingScreen(), state),
    ),
    GoRoute(
      path: Routes.habit,
      builder: (_, state) =>
          HabitDetailScreen(habitId: int.parse(state.pathParameters['id']!)),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.today, builder: (_, _) => const TodayScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.habits,
              builder: (_, _) => const HabitsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.settings,
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Sekme dışı tam ekran sayfalar için ortak geçiş.
Page<T> fadePage<T>(Widget child, GoRouterState state) =>
    CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
