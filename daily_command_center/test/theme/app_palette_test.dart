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

  test('migration aliases map old token names onto ketchup tokens', () {
    // TEMP: removed in K8. Guards the bridge while pre-rebrand widgets migrate.
    const p = AppPalette.dark;
    expect(p.terra, p.tomato);
    expect(p.amber, p.mustard);
    expect(p.moss, p.leaf);
    expect(p.bg, p.char);
    expect(p.panel, p.raise);
    expect(p.cream, p.salt);
    expect(p.muted, p.dim);
  });
}
