import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Plan round-trips through json losslessly for the seed', () async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(plan.schemaVersion, 3);
    expect(plan.dayTemplates.keys, containsAll(['office', 'wfh', 'weekend', 'weekend_sun']));
    expect(plan.week['mon']!.templateId, 'office');
    expect(plan.week['sat']!.training, false);
    expect(plan.training.frequencyPerWeek, 4);
    expect(plan.workouts['BENCH']!.exercises.first.progression!.addLoad, true);
    expect(plan.goals.single.id, 'dsa');
    // Lossless round-trip
    expect(Plan.fromJson(plan.toJson()).toJson(), plan.toJson());
  });
}
