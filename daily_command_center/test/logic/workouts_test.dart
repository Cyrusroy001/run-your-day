import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/workouts.dart';

void main() {
  test('all four workout keys are defined', () {
    expect(workouts.containsKey('A'), true);
    expect(workouts.containsKey('B'), true);
    expect(workouts.containsKey('BENCH'), true);
    expect(workouts.containsKey('CARDIO'), true);
  });

  test('each workout has a title, why, and at least 4 exercises', () {
    for (final entry in workouts.entries) {
      expect(entry.value.title, isNotEmpty, reason: '${entry.key} missing title');
      expect(entry.value.why, isNotEmpty, reason: '${entry.key} missing why');
      expect(entry.value.exercises.length, greaterThanOrEqualTo(4), reason: '${entry.key} too few exercises');
    }
  });
}
