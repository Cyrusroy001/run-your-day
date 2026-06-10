import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/assembler.dart';

/// Each expected row: time|cls|label|isTrain|workout
List<String> _sig(List<Block> blocks) =>
    blocks.map((b) => '${b.time}|${b.cls}|${b.label}|${b.isTrain}|${b.workout ?? ""}').toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Plan plan;

  setUpAll(() async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('office + training matches today', () {
    final got = _sig(TimelineAssembler.assembleDay(plan, 'office', 'mon', training: true));
    expect(got, [
      '8:00|meal|Wake · water · sunlight|false|',
      '8:30|focus|Deep Focus — AI Building|false|',
      '9:45|meal|Break + snack|false|',
      '10:00|train|Train — Full Body B|true|B',
      '11:00|meal|Shower + brunch|false|',
      '11:30|dsa|DSA Practice (45 min)|false|',
      '1:50|work|Walk to office (10 min)|false|',
      '2:00|work|Work — 2:00 to 8:00|false|',
      '3:00|meal|Lunch at office|false|',
      '5:00|meal|Light snack at office|false|',
      '8:30|meal|Dinner|false|',
      '9:15|chill|Chill — protected downtime|false|',
      '10:45|chill|Wind-down|false|',
      '11:15|chill|Sleep target|false|',
    ]);
  });

  test('office + rest matches today', () {
    final got = _sig(TimelineAssembler.assembleDay(plan, 'office', 'tue', training: false));
    expect(got, [
      '8:00|meal|Wake · water · sunlight|false|',
      '8:30|focus|Deep Focus — AI Building|false|',
      '9:45|meal|Break + snack|false|',
      '10:00|dsa|Extra Study Block|false|',
      '11:30|dsa|DSA Practice (45 min)|false|',
      '11:30|meal|Brunch — big protein meal|false|',
      '1:50|work|Walk to office (10 min)|false|',
      '2:00|work|Work — 2:00 to 8:00|false|',
      '3:00|meal|Lunch at office|false|',
      '5:00|meal|Light snack at office|false|',
      '8:30|meal|Dinner|false|',
      '9:15|chill|Chill — protected downtime|false|',
      '10:45|chill|Wind-down|false|',
      '11:15|chill|Sleep target|false|',
    ]);
  });

  test('wfh + training uses workout A, no commute, home meals', () {
    final got = _sig(TimelineAssembler.assembleDay(plan, 'wfh', 'wed', training: true));
    expect(got.firstWhere((s) => s.contains('|train|')), '11:00|train|Train — Full Body A|true|A');
    expect(got.first, '8:00|meal|Wake · water · sunlight|false|');
    expect(got.last, '11:15|chill|Sleep target|false|');
    expect(got.any((s) => s.contains('Walk to office')), false, reason: 'WFH has no commute');
    expect(got.any((s) => s.contains('Lunch at home')), true, reason: 'WFH lunch label');
    expect(got.any((s) => s.contains('Afternoon snack')), true, reason: 'WFH snack label');
  });

  test('weekend sat training uses BENCH; weekend_sun training uses CARDIO + review', () {
    final sat = _sig(TimelineAssembler.assembleDay(plan, 'weekend', 'sat', training: true));
    final sun = _sig(TimelineAssembler.assembleDay(plan, 'weekend_sun', 'sun', training: true));
    expect(sat.firstWhere((s) => s.contains('|train|')), '11:00|train|Train — Bench + Push|true|BENCH');
    expect(sun.firstWhere((s) => s.contains('|train|')), '11:00|train|Train — Treadmill + Core|true|CARDIO');
    expect(sun.any((s) => s.contains('WEEKLY REVIEW')), true);
    expect(sat.any((s) => s.contains('WEEKLY REVIEW')), false);
  });

  test('condition filtering: train shows only on training days', () {
    final rest = _sig(TimelineAssembler.assembleDay(plan, 'wfh', 'wed', training: false));
    expect(rest.any((s) => s.contains('|train|')), false);
  });

  test('deletedItems purge removes a block', () {
    const state = DailyState(date: '2026-06-08', deletedItems: ['snack']);
    final got = _sig(TimelineAssembler.assembleDay(plan, 'office', 'mon', training: true, state: state));
    expect(got.any((s) => s.contains('Break + snack')), false);
  });
}
