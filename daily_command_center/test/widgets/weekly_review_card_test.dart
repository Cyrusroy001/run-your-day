import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/weekly_review.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/weekly_review_card.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

void main() {
  testWidgets('shows the sentence and (on Sunday) the nudge', (tester) async {
    const summary = WeeklySummary(killCount: 2, compactCount: 4, jettisonCount: 0,
        sentence: 'This week — Train auto-cancelled 2×; Focus compacted 4×.');
    await tester.pumpWidget(_wrap(const WeeklyReviewCard(summary: summary, isSunday: true,
        nudge: 'Train keeps getting squeezed out — move it earlier, or shorten its budget?')));
    expect(find.textContaining('Train auto-cancelled 2×'), findsOneWidget);
    expect(find.textContaining('squeezed out'), findsOneWidget);
  });

  testWidgets('hides the nudge on non-Sunday', (tester) async {
    const summary = WeeklySummary(killCount: 0, compactCount: 0, jettisonCount: 0, sentence: 'No drift this week — the plan held. Nice.');
    await tester.pumpWidget(_wrap(const WeeklyReviewCard(summary: summary, isSunday: false, nudge: 'x')));
    expect(find.textContaining('No drift'), findsOneWidget);
    expect(find.textContaining('squeezed out'), findsNothing);
  });
}
