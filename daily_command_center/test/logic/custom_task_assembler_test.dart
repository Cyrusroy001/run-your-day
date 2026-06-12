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

  test('custom task in addedItems appears as isCustom block at priority 0', () {
    const task = CustomTask(
      id: 'custom_1', label: 'Call mom', startTime: '19:30',
      durationMinutes: 45, date: '2026-06-09',
    );
    const state = DailyState(date: '2026-06-09', addedItems: [task]);
    final blocks = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false, state: state);

    final custom = blocks.where((b) => b.id == 'custom_1').toList();
    expect(custom, hasLength(1));
    expect(custom.first.isCustom, isTrue);
    expect(custom.first.priority, 0);
    expect(custom.first.label, 'Call mom');
    expect(custom.first.durationMinutes, 45);
    expect(custom.first.cls, 'custom');
  });

  test('custom block time matches startTime (converted to 12h display)', () {
    const task = CustomTask(
      id: 'custom_2', label: 'Gym check-in', startTime: '07:30',
      durationMinutes: 30, date: '2026-06-09',
    );
    const state = DailyState(date: '2026-06-09', addedItems: [task]);
    final blocks = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false, state: state);

    final custom = blocks.firstWhere((b) => b.id == 'custom_2');
    expect(custom.time, '7:30'); // displayTime('07:30')
  });

  test('custom task with wrong date is excluded', () {
    const task = CustomTask(
      id: 'custom_3', label: 'Wrong day', startTime: '10:00',
      durationMinutes: 30, date: '2026-06-10', // different date
    );
    const state = DailyState(date: '2026-06-09', addedItems: [task]);
    final blocks = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false, state: state);

    expect(blocks.any((b) => b.id == 'custom_3'), isFalse);
  });

  test('no addedItems leaves output identical to baseline', () {
    final withoutCustom = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false);
    final withEmptyState = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false,
      state: const DailyState(date: '2026-06-09'));

    expect(withEmptyState.map((b) => b.id).toList(),
        withoutCustom.map((b) => b.id).toList());
  });

  test('multiple custom tasks are all included and sorted by start time', () {
    const t1 = CustomTask(id: 'c1', label: 'Task A', startTime: '15:00', durationMinutes: 30, date: '2026-06-09');
    const t2 = CustomTask(id: 'c2', label: 'Task B', startTime: '09:00', durationMinutes: 30, date: '2026-06-09');
    const state = DailyState(date: '2026-06-09', addedItems: [t1, t2]);
    final blocks = TimelineAssembler.assembleDay(
      _plan, 'office', 'mon', training: false, state: state);

    final customs = blocks.where((b) => b.isCustom).toList();
    expect(customs, hasLength(2));
    // earlier start time comes first in the assembled list
    final idxA = blocks.indexWhere((b) => b.id == 'c2'); // 09:00
    final idxB = blocks.indexWhere((b) => b.id == 'c1'); // 15:00
    expect(idxA, lessThan(idxB));
  });
}
