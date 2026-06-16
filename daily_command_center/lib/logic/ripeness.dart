import '../data/models.dart';

/// Ripeness = time (ADR-022 §1). Pure mapping from each block's relation to
/// NOW. Drift shows as overripe fruit + vine tension, never as alarm color.
enum Ripeness { unripe, ripening, nearly, ripe, overripe, picked }

class RipenessRules {
  /// Future blocks starting within this many minutes read "ripening".
  static const ripeningWindowMinutes = 90;

  /// One ripeness per block, index-aligned with [blocks] (assembler order,
  /// estStart already computed by the engine). [currentSignature] is
  /// HomeNowState's current block — null when resting or day done.
  /// Anchors can't be picked: past anchors read picked (the day walked past
  /// them, calyx stays); dropped blocks read overripe (squeeze ingredients).
  static List<Ripeness> assign(
    List<Block> blocks, {
    required double now,
    required Set<String> done,
    String? currentSignature,
  }) {
    var nextSeen = false;
    final out = <Ripeness>[];
    for (final b in blocks) {
      if (done.contains(b.signature)) {
        out.add(Ripeness.picked);
        continue;
      }
      if (currentSignature != null && b.signature == currentSignature) {
        out.add(Ripeness.ripe);
        continue;
      }
      if (b.isDropped) {
        out.add(Ripeness.overripe);
        continue;
      }
      final end = b.estStart + b.durationMinutes / 60.0;
      if (end <= now) {
        out.add(b.isAnchor ? Ripeness.picked : Ripeness.overripe);
        continue;
      }
      if (b.estStart <= now) {
        // In-progress but not the hero (e.g. a running anchor): treat as ripe-adjacent "nearly".
        out.add(Ripeness.nearly);
        continue;
      }
      if (!nextSeen && !b.isAnchor) {
        nextSeen = true;
        out.add(Ripeness.nearly);
        continue;
      }
      final minutesUntil = (b.estStart - now) * 60;
      out.add(minutesUntil <= ripeningWindowMinutes
          ? Ripeness.ripening
          : Ripeness.unripe);
    }
    return out;
  }
}
