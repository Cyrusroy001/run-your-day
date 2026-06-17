import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/weekly_review.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/screens/catchup_screen.dart';
import 'package:daily_command_center/screens/how_it_works_screen.dart';
import 'package:daily_command_center/widgets/jar_shelf.dart';

void main() {
  testWidgets('catch-up shows the pantry jars + the week sentence', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme, home: const CatchupScreen(
      summary: WeeklySummary(killCount: 0, compactCount: 2, jettisonCount: 0,
          sentence: 'This week — two squeezes, otherwise clean.'),
      jars: [
        null,
        DayKetchup(date: '2026-06-12', picked: 4, trackable: 6, squeezes: 1, drops: 0, latePicks: 0),
        DayKetchup(date: '2026-06-13', picked: 6, trackable: 6, squeezes: 0, drops: 0, latePicks: 0),
        DayKetchup(date: '2026-06-14', picked: 2, trackable: 6, squeezes: 3, drops: 1, latePicks: 0),
        null, null, null,
      ],
    )));
    expect(find.byType(JarShelf), findsOneWidget);
    expect(find.text('THE PANTRY'), findsOneWidget);
    expect(find.text('This week — two squeezes, otherwise clean.'), findsOneWidget);
  });

  testWidgets('catch-up shows headline + give-it-more-time writes back', (tester) async {
    String? gotLabel;
    int? gotMins;
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme, home: CatchupScreen(
      summary: const WeeklySummary(killCount: 0, compactCount: 3, jettisonCount: 0,
          sentence: 'This week — Shower + brunch compacted 3×.'),
      insightLabel: 'Shower + brunch',
      giveMinutes: 15,
      onGiveMoreTime: (label, mins) { gotLabel = label; gotMins = mins; },
    )));

    expect(find.text('Your week,\ncaught up.'), findsOneWidget);
    expect(find.text('Give it more time'), findsOneWidget);

    await tester.tap(find.text('Give it more time'));
    await tester.pump();
    expect(gotLabel, 'Shower + brunch');
    expect(gotMins, 15);
    // Insight collapses into the applied (leaf) confirmation.
    expect(find.textContaining('Gave Shower + brunch'), findsOneWidget);
  });

  testWidgets('how-it-works lists the manual on one screen', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme, home: const HowItWorksScreen()));
    expect(find.textContaining('The squeeze.'), findsOneWidget);
    expect(find.textContaining('Locked.'), findsOneWidget);
    expect(find.textContaining('whole manual'), findsOneWidget);
  });
}
