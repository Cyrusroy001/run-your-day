import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/widgets/now_card.dart';

void main() {
  testWidgets('NowCard renders a label and title without crashing', (tester) async {
    final plan = <String, DayPlan>{
      'mon': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'tue': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'wed': const DayPlan(schedule: DaySchedule.wfh,     isTraining: true),
      'thu': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'fri': const DayPlan(schedule: DaySchedule.office,  isTraining: true),
      'sat': const DayPlan(schedule: DaySchedule.weekend, isTraining: false),
      'sun': const DayPlan(schedule: DaySchedule.weekend, isTraining: true),
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: NowCard(plan: plan, todayKey: 'mon', onTap: () {}),
        ),
      ),
    );

    expect(find.textContaining('Right now'), findsOneWidget);
  });
}
