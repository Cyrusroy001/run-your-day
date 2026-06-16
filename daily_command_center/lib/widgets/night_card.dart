import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Night state (ADR-022 §1): the vine fully climbed, starry ground, and a
/// small green bud — tomorrow as pure metaphor. Replaces "Nothing left
/// today. / Go be a person." Deliberately textless.
class NightCard extends StatelessWidget {
  const NightCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: c.skyNight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: CustomPaint(painter: _NightPainter(c), child: const SizedBox.expand()),
    );
  }
}

class _NightPainter extends CustomPainter {
  final AppPalette c;
  const _NightPainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7); // fixed seed: a stable little sky
    final star = Paint()..color = c.star.withValues(alpha: 0.8);
    for (var i = 0; i < 26; i++) {
      canvas.drawCircle(
          Offset(rnd.nextDouble() * size.width,
              rnd.nextDouble() * size.height * 0.62),
          rnd.nextDouble() * 1.4 + 0.4,
          star);
    }
    // Ground line + the bud: a short stem with one small vine-green tip.
    final groundY = size.height * 0.78;
    canvas.drawLine(Offset(18, groundY), Offset(size.width - 18, groundY),
        Paint()..strokeWidth = 1.5..color = c.line);
    final bx = size.width / 2;
    canvas.drawLine(Offset(bx, groundY), Offset(bx, groundY - 18),
        Paint()..strokeWidth = 2..color = c.vine);
    canvas.drawCircle(Offset(bx, groundY - 22), 5, Paint()..color = c.vine);
    canvas.drawCircle(Offset(bx - 5, groundY - 14), 3,
        Paint()..color = c.unripe);
  }

  @override
  bool shouldRepaint(_NightPainter old) => old.c != c;
}
