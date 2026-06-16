import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/week_planner.dart';
import 'package:daily_command_center/screens/week_screen.dart';

late Plan _plan;
late Directory _tmp;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _tmp = Directory.systemTemp.createTempSync('week_screen_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
  });
  tearDown(() {
    try {
      _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle-lock on a freshly-written profile file; OS reclaims later.
    }
  });

  testWidgets('self-loading WeekScreen renders the planner with the injected debug plan', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppPalette.lightTheme,
        home: WeekScreen(debugPlan: _plan, debugTodayKey: 'mon')));
    await tester.pump();

    expect(find.byType(WeekPlanner), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
  });

  testWidgets('training-day toggle persists via AppStore', (tester) async {
    // Seed the repo's active profile so AppStore.savePlan has a doc to write into.
    // Real file I/O must run outside the fake-async test zone.
    await tester.runAsync(() => AppStore.savePlan(_plan));

    await tester.pumpWidget(MaterialApp(theme: AppPalette.lightTheme,
        home: WeekScreen(debugPlan: _plan, debugTodayKey: 'mon')));
    await tester.pump();

    final before = _plan.week['mon']!.training;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('train-mon')));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    final after = (await tester.runAsync(() => AppStore.loadPlan()))!.week['mon']!.training;
    expect(after, isNot(before));
  });
}
