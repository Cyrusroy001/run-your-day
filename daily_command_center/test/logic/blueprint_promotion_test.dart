import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/logic/blueprint_promotion.dart';

late Plan _plan;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('appends a RoutineItem to each named template', () {
    final before = {
      for (final id in ['office', 'wfh'])
        id: _plan.dayTemplates[id]!.routineStack.length,
    };
    final out = BlueprintPromotion.promote(
      _plan, label: 'Evening walk', time: '19:00',
      durationMinutes: 30, templateIds: ['office', 'wfh'],
    );
    expect(out.dayTemplates['office']!.routineStack.length, before['office']! + 1);
    expect(out.dayTemplates['wfh']!.routineStack.length, before['wfh']! + 1);
    expect(out.dayTemplates['office']!.routineStack.last.label, 'Evening walk');
    expect(out.dayTemplates['wfh']!.routineStack.last.label, 'Evening walk');
  });

  test('does not touch templates that were not named', () {
    final weekendBefore = _plan.dayTemplates['weekend']!.routineStack.length;
    final out = BlueprintPromotion.promote(
      _plan, label: 'Read', time: '22:00',
      durationMinutes: 20, templateIds: ['office'],
    );
    expect(out.dayTemplates['weekend']!.routineStack.length, weekendBefore);
  });

  test('promoted item has the expected blueprint fields', () {
    final out = BlueprintPromotion.promote(
      _plan, label: 'Deep stretch', time: '07:30',
      durationMinutes: 40, templateIds: ['office'],
    );
    final item = out.dayTemplates['office']!.routineStack.last;
    expect(item.kind, 'goal');
    expect(item.start, '07:30');
    expect(item.idealDuration, 40);
    expect(item.minDuration, 24); // round(40 * 0.6)
    expect(item.priority, 4);
    expect(item.id, startsWith('custom_'));
  });

  test('id is slugified from the label', () {
    final out = BlueprintPromotion.promote(
      _plan, label: 'Evening  Walk!', time: '19:00',
      durationMinutes: 30, templateIds: ['office'],
    );
    expect(out.dayTemplates['office']!.routineStack.last.id, 'custom_evening_walk');
  });

  test('the original plan is not mutated', () {
    final officeBefore = _plan.dayTemplates['office']!.routineStack.length;
    BlueprintPromotion.promote(
      _plan, label: 'Walk', time: '19:00',
      durationMinutes: 30, templateIds: ['office'],
    );
    expect(_plan.dayTemplates['office']!.routineStack.length, officeBefore);
  });

  test('unknown template ids are skipped without error', () {
    final out = BlueprintPromotion.promote(
      _plan, label: 'Walk', time: '19:00',
      durationMinutes: 30, templateIds: ['office', 'does_not_exist'],
    );
    expect(out.dayTemplates.containsKey('does_not_exist'), isFalse);
    expect(out.dayTemplates['office']!.routineStack.last.label, 'Walk');
  });

  group('persisted through AppStore', () {
    late Directory tmp;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tmp = Directory.systemTemp.createTempSync('blueprint_promotion_test');
      AppStore.repo = ProfileRepository(baseDir: tmp);
    });
    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows handle lock — OS reclaims later.
      }
    });

    test('savePlan persists the promoted routine across a reload', () async {
      final plan = await AppStore.loadPlan();
      final before = plan.dayTemplates['office']!.routineStack.length;

      final updated = BlueprintPromotion.promote(
        plan, label: 'Evening walk', time: '19:00',
        durationMinutes: 30, templateIds: ['office', 'wfh'],
      );
      await AppStore.savePlan(updated);

      // Fresh read from disk proves the write survived serialization.
      final reloaded = await AppStore.loadPlan();
      expect(reloaded.dayTemplates['office']!.routineStack.length, before + 1);
      final item = reloaded.dayTemplates['office']!.routineStack.last;
      expect(item.label, 'Evening walk');
      expect(item.kind, 'goal');
      expect(item.start, '19:00');
      expect(item.idealDuration, 30);
      expect(reloaded.dayTemplates['wfh']!.routineStack.last.label, 'Evening walk');
    });
  });
}
