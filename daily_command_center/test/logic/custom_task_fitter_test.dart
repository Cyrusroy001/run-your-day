import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/custom_task_fitter.dart';

// Helper: build a droppable routine block
Block _b(String id, String time, {int ideal = 60, int min = 30, int priority = 5}) => Block(
      id: id, time: time, cls: 'goal', label: id,
      durationMinutes: ideal, idealMinutes: ideal, minMinutes: min, priority: priority,
      estStart: _dec(time), seedStart: _dec(time),
    );

// Helper: build a hard anchor (never droppable)
Block _anchor(String id, String time) => Block(
      id: id, time: time, cls: 'work', label: id,
      isAnchor: true, hardAnchor: true,
      estStart: _dec(time), seedStart: _dec(time),
    );

// Helper: build a custom block (never a sacrifice candidate)
Block _custom(String id, String time, {int dur = 45}) => Block(
      id: id, time: time, cls: 'custom', label: id,
      durationMinutes: dur, idealMinutes: dur, minMinutes: dur,
      priority: 0, isCustom: true,
      estStart: _dec(time), seedStart: _dec(time),
    );

double _dec(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) + int.parse(p[1]) / 60.0;
}

void main() {
  group('compactionSlack', () {
    test('returns sum of (ideal - min) for flexible blocks', () {
      final blocks = [
        _b('a', '08:00', ideal: 60, min: 30), // 30 slack
        _b('b', '09:00', ideal: 45, min: 30), // 15 slack
        _anchor('work', '14:00'),              // 0 slack (anchor)
      ];
      expect(CustomTaskFitter.compactionSlack(blocks), 45);
    });

    test('anchors and custom blocks contribute 0 slack', () {
      final blocks = [
        _anchor('work', '14:00'),
        _custom('c1', '19:00'),
      ];
      expect(CustomTaskFitter.compactionSlack(blocks), 0);
    });
  });

  group('computeOffers', () {
    test('single block that covers needed → single offer marked recommended', () {
      final blocks = [
        _b('chill', '21:00', ideal: 90, min: 30, priority: 7),
        _b('dsa', '11:00', ideal: 45, min: 25, priority: 5),
      ];
      final offers = CustomTaskFitter.computeOffers(blocks, 45);
      expect(offers, isNotEmpty);
      final rec = offers.first;
      expect(rec.isRecommended, isTrue);
      expect(rec.freedMinutes, greaterThanOrEqualTo(45));
    });

    test('returns recommended flag on exactly one offer', () {
      final blocks = [_b('a', '09:00', ideal: 60, priority: 6)];
      final offers = CustomTaskFitter.computeOffers(blocks, 30);
      expect(offers.where((o) => o.isRecommended).length, 1);
    });

    test('two-block combo returned when no single block covers needed', () {
      final blocks = [
        _b('a', '09:00', ideal: 20, priority: 6),
        _b('b', '10:00', ideal: 20, priority: 5),
        _b('c', '11:00', ideal: 20, priority: 5),
      ];
      // Need 35 min; each block only covers 20 → need a pair
      final offers = CustomTaskFitter.computeOffers(blocks, 35);
      expect(offers, isNotEmpty);
      expect(offers.any((o) => o.drop.length == 2), isTrue);
    });

    test('anchors are never sacrifice candidates', () {
      final blocks = [
        _anchor('work', '14:00'),
        _b('chill', '21:00', ideal: 90, priority: 7),
      ];
      final offers = CustomTaskFitter.computeOffers(blocks, 45);
      for (final offer in offers) {
        expect(offer.drop.any((b) => b.isAnchor), isFalse);
      }
    });

    test('custom blocks are never sacrifice candidates', () {
      final blocks = [
        _custom('mycustom', '19:00', dur: 60),
        _b('chill', '21:00', ideal: 90, priority: 7),
      ];
      final offers = CustomTaskFitter.computeOffers(blocks, 45);
      for (final offer in offers) {
        expect(offer.drop.any((b) => b.isCustom), isFalse);
      }
    });

    test('protect-band blocks (priority ≤ 4) are never sacrifice candidates', () {
      final blocks = [
        _b('meal', '11:00', ideal: 45, priority: 4),  // protect band
        _b('chill', '21:00', ideal: 90, priority: 7), // ok to drop
      ];
      final offers = CustomTaskFitter.computeOffers(blocks, 45);
      for (final offer in offers) {
        expect(offer.drop.any((b) => b.id == 'meal'), isFalse);
      }
    });

    test('empty list when no droppable blocks exist', () {
      final blocks = [_anchor('work', '14:00')];
      final offers = CustomTaskFitter.computeOffers(blocks, 45);
      expect(offers, isEmpty);
    });

    test('singles come before pairs in sorted output', () {
      final blocks = [
        _b('a', '09:00', ideal: 60, priority: 7),  // single covers 45
        _b('b', '10:00', ideal: 30, priority: 6),
        _b('c', '11:00', ideal: 30, priority: 5),
      ];
      final offers = CustomTaskFitter.computeOffers(blocks, 45);
      final singles = offers.where((o) => o.drop.length == 1).toList();
      final pairs = offers.where((o) => o.drop.length == 2).toList();
      if (singles.isNotEmpty && pairs.isNotEmpty) {
        expect(offers.indexOf(singles.first), lessThan(offers.indexOf(pairs.first)));
      }
    });
  });
}
