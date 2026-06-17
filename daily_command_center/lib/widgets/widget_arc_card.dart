import 'package:flutter/material.dart';
import '../logic/day_arc.dart';
import '../logic/sun_clock.dart';
import '../theme/app_palette.dart';
import 'night_card.dart';
import 'sun_arc_card.dart';

/// Pre-rendered to an image for the home-screen widget (ADR-022 §7) on each
/// data push / WorkManager refresh. The arc crawls slowly, so ~15-min
/// staleness is fine. Night renders the bud card (no text — metaphor only).
class WidgetArcCard extends StatelessWidget {
  final DayArc arc;
  final SkyBlend blend;
  final AppPalette palette;
  const WidgetArcCard({super.key, required this.arc, required this.blend,
      required this.palette});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: [palette]),
          child: SizedBox(
            width: 400,
            height: 180,
            child: arc.dayDone
                ? const NightCard()
                : SunArcCard(arc: arc, blend: blend, height: 180),
          ),
        ),
      );
}
