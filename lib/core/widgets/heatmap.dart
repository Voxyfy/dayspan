import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../theme/app_colors.dart';

/// Katkı grafiği: sütun hafta, satır gün; hücre o günün yoğunluğu.
///
/// Tek renk: hücre alışkanlığın kendi rengiyle dolar, boş hücre grafit.
/// GitHub'ın dört tonlu yeşili yerine iki durum + kısmi: renk yalnızca karoda
/// yaşar, harita da o karonun uzantısı.
///
/// Sabit hücre ölçüsü ve yatay kaydırma: 26 haftayı telefon genişliğine
/// sığdırmak hücreyi 9 piksele düşürüyordu, parmakla okunmuyor. Kaydırma
/// sondan başlar; kullanıcı önce bu haftayı görür.
class Heatmap extends StatelessWidget {
  const Heatmap({
    required this.levelOn,
    required this.color,
    required this.today,
    required this.dayLetters,
    this.weeks = 26,
    this.semanticsLabel,
    super.key,
  });

  /// Günün yoğunluğu: 0 boş, (0,1) kısmi, 1 dolu.
  final double Function(DateTime day) levelOn;
  final Color color;
  final DateTime today;

  /// Pazartesiden pazara yedi harf; yalnızca Pzt/Çar/Cum satırları yazılır.
  final String dayLetters;
  final int weeks;
  final String? semanticsLabel;

  static const cell = 14.0;
  static const gap = 3.0;
  static const labelWidth = 22.0;
  static const monthRow = 18.0;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final width = labelWidth + weeks * (cell + gap);
    const height = monthRow + 7 * (cell + gap);
    return Semantics(
      label: semanticsLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: CustomPaint(
          size: Size(width, height),
          painter: _HeatmapPainter(
            levelOn: levelOn,
            color: color,
            today: DateTime(today.year, today.month, today.day),
            weeks: weeks,
            dayLetters: dayLetters,
            monthFormat: DateFormat.MMM(locale),
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.levelOn,
    required this.color,
    required this.today,
    required this.weeks,
    required this.dayLetters,
    required this.monthFormat,
  });

  final double Function(DateTime) levelOn;
  final Color color;
  final DateTime today;
  final int weeks;
  final String dayLetters;
  final DateFormat monthFormat;

  @override
  void paint(Canvas canvas, Size size) {
    const c = Heatmap.cell;
    const g = Heatmap.gap;
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = thisMonday.subtract(Duration(days: 7 * (weeks - 1)));
    final empty = Paint()..color = AppColors.surfaceMuted;
    final full = Paint()..color = color;
    final partial = Paint()..color = color.withValues(alpha: 0.45);
    final todayRing = Paint()
      ..color = AppColors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final labelStyle = const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textTertiary,
    );

    // Gün harfleri: Pzt, Çar, Cum. Hepsini yazmak sütunu sıkıştırıyordu.
    final letters = dayLetters.characters.toList();
    for (final row in const [0, 2, 4]) {
      if (row >= letters.length) break;
      final tp = TextPainter(
        text: TextSpan(text: letters[row], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(0, Heatmap.monthRow + row * (c + g) + (c - tp.height) / 2),
      );
    }

    int? lastMonth;
    for (var w = 0; w < weeks; w++) {
      final monday = firstMonday.add(Duration(days: 7 * w));
      final x = Heatmap.labelWidth + w * (c + g);

      // Ay adı, ayın ilk haftasının üstüne. İlk sütunun ayı da yazılır ki
      // harita "hangi aydayım" sorusuz başlasın.
      final month = monday.add(const Duration(days: 6)).month;
      if (month != lastMonth) {
        lastMonth = month;
        final tp = TextPainter(
          text: TextSpan(
            text: monthFormat.format(monday.add(const Duration(days: 6))),
            style: labelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x, 0));
      }

      for (var d = 0; d < 7; d++) {
        final day = monday.add(Duration(days: d));
        // Gelecek günler çizilmez; boş hücre "yapılmadı" demek, yarın için
        // bu yanlış bir yargı olur.
        if (day.isAfter(today)) continue;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, Heatmap.monthRow + d * (c + g), c, c),
          const Radius.circular(3),
        );
        final level = levelOn(day);
        canvas.drawRRect(
          rect,
          level >= 1
              ? full
              : level > 0
              ? partial
              : empty,
        );
        if (day == today && level < 1) canvas.drawRRect(rect, todayRing);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.color != color ||
      old.today != today ||
      old.weeks != weeks ||
      old.levelOn != levelOn;
}
