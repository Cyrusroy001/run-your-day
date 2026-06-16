import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/day_arc.dart';
import 'package:daily_command_center/logic/ripeness.dart';

Block b(String label, double start, int dur, {String cls = 'focus'}) => Block(
    time: label, cls: cls, label: label,
    estStart: start, durationMinutes: dur, idealMinutes: dur);

void main() {
  test('window spans first start to last end — schema-driven', () {
    final arc = DayArc.from([b('a', 8, 30), b('z', 22, 60)], now: 10, done: {});
    expect(arc.startH, 8);
    expect(arc.endH, 23);
    expect(arc.nowPos, closeTo((10 - 8) / 15, 0.001));
    expect(arc.stops.length, 2);
    expect(arc.stops.first.pos, 0);
    expect(arc.dayDone, isFalse);
  });

  test('dayDone when all trackables picked or window passed', () {
    final blocks = [b('a', 8, 30), b('w', 9, 60, cls: 'work')];
    expect(DayArc.from(blocks, now: 9, done: {'a|a'}).dayDone, isTrue);
    expect(DayArc.from(blocks, now: 23.9, done: {}).dayDone, isTrue);
  });

  test('ripeness rides along', () {
    final arc = DayArc.from([b('a', 8, 30)], now: 9, done: {});
    expect(arc.stops.single.ripeness, Ripeness.overripe);
  });
}
