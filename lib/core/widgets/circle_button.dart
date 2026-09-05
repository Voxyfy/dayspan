import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Daire içinde tek ikon: başlık satırındaki geri / ekle / ayar düğmeleri.
class CircleButton extends StatelessWidget {
  const CircleButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.fill = AppColors.surface,
    this.ink = AppColors.textPrimary,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color fill;
  final Color ink;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: fill,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Icon(icon, size: IconSize.md, color: ink),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
