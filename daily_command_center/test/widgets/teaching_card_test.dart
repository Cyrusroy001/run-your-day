import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/teaching_card.dart';

void main() {
  testWidgets('renders copy and fires callbacks', (tester) async {
    var got = false;
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body:
      TeachingCard(text: 'I trimmed Brunch by 15m.', onGotIt: () => got = true, onWhy: () {}))));
    expect(find.textContaining('trimmed Brunch'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    expect(got, true);
  });
}
