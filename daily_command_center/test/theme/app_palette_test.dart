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
    expect(got.char, AppPalette.light.char);

    await tester.pumpWidget(MaterialApp(
      theme: AppPalette.darkTheme,
      themeAnimationDuration: Duration.zero,
      home: Builder(builder: (ctx) { got = ctx.c; return const SizedBox(); }),
    ));
    expect(got.char, AppPalette.dark.char);
    // Condiment rule: tomato is brand/now/action (never a warning); mustard is
    // the only caution tone; leaf is done. No alarm-red anywhere.
    expect(AppPalette.dark.tomato, const Color(0xFFD9543E));
    expect(AppPalette.dark.mustard, const Color(0xFFDCA03F));
    expect(AppPalette.dark.leaf, const Color(0xFF7FB46A));
  });
}
