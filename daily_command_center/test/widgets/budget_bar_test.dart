import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/budget_bar.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

void main() {
  testWidgets('shows -Nm tag when compacted', (tester) async {
    await tester.pumpWidget(_wrap(const BudgetBar(idealMinutes: 45, currentMinutes: 30)));
    expect(find.textContaining('−15m'), findsOneWidget);
    expect(find.textContaining('30m'), findsOneWidget);
  });

  testWidgets('no tag when at ideal', (tester) async {
    await tester.pumpWidget(_wrap(const BudgetBar(idealMinutes: 45, currentMinutes: 45)));
    expect(find.textContaining('−'), findsNothing);
    expect(find.textContaining('45m'), findsOneWidget);
  });
}
