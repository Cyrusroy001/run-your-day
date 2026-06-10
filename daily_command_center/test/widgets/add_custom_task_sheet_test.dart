import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/add_custom_task_sheet.dart';

Widget _host(Widget child) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: child));

void main() {
  testWidgets('Continue button disabled when label empty', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(
      onPressed: () => showAddCustomTaskSheet(ctx, onSubmit: (_, __, ___) {}),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final continueBtn = find.widgetWithText(FilledButton, 'Continue');
    expect(continueBtn, findsOneWidget);
    final btn = tester.widget<FilledButton>(continueBtn);
    expect(btn.onPressed, isNull); // disabled
  });

  testWidgets('Continue button enabled after typing a label', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(
      onPressed: () => showAddCustomTaskSheet(ctx, onSubmit: (_, __, ___) {}),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Call mom');
    await tester.pump();

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('onSubmit fires with label, time string, and duration', (tester) async {
    String? gotLabel;
    String? gotTime;
    int? gotDur;

    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(
      onPressed: () => showAddCustomTaskSheet(ctx, onSubmit: (l, t, d) {
        gotLabel = l; gotTime = t; gotDur = d;
      }),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Call mom');
    await tester.pump();

    // Tap a duration chip
    await tester.tap(find.text('45m'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();

    expect(gotLabel, 'Call mom');
    expect(gotTime, isNotNull);
    expect(gotTime, matches(RegExp(r'^\d{2}:\d{2}$'))); // HH:mm
    expect(gotDur, 45);
  });

  testWidgets('duration chips 15/30/45/60/90/120 are all present', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(
      onPressed: () => showAddCustomTaskSheet(ctx, onSubmit: (_, __, ___) {}),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final d in ['15m', '30m', '45m', '60m', '90m', '120m']) {
      expect(find.text(d), findsOneWidget, reason: 'chip $d missing');
    }
  });
}
