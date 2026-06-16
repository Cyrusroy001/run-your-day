import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

/// The ketchup signature: a vertical rail of the day's remaining stops where a
/// stop's spine height is proportional to its duration, and a squeezed block
/// reads as a dashed mustard spine + one mono delta — "legible with zero
/// reading" (spec R4). Replaces budget_bar + anchor_wall + the old per-row
/// progress/⚠/checkbox stack.
enum RailVariant { normal, squeeze, anchor, skip, done }

/// One stop on the rail. A pure view-model — the Today screen (K3) builds these
/// from the engine's ResolvedDay; the widget never touches the engine.
@immutable
class RailStop {
  /// Already-formatted display time, e.g. "11:03", "~1:19", "9-ish".
  final String time;
  final String label;

  /// One mono line under the name: "2 h deep work" / "−20 min · 25 min" /
  /// "held · 2:00 → 8:00".
  final String sub;
  final RailVariant variant;
  final int durationMinutes;

  /// Show the ◉ lock glyph before the name (anchors).
  final bool locked;

  /// Tap toggles done. Null for anchors and non-interactive rows.
  final VoidCallback? onTap;

  const RailStop({
    required this.time,
    required this.label,
    this.sub = '',
    this.variant = RailVariant.normal,
    this.durationMinutes = 30,
    this.locked = false,
    this.onTap,
  });
}

class ElasticRail extends StatelessWidget {
  final String? header;
  final List<RailStop> stops;
  const ElasticRail({super.key, required this.stops, this.header});

  /// Spine height ∝ duration, clamped 56–120 dp (spec R4). Linear 15→56, 120→120.
  static double spineHeight(int minutes) =>
      (56 + (minutes - 15) * (64 / 105)).clamp(56.0, 120.0);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // The two ketchup motions live here: the squeeze (a stop's height animates
    // as its duration compresses) and Done (the card tints leaf). Honour
    // reduced-motion by collapsing the duration to zero.
    final motion = (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
        ? Duration.zero
        : const Duration(milliseconds: 320);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(header!.toUpperCase(),
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1.4, color: c.dim, fontWeight: FontWeight.w600)),
        ),
      for (var i = 0; i < stops.length; i++) _stop(c, motion, stops[i], i),
    ]);
  }

  Widget _stop(AppPalette c, Duration motion, RailStop s, int i) {
    // Spine/stop height is proportional to duration but acts as a MINIMUM —
    // short blocks grow to fit their content instead of clipping (IntrinsicHeight
    // makes the spine match the card's height either way). AnimatedSize makes a
    // squeeze (a drop in duration) compress the segment over 320 ms.
    final h = spineHeight(s.durationMinutes);
    final faded = s.variant == RailVariant.skip;
    return Opacity(
      opacity: faded ? 0.45 : 1,
      child: AnimatedSize(
        duration: motion,
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 13, right: 10),
              child: Text(s.time,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.splineSansMono(
                      fontSize: 12,
                      color: s.variant == RailVariant.squeeze ? c.jammyText : c.dim)),
            ),
          ),
          SizedBox(
            width: 14,
            child: CustomPaint(
              key: Key('rail-spine-$i'),
              painter: _SpinePainter(s.variant, c),
              child: const SizedBox.expand(),
            ),
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: h),
              child: _card(c, motion, s, i),
            ),
          ),
        ]),
        ),
      ),
    );
  }

  Widget _card(AppPalette c, Duration motion, RailStop s, int i) {
    final box = _cardDecoration(c, s.variant);
    final card = AnimatedContainer(
      duration: motion,
      curve: Curves.easeOut,
      key: Key('rail-card-$i'),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: box,
      alignment: Alignment.centerLeft,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (s.locked) ...[
            Text('◉', style: TextStyle(fontSize: 12, color: c.dim)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: s.variant == RailVariant.done ? c.vine : c.salt,
                  decoration:
                      s.variant == RailVariant.skip ? TextDecoration.lineThrough : null,
                  decorationColor: c.dim,
                )),
          ),
        ]),
        if (s.sub.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(s.sub,
                style: GoogleFonts.splineSansMono(
                    fontSize: 11.5,
                    color: s.variant == RailVariant.squeeze ? c.jammyText : c.dim)),
          ),
      ]),
    );
    if (s.onTap == null) return card;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: s.onTap, child: card);
  }

  BoxDecoration _cardDecoration(AppPalette c, RailVariant v) {
    final radius = BorderRadius.circular(16);
    switch (v) {
      case RailVariant.squeeze:
        return BoxDecoration(
            color: c.raise, borderRadius: radius, border: Border.all(color: c.jammy.withValues(alpha: .55)));
      case RailVariant.anchor:
        return BoxDecoration(
            color: Colors.transparent, borderRadius: radius, border: Border.all(color: c.salt));
      case RailVariant.done:
        return BoxDecoration(
            color: c.vineDim, borderRadius: radius, border: Border.all(color: c.vine.withValues(alpha: .4)));
      case RailVariant.normal:
      case RailVariant.skip:
        return BoxDecoration(color: c.raise, borderRadius: radius, border: Border.all(color: c.line));
    }
  }
}

/// Draws the continuous vertical spine for one stop + its node. Solid for
/// normal/done/skip, a thick salt bar for anchors, dashed mustard for squeezes.
class _SpinePainter extends CustomPainter {
  final RailVariant variant;
  final AppPalette c;
  const _SpinePainter(this.variant, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final line = Paint()
      ..strokeWidth = variant == RailVariant.anchor ? 4 : 2
      ..color = switch (variant) {
        RailVariant.anchor => c.salt,
        RailVariant.squeeze => c.jammy,
        _ => c.line,
      };
    if (variant == RailVariant.squeeze) {
      // dashed
      const dash = 3.0, gap = 3.0;
      var y = 0.0;
      while (y < size.height) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + dash).clamp(0, size.height)), line);
        y += dash + gap;
      }
    } else {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    // node
    const ny = 18.0;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = switch (variant) {
        RailVariant.anchor => c.salt,
        RailVariant.done => c.vine,
        _ => c.raise2,
      };
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = switch (variant) {
        RailVariant.anchor => c.salt,
        RailVariant.squeeze => c.jammy,
        RailVariant.done => c.vine,
        _ => c.dim,
      };
    canvas.drawCircle(Offset(x, ny), 4, fill);
    canvas.drawCircle(Offset(x, ny), 4, border);
  }

  @override
  bool shouldRepaint(_SpinePainter old) => old.variant != variant || old.c != c;
}
