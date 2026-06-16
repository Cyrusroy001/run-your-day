import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/ripeness.dart';

Block b(String label, double start, int dur, {bool anchor = false}) => Block(
    time: label, cls: anchor ? 'work' : 'focus', label: label,
    estStart: start, durationMinutes: dur, idealMinutes: dur, isAnchor: anchor);

void main() {
  test('assign maps each block to its time-relative ripeness', () {
    final blocks = [
      b('done1', 8, 30), b('missed', 9, 30), b('now', 10, 60),
      b('next', 11, 30), b('soon', 12, 30), b('later', 14, 60),
    ];
    final r = RipenessRules.assign(blocks,
        now: 10.5, done: {'done1|done1'}, currentSignature: 'now|now');
    expect(r, [
      Ripeness.picked,    // done
      Ripeness.overripe,  // past, untapped → jammy
      Ripeness.ripe,      // NOW
      Ripeness.nearly,    // up next
      Ripeness.ripening,  // within 90 min
      Ripeness.unripe,    // later
    ]);
  });

  test('past anchors read picked (walked past), future by time', () {
    final blocks = [b('work', 9, 60, anchor: true), b('late', 22, 30, anchor: true)];
    final r = RipenessRules.assign(blocks, now: 12, done: {});
    expect(r, [Ripeness.picked, Ripeness.unripe]);
  });

  test('dropped blocks read overripe', () {
    final dropped = b('x', 11, 30).copyWith(status: BlockStatus.dropped);
    expect(RipenessRules.assign([dropped], now: 10, done: {}).single,
        Ripeness.overripe);
  });
}
