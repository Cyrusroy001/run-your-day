import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/priority_level.dart';

void main() {
  test('maps numeric priority to a human level', () {
    expect(PriorityLevel.fromPriority(1), PriorityLevel.protect);
    expect(PriorityLevel.fromPriority(3), PriorityLevel.normal);
    expect(PriorityLevel.fromPriority(5), PriorityLevel.normal);
    expect(PriorityLevel.fromPriority(7), PriorityLevel.dropFirst);
  });

  test('each level has a representative numeric priority and label', () {
    expect(PriorityLevel.protect.toPriority(), 2);
    expect(PriorityLevel.normal.toPriority(), 4);
    expect(PriorityLevel.dropFirst.toPriority(), 7);
    expect(PriorityLevel.protect.label, 'Protect');
    expect(PriorityLevel.dropFirst.label, 'Drop first');
  });
}
