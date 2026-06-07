import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  group('DayPlan', () {
    test('serializes and deserializes correctly', () {
      const plan = DayPlan(schedule: DaySchedule.wfh, isTraining: true);
      final json = plan.toJson();
      final restored = DayPlan.fromJson(json);
      expect(restored.schedule, DaySchedule.wfh);
      expect(restored.isTraining, true);
    });

    test('copyWith preserves unchanged fields', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: false);
      final updated = plan.copyWith(isTraining: true);
      expect(updated.schedule, DaySchedule.office);
      expect(updated.isTraining, true);
    });
  });

  group('WorkoutLog', () {
    test('serializes and deserializes correctly', () {
      const log = WorkoutLog(date: '5 Jun', reps: '3×14', weight: '', waist: '82', note: 'felt strong');
      final json = log.toJson();
      final restored = WorkoutLog.fromJson(json);
      expect(restored.date, '5 Jun');
      expect(restored.reps, '3×14');
      expect(restored.waist, '82');
    });
  });

  group('Block.isTrackable', () {
    test('meal/focus/dsa/train are trackable', () {
      for (final c in ['meal', 'focus', 'dsa', 'train']) {
        expect(Block(time: '8:00', cls: c, label: 'x').isTrackable, isTrue, reason: c);
      }
    });
    test('work/chill are passive', () {
      for (final c in ['work', 'chill']) {
        expect(Block(time: '8:00', cls: c, label: 'x').isTrackable, isFalse, reason: c);
      }
    });
  });

  test('Block.signature combines time and label', () {
    const b = Block(time: '10:00', cls: 'train', label: 'Train — Workout B');
    expect(b.signature, '10:00|Train — Workout B');
  });
}
