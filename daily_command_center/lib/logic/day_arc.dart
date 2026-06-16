import '../data/models.dart';
import 'ripeness.dart';

/// One stop hung on the day's arc.
class ArcStop {
  final double pos; // 0..1 across the waking window
  final Ripeness ripeness;
  final bool anchor;
  const ArcStop(this.pos, this.ripeness, {this.anchor = false});
}

/// The day as one arc across the plan's waking window (ADR-022 §3) —
/// schema-driven: first block start → last block end, never hardcoded hours.
class DayArc {
  final double startH, endH;
  final double nowPos; // 0..1 clamped
  final List<ArcStop> stops;
  final bool dayDone; // all trackables picked, or the window has passed

  const DayArc({
    required this.startH, required this.endH, required this.nowPos,
    required this.stops, required this.dayDone,
  });

  static DayArc from(List<Block> blocks,
      {required double now, required Set<String> done, String? currentSignature}) {
    if (blocks.isEmpty) {
      return const DayArc(startH: 8, endH: 23, nowPos: 0, stops: [], dayDone: false);
    }
    final startH = blocks.first.estStart;
    var endH = startH;
    for (final b in blocks) {
      final dur = b.durationMinutes > 0 ? b.durationMinutes : b.idealMinutes;
      final end = b.estStart + dur / 60.0;
      if (end > endH) endH = end;
    }
    final span = (endH - startH).clamp(0.1, 24.0);
    final ripeness = RipenessRules.assign(blocks,
        now: now, done: done, currentSignature: currentSignature);
    final stops = <ArcStop>[
      for (var i = 0; i < blocks.length; i++)
        if (!blocks[i].isDropped)
          ArcStop(((blocks[i].estStart - startH) / span).clamp(0.0, 1.0),
              ripeness[i], anchor: blocks[i].isAnchor),
    ];
    final trackables =
        blocks.where((b) => b.isTrackable && !b.isDropped).toList();
    final dayDone = now >= endH ||
        (trackables.isNotEmpty &&
            trackables.every((b) => done.contains(b.signature)));
    return DayArc(
        startH: startH, endH: endH,
        nowPos: ((now - startH) / span).clamp(0.0, 1.0),
        stops: stops, dayDone: dayDone);
  }
}
