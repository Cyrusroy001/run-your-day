import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/recurring_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('recurring_store_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('RecurringCustomTask model', () {
    const task = RecurringCustomTask(
      id: 'recur_1000',
      label: 'Evening walk',
      preferredTime: '19:00',
      durationMinutes: 30,
      activeDates: ['2026-06-10', '2026-06-12', '2026-06-14'],
      originTaskId: 'custom_999',
    );

    test('round-trips through toJson/fromJson', () {
      final json = task.toJson();
      final restored = RecurringCustomTask.fromJson(json);
      expect(restored.id, task.id);
      expect(restored.label, task.label);
      expect(restored.preferredTime, task.preferredTime);
      expect(restored.durationMinutes, task.durationMinutes);
      expect(restored.activeDates, task.activeDates);
      expect(restored.originTaskId, task.originTaskId);
    });

    test('toJson includes all fields', () {
      final json = task.toJson();
      expect(json['id'], 'recur_1000');
      expect(json['label'], 'Evening walk');
      expect(json['preferredTime'], '19:00');
      expect(json['durationMinutes'], 30);
      expect(json['activeDates'], ['2026-06-10', '2026-06-12', '2026-06-14']);
      expect(json['originTaskId'], 'custom_999');
    });
  });

  group('RecurringStore', () {
    const task1 = RecurringCustomTask(
      id: 'recur_1',
      label: 'Walk',
      preferredTime: '19:00',
      durationMinutes: 30,
      activeDates: ['2026-06-10', '2026-06-12'],
      originTaskId: 'custom_1',
    );
    const task2 = RecurringCustomTask(
      id: 'recur_2',
      label: 'Read',
      preferredTime: '21:00',
      durationMinutes: 45,
      activeDates: ['2026-06-11', '2026-06-14'],
      originTaskId: 'custom_2',
    );

    test('loadAll returns empty when nothing saved', () async {
      final tasks = await RecurringStore.loadAll();
      expect(tasks, isEmpty);
    });

    test('save then loadAll returns the task', () async {
      await RecurringStore.save(task1);
      final tasks = await RecurringStore.loadAll();
      expect(tasks, hasLength(1));
      expect(tasks.first.id, 'recur_1');
      expect(tasks.first.label, 'Walk');
    });

    test('save multiple tasks accumulates them', () async {
      await RecurringStore.save(task1);
      await RecurringStore.save(task2);
      final tasks = await RecurringStore.loadAll();
      expect(tasks, hasLength(2));
      expect(tasks.map((t) => t.id), containsAll(['recur_1', 'recur_2']));
    });

    test('save replaces existing task with same id', () async {
      await RecurringStore.save(task1);
      final updated = RecurringCustomTask(
        id: task1.id,
        label: 'Walk (updated)',
        preferredTime: task1.preferredTime,
        durationMinutes: task1.durationMinutes,
        activeDates: [...task1.activeDates, '2026-06-15'],
        originTaskId: task1.originTaskId,
      );
      await RecurringStore.save(updated);
      final tasks = await RecurringStore.loadAll();
      expect(tasks, hasLength(1));
      expect(tasks.first.label, 'Walk (updated)');
      expect(tasks.first.activeDates, hasLength(3));
    });

    test('removeById removes the matching task', () async {
      await RecurringStore.save(task1);
      await RecurringStore.save(task2);
      await RecurringStore.removeById(task1.id);
      final tasks = await RecurringStore.loadAll();
      expect(tasks, hasLength(1));
      expect(tasks.first.id, 'recur_2');
    });

    test('removeById on non-existent id is a no-op', () async {
      await RecurringStore.save(task1);
      await RecurringStore.removeById('recur_999');
      final tasks = await RecurringStore.loadAll();
      expect(tasks, hasLength(1));
    });

    test('activeFor returns tasks containing the date', () async {
      await RecurringStore.save(task1); // active on 2026-06-10, 2026-06-12
      await RecurringStore.save(task2); // active on 2026-06-11, 2026-06-14
      final onJune10 = await RecurringStore.activeFor('2026-06-10');
      expect(onJune10, hasLength(1));
      expect(onJune10.first.id, 'recur_1');

      final onJune11 = await RecurringStore.activeFor('2026-06-11');
      expect(onJune11, hasLength(1));
      expect(onJune11.first.id, 'recur_2');

      final onJune12 = await RecurringStore.activeFor('2026-06-12');
      expect(onJune12, hasLength(1));
      expect(onJune12.first.id, 'recur_1');
    });

    test('activeFor returns empty when no tasks match the date', () async {
      await RecurringStore.save(task1);
      final tasks = await RecurringStore.activeFor('2026-06-20');
      expect(tasks, isEmpty);
    });

    test('plan is intact after recurring store writes', () async {
      await RecurringStore.save(task1);
      final plan = await AppStore.loadPlan();
      expect(plan.schemaVersion, 3);
    });
  });
}
