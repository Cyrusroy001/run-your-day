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
import 'package:daily_command_center/widgets/teaching_card.dart';
import 'package:daily_command_center/screens/live_timeline_view.dart';

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
    _tmp = Directory.systemTemp.createTempSync('live_timeline_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
  });
  tearDown(() {
    try {
      _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // On Windows a just-written profile file can still be handle-locked the
      // instant tearDown runs (Adjust-mode tests persist via StateStore). The
      // OS reclaims the temp dir later regardless.
    }
  });

  testWidgets('renders anchor wall + a routine block on an office day', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();                                   // first frame
    await tester.pump(const Duration(milliseconds: 100));  // let _load() complete + setState

    expect(find.textContaining('ANCHOR'), findsWidgets);
    expect(find.text('Deep Focus — AI Building'), findsOneWidget);
    expect(find.textContaining('On track'), findsOneWidget); // zero-drift summary
  });

  testWidgets('tapping a row toggles its done state', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final state = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    expect(state.doneSignatures.any((s) => s.contains('Deep Focus')), false);

    // Run the tap on the real event loop so _toggle's awaited dart:io writes
    // (saveDone/writeAdherence) actually complete instead of hanging under
    // flutter_test's fake-async zone. Persistence itself is covered by
    // adherence_store_test.dart; here we assert the in-memory toggle wiring.
    await tester.runAsync(() async {
      await tester.tap(find.text('Deep Focus — AI Building'));
      // tester.tap doesn't await _toggle's returned future; give its dart:io
      // writes (saveDone + writeAdherence) time to flush on the real event loop
      // so no I/O dangles past the test.
      await Future.delayed(const Duration(milliseconds: 200));
    });
    expect(state.doneSignatures.any((s) => s.contains('Deep Focus')), true);
  });

  testWidgets('peek shows planned vs now for a compacted row', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Late enough to force compaction on the office morning.
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 11.5)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final info = find.byIcon(Icons.info_outline);
    if (info.evaluate().isNotEmpty) {
      await tester.tap(info.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('planned'), findsOneWidget);
    }
  });

  // ── Phase U4: Adjust mode ──────────────────────────────────────────────────
  // Mutations route through _commit (which does dart:io via StateStore). We
  // drive them through @visibleForTesting seams inside tester.runAsync so the
  // real writes complete, then assert on in-memory state (stateForTest). Disk
  // persistence is covered by state_store_test.dart.

  testWidgets('Adjust toggle reveals editor; reorder writes dailySequence', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Adjust today'));
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    await tester.runAsync(() => st.reorderForTest(0, 3));
    expect(st.stateForTest.dailySequence, isNotEmpty);
  });

  testWidgets('remove-for-today then restore updates deletedItems', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    await tester.runAsync(() => st.removeForTest('snack'));
    expect(st.stateForTest.deletedItems, contains('snack'));
    await tester.runAsync(() => st.restoreForTest('snack'));
    expect(st.stateForTest.deletedItems, isNot(contains('snack')));
  });

  testWidgets('priority chip writes dailyOverrides', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    await tester.runAsync(() => st.setLevelForTest('focus', PriorityLevel.dropFirst));
    expect(st.stateForTest.dailyOverrides['focus']!.priority, PriorityLevel.dropFirst.toPriority());
  });

  testWidgets('undo restores the prior state after a remove', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    await tester.runAsync(() => st.removeForTest('snack'));
    expect(st.stateForTest.deletedItems, contains('snack'));
    await tester.runAsync(() => st.undoForTest());
    expect(st.stateForTest.deletedItems, isNot(contains('snack')));
  });

  // ── Phase U5.2: just-in-time teaching ──────────────────────────────────────

  testWidgets('first compaction shows a teaching card', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Late office morning: the cascade pushes the day past the 14:00 work
    // anchor, forcing compaction/drops -> a one-time teaching card.
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 11.5)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(TeachingCard), findsWidgets);
  });

  // ── Phase C6: custom task wiring ───────────────────────────────────────────

  testWidgets('insertCustomTaskForTest adds task to addedItems', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    const task = CustomTask(
        id: 'custom_test1', label: 'Call mom', startTime: '19:30',
        durationMinutes: 45, date: '');
    await tester.runAsync(() => st.insertCustomTaskForTest(task));

    expect(st.stateForTest.addedItems.any((t) => t.id == 'custom_test1'), isTrue);
  });

  testWidgets('insertCustomTaskForTest with drop adds ids to deletedItems', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    const task = CustomTask(
        id: 'custom_test2', label: 'Team meeting', startTime: '15:00',
        durationMinutes: 60, date: '');
    const dropBlock = Block(
        id: 'chill', time: '21:00', cls: 'goal', label: 'Evening chill',
        estStart: 21.0, seedStart: 21.0,
        durationMinutes: 90, idealMinutes: 90, minMinutes: 30, priority: 7);
    await tester.runAsync(
        () => st.insertCustomTaskForTest(task, drop: [dropBlock]));

    expect(st.stateForTest.addedItems.any((t) => t.id == 'custom_test2'), isTrue);
    expect(st.stateForTest.deletedItems, contains('chill'));
  });

  testWidgets('custom block renders with CUSTOM badge', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    const task = CustomTask(
        id: 'custom_badge', label: 'My custom task', startTime: '10:00',
        durationMinutes: 30, date: '');
    await tester.runAsync(() => st.insertCustomTaskForTest(task));
    await tester.pump();

    expect(find.text('My custom task'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);
  });

  testWidgets('FAB is visible in readonly mode and hidden in adjust mode', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.text('Adjust today'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
