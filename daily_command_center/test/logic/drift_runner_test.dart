import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/state_store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/logic/drift_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('drift_runner_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Block _train() => const Block(
        time: 'train', cls: 'train', label: 'Train', id: 'train', isTrain: true,
        seedStart: 18.5, estStart: 20.5, durationMinutes: 60, idealMinutes: 60,
        minMinutes: 40, priority: 3,
        cutoffDecimal: 20.0, dropStrategy: 'kill_and_notify',
      );

  test('a new kill fires once and is persisted; re-run does not double-fire', () async {
    final day = DateTime(2026, 6, 9);
    final fired = <String>[];
    final runner = DriftRunner(notify: (t, b) async => fired.add(t));

    final r1 = await runner.run([_train()], now: 20.5, done: {}, day: day);
    expect(r1.blocks.first.status, BlockStatus.dropped);
    expect(fired.length, 1);
    final logged = (await StateStore.loadState(day)).driftLog;
    expect(logged.where((e) => e.event == 'killed' && e.itemId == 'train').length, 1);

    // Re-run same minute: no new notification, no duplicate log entry.
    await runner.run([_train()], now: 20.6, done: {}, day: day);
    expect(fired.length, 1);
    final logged2 = (await StateStore.loadState(day)).driftLog;
    expect(logged2.where((e) => e.event == 'killed' && e.itemId == 'train').length, 1);
  });

  test('compacted events are not notified (only killed)', () async {
    final day = DateTime(2026, 6, 9);
    final fired = <String>[];
    final runner = DriftRunner(notify: (t, b) async => fired.add(t));

    // A compacted block (no dropStrategy) should not trigger a notification.
    const focus = Block(
      time: 'focus', cls: 'focus', label: 'Deep Focus', id: 'focus',
      seedStart: 8.5, estStart: 8.5, durationMinutes: 75, idealMinutes: 75,
      minMinutes: 45, priority: 2,
    );
    final anchor = const Block(
      time: 'work', cls: 'work', label: 'Work', id: 'work',
      estStart: 9.0, isAnchor: true, hardAnchor: true,
    );
    await runner.run([focus, anchor], now: 8.9, done: {}, day: day);
    expect(fired, isEmpty);
  });
}
