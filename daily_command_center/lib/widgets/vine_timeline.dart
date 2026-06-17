import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../logic/ripeness.dart';
import '../theme/app_palette.dart';

/// One fruit on the vine. A pure view-model — the Timeline screen builds
/// these from the engine's ResolvedDay; this widget never touches the engine.
@immutable
class VineStop {
  final String time, label, sub;
  final Ripeness ripeness;
  final bool anchor;
  final bool squeezed;
  final VoidCallback? onPick; // null = not pickable (anchors)
  const VineStop({
    required this.time, required this.label, this.sub = '',
    required this.ripeness, this.anchor = false, this.squeezed = false,
    this.onPick,
  });
}

/// The living vine (ADR-022 §4): climbs upward — future above, NOW ripe
/// inline (enlarged), basket at ground. The basket row folds the walked
/// morning beneath it; jammy past fruit offer "pick late?". Drift is
/// physical: slack/curvy when caught up, taut as [tension] → 1.
class VineTimeline extends StatelessWidget {
  final List<VineStop> future; // soonest LAST (rendered just above NOW)
  final VineStop? now;
  final List<VineStop> past; // clock order
  final int pickedCount, jammyCount;
  final double tension; // 0 slack … 1 taut
  final bool unfurled;
  final VoidCallback onToggleUnfurl;

  const VineTimeline({
    super.key, required this.future, required this.now, required this.past,
    required this.pickedCount, required this.jammyCount,
    required this.tension, required this.unfurled, required this.onToggleUnfurl,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final motion = (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
        ? Duration.zero
        : const Duration(milliseconds: 320);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final s in future) _row(c, motion, s, hero: false),
      if (now != null) _row(c, motion, now!, hero: true),
      _basketRow(c),
      AnimatedSize(
        duration: motion,
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: unfurled
            ? Column(children: [
                for (final s in past) _row(c, motion, s, hero: false, walked: true)
              ])
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }

  Widget _basketRow(AppPalette c) => GestureDetector(
        key: const Key('vine-basket'),
        behavior: HitTestBehavior.opaque,
        onTap: onToggleUnfurl,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: c.raise2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line)),
          child: Row(children: [
            const Text('🧺', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$pickedCount picked${jammyCount > 0 ? ' · $jammyCount jammy' : ''}',
                style: GoogleFonts.splineSansMono(fontSize: 12.5, color: c.salt),
              ),
            ),
            Text(unfurled ? '▴' : '▾', style: TextStyle(color: c.dim)),
          ]),
        ),
      );

  Widget _row(AppPalette c, Duration motion, VineStop s,
      {required bool hero, bool walked = false}) {
    final jammy = s.ripeness == Ripeness.overripe;
    final picked = s.ripeness == Ripeness.picked;
    return AnimatedSwitcher(
      duration: motion,
      transitionBuilder: (child, anim) => SlideTransition(
          position: Tween(begin: const Offset(0, -0.15), end: Offset.zero)
              .animate(anim),
          child: FadeTransition(opacity: anim, child: child)),
      child: IntrinsicHeight(
        key: ValueKey('${s.time}|${s.label}|${s.ripeness}'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 14, right: 10),
              child: Text(s.time,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.splineSansMono(
                      fontSize: 12,
                      color: s.squeezed ? c.jammyText : c.dim)),
            ),
          ),
          SizedBox(
            width: 18,
            child: CustomPaint(
              painter: _VinePainter(s, c, tension, hero: hero),
              child: const SizedBox.expand(),
            ),
          ),
          Expanded(child: _card(c, s, hero: hero, jammy: jammy, picked: picked, walked: walked)),
        ]),
      ),
    );
  }

  Widget _card(AppPalette c, VineStop s,
      {required bool hero, required bool jammy, required bool picked, required bool walked}) {
    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: hero ? 16 : 11),
      decoration: BoxDecoration(
        color: walked ? Colors.transparent : c.raise,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: hero
                ? c.ripe.withValues(alpha: .5)
                : s.anchor
                    ? c.salt
                    : c.line),
      ),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (s.anchor) ...[
            Text('◉', style: TextStyle(fontSize: 12, color: c.dim)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(s.label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: hero ? 20 : 15.5,
                  fontWeight: hero ? FontWeight.w800 : FontWeight.w600,
                  color: picked ? c.dim : c.salt,
                  decoration: picked ? TextDecoration.lineThrough : null,
                  decorationColor: c.dim,
                )),
          ),
        ]),
        if (s.sub.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(s.sub,
                style: GoogleFonts.splineSansMono(
                    fontSize: 11.5, color: s.squeezed ? c.jammyText : c.dim)),
          ),
        if (jammy && s.onPick != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: s.onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: c.vineDim, borderRadius: BorderRadius.circular(99)),
                child: Text('pick late?',
                    style: GoogleFonts.splineSansMono(
                        fontSize: 11, color: c.vine)),
              ),
            ),
          ),
      ]),
    );
    if (s.onPick == null || jammy) return card; // jammy picks via the button
    return GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: s.onPick, child: card);
  }
}

/// The vine segment + fruit for one row. Slack vines curve (amplitude shrinks
/// as tension → 1). Squeezed fruit draw squashed (ellipse); anchors a dashed
/// ring; picked a bare calyx; NOW enlarged with a soft glow.
class _VinePainter extends CustomPainter {
  final VineStop s;
  final AppPalette c;
  final double tension;
  final bool hero;
  const _VinePainter(this.s, this.c, this.tension, {required this.hero});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final amp = (1 - tension) * 5; // slack curve → taut line
    final vinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = c.vine.withValues(alpha: 0.55);
    final path = Path()..moveTo(x, 0);
    path.cubicTo(x + amp, size.height * 0.33, x - amp, size.height * 0.66,
        x, size.height);
    canvas.drawPath(path, vinePaint);

    final p = Offset(x, 20);
    final color = c.fruit(s.ripeness);
    if (s.ripeness == Ripeness.picked) {
      canvas.drawCircle(p, 4, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 2..color = c.vine);
    } else if (s.anchor) {
      final ring = Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 2..color = color;
      for (var i = 0; i < 6; i++) {
        canvas.drawArc(Rect.fromCircle(center: p, radius: 5.5),
            i * 1.047, 0.6, false, ring);
      }
    } else if (s.squeezed) {
      canvas.drawOval(
          Rect.fromCenter(center: p, width: 13, height: 8),
          Paint()..color = color);
    } else {
      final r = hero ? 8.0 : 4.5;
      if (hero) {
        canvas.drawCircle(p, r + 5,
            Paint()..color = c.ripe.withValues(alpha: 0.2));
      }
      canvas.drawCircle(p, r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_VinePainter old) =>
      old.s != s || old.tension != tension || old.c != c;
}
