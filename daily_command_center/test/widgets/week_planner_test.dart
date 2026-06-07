import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/planner.dart';
import 'package:daily_command_center/widgets/week_planner.dart';

Widget _host(WeekPlan plan, void Function(WeekPlan) onChanged) =>
    MaterialApp(home: Scaffold(body: WeekPlanner(
      plan: plan, todayKey: 'mon', onPlanChanged: onChanged)));

void main() {
  testWidgets('renders all seven day labels', (tester) async {
    await tester.pumpWidget(_host(PlannerLogic.defaultWeek(), (_) {}));
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(d), findsOneWidget);
    }
  });

  testWidgets('tapping a weekday schedule chip toggles office<->wfh', (tester) async {
    WeekPlan? updated;
    await tester.pumpWidget(_host(PlannerLogic.defaultWeek(), (p) => updated = p));
    expect(PlannerLogic.defaultWeek()['mon']!.schedule, DaySchedule.office);
    await tester.tap(find.byKey(const Key('sched-mon')));
    await tester.pump();
    expect(updated!['mon']!.schedule, DaySchedule.wfh);
  });

  testWidgets('weekend schedule chip does nothing', (tester) async {
    WeekPlan? updated;
    await tester.pumpWidget(_host(PlannerLogic.defaultWeek(), (p) => updated = p));
    await tester.tap(find.byKey(const Key('sched-sat')));
    await tester.pump();
    expect(updated, isNull);
  });

  testWidgets('toggling an extra training day shows the move caption', (tester) async {
    // defaultWeek trains mon/wed/fri/sun; turning tue on forces a spacing move.
    await tester.pumpWidget(_host(PlannerLogic.defaultWeek(), (_) {}));
    await tester.tap(find.byKey(const Key('train-tue')));
    await tester.pump();
    expect(find.textContaining('Moved training'), findsOneWidget);
  });
}
