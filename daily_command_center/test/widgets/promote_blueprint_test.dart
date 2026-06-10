import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/weekly_review.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/promote_blueprint_sheet.dart';

const _candidate = PromotionCandidate(
  label: 'Evening walk', count: 3, preferredTime: '19:00', durationMinutes: 30,
);

const _templates = <({String id, String label})>[
  (id: 'office', label: 'Office'),
  (id: 'wfh', label: 'WFH'),
  (id: 'weekend', label: 'Weekend'),
];

// Pumps a button that opens the sheet, then taps it.
Future<void> _open(
  WidgetTester tester, {
  required void Function(String, String, int, List<String>) onConfirm,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppPalette.darkTheme,
    home: Scaffold(
      body: Builder(builder: (context) => Center(child: ElevatedButton(
        onPressed: () => showPromoteToBlueprintSheet(context,
            candidate: _candidate, templates: _templates, onConfirm: onConfirm),
        child: const Text('open'),
      ))),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sheet shows pre-filled label, time and duration', (tester) async {
    await _open(tester, onConfirm: (_, __, ___, ____) {});
    expect(find.text('Evening walk'), findsOneWidget);      // label field
    expect(find.text('30m'), findsWidgets);                 // duration chip
    expect(find.textContaining('7:00'), findsWidgets);      // time readout (19:00 → 7:00)
  });

  testWidgets('Add to plan is disabled until a template is chosen', (tester) async {
    List<String>? got;
    await _open(tester, onConfirm: (_, __, ___, ids) => got = ids);
    await tester.tap(find.text('Add to plan'));
    await tester.pumpAndSettle();
    expect(got, isNull); // nothing selected → no-op
  });

  testWidgets('selecting Office then Add to plan fires onConfirm with [office]', (tester) async {
    String? label; String? time; int? dur; List<String>? ids;
    await _open(tester, onConfirm: (l, t, d, i) { label = l; time = t; dur = d; ids = i; });
    await tester.tap(find.text('Office'));
    await tester.pump();
    await tester.tap(find.text('Add to plan'));
    await tester.pumpAndSettle();
    expect(label, 'Evening walk');
    expect(time, '19:00');
    expect(dur, 30);
    expect(ids, ['office']);
  });

  testWidgets('Every day selects all templates', (tester) async {
    List<String>? ids;
    await _open(tester, onConfirm: (_, __, ___, i) => ids = i);
    await tester.tap(find.text('Every day'));
    await tester.pump();
    await tester.tap(find.text('Add to plan'));
    await tester.pumpAndSettle();
    expect(ids, containsAll(['office', 'wfh', 'weekend']));
  });

  testWidgets('editing the label is reflected in onConfirm', (tester) async {
    String? label;
    await _open(tester, onConfirm: (l, _, __, ___) => label = l);
    await tester.enterText(find.byType(TextField), 'Night stroll');
    await tester.tap(find.text('Office'));
    await tester.pump();
    await tester.tap(find.text('Add to plan'));
    await tester.pumpAndSettle();
    expect(label, 'Night stroll');
  });
}
