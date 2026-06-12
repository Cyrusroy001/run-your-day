import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/heads_up.dart';

Block _b(String label, double start, {String cls = 'focus', bool anchor = false, bool dropped = false}) =>
    Block(time: label, cls: cls, label: label, estStart: start, durationMinutes: 30,
        isAnchor: anchor, status: dropped ? BlockStatus.dropped : BlockStatus.pending);

void main() {
  final now = DateTime(2026, 6, 12, 8, 0); // 08:00

  test('schedules one heads-up per upcoming actionable block, lead before start', () {
    final ups = planHeadsUps(blocks: [
      _b('Gym', 10.0), // 10:00 → fires 09:50
      _b('Lunch', 15.0), // 15:00
    ], now: now);
    expect(ups.length, 2);
    expect(ups.first.title, 'Gym in 10');
    expect(ups.first.when, DateTime(2026, 6, 12, 9, 50));
    expect(ups.first.id, headsUpIdBase);
    expect(ups.first.body, "You're all caught up.");
  });

  test('skips past, anchor, dropped, and passive blocks', () {
    final ups = planHeadsUps(blocks: [
      _b('Wake', 7.0), // past (07:00, now 08:00) → skip
      _b('Work', 14.0, cls: 'work', anchor: true), // anchor → skip
      _b('Walk', 13.0, cls: 'work'), // passive work cls → skip
      _b('Skipped', 16.0, dropped: true), // dropped → skip
      _b('Focus', 9.0), // 09:00 → fires 08:50, keep
    ], now: now);
    expect(ups.map((u) => u.title), ['Focus in 10']);
  });

  test('behind state changes the body copy', () {
    final ups = planHeadsUps(blocks: [_b('Gym', 10.0)], now: now, caughtUp: false, behindMinutes: 20);
    expect(ups.single.body, "Running ~20 behind. I'll catch you up.");
  });
}
