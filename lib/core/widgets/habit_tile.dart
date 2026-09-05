import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../locale.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Karo: ürünün imza bileşeni.
///
/// Sol üstte ikon, sağ üstte tamamla dairesi, altta ad ve hedef satırı, en
/// altta haftanın yedi noktası. Renk karonun kendisinde; koyu karolar
/// renklilerin arasında nefes payı.
///
/// Dokunma iki hedefe ayrılıyor: daire "bugün yaptım" der, karonun geri kalanı
/// ayrıntıyı açar. Tek hedef olsaydı her açma bir yanlış tamamlamaya dönerdi.
class HabitTile extends StatelessWidget {
  const HabitTile({
    required this.name,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.week,
    this.scheduled,
    required this.doneToday,
    this.muteWhenDone = false,
    required this.onToggle,
    required this.onOpen,
    super.key,
  });

  final String name;
  final IconData icon;
  final TileColor color;

  /// "Daily · 0/1", "Weekly · 2/3" gibi.
  final String subtitle;

  /// Pazartesiden pazara yedi değer: o gün yapıldı mı.
  final List<bool> week;

  /// Pazartesiden pazara: o gün bekleniyor mu. Boşsa hepsi. Beklenmeyen gün
  /// soluk çizilir; kullanıcı "salı niye boş" diye bakmasın.
  final List<bool>? scheduled;
  final bool doneToday;

  /// Bugün bitince biten iş gibi grafite dönsün mü. Today panosunda evet:
  /// renk yalnızca bekleyeni çağırır. Habits sayfasında hayır: orası
  /// alışkanlığın kimliği, renk her zaman görünür (kullanıcı, 4 Eylül 2026).
  final bool muteWhenDone;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    // Bugün bitmiş alışkanlık biten işle aynı dile geçer: grafit zemin, soluk
    // mürekkep, yeşil daire. Renk yalnızca bekleyen işi çağırır; bitmişin
    // rengi panoda gürültü olurdu. Yarın sayaç sıfırlanınca renk geri gelir.
    final muted = doneToday && muteWhenDone;
    final fill = muted ? AppColors.surface : color.fill;
    final ink = muted ? AppColors.textTertiary : color.ink;
    final faint = ink.withValues(alpha: 0.35);
    final todayIndex = DateTime.now().weekday - 1;
    final letters = context.l10n.dayLetters.characters.toList();

    return Material(
      color: fill,
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
                  Icon(icon, size: IconSize.tile, color: ink),
                  const Spacer(),
                  _DoneCircle(
                    done: doneToday,
                    ink: ink,
                    fill: fill,
                    onTap: onToggle,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: Gap.md),
              // Nokta boyutu karonun genişliğinden türer. Sabit 22 piksel,
              // 6.1" telefonda karoyu 6 piksel taşırıyordu; yedi nokta her
              // karo genişliğinde sığmalı.
              LayoutBuilder(
                builder: (context, c) {
                  final size = ((c.maxWidth - 6 * 4) / 7).clamp(14.0, 22.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 7; i++)
                        _DayDot(
                          letter: i < letters.length ? letters[i] : '',
                          filled: i < week.length && week[i],
                          isToday: i == todayIndex,
                          expected: scheduled == null || scheduled![i],
                          ink: ink,
                          fill: fill,
                          faint: faint,
                          size: size,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneCircle extends StatelessWidget {
  const _DoneCircle({
    required this.done,
    required this.ink,
    required this.fill,
    required this.onTap,
  });

  final bool done;
  final Color ink;

  /// Karo zemini: dolu dairenin içindeki tik bu renkte. Mürekkep beyazsa
  /// beyaz daire içinde beyaz tik görünmüyordu.
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      label: context.l10n.doneToday,
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
                // Dolu daire iş karosuyla aynı yeşil: bitmiş her şey panoda
                // tek işaretle okunsun.
                color: done ? AppColors.done : Colors.transparent,
                border: Border.all(
                  color: done ? AppColors.done : ink,
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

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.filled,
    required this.isToday,
    required this.expected,
    required this.ink,
    required this.fill,
    required this.faint,
    required this.size,
  });

  final String letter;
  final bool filled;
  final bool isToday;
  final bool expected;
  final Color ink;
  final Color fill;
  final Color faint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? ink : ink.withValues(alpha: expected ? 0.12 : 0.04),
        border: isToday && !filled ? Border.all(color: ink, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          color: filled
              ? fill
              : (isToday
                    ? ink
                    : (expected ? faint : ink.withValues(alpha: 0.18))),
        ),
      ),
    );
  }
}
