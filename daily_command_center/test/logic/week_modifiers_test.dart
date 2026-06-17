import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/week_modifiers.dart';

// 4 well-spaced training days (mon/wed/fri/sun), frequency configurable.
Plan _plan({int freq = 4}) => Plan(
      schemaVersion: 3,
      meta: const PlanMeta(),
      dayTemplates: const {
        'office': DayTemplate(label: 'Office', colorKey: 'terra', anchors: [], routineStack: []),
        'wfh': DayTemplate(label: 'WFH', colorKey: 'sky', anchors: [], routineStack: []),
      },
      week: const {
        'mon': WeekEntry(templateId: 'office', training: true),
        'tue': WeekEntry(templateId: 'office', training: false),
        'wed': WeekEntry(templateId: 'wfh', training: true),
        'thu': WeekEntry(templateId: 'office', training: false),
        'fri': WeekEntry(templateId: 'office', training: true),
        'sat': WeekEntry(templateId: 'weekend', training: false),
        'sun': WeekEntry(templateId: 'weekend_sun', training: true),
      },
      weekEditor: const WeekEditorConfig(toggleTemplates: ['office', 'wfh'], lockedDays: ['sat', 'sun']),
      training: TrainingRules(frequencyPerWeek: freq, avoidConsecutive: true, rotation: const ['A', 'B']),
      workouts: const {},
      nutrition: const NutritionConfig(),
      goals: const [],
    );

void main() {
  test('one modifier from training rules; none when frequency is 0 (goals are 0..N)', () {
    expect(WeekModifiers.of(_plan()).length, 1);
    expect(WeekModifiers.of(_plan(freq: 0)), isEmpty);
  });

  test('caption is generated from the rule, never from lifestyle words', () {
    expect(WeekModifiers.of(_plan()).single.caption(_plan()), '4 caged · well spaced ✓');
  });
}
