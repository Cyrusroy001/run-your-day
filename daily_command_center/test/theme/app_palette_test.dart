import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';

void main() {
  testWidgets('context.c resolves dark vs light tokens', (tester) async {
    late AppPalette got;
    await tester.pumpWidget(MaterialApp(
      theme: AppPalette.lightTheme,
      themeAnimationDuration: Duration.zero,
      home: Builder(builder: (ctx) { got = ctx.c; return const SizedBox(); }),
    ));
    expect(got.bg, AppPalette.light.bg);

    await tester.pumpWidget(MaterialApp(
      theme: AppPalette.darkTheme,
      themeAnimationDuration: Duration.zero,
      home: Builder(builder: (ctx) { got = ctx.c; return const SizedBox(); }),
    ));
    expect(got.bg, AppPalette.dark.bg);
    // No-red guarantee: amber is the loudest accent; terra is the anchor color.
    expect(AppPalette.dark.terra, const Color(0xFFC8633A));
  });
}
