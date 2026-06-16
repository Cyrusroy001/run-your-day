import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/logic/ripeness.dart';
import 'package:daily_command_center/logic/sun_clock.dart';

void main() {
  test('garden (light) tokens match ADR-022', () {
    const p = AppPalette.light;
    expect(p.char, const Color(0xFFF5EFE3));   // ground cream
    expect(p.raise, const Color(0xFFFFFCF5));  // card
    expect(p.salt, const Color(0xFF2E2718));   // ink
    expect(p.dim, const Color(0xFF8A8170));
    expect(p.ripe, const Color(0xFFC8523C));   // NOW — the only red
    expect(p.vine, const Color(0xFF5F7050));   // primary action
    expect(p.jammyText, const Color(0xFF9C4F43));
    expect(p.todayTint, const Color(0xA6E2A35F));
  });

  test('greenhouse (dark) grounds', () {
    const p = AppPalette.dark;
    expect(p.char, const Color(0xFF211E16));   // soil
    expect(p.raise, const Color(0xFF2B271E));
    expect(p.ripe, const Color(0xFFC8523C));   // same ripeness ramp
  });

  test('fruit() maps every ripeness', () {
    const p = AppPalette.light;
    expect(p.fruit(Ripeness.ripe), p.ripe);
    expect(p.fruit(Ripeness.picked), p.vine);
    expect(p.fruit(Ripeness.overripe), p.jammy);
  });

  test('ambient clamps night to dusk unless allowed', () {
    const p = AppPalette.light;
    final night = const SkyBlend(SkyPhase.night, SkyPhase.night, 0);
    expect(p.ambient(night), p.skyDusk);
    expect(p.ambient(night, allowNight: true), p.skyNight);
  });
}
