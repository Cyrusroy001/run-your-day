import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_palette.dart';

class AnchorWall extends StatelessWidget {
  final Block block;
  final String timeText;
  const AnchorWall({super.key, required this.block, required this.timeText});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hard = block.hardAnchor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 11),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
      decoration: BoxDecoration(
        color: hard ? c.terraD : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hard ? c.terra : c.dim,
          style: hard ? BorderStyle.solid : BorderStyle.none,
        ),
      ),
      foregroundDecoration: hard
          ? null
          : _DashedBorder(color: c.dim, radius: 10),
      child: Row(children: [
        Text(hard ? '🔒 ANCHOR' : '⌛ AIM',
            style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700, color: hard ? c.terra : c.dim)),
        const SizedBox(width: 10),
        Expanded(child: Text('${block.label} · $timeText',
            style: TextStyle(fontSize: 12.5, color: hard ? c.cream : c.muted))),
      ]),
    );
  }
}

/// Lightweight dashed border for soft ceilings.
class _DashedBorder extends BoxDecoration {
  final Color color;
  final double radius;
  const _DashedBorder({required this.color, required this.radius});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _DashedPainter(color, radius);
}

class _DashedPainter extends BoxPainter {
  final Color color;
  final double radius;
  _DashedPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = offset & cfg.size!;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }
}
