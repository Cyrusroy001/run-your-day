import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/weekly_review.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/weekly_review_card.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

const _summary = WeeklySummary(
  killCount: 0, compactCount: 0, jettisonCount: 0,
  sentence: 'No drift this week — the plan held. Nice.',
);

const _cands = [
  PromotionCandidate(label: 'Evening walk', count: 3, preferredTime: '19:00', durationMinutes: 30),
  PromotionCandidate(label: 'Read', count: 4, preferredTime: '22:00', durationMinutes: 20),
];

void main() {
  testWidgets('promotion section appears when candidates are present', (tester) async {
    await tester.pumpWidget(_wrap(const WeeklyReviewCard(
      summary: _summary, isSunday: true, promotionCandidates: _cands,
    )));
    expect(find.text('Evening walk'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.textContaining('Add to plan'), findsWidgets);
  });

  testWidgets('no promotion section when candidates empty', (tester) async {
    await tester.pumpWidget(_wrap(const WeeklyReviewCard(
      summary: _summary, isSunday: true,
    )));
    expect(find.textContaining('Add to plan'), findsNothing);
  });

  testWidgets('each candidate shows its run-count', (tester) async {
    await tester.pumpWidget(_wrap(const WeeklyReviewCard(
      summary: _summary, isSunday: true, promotionCandidates: _cands,
    )));
    expect(find.textContaining('3×'), findsOneWidget);
    expect(find.textContaining('4×'), findsOneWidget);
  });

  testWidgets('Add to plan fires onPromote with the candidate', (tester) async {
    PromotionCandidate? promoted;
    await tester.pumpWidget(_wrap(WeeklyReviewCard(
      summary: _summary, isSunday: true, promotionCandidates: _cands,
      onPromote: (c) => promoted = c,
    )));
    // Tap the first candidate's "Add to plan" button.
    await tester.tap(find.textContaining('Add to plan').first);
    await tester.pump();
    expect(promoted, isNotNull);
    expect(promoted!.label, 'Evening walk');
  });

  testWidgets('Not yet fires onDismiss with the candidate', (tester) async {
    PromotionCandidate? dismissed;
    await tester.pumpWidget(_wrap(WeeklyReviewCard(
      summary: _summary, isSunday: true, promotionCandidates: _cands,
      onDismiss: (c) => dismissed = c,
    )));
    await tester.tap(find.text('Not yet').first);
    await tester.pump();
    expect(dismissed, isNotNull);
    expect(dismissed!.label, 'Evening walk');
  });
}
