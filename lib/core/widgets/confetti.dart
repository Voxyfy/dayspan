import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Gün tamamlanınca iki kenardan fırlayan konfeti.
///
/// Paket yok: altmış küçük yuvarlatılmış dikdörtgen (karonun minyatürü), karo
/// paletinin renkleriyle, iki kenardan ortaya doğru fırlar, yer çekimiyle
/// düşer ve solar. Bir buçuk saniye; dokunmayı engellemez; kendini kaldırır.
/// Günde en fazla bir kez çıkması tetikleyenin sorumluluğu ([Confetti.burst]
/// çağıran karar verir).
abstract final class Confetti {
  static const duration = Duration(milliseconds: 1600);

  static void burst(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiLayer(onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Confetti.duration,
  );
  late final _particles = _Particle.spray(Random());

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          key: const Key('confetti'),
          size: Size.infinite,
          painter: _ConfettiPainter(_particles, _controller.value),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.fromLeft,
    required this.startY,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.color,
    required this.size,
  });

  /// Sol kenardan mı sağdan mı.
  final bool fromLeft;

  /// Ekran yüksekliğine oran (0 üst).
  final double startY;

  /// Ekran genişliği / saniye.
  final double vx;

  /// Ekran yüksekliği / saniye, yukarı eksi.
  final double vy;
  final double spin;
  final Color color;
  final double size;

  static List<_Particle> spray(Random rnd) {
    // Grafit dışındaki dokuz renk; koyu parça koyu zeminde kaybolur.
    final colors = TilePalette.colors.skip(1).map((c) => c.fill).toList();
    return List.generate(60, (i) {
      final left = i.isEven;
      return _Particle(
        fromLeft: left,
        startY: 0.45 + rnd.nextDouble() * 0.25,
        vx: (0.45 + rnd.nextDouble() * 0.55) * (left ? 1 : -1),
        vy: -(0.9 + rnd.nextDouble() * 0.7),
        spin: (rnd.nextDouble() - 0.5) * 12,
        color: colors[rnd.nextInt(colors.length)],
        size: 6 + rnd.nextDouble() * 6,
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;

  /// 0..1 ilerleme.
  final double t;

  static const _gravity = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = t * Confetti.duration.inMilliseconds / 1000;
    // Son üçte birde solar; parça hâlâ hareket ederken kaybolur, "yere
    // düşüp durdu" gibi kalmaz.
    final fade = t < 0.66 ? 1.0 : 1 - (t - 0.66) / 0.34;
    final paint = Paint();

    for (final p in particles) {
      final x = (p.fromLeft ? 0 : size.width) + p.vx * seconds * size.width;
      final y =
          (p.startY + p.vy * seconds + 0.5 * _gravity * seconds * seconds) *
          size.height;
      paint.color = p.color.withValues(alpha: fade.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * seconds);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
