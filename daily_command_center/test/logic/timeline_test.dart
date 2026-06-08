import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/timeline.dart';

void main() {
  group('buildTimes', () {
    test('correctly resolves AM times', () {
      final blocks = [
        const Block(time: '8:00', cls: 'meal', label: 'Wake'),
        const Block(time: '8:30', cls: 'focus', label: 'Focus'),
        const Block(time: '11:30', cls: 'meal', label: 'Brunch'),
      ];
      final times = buildTimes(blocks);
      expect(times[0], closeTo(8.0, 0.01));
      expect(times[1], closeTo(8.5, 0.01));
      expect(times[2], closeTo(11.5, 0.01));
    });

    test('resolves afternoon times as PM, not AM', () {
      final blocks = [
        const Block(time: '8:00', cls: 'meal', label: 'Wake'),
        const Block(time: '1:50', cls: 'work', label: 'Commute'),
        const Block(time: '2:00', cls: 'work', label: 'Work'),
        const Block(time: '3:00', cls: 'meal', label: 'Lunch'),
        const Block(time: '8:30', cls: 'meal', label: 'Dinner'),
      ];
      final times = buildTimes(blocks);
      expect(times[1], closeTo(13.833, 0.01));
      expect(times[2], closeTo(14.0, 0.01));
      expect(times[3], closeTo(15.0, 0.01));
      expect(times[4], closeTo(20.5, 0.01));
    });

    test('times are always strictly increasing on a full office+training day', () {
      // Hand-constructed representative of the daily timeline to keep this
      // test free of asset loading (the monotonic invariant is in buildTimes).
      final blocks = [
        const Block(time: '8:00',  cls: 'meal',  label: 'Wake'),
        const Block(time: '8:30',  cls: 'focus', label: 'Focus'),
        const Block(time: '9:45',  cls: 'meal',  label: 'Snack'),
        const Block(time: '10:00', cls: 'train', label: 'Train'),
        const Block(time: '11:00', cls: 'meal',  label: 'Brunch'),
        const Block(time: '11:30', cls: 'dsa',   label: 'DSA'),
        const Block(time: '1:50',  cls: 'work',  label: 'Commute'),
        const Block(time: '2:00',  cls: 'work',  label: 'Work'),
        const Block(time: '3:00',  cls: 'meal',  label: 'Lunch'),
        const Block(time: '5:00',  cls: 'meal',  label: 'Snack'),
        const Block(time: '8:30',  cls: 'meal',  label: 'Dinner'),
        const Block(time: '9:15',  cls: 'chill', label: 'Chill'),
        const Block(time: '10:45', cls: 'chill', label: 'Wind'),
        const Block(time: '11:15', cls: 'chill', label: 'Sleep'),
      ];
      final times = buildTimes(blocks);
      for (int i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]),
            reason: 'Time went backward at index $i: ${times[i - 1]} → ${times[i]}');
      }
    });
  });
}
