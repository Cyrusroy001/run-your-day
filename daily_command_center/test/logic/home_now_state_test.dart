import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/drift_engine.dart';
import 'package:daily_command_center/logic/home_now_state.dart';

Block _b(String id, String label, double start, int dur) =>
    Block(time: id, cls: 'meal', label: label, id: id, estStart: start, durationMinutes: dur, idealMinutes: dur);

void main() {
  final day = ResolvedDay([_b('a', 'Wake', 8.0, 30), _b('b', 'Focus', 8.5, 75), _b('c', 'Brunch', 11.0, 45)], const []);

  test('before first block -> resting state', () {
    final s = HomeNowState.from(day, now: 7.0);
    expect(s.isResting, true);
    expect(s.nextLabel, 'Wake');
  });

  test('within a block -> current + next + progress', () {
    final s = HomeNowState.from(day, now: 9.0); // inside Focus (8.5–9.75)
    expect(s.currentLabel, 'Focus');
    expect(s.nextLabel, 'Brunch');
    expect(s.progress, closeTo((9.0 - 8.5) / (75 / 60), 0.05));
    expect(s.minutesLeft, closeTo(45, 2));
  });

  test('after last block -> day done', () {
    final s = HomeNowState.from(day, now: 23.5);
    expect(s.isDayDone, true);
  });

  test('live card is present-time, not a stale un-done morning block', () {
    // Nothing done by 20:15. The engine must not surface "Wake" as current.
    const blocks = [
      Block(time: 'wake', cls: 'meal', label: 'Wake', id: 'wake', estStart: 8.0, durationMinutes: 30, idealMinutes: 30),
      Block(time: 'focus', cls: 'focus', label: 'Focus', id: 'focus', estStart: 8.5, durationMinutes: 60, idealMinutes: 60),
      Block(time: 'dinner', cls: 'meal', label: 'Dinner', id: 'dinner', estStart: 20.0, durationMinutes: 45, idealMinutes: 45),
    ];
    final resolved = DriftEngine.computeDay(blocks, now: 20.25, done: {});
    final s = HomeNowState.from(resolved, now: 20.25);
    expect(s.currentLabel, 'Dinner');
    expect(s.currentLabel, isNot('Wake'));
  });
}
