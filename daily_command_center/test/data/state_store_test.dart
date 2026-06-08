import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/state_store.dart';
import 'package:daily_command_center/data/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('state_store_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('loadState returns empty state for an unknown date', () async {
    final state = await StateStore.loadState(DateTime(2026, 6, 8));
    expect(state.date, '2026-06-08');
    expect(state.deletedItems, isEmpty);
    expect(state.driftLog, isEmpty);
  });

  test('saveState then loadState round-trips', () async {
    const state = DailyState(
      date: '2026-06-08',
      deletedItems: ['snack'],
    );
    await StateStore.saveState(state);
    final loaded = await StateStore.loadState(DateTime(2026, 6, 8));
    expect(loaded.deletedItems, ['snack']);
  });

  test('appendDriftEvent accumulates events without clobbering plan', () async {
    const e1 = DriftEvent(date: '2026-06-08', itemId: 'focus', label: 'Deep Focus', event: 'compacted', driftMinutes: 10);
    const e2 = DriftEvent(date: '2026-06-08', itemId: 'dsa', label: 'DSA', event: 'killed');
    await StateStore.appendDriftEvent(DateTime(2026, 6, 8), e1);
    await StateStore.appendDriftEvent(DateTime(2026, 6, 8), e2);
    final state = await StateStore.loadState(DateTime(2026, 6, 8));
    expect(state.driftLog.length, 2);
    expect(state.driftLog[0].itemId, 'focus');
    expect(state.driftLog[1].itemId, 'dsa');
    // Confirm plan is intact after state writes.
    final plan = await AppStore.loadPlan();
    expect(plan.schemaVersion, 3);
  });

  test('recentDriftEvents aggregates across days oldest-first', () async {
    final today = DateTime(2026, 6, 8);
    final yesterday = today.subtract(const Duration(days: 1));
    const e1 = DriftEvent(date: '2026-06-07', itemId: 'focus', label: 'Deep Focus', event: 'compacted');
    const e2 = DriftEvent(date: '2026-06-08', itemId: 'dsa', label: 'DSA', event: 'killed');
    await StateStore.appendDriftEvent(yesterday, e1);
    await StateStore.appendDriftEvent(today, e2);
    final events = await StateStore.recentDriftEvents(today, days: 7);
    expect(events.length, 2);
    expect(events.first.date, '2026-06-07');
    expect(events.last.date, '2026-06-08');
  });

  test('recentDriftEvents returns empty when no events exist', () async {
    final events = await StateStore.recentDriftEvents(DateTime(2026, 6, 8));
    expect(events, isEmpty);
  });
}
