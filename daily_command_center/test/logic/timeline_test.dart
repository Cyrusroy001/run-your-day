import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/timeline.dart';

void main() {
  group('buildTimes', () {
    test('correctly resolves AM times', () {
      final blocks = [
        const Block(time: '8:00', cls: 'meal', label: 'Wake'),
        const Block(time: '8:30', cls: 'focus', label: 'Focus'),
        const Block(time: '11:30', cls: 'meal', label: 'Brunch'),
      ];
      final times = buildTimes(blocks);
      expect(times[0], closeTo(8.0, 0.01));
      expect(times[1], closeTo(8.5, 0.01));
      expect(times[2], closeTo(11.5, 0.01));
    });

    test('resolves afternoon times as PM, not AM', () {
      final blocks = [
        const Block(time: '8:00', cls: 'meal', label: 'Wake'),
        const Block(time: '1:50', cls: 'work', label: 'Commute'),
        const Block(time: '2:00', cls: 'work', label: 'Work'),
        const Block(time: '3:00', cls: 'meal', label: 'Lunch'),
        const Block(time: '8:30', cls: 'meal', label: 'Dinner'),
      ];
      final times = buildTimes(blocks);
      expect(times[1], closeTo(13.833, 0.01));
      expect(times[2], closeTo(14.0, 0.01));
      expect(times[3], closeTo(15.0, 0.01));
      expect(times[4], closeTo(20.5, 0.01));
    });

    test('times are always strictly increasing', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: true);
      final blocks = buildTimeline('mon', plan);
      final times = buildTimes(blocks);
      for (int i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]),
            reason: 'Time went backward at index $i: ${times[i - 1]} → ${times[i]}');
      }
    });
  });

  group('buildTimeline', () {
    test('office+training day includes a train block', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: true);
      final blocks = buildTimeline('mon', plan);
      expect(blocks.any((b) => b.isTrain), true);
    });

    test('office+rest day has no train block', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: false);
      final blocks = buildTimeline('mon', plan);
      expect(blocks.any((b) => b.isTrain), false);
    });

    test('wfh+training uses workout A', () {
      const plan = DayPlan(schedule: DaySchedule.wfh, isTraining: true);
      final blocks = buildTimeline('wed', plan);
      final trainBlock = blocks.firstWhere((b) => b.isTrain);
      expect(trainBlock.workout, 'A');
    });

    test('office+training uses workout B', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: true);
      final blocks = buildTimeline('mon', plan);
      final trainBlock = blocks.firstWhere((b) => b.isTrain);
      expect(trainBlock.workout, 'B');
    });

    test('sat uses BENCH, sun uses CARDIO', () {
      const plan = DayPlan(schedule: DaySchedule.weekend, isTraining: true);
      final sat = buildTimeline('sat', plan);
      final sun = buildTimeline('sun', plan);
      expect(sat.firstWhere((b) => b.isTrain).workout, 'BENCH');
      expect(sun.firstWhere((b) => b.isTrain).workout, 'CARDIO');
    });
  });
}
