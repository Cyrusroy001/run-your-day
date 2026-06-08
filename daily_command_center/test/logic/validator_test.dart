import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled seed passes validation', () async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(PlanValidator.validate(plan), isEmpty);
  });

  test('flags an unknown templateId in week', () {
    final base = _minimalPlan();
    final broken = base.copyWith(week: {'mon': const WeekEntry(templateId: 'ghost', training: false)});
    final errs = PlanValidator.validate(broken);
    expect(errs.any((e) => e.contains('ghost')), true);
  });
}

Plan _minimalPlan() => Plan(
      schemaVersion: 3,
      meta: const PlanMeta(),
      dayTemplates: {
        'office': const DayTemplate(label: 'Office', colorKey: 'terra', anchors: [], routineStack: []),
      },
      week: {'mon': const WeekEntry(templateId: 'office', training: false)},
      weekEditor: const WeekEditorConfig(),
      training: const TrainingRules(frequencyPerWeek: 4, avoidConsecutive: true, rotation: []),
      workouts: const {},
      nutrition: const NutritionConfig(),
      goals: const [],
    );
