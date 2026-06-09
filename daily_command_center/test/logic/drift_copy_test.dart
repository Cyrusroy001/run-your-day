import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/drift_engine.dart';
import 'package:daily_command_center/logic/drift_copy.dart';

Block _b(String id, String label, {bool anchor = false, bool dropped = false, int ideal = 60, int dur = 60, bool hard = false}) =>
    Block(time: id, cls: anchor ? 'work' : 'focus', label: label, id: id, isAnchor: anchor, hardAnchor: hard,
        idealMinutes: ideal, durationMinutes: dur, status: dropped ? BlockStatus.dropped : BlockStatus.pending);

void main() {
  test('on-track summary when nothing drifted', () {
    final day = ResolvedDay([_b('focus', 'Deep Focus'), _b('work', 'Work', anchor: true, hard: true)], const []);
    expect(DriftCopy.summary(day), 'On track. The plan’s holding.');
  });

  test('drifting summary names trimmed items and the protected anchor — from labels', () {
    final day = ResolvedDay([
      _b('brunch', 'Shower + brunch', ideal: 45, dur: 30),
      _b('work', 'Work', anchor: true, hard: true),
      _b('train', 'Train', dropped: true),
    ], const []);
    final s = DriftCopy.summary(day);
    expect(s, contains('Shower + brunch')); // trimmed item label
    expect(s, contains('Work'));            // protected anchor label
    expect(s, contains('Train'));           // dropped item label
  });

  test('compaction teaching copy uses the item + anchor labels', () {
    final c = DriftCopy.teachCompaction(itemLabel: 'Shower + brunch', minutes: 15, anchorLabel: 'Work');
    expect(c, 'I trimmed Shower + brunch by 15m so your Work still starts on time. Budgets flex; anchors don’t.');
  });

  test('peek line shows planned vs now + budget', () {
    final blk = Block(time: '9:05', cls: 'meal', label: 'Brunch', id: 'brunch',
        seedStart: 11.0, estStart: 11.17, idealMinutes: 45, durationMinutes: 30);
    expect(DriftCopy.peek(blk, anchorLabel: 'Work'),
        'planned 11:00 · now 11:10 · budget 45→30m (to hold Work)');
  });

  test('weeklyNudge names the most-killed item from labels', () {
    final events = [
      const DriftEvent(date: 'x', itemId: 'train', label: 'Train', event: 'killed'),
      const DriftEvent(date: 'y', itemId: 'train', label: 'Train', event: 'killed'),
      const DriftEvent(date: 'z', itemId: 'focus', label: 'Focus', event: 'compacted'),
    ];
    expect(DriftCopy.weeklyNudge(events), 'Train keeps getting squeezed out — move it earlier, or shorten its budget?');
    expect(DriftCopy.weeklyNudge(const []), isNull);
  });
}
