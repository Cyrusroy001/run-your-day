import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/planner.dart';
import 'package:daily_command_center/logic/timeline.dart';
import 'package:daily_command_center/widgets/now_card.dart';

WeekPlan get _plan => PlannerLogic.defaultWeek(); // mon = office + training

Widget _host({
  required Set<String> done,
  required double now,
  void Function(String)? onToggle,
  VoidCallback? onViewAll,
}) =>
    MaterialApp(home: Scaffold(body: NowCard(
      plan: _plan,
      todayKey: 'mon',
      doneToday: done,
      debugNow: now,
      onViewAll: onViewAll ?? () {},
      onToggleDone: onToggle ?? (_) {},
    )));

void main() {
  // 10:30 falls inside mon's 10:00 training block (trackable).
  testWidgets('shows Mark done for a trackable current block', (tester) async {
    await tester.pumpWidget(_host(done: const {}, now: 10.5));
    expect(find.text('◯ Mark done'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('done current block shows green Done + badge', (tester) async {
    final train = buildTimeline('mon', _plan['mon']!).firstWhere((b) => b.isTrain);
    await tester.pumpWidget(_host(done: {train.signature}, now: 10.5));
    expect(find.text('✓ Done'), findsOneWidget);
    expect(find.text('✓ done'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping Mark done reports the current block signature', (tester) async {
    final train = buildTimeline('mon', _plan['mon']!).firstWhere((b) => b.isTrain);
    String? toggled;
    await tester.pumpWidget(_host(done: const {}, now: 10.5, onToggle: (s) => toggled = s));
    await tester.tap(find.text('◯ Mark done'));
    await tester.pump();
    expect(toggled, train.signature);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('passive current block hides Mark done', (tester) async {
    // 14.5 = 2:30pm = "Work — 2:00 to 8:00" (cls work, passive)
    await tester.pumpWidget(_host(done: const {}, now: 14.5));
    expect(find.text('◯ Mark done'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('View all is always present and reports taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(done: const {}, now: 14.5, onViewAll: () => tapped = true));
    await tester.tap(find.text('View all ›'));
    await tester.pump();
    expect(tapped, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
