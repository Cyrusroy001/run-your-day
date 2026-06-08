import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  test('WorkoutDef round-trips through json with progression', () {
    const json = {
      'title': 'Full Body A',
      'why': 'because',
      'exercises': [
        {
          'name': 'Goblet squat', 'sets': '3–4 × 15–20', 'repRange': [15, 20],
          'cue': 'slow', 'tempo': '3s eccentric', 'loggable': true,
          'progression': {'method': 'double', 'addLoad': false, 'escalation': ['a', 'b']}
        }
      ]
    };
    final wo = WorkoutDef.fromJson(json);
    expect(wo.title, 'Full Body A');
    expect(wo.exercises.first.repRange, [15, 20]);
    expect(wo.exercises.first.progression!.addLoad, false);
    expect(wo.exercises.first.progression!.escalation, ['a', 'b']);
    expect(WorkoutDef.fromJson(wo.toJson()).toJson(), wo.toJson());
  });

  test('ExerciseDef tolerates missing optional fields', () {
    final ex = ExerciseDef.fromJson({'name': 'Plank', 'sets': '3 × max', 'cue': 'core'});
    expect(ex.repRange, isNull);
    expect(ex.loggable, false);
    expect(ex.progression, isNull);
  });
}
