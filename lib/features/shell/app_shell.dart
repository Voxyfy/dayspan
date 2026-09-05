import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';

/// Yüzen sekme kabuğu: yalnızca ikon, seçili sekme kayan beyaz daire.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (
      icon: PhosphorIconsRegular.sun,
      active: PhosphorIconsFill.sun,
      key: Key('tab-today'),
    ),
    (
      icon: PhosphorIconsRegular.squaresFour,
      active: PhosphorIconsFill.squaresFour,
      key: Key('tab-habits'),
    ),
    (
      icon: PhosphorIconsRegular.gear,
      active: PhosphorIconsFill.gear,
      key: Key('tab-settings'),
    ),
  ];

  static const _tabWidth = 64.0;
  static const _barHeight = 64.0;
  static const _inset = 6.0;

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    final l = context.l10n;
    final labels = [l.tabToday, l.tabHabits, l.tabSettings];

    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Gap.md),
          child: Center(
            heightFactor: 1,
            child: Container(
              height: _barHeight,
              width: _tabWidth * _tabs.length + _inset * 2,
              padding: const EdgeInsets.all(_inset),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
                boxShadow: AppColors.floatingShadow,
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final slot = c.maxWidth / _tabs.length;
                  final dot = c.maxHeight;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: Motion.base,
                        curve: Motion.curve,
                        left: slot * index + (slot - dot) / 2,
                        top: 0,
                        width: dot,
                        height: dot,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < _tabs.length; i++)
                            Expanded(
                              child: Semantics(
                                label: labels[i],
                                selected: index == i,
                                button: true,
                                child: GestureDetector(
                                  key: _tabs[i].key,
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    navigationShell.goBranch(
                                      i,
                                      initialLocation: i == index,
                                    );
                                  },
                                  child: Center(
                                    child: Icon(
                                      index == i
                                          ? _tabs[i].active
                                          : _tabs[i].icon,
                                      size: IconSize.lg,
                                      color: index == i
                                          ? AppColors.onAccent
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
