import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/recurring_store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/screens/live_timeline_view.dart';

late Plan _plan;
late Directory _tmp;
final _fmt = DateFormat('yyyy-MM-dd');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _tmp = Directory.systemTemp.createTempSync('repeat_prompt_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
    // Pre-create the profile file in the test-runner zone (not fake-async),
    // so runAsync seeding never hits rootBundle.loadString().
    await AppStore.loadPlan();
  });
  tearDown(() {
    try {
      _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle lock — OS reclaims later.
    }
  });

  // Seeds yesterday's custom task + done-set.
  // Uses load(id) directly — avoids rootBundle.loadString() which fails in
  // runAsync; the file already exists from setUp so load(id) is pure dart:io.
  Future<void> seedYesterdayTask() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey = _fmt.format(yesterday);
    final task = CustomTask(
      id: 'custom_yesterday_test',
      label: 'Evening walk',
      startTime: '19:00',
      durationMinutes: 30,
      date: yesterdayKey,
    );
    final doc = await AppStore.repo.load(ProfileRepository.defaultProfileId);
    await AppStore.repo.save(doc.copyWith(
      states: {...doc.states, yesterdayKey: DailyState(date: yesterdayKey, addedItems: [task])},
      done: {...doc.done, yesterdayKey: ['7:00|Evening walk']},
    ));
  }

  // Render the view and drive _load() to deterministic completion.
  // pump(100ms) before runAsync is required: it exhausts any pending
  // GoogleFonts HTTP futures in fake-async; entering runAsync while those
  // futures are still alive causes them to fire real HTTP calls and throw.
  Future<LiveTimelineViewState> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
      home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    await tester.runAsync(() => st.loadPendingRepeatTasksForTest());
    await tester.pump();
    return st;
  }

  // Priming render: the AppBar title uses GoogleFonts.fraunces, whose font
  // bytes are fetched over HTTP on first use and cached in a process-static set.
  // A plain pump (no runAsync) leaves that fetch harmlessly pending and seeds
  // the cache; without it the first runAsync test would fire the real, failing
  // HTTP request and throw. Mirrors live_timeline_test.dart's first test.
  testWidgets('(warms up google_fonts cache before runAsync tests)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
      home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LiveTimelineView), findsOneWidget);
  });

  testWidgets('repeat card appears when yesterday had a completed custom task',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(seedYesterdayTask);
    final st = await pumpView(tester);

    expect(st.pendingRepeatTasksForTest, hasLength(1));
    expect(find.textContaining('Repeat'), findsWidgets);
    expect(find.textContaining('Evening walk'), findsWidgets);
  });

  testWidgets('repeat card does NOT appear when no custom tasks yesterday',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final st = await pumpView(tester);

    expect(st.pendingRepeatTasksForTest, isEmpty);
    expect(find.textContaining('Repeat "'), findsNothing);
  });

  testWidgets('repeat card does NOT appear when task already recurring',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await seedYesterdayTask();
      const recurring = RecurringCustomTask(
        id: 'recur_for_yesterday',
        label: 'Evening walk',
        preferredTime: '19:00',
        durationMinutes: 30,
        activeDates: [],
        originTaskId: 'custom_yesterday_test',
      );
      await RecurringStore.save(recurring);
    });
    final st = await pumpView(tester);

    expect(st.pendingRepeatTasksForTest, isEmpty);
    expect(find.textContaining('Repeat "'), findsNothing);
  });

  testWidgets('tapping a day chip creates a RecurringCustomTask and card disappears',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(seedYesterdayTask);
    await pumpView(tester);

    expect(find.textContaining('Repeat'), findsWidgets);

    await tester.runAsync(() async {
      await tester.tap(find.text('+2'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    expect(st.pendingRepeatTasksForTest, isEmpty);
    expect(find.textContaining('Repeat "'), findsNothing);

    final tasks = await tester.runAsync(() => RecurringStore.loadAll());
    expect(tasks, hasLength(1));
    expect(tasks!.first.label, 'Evening walk');
    expect(tasks.first.originTaskId, 'custom_yesterday_test');
  });

  testWidgets('tapping Skip dismisses the card', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(seedYesterdayTask);
    await pumpView(tester);

    expect(find.textContaining('Repeat'), findsWidgets);

    await tester.runAsync(() async {
      await tester.tap(find.text('Skip'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    expect(st.pendingRepeatTasksForTest, isEmpty);
    expect(find.textContaining('Repeat "'), findsNothing);
  });

  testWidgets('skipped task does not reappear after reload', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(seedYesterdayTask);
    final st = await pumpView(tester);

    // Skip the task
    await tester.runAsync(() async {
      await tester.tap(find.text('Skip'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Reload via the seam — profile file exists, all IO is pure dart:io
    await tester.runAsync(() => st.loadPendingRepeatTasksForTest());
    await tester.pump();

    expect(st.pendingRepeatTasksForTest, isEmpty);
    expect(find.textContaining('Repeat "'), findsNothing);
  });
}
