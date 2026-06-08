import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/weekly_review.dart';

void main() {
  test('summarizes kills and compactions in plain language', () {
    final events = [
      const DriftEvent(date: '2026-06-02', itemId: 'train', label: 'Train', event: 'killed', driftMinutes: 100),
      const DriftEvent(date: '2026-06-05', itemId: 'train', label: 'Train', event: 'killed', driftMinutes: 110),
      const DriftEvent(date: '2026-06-03', itemId: 'focus', label: 'Deep Focus', event: 'compacted', fromDuration: 75, toDuration: 45),
      const DriftEvent(date: '2026-06-04', itemId: 'focus', label: 'Deep Focus', event: 'compacted', fromDuration: 75, toDuration: 50),
    ];
    final s = WeeklyReview.summarize(events);
    expect(s.killCount, 2);
    expect(s.compactCount, 2);
    expect(s.jettisonCount, 0);
    expect(s.sentence, contains('Train auto-cancelled 2×'));
    expect(s.sentence, contains('Deep Focus compacted 2×'));
  });

  test('empty week yields an encouraging message', () {
    final s = WeeklyReview.summarize(const []);
    expect(s.killCount, 0);
    expect(s.sentence, contains('No drift'));
  });

  test('jettisoned events are counted and labelled', () {
    final events = [
      const DriftEvent(date: '2026-06-06', itemId: 'dsa', label: 'DSA Practice', event: 'jettisoned'),
    ];
    final s = WeeklyReview.summarize(events);
    expect(s.jettisonCount, 1);
    expect(s.sentence, contains('DSA Practice dropped 1×'));
  });
}
