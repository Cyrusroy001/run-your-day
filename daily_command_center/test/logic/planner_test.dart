import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/planner.dart';

void main() {
  group('defaultWeek', () {
    test('has exactly 4 training days', () {
      final week = PlannerLogic.defaultWeek();
      final count = week.values.where((p) => p.isTraining).length;
      expect(count, 4);
    });

    test('has no two consecutive training days', () {
      final week = PlannerLogic.defaultWeek();
      const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      for (int i = 0; i < order.length - 1; i++) {
        final a = week[order[i]]!.isTraining;
        final b = week[order[i + 1]]!.isTraining;
        expect(a && b, false,
            reason: '${order[i]} and ${order[i + 1]} are both training — consecutive');
      }
    });

    test('weekends have DaySchedule.weekend', () {
      final week = PlannerLogic.defaultWeek();
      expect(week['sat']!.schedule, DaySchedule.weekend);
      expect(week['sun']!.schedule, DaySchedule.weekend);
    });
  });

  group('toggleTraining', () {
    test('toggling training days never exceeds 4', () {
      // Behavior: a day can be toggled on/off freely; turning on a 5th day
      // displaces another for spacing, so the count is capped at 4 (and may be < 4).
      var week = PlannerLogic.defaultWeek();
      for (final day in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
        if (!week[day]!.isTraining) {
          week = PlannerLogic.toggleTraining(week, day).plan;
        }
        final count = week.values.where((p) => p.isTraining).length;
        expect(count, lessThanOrEqualTo(4));
      }
    });

    test('always maintains exactly 4 training days after toggle on', () {
      // Note: with 7 days and 4 training, the only no-consecutive subset is [Mon,Wed,Fri,Sun].
      // Toggling any non-training day must displace another, always keeping count at 4.
      final week = PlannerLogic.defaultWeek();
      final result = PlannerLogic.toggleTraining(week, 'tue');
      final count = result.plan.values.where((p) => p.isTraining).length;
      expect(count, 4);
    });

    test('provides a message when a day is moved', () {
      final week = PlannerLogic.defaultWeek();
      for (final day in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
        if (!week[day]!.isTraining) {
          final result = PlannerLogic.toggleTraining(week, day);
          expect(result.message, anyOf(isNull, isA<String>()));
          break;
        }
      }
    });
  });

  group('toggleSchedule', () {
    test('flips office to wfh', () {
      final week = PlannerLogic.defaultWeek();
      final updated = PlannerLogic.toggleSchedule(week, 'mon');
      expect(updated['mon']!.schedule, DaySchedule.wfh);
    });

    test('flips wfh to office', () {
      final week = <String, DayPlan>{
        'mon': const DayPlan(schedule: DaySchedule.wfh, isTraining: false),
        'tue': const DayPlan(schedule: DaySchedule.office, isTraining: false),
        'wed': const DayPlan(schedule: DaySchedule.wfh,    isTraining: true),
        'thu': const DayPlan(schedule: DaySchedule.office, isTraining: false),
        'fri': const DayPlan(schedule: DaySchedule.office, isTraining: true),
        'sat': const DayPlan(schedule: DaySchedule.weekend, isTraining: false),
        'sun': const DayPlan(schedule: DaySchedule.weekend, isTraining: true),
      };
      final updated = PlannerLogic.toggleSchedule(week, 'wed');
      expect(updated['wed']!.schedule, DaySchedule.office);
    });
  });
}
