import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/logic/priority_level.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/elastic_rail.dart';
import 'package:daily_command_center/screens/today_screen.dart';

late Plan _plan;
late Directory _tmp;

Future<void> _pumpToday(WidgetTester tester, {required double now}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
      home: TodayScreen(debugPlan: _plan, debugNow: now, debugTodayKey: 'mon')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _tmp = Directory.systemTemp.createTempSync('today_screen_test');
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

  testWidgets('merged Today shows the NOW hero + elastic rail', (tester) async {
    // 8:15 — the wake block is current, so the rest renders on the rail.
    await _pumpToday(tester, now: 8.25);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.byType(ElasticRail), findsOneWidget);
    expect(find.text('Rest of today'.toUpperCase()), findsOneWidget);
    expect(find.text('Deep Focus — AI Building'), findsOneWidget); // a rail stop
  });

  testWidgets('calm day shows the caught-up whisper, no stat tiles', (tester) async {
    await _pumpToday(tester, now: 8.25);
    // Both the hero chip ("✓ all caught up") and the whisper carry the calm state.
    expect(find.textContaining('caught up'), findsWidgets);
    expect(find.textContaining("The plan’s holding."), findsOneWidget);
    // The banned v1 chrome must be gone.
    expect(find.textContaining('done today'), findsNothing);
    expect(find.text('Reflowed'), findsNothing);
  });

  testWidgets('tapping a rail card toggles its done state', (tester) async {
    await _pumpToday(tester, now: 8.25);
    final st = tester.state<TodayScreenState>(find.byType(TodayScreen));
    expect(st.doneSignatures.any((s) => s.contains('Deep Focus')), false);
    await tester.runAsync(() async {
      await tester.tap(find.text('Deep Focus — AI Building'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    expect(st.doneSignatures.any((s) => s.contains('Deep Focus')), true);
  });

  testWidgets('FAB visible in Today, hidden while adjusting', (tester) async {
    await _pumpToday(tester, now: 8.25);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.text('ADJUST TODAY'));
    await tester.pumpAndSettle();
    expect(find.text('Adjusting today'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('adjust: skip writes deletedItems; undo restores; priority writes override',
      (tester) async {
    await _pumpToday(tester, now: 7.0);
    final st = tester.state<TodayScreenState>(find.byType(TodayScreen));
    final focus = st.blocksForTest.firstWhere((b) => b.id == 'focus');

    await tester.runAsync(() => st.removeForTest(focus));
    expect(st.stateForTest.deletedItems, contains('focus'));
    await tester.runAsync(() => st.undoForTest());
    expect(st.stateForTest.deletedItems, isNot(contains('focus')));

    await tester.runAsync(() => st.setLevelForTest(focus, PriorityLevel.dropFirst));
    expect(st.stateForTest.dailyOverrides['focus']!.priority, PriorityLevel.dropFirst.toPriority());
  });

  testWidgets('give-it-more-time adds minutes to the matching routine item', (tester) async {
    await _pumpToday(tester, now: 7.0);
    final st = tester.state<TodayScreenState>(find.byType(TodayScreen));
    final before = st.blocksForTest.firstWhere((b) => b.id == 'dsa').idealMinutes; // seed 45
    await tester.runAsync(() => st.giveMoreTimeForTest('DSA practice', 15));
    final after = st.blocksForTest.firstWhere((b) => b.id == 'dsa').idealMinutes;
    expect(after, before + 15);
  });
}
