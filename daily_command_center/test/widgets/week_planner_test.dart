import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/widgets/week_planner.dart';

late Plan _plan;
late Directory _tmp;

Widget _host(Plan plan, void Function(Plan) onChanged) =>
    MaterialApp(home: Scaffold(body: WeekPlanner(
      plan: plan, todayKey: 'mon', onPlanChanged: onChanged)));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _tmp = Directory.systemTemp.createTempSync('week_planner_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
  });
  tearDown(() => _tmp.deleteSync(recursive: true));

  testWidgets('renders all seven day labels', (tester) async {
    await tester.pumpWidget(_host(_plan, (_) {}));
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(d), findsOneWidget);
    }
  });

  testWidgets('tapping a weekday schedule chip toggles office<->wfh', (tester) async {
    Plan? updated;
    await tester.pumpWidget(_host(_plan, (p) => updated = p));
    expect(_plan.week['mon']!.templateId, 'office');
    await tester.tap(find.byKey(const Key('sched-mon')));
    await tester.pump();
    expect(updated!.week['mon']!.templateId, 'wfh');
  });

  testWidgets('weekend schedule chip does nothing', (tester) async {
    Plan? updated;
    await tester.pumpWidget(_host(_plan, (p) => updated = p));
    await tester.tap(find.byKey(const Key('sched-sat')));
    await tester.pump();
    expect(updated, isNull);
  });

  testWidgets('toggling an extra training day shows the move caption', (tester) async {
    // seed week trains mon/wed/fri/sun; turning tue on forces a spacing move.
    await tester.pumpWidget(_host(_plan, (_) {}));
    await tester.tap(find.byKey(const Key('train-tue')));
    await tester.pump();
    expect(find.textContaining('Moved training'), findsOneWidget);
  });
}
