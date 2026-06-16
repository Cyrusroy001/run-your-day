import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../logic/day_arc.dart';
import '../logic/ripeness.dart';
import '../logic/sun_clock.dart';
import '../theme/app_palette.dart';

/// The day drawn as one arc across the plan's waking window (ADR-022 §3).
/// Ambient ground follows the clock; fruit hang at their hours in ripeness
/// colors; the walked arc thickens; picked fruit leave a hollow calyx;
/// NOW glows on the curve. Pure paint — no engine access.
class SunArcCard extends StatelessWidget {
  final DayArc arc;
  final SkyBlend blend;
  final double height;
  const SunArcCard({super.key, required this.arc, required this.blend, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.ambient(blend),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: CustomPaint(painter: ArcPainter(arc, c), child: const SizedBox.expand()),
    );
  }
}

class ArcPainter extends CustomPainter {
  final DayArc arc;
  final AppPalette c;
  const ArcPainter(this.arc, this.c);

  // Quadratic bezier across the card: B(t) = (1-t)²P0 + 2(1-t)tC + t²P1.
  Offset _point(Size s, double t) {
    final p0 = Offset(18, s.height * 0.82);
    final p1 = Offset(s.width - 18, s.height * 0.82);
    final ctrl = Offset(s.width / 2, s.height * 0.10);
    final u = 1 - t;
    return p0 * (u * u) + ctrl * (2 * u * t) + p1 * (t * t);
  }

  Path _path(Size s) {
    final path = Path()..moveTo(18, s.height * 0.82);
    path.quadraticBezierTo(
        s.width / 2, s.height * 0.10, s.width - 18, s.height * 0.82);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final full = _path(size);
    canvas.drawPath(full, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2..color = c.line);

    // Walked portion, thicker.
    final metric = full.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * arc.nowPos), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = c.vine);

    // Fruit at their hours.
    for (final s in arc.stops) {
      final p = _point(size, s.pos);
      final color = c.fruit(s.ripeness);
      if (s.ripeness == Ripeness.picked) {
        // hollow calyx
        canvas.drawCircle(p, 4.5, Paint()
          ..style = PaintingStyle.stroke..strokeWidth = 2..color = c.vine);
      } else if (s.anchor) {
        // dashed ring: 6 arc dashes
        final ring = Paint()
          ..style = PaintingStyle.stroke..strokeWidth = 2..color = color;
        for (var i = 0; i < 6; i++) {
          canvas.drawArc(Rect.fromCircle(center: p, radius: 5.5),
              i * 1.047, 0.6, false, ring);
        }
      } else {
        canvas.drawCircle(p, 4.5, Paint()..color = color);
      }
    }

    // NOW glow on the curve (the only red — small and earned).
    if (!arc.dayDone) {
      final now = _point(size, arc.nowPos);
      canvas.drawCircle(now, 11,
          Paint()..color = c.ripe.withValues(alpha: 0.22)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4));
      canvas.drawCircle(now, 5.5, Paint()..color = c.ripe);
    }
  }

  @override
  bool shouldRepaint(ArcPainter old) => old.arc != arc || old.c != c;
}
