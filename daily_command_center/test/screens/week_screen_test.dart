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
import 'package:daily_command_center/screens/week_screen.dart';

late Plan _plan;
late Directory _tmp;

Future<void> _pump(WidgetTester tester, {String today = 'mon'}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Wrap in a Scaffold (the HomeShell hosts the tab in one in-app) so Material
  // widgets like Switch find their ancestor.
  await tester.pumpWidget(MaterialApp(theme: AppPalette.lightTheme,
      home: Scaffold(body: WeekScreen(debugPlan: _plan, debugTodayKey: today))));
  await tester.pump();
}

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
    activeProfile.value = null;
  });
  tearDown(() {
    activeProfile.value = null;
    try {
      _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle-lock on a freshly-written profile file; OS reclaims later.
    }
  });

  testWidgets('the allotment renders 7 plots + the rule caption', (tester) async {
    await _pump(tester);
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
      expect(find.byKey(Key('plot-$d')), findsOneWidget);
    }
    expect(find.text('4 caged · well spaced ✓'), findsOneWidget);
  });

  testWidgets('training-day plots carry the cage glyph', (tester) async {
    await _pump(tester);
    // mon is a training day in the seed → its plot shows the cage glyph.
    expect(
        find.descendant(of: find.byKey(const Key('plot-mon')), matching: find.text('⌗')),
        findsOneWidget);
  });

  testWidgets('tapping a plot opens its detail card; tapping a chip changes the template',
      (tester) async {
    await tester.runAsync(() => AppStore.savePlan(_plan));
    await _pump(tester);
    await tester.tap(find.byKey(const Key('plot-tue')));
    await tester.pump();
    // Chips are labelled from the Life JSON, never code literals.
    expect(find.text('Work from home'), findsWidgets);
    expect(find.byKey(const Key('chip-wfh')), findsOneWidget);
    // tue is 'office' in the seed → tapping the wfh chip switches it.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('chip-wfh')));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    final saved = (await tester.runAsync(() => AppStore.loadPlan()))!;
    expect(saved.week['tue']!.templateId, 'wfh');
  });

  testWidgets('the detail card has a modifier toggle row', (tester) async {
    await _pump(tester);
    expect(find.byType(Switch), findsWidgets);
  });

  testWidgets('re-sow applies best spacing (4 training days, none consecutive)', (tester) async {
    await tester.runAsync(() => AppStore.savePlan(_plan));
    await _pump(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('↻ Re-sow the suggested week'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    final saved = (await tester.runAsync(() => AppStore.loadPlan()))!;
    expect(saved.week.values.where((e) => e.training).length, 4);
    const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    for (var i = 0; i < order.length - 1; i++) {
      expect(saved.week[order[i]]!.training && saved.week[order[i + 1]]!.training, false);
    }
  });
}
