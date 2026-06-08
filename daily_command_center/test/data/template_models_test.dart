import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  test('Anchor parses hard/soft and optional end', () {
    final hard = Anchor.fromJson({'id': 'work', 'kind': 'work', 'label': 'Work', 'start': '14:00', 'end': '20:00', 'hard': true});
    final soft = Anchor.fromJson({'id': 'sleep', 'kind': 'chill', 'label': 'Sleep', 'start': '23:15', 'hard': false});
    expect(hard.hard, true);
    expect(hard.end, '20:00');
    expect(soft.end, isNull);
    expect(Anchor.fromJson(hard.toJson()).toJson(), hard.toJson());
  });

  test('RoutineItem parses drift fields and defaults condition to always', () {
    final item = RoutineItem.fromJson({
      'id': 'train', 'kind': 'train', 'label': 'Train', 'start': '10:00',
      'idealDuration': 60, 'minDuration': 40, 'priority': 3,
      'condition': 'isTrainingDay', 'workoutId': 'B', 'cutoffTime': '20:00', 'dropStrategy': 'kill_and_notify',
    });
    expect(item.idealDuration, 60);
    expect(item.condition, 'isTrainingDay');
    expect(item.workoutId, 'B');
    expect(item.cutoffTime, '20:00');
    final plain = RoutineItem.fromJson({'id': 'x', 'kind': 'meal', 'label': 'y', 'start': '08:00', 'idealDuration': 30, 'minDuration': 20, 'priority': 1});
    expect(plain.condition, 'always');
    expect(plain.maxDriftMinutes, isNull);
    expect(RoutineItem.fromJson(item.toJson()).toJson(), item.toJson());
  });

  test('DayTemplate holds anchors and routineStack', () {
    final t = DayTemplate.fromJson({
      'label': 'Office', 'colorKey': 'terra',
      'anchors': [{'id': 'work', 'kind': 'work', 'label': 'Work', 'start': '14:00', 'end': '20:00', 'hard': true}],
      'routineStack': [{'id': 'wake', 'kind': 'meal', 'label': 'Wake', 'start': '08:00', 'idealDuration': 30, 'minDuration': 20, 'priority': 1}],
    });
    expect(t.anchors.single.id, 'work');
    expect(t.routineStack.single.id, 'wake');
    expect(t.colorKey, 'terra');
  });
}
