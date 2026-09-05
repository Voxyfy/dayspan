import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// İş karosu. Alışkanlık karosuyla aynı iskelet: sol üstte ikon, sağ üstte
/// tamamla dairesi, altta ad ve alt satır.
///
/// Zemin her zaman grafit. Ayrımı etiket değil renk yapar: pano üstünde
/// renkli olan alışkanlık, gri olan iştir. Alt satırda yedi gün yerine saat
/// (ya da "Anytime"): işin tek zaman boyutu bugün.
///
/// Biten iş kaybolmaz, solar ve üstü çizilir; gün sonunda "ne yaptım"
/// sorusunun cevabı panoda kalır.
class TaskTile extends StatelessWidget {
  const TaskTile({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onToggle,
    required this.onOpen,
    this.hasNote = false,
    super.key,
  });

  final String title;

  /// Saat ("09:30") ya da "Anytime".
  final String subtitle;
  final bool done;
  final bool hasNote;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ink = done ? AppColors.textTertiary : AppColors.textPrimary;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.all(Gap.tile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIconsRegular.checkSquareOffset,
                    size: IconSize.tile,
                    color: ink,
                  ),
                  const Spacer(),
                  _DoneCircle(done: done, onTap: onToggle),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: ink,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: done
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (hasNote) ...[
                    const SizedBox(width: 6),
                    Icon(
                      PhosphorIconsRegular.notePencil,
                      size: IconSize.sm,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneCircle extends StatelessWidget {
  const _DoneCircle({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.quick,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.done : Colors.transparent,
                border: Border.all(
                  color: done ? AppColors.done : AppColors.textPrimary,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(
                      PhosphorIconsBold.check,
                      size: IconSize.sm,
                      color: AppColors.background,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
