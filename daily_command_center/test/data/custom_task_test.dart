import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  group('CustomTask', () {
    const task = CustomTask(
      id: 'custom_1234',
      label: 'Call mom',
      startTime: '19:00',
      durationMinutes: 45,
      date: '2026-06-09',
    );

    test('round-trips through toJson/fromJson', () {
      final json = task.toJson();
      final restored = CustomTask.fromJson(json);
      expect(restored.id, task.id);
      expect(restored.label, task.label);
      expect(restored.startTime, task.startTime);
      expect(restored.durationMinutes, task.durationMinutes);
      expect(restored.date, task.date);
    });

    test('toJson includes all fields', () {
      final json = task.toJson();
      expect(json['id'], 'custom_1234');
      expect(json['label'], 'Call mom');
      expect(json['startTime'], '19:00');
      expect(json['durationMinutes'], 45);
      expect(json['date'], '2026-06-09');
    });
  });

  group('DailyState with addedItems', () {
    const task = CustomTask(
      id: 'custom_1234', label: 'Call mom', startTime: '19:00',
      durationMinutes: 45, date: '2026-06-09',
    );

    test('defaults to empty addedItems', () {
      const state = DailyState(date: '2026-06-09');
      expect(state.addedItems, isEmpty);
    });

    test('copyWith addedItems', () {
      const state = DailyState(date: '2026-06-09');
      final updated = state.copyWith(addedItems: [task]);
      expect(updated.addedItems, hasLength(1));
      expect(updated.addedItems.first.label, 'Call mom');
      // other fields unchanged
      expect(updated.date, '2026-06-09');
      expect(updated.deletedItems, isEmpty);
    });

    test('round-trips through toJson/fromJson with addedItems', () {
      const state = DailyState(date: '2026-06-09', addedItems: [task]);
      final json = state.toJson();
      final restored = DailyState.fromJson(json);
      expect(restored.addedItems, hasLength(1));
      expect(restored.addedItems.first.id, 'custom_1234');
    });
  });

  group('Block.isCustom', () {
    test('defaults to false', () {
      const b = Block(time: '10:00', cls: 'goal', label: 'Test');
      expect(b.isCustom, isFalse);
    });

    test('can be set to true', () {
      const b = Block(time: '10:00', cls: 'custom', label: 'Test', isCustom: true);
      expect(b.isCustom, isTrue);
    });

    test('copyWith preserves isCustom', () {
      const b = Block(time: '10:00', cls: 'custom', label: 'Test', isCustom: true);
      final b2 = b.copyWith(label: 'New');
      expect(b2.isCustom, isTrue);
    });
  });
}
