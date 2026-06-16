import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../theme/app_palette.dart';

/// 7 jars on a shelf — the pantry replaces percentages (ADR-022 §6).
/// Fill = picked/trackable; tint = batch grade (first press = vine,
/// good = ripening, rough = jammy). null = empty outline (no data).
class JarShelf extends StatelessWidget {
  final List<DayKetchup?> jars; // oldest → newest, length 7
  final bool mini;
  const JarShelf({super.key, required this.jars, this.mini = false});

  Color _tint(AppPalette c, BatchGrade g) => switch (g) {
        BatchGrade.firstPress => c.vine,
        BatchGrade.goodBatch => c.ripening,
        BatchGrade.roughBatch => c.jammy,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = mini ? 34.0 : 64.0;
    return Row(children: [
      for (var i = 0; i < jars.length; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: mini ? 2 : 5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: h,
                child: CustomPaint(
                  painter: _JarPainter(
                      fill: jars[i]?.fill ?? 0,
                      tint: jars[i] == null ? c.line : _tint(c, jars[i]!.grade),
                      outline: c.line, empty: jars[i] == null),
                  child: const SizedBox.expand(),
                ),
              ),
              if (!mini && jars[i] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      DateFormat('E')
                          .format(DateTime.parse(jars[i]!.date))
                          .substring(0, 1),
                      style: GoogleFonts.splineSansMono(fontSize: 10, color: c.dim)),
                ),
            ]),
          ),
        ),
    ]);
  }
}

class _JarPainter extends CustomPainter {
  final double fill;
  final Color tint, outline;
  final bool empty;
  const _JarPainter({required this.fill, required this.tint,
      required this.outline, required this.empty});

  @override
  void paint(Canvas canvas, Size size) {
    // Jar body: rounded rect with a narrower neck band on top.
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.82),
        const Radius.circular(6));
    final lid = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.2, 0, size.width * 0.6, size.height * 0.14),
        const Radius.circular(3));
    canvas.drawRRect(lid, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.5..color = outline);
    canvas.drawRRect(body, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.5..color = outline);
    if (!empty && fill > 0) {
      final fh = (size.height * 0.82) * fill;
      canvas.save();
      canvas.clipRRect(body);
      canvas.drawRect(
          Rect.fromLTWH(0, size.height - fh, size.width, fh),
          Paint()..color = tint.withValues(alpha: 0.75));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_JarPainter old) =>
      old.fill != fill || old.tint != tint || old.empty != empty;
}
