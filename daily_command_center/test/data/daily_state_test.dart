import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  test('DailyState round-trips, with empty defaults', () {
    const ds = DailyState(date: '2026-06-08');
    expect(ds.deletedItems, isEmpty);
    expect(ds.dailySequence, isEmpty);
    expect(ds.dailyOverrides, isEmpty);
    expect(ds.driftLog, isEmpty);
    expect(DailyState.fromJson(ds.toJson()).date, '2026-06-08');
  });

  test('DailyState carries overrides and drift events', () {
    const ds = DailyState(
      date: '2026-06-08',
      deletedItems: ['snack'],
      dailySequence: ['wake', 'focus', 'train'],
      dailyOverrides: {'focus': ItemOverride(priority: 1)},
      driftLog: [DriftEvent(date: '2026-06-08', itemId: 'train', label: 'Train', event: 'killed', driftMinutes: 105)],
    );
    final round = DailyState.fromJson(ds.toJson());
    expect(round.deletedItems, ['snack']);
    expect(round.dailyOverrides['focus']!.priority, 1);
    expect(round.driftLog.single.event, 'killed');
    expect(round.toJson(), ds.toJson());
  });
}
