import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  test('displayTime converts 24h to the existing 12h display strings', () {
    expect(displayTime('08:00'), '8:00');
    expect(displayTime('09:45'), '9:45');
    expect(displayTime('11:30'), '11:30');
    expect(displayTime('12:00'), '12:00');
    expect(displayTime('13:50'), '1:50');
    expect(displayTime('14:00'), '2:00');
    expect(displayTime('17:00'), '5:00');
    expect(displayTime('20:30'), '8:30');
    expect(displayTime('23:15'), '11:15');
    expect(displayTime('00:30'), '12:30');
  });

  test('Block keeps backward-compatible defaults and adds engine fields', () {
    const b = Block(time: '8:00', cls: 'meal', label: 'Wake');
    expect(b.status, BlockStatus.pending);
    expect(b.isAnchor, false);
    expect(b.durationMinutes, 0);
    expect(b.signature, '8:00|Wake');
    final b2 = b.copyWith(status: BlockStatus.dropped, durationMinutes: 40, idealMinutes: 60, estStart: 10.5);
    expect(b2.status, BlockStatus.dropped);
    expect(b2.isCompacted, true); // 40 < 60, and not an anchor
    expect(b2.estStart, 10.5);
    // Anchors are fixed walls — never reported as compacted.
    expect(b.copyWith(isAnchor: true).isAnchor, true);
    expect(b.copyWith(durationMinutes: 40, idealMinutes: 60, isAnchor: true).isCompacted, false);
  });
}
