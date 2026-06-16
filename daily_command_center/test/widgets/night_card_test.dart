import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/night_card.dart';

void main() {
  testWidgets('renders a textless starry card without exception', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppPalette.lightTheme,
      home: const Scaffold(body: NightCard()),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Text), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('survives 1.3 text scale', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppPalette.lightTheme,
      home: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(body: NightCard()),
      ),
    ));
    expect(t.takeException(), isNull);
  });
}
