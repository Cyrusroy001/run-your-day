import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/weekly_review.dart';

CustomTask _t(String label, String date, {String time = '19:00', int dur = 30}) =>
    CustomTask(id: 'c_${date}_$label', label: label, startTime: time, durationMinutes: dur, date: date);

DailyState _day(String date, List<CustomTask> items) => DailyState(date: date, addedItems: items);

void main() {
  test('label appearing on 3 distinct days becomes a candidate (count = days)', () {
    final states = [
      _day('2026-06-08', [_t('Evening walk', '2026-06-08')]),
      _day('2026-06-09', [_t('Evening walk', '2026-06-09')]),
      _day('2026-06-10', [_t('Evening walk', '2026-06-10')]),
    ];
    final cands = WeeklyReview.promotionCandidates(states);
    expect(cands, hasLength(1));
    expect(cands.first.label, 'Evening walk');
    expect(cands.first.count, 3);
  });

  test('label appearing on only 2 days is NOT a candidate', () {
    final states = [
      _day('2026-06-09', [_t('Read', '2026-06-09')]),
      _day('2026-06-10', [_t('Read', '2026-06-10')]),
    ];
    expect(WeeklyReview.promotionCandidates(states), isEmpty);
  });

  test('preferredTime and duration come from the most recent occurrence', () {
    final states = [
      _day('2026-06-08', [_t('Stretch', '2026-06-08', time: '07:00', dur: 15)]),
      _day('2026-06-09', [_t('Stretch', '2026-06-09', time: '07:30', dur: 20)]),
      _day('2026-06-10', [_t('Stretch', '2026-06-10', time: '08:00', dur: 45)]),
    ];
    final c = WeeklyReview.promotionCandidates(states).single;
    expect(c.preferredTime, '08:00');
    expect(c.durationMinutes, 45);
  });

  test('same label twice on the same day counts as one day', () {
    final states = [
      _day('2026-06-08', [_t('Walk', '2026-06-08'), _t('Walk', '2026-06-08')]),
      _day('2026-06-09', [_t('Walk', '2026-06-09')]),
    ];
    // Only two distinct days → below the 3-day threshold.
    expect(WeeklyReview.promotionCandidates(states), isEmpty);
  });

  test('candidates are sorted by run-count descending', () {
    final states = [
      _day('2026-06-06', [_t('A', '2026-06-06'), _t('B', '2026-06-06')]),
      _day('2026-06-07', [_t('A', '2026-06-07'), _t('B', '2026-06-07')]),
      _day('2026-06-08', [_t('A', '2026-06-08'), _t('B', '2026-06-08')]),
      _day('2026-06-09', [_t('B', '2026-06-09')]),
    ];
    final cands = WeeklyReview.promotionCandidates(states);
    expect(cands.map((c) => c.label).toList(), ['B', 'A']);
    expect(cands.first.count, 4);
    expect(cands.last.count, 3);
  });

  test('empty states → empty candidates', () {
    expect(WeeklyReview.promotionCandidates(const []), isEmpty);
  });

  test('minRuns is configurable', () {
    final states = [
      _day('2026-06-09', [_t('Yoga', '2026-06-09')]),
      _day('2026-06-10', [_t('Yoga', '2026-06-10')]),
    ];
    expect(WeeklyReview.promotionCandidates(states, minRuns: 2), hasLength(1));
  });
}
