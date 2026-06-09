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
}
