import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/custom_task_fitter.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/sacrifice_picker_sheet.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: child));

Block _b(String id, String label, {int ideal = 60, int priority = 6}) => Block(
      id: id, time: '9:00', cls: 'goal', label: label,
      durationMinutes: ideal, idealMinutes: ideal, minMinutes: 30, priority: priority,
      estStart: 9.0, seedStart: 9.0,
    );

void main() {
  final offers = [
    SacrificeOffer(drop: [_b('chill', 'Evening chill', ideal: 90)], freedMinutes: 90, isRecommended: true),
    SacrificeOffer(drop: [_b('dsa', 'DSA practice', ideal: 45), _b('read', 'Reading', ideal: 30)], freedMinutes: 75),
  ];

  testWidgets('shows all offer rows', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(
      onPressed: () => showSacrificePickerSheet(
        ctx,
        offers: offers,
        taskLabel: 'Call mom',
        onConfirm: (_) {},
      ),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Evening chill'), findsOneWidget);
    expect(find.text('DSA practice'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets('recommended offer is visually marked', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(
      onPressed: () => showSacrificePickerSheet(
        ctx,
        offers: offers,
        taskLabel: 'Call mom',
        onConfirm: (_) {},
      ),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets('tapping an offer calls onConfirm with that offer', (tester) async {
    SacrificeOffer? confirmed;
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(
      onPressed: () => showSacrificePickerSheet(
        ctx,
        offers: offers,
        taskLabel: 'Call mom',
        onConfirm: (o) => confirmed = o,
      ),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the first offer's confirm button
    final confirmBtns = find.widgetWithText(FilledButton, 'Drop it');
    expect(confirmBtns, findsWidgets);
    await tester.tap(confirmBtns.first);
    await tester.pump();

    expect(confirmed, isNotNull);
    expect(confirmed!.drop.first.id, 'chill');
  });

  testWidgets('task label shown in sheet title', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(
      onPressed: () => showSacrificePickerSheet(
        ctx,
        offers: offers,
        taskLabel: 'Call mom',
        onConfirm: (_) {},
      ),
      child: const Text('open'),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Call mom'), findsWidgets);
  });
}
