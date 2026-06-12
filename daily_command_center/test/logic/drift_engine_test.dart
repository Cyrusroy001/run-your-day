import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/drift_engine.dart';

Block _item(String id, double start, {int ideal = 30, int prio = 3}) =>
    Block(time: id, cls: 'focus', label: id, id: id, estStart: start, durationMinutes: ideal, idealMinutes: ideal, priority: prio);

Block _anchor(String id, double start, {bool hard = true}) =>
    Block(time: id, cls: 'work', label: id, id: id, estStart: start, isAnchor: true, hardAnchor: hard);

Block _itemC(String id, double start, {required int ideal, required int min, required int prio}) =>
    Block(time: id, cls: 'focus', label: id, id: id, estStart: start,
        durationMinutes: ideal, idealMinutes: ideal, minMinutes: min, priority: prio);

void main() {
  // B1: Est-Start cascade + pinned anchors
  test('zero-drift: estStart equals seed start (now before first item)', () {
    final blocks = [_item('a', 8.0, ideal: 30), _item('b', 9.0, ideal: 30)];
    final day = DriftEngine.computeDay(blocks, now: 7.0, done: {});
    expect(day.blocks[0].estStart, closeTo(8.0, 0.001));
    expect(day.blocks[1].estStart, closeTo(9.0, 0.001));
    expect(day.events, isEmpty);
  });

  test('anchor keeps its fixed estStart regardless of upstream', () {
    final blocks = [_item('a', 8.0, ideal: 60), _anchor('work', 14.0)];
    final day = DriftEngine.computeDay(blocks, now: 7.0, done: {});
    expect(day.blocks.firstWhere((b) => b.id == 'work').estStart, closeTo(14.0, 0.001));
  });

  // B2: Transition buffer
  test('inserts a 5-min transition buffer when items are back-to-back', () {
    // now before first item: a runs 8:00 + 60min = 9:00; b seeds 9:00 -> pushed to 9:00 + 5min buffer
    final blocks = [_item('a', 8.0, ideal: 60), _item('b', 9.0, ideal: 30)];
    final day = DriftEngine.computeDay(blocks, now: 7.0, done: {});
    expect(day.blocks[1].estStart, closeTo(9.0 + 5 / 60.0, 0.001));
  });

  // B3: Drift injection from now
  test('running late: active item and downstream cascade from now', () {
    // now=10:00 but item a seeds 8:00 (not done) -> a starts at 10:00, b cascades after
    final blocks = [_item('a', 8.0, ideal: 60), _item('b', 9.5, ideal: 30)];
    final day = DriftEngine.computeDay(blocks, now: 10.0, done: {});
    expect(day.blocks[0].estStart, closeTo(10.0, 0.001));          // pulled to now
    expect(day.blocks[1].estStart, closeTo(11.0 + 5 / 60.0, 0.01)); // 10 + 60min + buffer
  });

  test('done items do not absorb now; first not-done is the active anchor of drift', () {
    final blocks = [_item('a', 8.0, ideal: 30), _item('b', 9.0, ideal: 30)];
    final day = DriftEngine.computeDay(blocks, now: 10.0, done: {'a|a'});
    // a is done (keeps seed), b is active -> pulled to now
    expect(day.blocks[1].estStart, closeTo(10.0, 0.001));
  });

  // B4: Micro-compaction
  test('compaction shrinks least-important item first to protect a hard anchor', () {
    // Two items before a hard anchor at 11:00. Running late at 10:00.
    // a: ideal 60 min 40 prio 2 ; b: ideal 60 min 30 prio 5 (less important)
    final blocks = [
      _itemC('a', 10.0, ideal: 60, min: 40, prio: 2),
      _itemC('b', 10.5, ideal: 60, min: 30, prio: 5),
      _anchor('work', 11.0, hard: true),
    ];
    final day = DriftEngine.computeDay(blocks, now: 10.0, done: {});
    final b = day.blocks.firstWhere((x) => x.id == 'b');
    expect(b.durationMinutes, lessThan(60));
    expect(day.events.any((e) => e.itemId == 'b' && e.event == 'compacted'), true);
  });

  // B5: Jettison protocol
  test('jettisons the least-important item when min durations still overflow', () {
    // Two 60min items (no shrink room) before a hard anchor 30 min away -> must drop.
    final blocks = [
      _itemC('a', 13.0, ideal: 60, min: 60, prio: 2),
      _itemC('b', 13.0, ideal: 60, min: 60, prio: 7), // least important
      _anchor('work', 14.0, hard: true),
    ];
    final day = DriftEngine.computeDay(blocks, now: 13.0, done: {});
    final b = day.blocks.firstWhere((x) => x.id == 'b');
    expect(b.status, BlockStatus.dropped);
    expect(day.events.any((e) => e.itemId == 'b' && e.event == 'jettisoned'), true);
  });

  // B6: Two-way elasticity
  test('re-inflates to ideal when the schedule is no longer late', () {
    // a seeds 12.0 ideal=30min; b seeds 12.5 ideal=60min min=30; anchor at 14.0.
    // Late (now=13.5): a pulled to 13.5 → ends 14.0; b pushed to 14.083 → overflows → compact b.
    // Ahead (now=7.0): a stays at seed 12.0 → ends 12.5; b at 12.583 → ends 13.25 → fits → b stays ideal.
    final blocks = [
      _itemC('a', 12.0, ideal: 30, min: 20, prio: 2),
      _itemC('b', 12.5, ideal: 60, min: 30, prio: 5),
      _anchor('work', 14.0, hard: true),
    ];
    final late = DriftEngine.computeDay(blocks, now: 13.5, done: {});
    expect(late.blocks.firstWhere((x) => x.id == 'b').durationMinutes, lessThan(60));
    final ahead = DriftEngine.computeDay(blocks, now: 7.0, done: {});
    expect(ahead.blocks.firstWhere((x) => x.id == 'b').durationMinutes, 60);
    expect(ahead.blocks.firstWhere((x) => x.id == 'a').durationMinutes, 30);
  });

  // C1: cutoffTime breach
  test('cutoffTime breach kills the item and emits a killed event', () {
    const train = Block(
      time: 'train', cls: 'train', label: 'Train', id: 'train', isTrain: true,
      seedStart: 18.5, estStart: 20.5, durationMinutes: 60, idealMinutes: 60, minMinutes: 40, priority: 3,
      cutoffDecimal: 20.0, dropStrategy: 'kill_and_notify',
    );
    final day = DriftEngine.computeDay([train], now: 20.5, done: {});
    final t = day.blocks.firstWhere((b) => b.id == 'train');
    expect(t.status, BlockStatus.dropped);
    expect(day.events.any((e) => e.itemId == 'train' && e.event == 'killed'), true);
  });

  test('no breach when estStart is before the cutoff', () {
    const train = Block(
      time: 'train', cls: 'train', label: 'Train', id: 'train', isTrain: true,
      seedStart: 10.0, estStart: 10.0, durationMinutes: 60, idealMinutes: 60, minMinutes: 40, priority: 3,
      cutoffDecimal: 20.0, dropStrategy: 'kill_and_notify',
    );
    final day = DriftEngine.computeDay([train], now: 10.0, done: {});
    expect(day.blocks.first.status, BlockStatus.pending);
    expect(day.events, isEmpty);
  });

  // C2: maxDriftMinutes breach
  test('maxDriftMinutes breach kills when drift exceeds the ceiling', () {
    const focus = Block(
      time: 'focus', cls: 'focus', label: 'Deep Focus', id: 'focus',
      seedStart: 8.5, estStart: 8.5, durationMinutes: 75, idealMinutes: 75, minMinutes: 45, priority: 2,
      maxDriftMinutes: 60, dropStrategy: 'kill_and_notify',
    );
    // now = 10:00 -> active item pulled to 10:00; drift = 90 min > 60 ceiling
    final day = DriftEngine.computeDay([focus], now: 10.0, done: {});
    expect(day.blocks.first.status, BlockStatus.dropped);
    expect(day.events.single.event, 'killed');
    expect(day.events.single.driftMinutes, 90);
  });
}
