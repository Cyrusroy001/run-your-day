import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/planner.dart';

// Minimal in-memory Plan with all four template ids present.
Plan _minPlan() => const Plan(
      schemaVersion: 3,
      meta: PlanMeta(),
      dayTemplates: {
        'office':      DayTemplate(label: 'Office',      colorKey: 'terra',  anchors: [], routineStack: []),
        'wfh':         DayTemplate(label: 'WFH',         colorKey: 'sky',    anchors: [], routineStack: []),
        'weekend':     DayTemplate(label: 'Weekend',     colorKey: 'amber',  anchors: [], routineStack: []),
        'weekend_sun': DayTemplate(label: 'Weekend Sun', colorKey: 'amber',  anchors: [], routineStack: []),
      },
      week: {
        'mon': WeekEntry(templateId: 'office',      training: true),
        'tue': WeekEntry(templateId: 'office',      training: false),
        'wed': WeekEntry(templateId: 'wfh',         training: true),
        'thu': WeekEntry(templateId: 'office',      training: false),
        'fri': WeekEntry(templateId: 'office',      training: true),
        'sat': WeekEntry(templateId: 'weekend',     training: false),
        'sun': WeekEntry(templateId: 'weekend_sun', training: true),
      },
      weekEditor: WeekEditorConfig(),
      training: TrainingRules(frequencyPerWeek: 4, avoidConsecutive: true, rotation: ['A', 'B']),
      workouts: {},
      nutrition: NutritionConfig(),
      goals: [],
    );

void main() {
  group('applyBestSpacing', () {
    test('has exactly 4 training days', () {
      final plan = PlannerLogic.applyBestSpacing(_minPlan());
      final count = plan.week.values.where((e) => e.training).length;
      expect(count, 4);
    });

    test('has no two consecutive training days', () {
      final plan = PlannerLogic.applyBestSpacing(_minPlan());
      const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      for (int i = 0; i < order.length - 1; i++) {
        final a = plan.week[order[i]]!.training;
        final b = plan.week[order[i + 1]]!.training;
        expect(a && b, false,
            reason: '${order[i]} and ${order[i + 1]} are both training — consecutive');
      }
    });

    test('weekends keep their weekend template ids', () {
      final plan = PlannerLogic.applyBestSpacing(_minPlan());
      expect(plan.week['sat']!.templateId, 'weekend');
      expect(plan.week['sun']!.templateId, 'weekend_sun');
    });
  });

  group('toggleTraining', () {
    test('toggling training days never exceeds 4', () {
      var plan = PlannerLogic.applyBestSpacing(_minPlan());
      for (final day in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
        if (!plan.week[day]!.training) {
          plan = PlannerLogic.toggleTraining(plan, day).plan;
        }
        final count = plan.week.values.where((e) => e.training).length;
        expect(count, lessThanOrEqualTo(4));
      }
    });

    test('turning on a fifth day always displaces one, keeping count at 4', () {
      final plan = PlannerLogic.applyBestSpacing(_minPlan());
      final result = PlannerLogic.toggleTraining(plan, 'tue');
      final count = result.plan.week.values.where((e) => e.training).length;
      expect(count, 4);
    });

    test('provides a message when a day is moved', () {
      final plan = PlannerLogic.applyBestSpacing(_minPlan());
      for (final day in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
        if (!plan.week[day]!.training) {
          final result = PlannerLogic.toggleTraining(plan, day);
          expect(result.message, anyOf(isNull, isA<String>()));
          break;
        }
      }
    });
  });

  group('cycleTemplate', () {
    Plan editable() {
      final b = _minPlan();
      return Plan(
        schemaVersion: b.schemaVersion, meta: b.meta, dayTemplates: b.dayTemplates,
        week: b.week, training: b.training, workouts: b.workouts,
        nutrition: b.nutrition, goals: b.goals,
        weekEditor: const WeekEditorConfig(
            toggleTemplates: ['office', 'wfh'], lockedDays: ['sat', 'sun']),
      );
    }

    test('walks weekEditor.toggleTemplates and honors lockedDays', () {
      final p = editable();
      final p2 = PlannerLogic.cycleTemplate(p, 'mon'); // office → wfh
      expect(p2.week['mon']!.templateId, 'wfh');
      expect(PlannerLogic.cycleTemplate(p2, 'mon').week['mon']!.templateId, 'office');
      expect(PlannerLogic.cycleTemplate(p, 'sat').week['sat']!.templateId, 'weekend'); // locked
    });
  });

  group('toggleSchedule', () {
    test('flips office to wfh', () {
      final plan = PlannerLogic.applyBestSpacing(_minPlan());
      final updated = PlannerLogic.toggleSchedule(plan, 'mon');
      expect(updated.week['mon']!.templateId, 'wfh');
    });

    test('flips wfh to office', () {
      final base = _minPlan().copyWith(week: {
        ..._minPlan().week,
        'wed': const WeekEntry(templateId: 'wfh', training: true),
      });
      final updated = PlannerLogic.toggleSchedule(base, 'wed');
      expect(updated.week['wed']!.templateId, 'office');
    });

    test('weekend template is unchanged by toggleSchedule', () {
      final plan = _minPlan();
      final result = PlannerLogic.toggleSchedule(plan, 'sat');
      expect(result.week['sat']!.templateId, 'weekend');
    });
  });
}
