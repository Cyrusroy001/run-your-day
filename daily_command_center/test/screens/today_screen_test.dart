import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/logic/planner.dart';
import 'package:daily_command_center/screens/today_screen.dart';

Widget _host({required void Function(String) onToggle, Set<String> done = const {}}) =>
    MaterialApp(home: TodayScreen(
      plan: PlannerLogic.defaultWeek(),
      todayKey: 'mon', // office + training in the default week
      doneToday: done,
      onToggle: onToggle,
      debugNow: 10.5, // 10:30 → inside the 10:00 training block
    ));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester t) async {
    // Tall surface so the ListView builds every row (lazy lists skip off-screen rows).
    t.view.physicalSize = const Size(1200, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50)); // resolve last7 future
  }

  testWidgets('renders the week strip header and screen title', (tester) async {
    await tester.pumpWidget(_host(onToggle: (_) {}));
    await settle(tester);
    expect(find.text('LAST 7 DAYS'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('tapping a trackable row reports its signature', (tester) async {
    String? sig;
    await tester.pumpWidget(_host(onToggle: (s) => sig = s));
    await settle(tester);
    await tester.tap(find.text('Wake · water · sunlight'));
    await tester.pump();
    expect(sig, '8:00|Wake · water · sunlight');
  });

  testWidgets('passive block is not tappable', (tester) async {
    var called = false;
    await tester.pumpWidget(_host(onToggle: (_) => called = true));
    await settle(tester);
    await tester.tap(find.text('Walk to office (10 min)'));
    await tester.pump();
    expect(called, isFalse);
  });

  testWidgets('current block shows NOW', (tester) async {
    await tester.pumpWidget(_host(onToggle: (_) {}));
    await settle(tester);
    expect(find.text('NOW'), findsOneWidget);
  });
}
