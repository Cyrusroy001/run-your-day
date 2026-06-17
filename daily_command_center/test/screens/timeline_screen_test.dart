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
import 'package:daily_command_center/widgets/vine_timeline.dart';
import 'package:daily_command_center/screens/timeline_screen.dart';

late Plan _plan;
late Directory _tmp;

Future<void> _pumpTimeline(WidgetTester tester, {required double now}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
      home: TimelineScreen(debugPlan: _plan, debugNow: now, debugTodayKey: 'mon')));
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
    _tmp = Directory.systemTemp.createTempSync('timeline_screen_test');
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

  testWidgets('Timeline shows the vine over the full day', (tester) async {
    await _pumpTimeline(tester, now: 8.25);
    expect(find.byType(VineTimeline), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Deep Focus — AI Building'), findsOneWidget); // a future vine stop
  });

  testWidgets('tapping a vine card toggles its done state', (tester) async {
    await _pumpTimeline(tester, now: 8.25);
    final st = tester.state<TimelineScreenState>(find.byType(TimelineScreen));
    expect(st.doneSignatures.any((s) => s.contains('Deep Focus')), false);
    await tester.runAsync(() async {
      await tester.tap(find.text('Deep Focus — AI Building'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    expect(st.doneSignatures.any((s) => s.contains('Deep Focus')), true);
  });

  testWidgets('vine basket folds the missed morning; NOW is present-time, not a stale block', (tester) async {
    // 12:00, nothing done: the morning is missed → folded into the basket as
    // jammy fruit. The live NOW must be the present block, never the long-passed
    // "Wake" (the drift "missed-task" fix, guarded at the screen level).
    await _pumpTimeline(tester, now: 12.0);
    expect(find.byKey(const Key('vine-basket')), findsOneWidget);
    expect(find.textContaining('jammy'), findsOneWidget);
    expect(find.text('Wake · water · sunlight'), findsNothing);
  });

  testWidgets('unfurling the basket reveals a late pick that marks the block done',
      (tester) async {
    await _pumpTimeline(tester, now: 12.0);
    final st = tester.state<TimelineScreenState>(find.byType(TimelineScreen));
    expect(st.doneSignatures, isEmpty);
    await tester.tap(find.byKey(const Key('vine-basket')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('pick late?'), findsWidgets);
    await tester.runAsync(() async {
      await tester.tap(find.text('pick late?').first);
      await Future.delayed(const Duration(milliseconds: 200));
    });
    expect(st.doneSignatures, isNotEmpty);
  });

  testWidgets('FAB visible in Timeline, hidden while adjusting', (tester) async {
    await _pumpTimeline(tester, now: 8.25);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.text('ADJUST'));
    await tester.pumpAndSettle();
    expect(find.text('Adjusting today'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('adjust: skip writes deletedItems; undo restores; priority writes override',
      (tester) async {
    await _pumpTimeline(tester, now: 7.0);
    final st = tester.state<TimelineScreenState>(find.byType(TimelineScreen));
    final focus = st.blocksForTest.firstWhere((b) => b.id == 'focus');

    await tester.runAsync(() => st.removeForTest(focus));
    expect(st.stateForTest.deletedItems, contains('focus'));
    await tester.runAsync(() => st.undoForTest());
    expect(st.stateForTest.deletedItems, isNot(contains('focus')));

    await tester.runAsync(() => st.setLevelForTest(focus, PriorityLevel.dropFirst));
    expect(st.stateForTest.dailyOverrides['focus']!.priority, PriorityLevel.dropFirst.toPriority());
  });
}
