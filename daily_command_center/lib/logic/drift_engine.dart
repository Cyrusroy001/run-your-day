import '../data/models.dart';

class ResolvedDay {
  final List<Block> blocks;
  final List<DriftEvent> events;
  const ResolvedDay(this.blocks, this.events);
}

class DriftEngine {
  static const int transitionBufferMinutes = 5;

  /// Pure: compute Est Start + durations + status for the day.
  /// [blocks] must be clock-ordered (assembler output). [now] is a 24h decimal.
  static ResolvedDay computeDay(
    List<Block> blocks, {
    required double now,
    required Set<String> done,
    String dateIso = '',
  }) {
    final events = <DriftEvent>[];
    final dur = [for (final b in blocks) b.idealMinutes > 0 ? b.idealMinutes : b.durationMinutes];
    final allDropped = <int>{};

    var day = _cascade(blocks, dur, now: now, done: done, dropped: allDropped);

    // Compaction: for each hard anchor, shrink overflowing items before it.
    for (int ai = 0; ai < blocks.length; ai++) {
      final anchor = blocks[ai];
      if (!anchor.isAnchor || !anchor.hardAnchor) continue;

      bool overflows() {
        final anchorEst = anchor.estStart;
        for (int i = ai - 1; i >= 0; i--) {
          if (blocks[i].isAnchor || allDropped.contains(i)) continue;
          final endH = day.blocks[i].estStart + dur[i] / 60.0;
          return endH > anchorEst + 0.0001;
        }
        return false;
      }

      final candidates = <int>[];
      for (int i = 0; i < ai; i++) {
        if (blocks[i].isAnchor) continue;
        if (done.contains(blocks[i].signature)) continue;
        if (allDropped.contains(i)) continue;
        if (blocks[i].minMinutes < dur[i]) candidates.add(i);
      }
      candidates.sort((x, y) => blocks[y].priority.compareTo(blocks[x].priority));

      int ci = 0;
      while (overflows() && ci < candidates.length) {
        final i = candidates[ci];
        if (dur[i] > blocks[i].minMinutes) {
          final from = dur[i];
          dur[i] = blocks[i].minMinutes;
          events.add(DriftEvent(
            date: dateIso, itemId: blocks[i].id ?? '', label: blocks[i].label,
            event: 'compacted', fromDuration: from, toDuration: dur[i],
            note: 'compacted to protect ${anchor.label}',
          ));
          day = _cascade(blocks, dur, now: now, done: done, dropped: allDropped);
        }
        ci++;
      }

      // Jettison: if still overflowing after compaction, drop least-important items.
      final jettCandidates = <int>[];
      for (int i = 0; i < ai; i++) {
        if (blocks[i].isAnchor) continue;
        if (done.contains(blocks[i].signature)) continue;
        if (allDropped.contains(i)) continue;
        jettCandidates.add(i);
      }
      jettCandidates.sort((x, y) => blocks[y].priority.compareTo(blocks[x].priority));
      int ji = 0;
      while (overflows() && ji < jettCandidates.length) {
        final i = jettCandidates[ji];
        allDropped.add(i);
        dur[i] = 0;
        events.add(DriftEvent(
          date: dateIso, itemId: blocks[i].id ?? '', label: blocks[i].label,
          event: 'jettisoned', note: 'dropped to protect ${anchor.label}',
        ));
        day = _cascade(blocks, dur, now: now, done: done, dropped: allDropped);
        ji++;
      }
    }

    // Circuit-breaker: kill items past cutoff or drift ceiling.
    bool anyKilled = false;
    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.isAnchor) continue;
      if (b.dropStrategy != 'kill_and_notify') continue;
      if (done.contains(b.signature)) continue;
      if (allDropped.contains(i)) continue;
      final est = day.blocks[i].estStart;
      final cutoffBreach = b.cutoffDecimal != null && est > b.cutoffDecimal! + 0.0001;
      final driftBreach = b.maxDriftMinutes != null && (est - b.seedStart) * 60.0 > b.maxDriftMinutes! + 0.0001;
      if (cutoffBreach || driftBreach) {
        allDropped.add(i);
        dur[i] = 0;
        anyKilled = true;
        events.add(DriftEvent(
          date: dateIso, itemId: b.id ?? '', label: b.label, event: 'killed',
          driftMinutes: ((est - b.seedStart) * 60.0).round(),
          note: cutoffBreach ? 'past cutoff ${b.cutoffDecimal}' : 'drifted past ${b.maxDriftMinutes}m',
        ));
      }
    }
    if (anyKilled) {
      day = _cascade(blocks, dur, now: now, done: done, dropped: allDropped);
    }

    return ResolvedDay(day.blocks, events);
  }

  /// Single forward pass: compute estStart per block given working durations [dur].
  static ResolvedDay _cascade(
    List<Block> blocks,
    List<int> dur, {
    required double now,
    required Set<String> done,
    Set<int> dropped = const {},
  }) {
    final out = <Block>[];
    final buffer = transitionBufferMinutes / 60.0;
    final activeIdx = _findActive(blocks, done, dropped);
    double cursor = 0;
    bool started = false;

    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.isAnchor) {
        out.add(b.copyWith(status: BlockStatus.pending));
        if (cursor < b.estStart) cursor = b.estStart;
        continue;
      }
      if (dropped.contains(i)) {
        out.add(b.copyWith(durationMinutes: 0, status: BlockStatus.dropped));
        continue;
      }
      final isDone = done.contains(b.signature);
      double est = b.estStart;
      if (i == activeIdx && now > est) {
        est = now;
      } else if (started && cursor + buffer > est) {
        est = cursor + buffer;
      }
      cursor = est + dur[i] / 60.0;
      started = true;
      out.add(b.copyWith(estStart: est, durationMinutes: dur[i], status: isDone ? BlockStatus.done : BlockStatus.pending));
    }
    return ResolvedDay(out, const []);
  }

  static int _findActive(List<Block> blocks, Set<String> done, Set<int> dropped) {
    for (int i = 0; i < blocks.length; i++) {
      if (blocks[i].isAnchor) continue;
      if (dropped.contains(i)) continue;
      if (!done.contains(blocks[i].signature)) return i;
    }
    return -1;
  }
}
