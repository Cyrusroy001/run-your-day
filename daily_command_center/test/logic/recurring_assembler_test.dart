import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/assembler.dart';

late Plan _plan;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  const today = '2026-06-10';

  test('recurring task active for today appears as isCustom block at priority 0', () {
    const task = RecurringCustomTask(
      id: 'recur_1',
      label: 'Evening walk',
      preferredTime: '19:30',
      durationMinutes: 30,
      activeDates: [today],
      originTaskId: 'custom_1',
    );
    final blocks = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon',
      training: false,
      state: const DailyState(date: today),
      recurringTasks: [task],
    );

    final recur = blocks.where((b) => b.id == 'recur_1').toList();
    expect(recur, hasLength(1));
    expect(recur.first.isCustom, isTrue);
    expect(recur.first.priority, 0);
    expect(recur.first.label, 'Evening walk');
    expect(recur.first.durationMinutes, 30);
    expect(recur.first.cls, 'custom');
  });

  test('recurring task time matches preferredTime (converted to 12h display)', () {
    const task = RecurringCustomTask(
      id: 'recur_2',
      label: 'Yoga',
      preferredTime: '07:30',
      durationMinutes: 45,
      activeDates: [today],
      originTaskId: 'custom_2',
    );
    final blocks = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon',
      training: false,
      state: const DailyState(date: today),
      recurringTasks: [task],
    );

    final recur = blocks.firstWhere((b) => b.id == 'recur_2');
    expect(recur.time, '7:30'); // displayTime('07:30')
  });

  test('recurring task not in activeDates for today is excluded', () {
    const task = RecurringCustomTask(
      id: 'recur_3',
      label: 'Wrong day task',
      preferredTime: '10:00',
      durationMinutes: 30,
      activeDates: ['2026-06-11', '2026-06-12'], // not today
      originTaskId: 'custom_3',
    );
    final blocks = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon',
      training: false,
      state: const DailyState(date: today),
      recurringTasks: [task],
    );

    expect(blocks.any((b) => b.id == 'recur_3'), isFalse);
  });

  test('empty recurringTasks list leaves output unchanged', () {
    final without = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false,
      state: const DailyState(date: today),
    );
    final withEmpty = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false,
      state: const DailyState(date: today),
      recurringTasks: const [],
    );

    expect(withEmpty.map((b) => b.id).toList(),
        without.map((b) => b.id).toList());
  });

  test('recurring and addedItems tasks both appear when both present', () {
    const custom = CustomTask(
      id: 'custom_A', label: 'One-off', startTime: '14:00',
      durationMinutes: 30, date: today,
    );
    const recur = RecurringCustomTask(
      id: 'recur_A', label: 'Recurring', preferredTime: '20:00',
      durationMinutes: 30, activeDates: [today], originTaskId: 'custom_A',
    );
    final blocks = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false,
      state: DailyState(date: today, addedItems: [custom]),
      recurringTasks: [recur],
    );

    expect(blocks.any((b) => b.id == 'custom_A'), isTrue);
    expect(blocks.any((b) => b.id == 'recur_A'), isTrue);
  });
}
