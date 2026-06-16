import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../logic/ripeness.dart';
import '../logic/sun_clock.dart';

/// Garden palette (ADR-022) — ripeness = time:
///   char/raise/raise2 = ground · salt/dim = ink · line = hairline
///   ramp: unripe → ripening → nearly → ripe (NOW — the ONLY red, small and
///   earned) → jammy (missed → squeeze ingredients) → picked (vine).
///   vine = primary action (Pick ✓, FAB, links). Ripe never fills surfaces.
///   sky* = ambient sun-clock grounds — light means time, never drift.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color char, raise, raise2, salt, dim, line;
  final Color unripe, ripening, nearly, ripe, jammy, jammyText;
  final Color vine, vineDim, ripeDim, nearlyDim, jammyDim;
  final Color todayTint;
  final Color skyDawn, skyDay, skyGolden, skyDusk, skyNight, star;
  final Color plotA, plotB, plotC, plotD;
  final Color onAccent; // text/icon on vine & ripe fills (warm off-white)

  const AppPalette({
    required this.char, required this.raise, required this.raise2,
    required this.salt, required this.dim, required this.line,
    required this.unripe, required this.ripening, required this.nearly,
    required this.ripe, required this.jammy, required this.jammyText,
    required this.vine, required this.vineDim, required this.ripeDim,
    required this.nearlyDim, required this.jammyDim, required this.todayTint,
    required this.skyDawn, required this.skyDay, required this.skyGolden,
    required this.skyDusk, required this.skyNight, required this.star,
    required this.plotA, required this.plotB, required this.plotC, required this.plotD,
    required this.onAccent,
  });

  /// Greenhouse. Same ripeness ramp; vine/jammyText lightened for contrast
  /// on soil (spec gives light-theme values).
  static const dark = AppPalette(
    char: Color(0xFF211E16), raise: Color(0xFF2B271E), raise2: Color(0xFF353026),
    salt: Color(0xFFEFE9DC), dim: Color(0xFF9B927F), line: Color(0x21EFE9DC),
    unripe: Color(0xFF7E9A6B), ripening: Color(0xFFB5A65A), nearly: Color(0xFFE2A35F),
    ripe: Color(0xFFC8523C), jammy: Color(0xFF8E4540), jammyText: Color(0xFFC97B6A),
    vine: Color(0xFF7E9A6B), vineDim: Color(0x297E9A6B),
    ripeDim: Color(0x29C8523C), nearlyDim: Color(0x24E2A35F), jammyDim: Color(0x298E4540),
    todayTint: Color(0x33E2A35F),
    skyDawn: Color(0xFF2B2520), skyDay: Color(0xFF211E16), skyGolden: Color(0xFF2B271C),
    skyDusk: Color(0xFF262028), skyNight: Color(0xFF1B1914), star: Color(0xFFEFE6C9),
    plotA: Color(0x2E7E9A6B), plotB: Color(0x2EB5A65A), plotC: Color(0x2EE2A35F), plotD: Color(0x2E8E9A86),
    onAccent: Color(0xFFFFF9EF),
  );

  /// Garden — the primary theme.
  static const light = AppPalette(
    char: Color(0xFFF5EFE3), raise: Color(0xFFFFFCF5), raise2: Color(0xFFECE4D2),
    salt: Color(0xFF2E2718), dim: Color(0xFF8A8170), line: Color(0x1F2E2718),
    unripe: Color(0xFF7E9A6B), ripening: Color(0xFFB5A65A), nearly: Color(0xFFE2A35F),
    ripe: Color(0xFFC8523C), jammy: Color(0xFF8E4540), jammyText: Color(0xFF9C4F43),
    vine: Color(0xFF5F7050), vineDim: Color(0x265F7050),
    ripeDim: Color(0x29C8523C), nearlyDim: Color(0x24E2A35F), jammyDim: Color(0x248E4540),
    todayTint: Color(0xA6E2A35F),
    skyDawn: Color(0xFFF2DFD3), skyDay: Color(0xFFF5EFE3), skyGolden: Color(0xFFF2E2C8),
    skyDusk: Color(0xFFE9DCE2), skyNight: Color(0xFF2A2620), star: Color(0xFFEFE6C9),
    plotA: Color(0x2E7E9A6B), plotB: Color(0x2EB5A65A), plotC: Color(0x2EE2A35F), plotD: Color(0x2E8E9A86),
    onAccent: Color(0xFFFFF9EF),
  );

  static ThemeData get darkTheme => _theme(dark, Brightness.dark);
  static ThemeData get lightTheme => _theme(light, Brightness.light);

  static ThemeData _theme(AppPalette p, Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        scaffoldBackgroundColor: p.char,
        cardColor: p.raise,
        colorScheme: ColorScheme.fromSeed(seedColor: p.vine, brightness: b)
            .copyWith(surface: p.char, primary: p.vine, outline: p.line),
        textTheme: GoogleFonts.splineSansTextTheme(
          (b == Brightness.dark ? ThemeData.dark() : ThemeData.light())
              .textTheme.apply(bodyColor: p.salt, displayColor: p.salt),
        ),
        extensions: [p],
      );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) => this;
}

extension PaletteX on BuildContext {
  AppPalette get c => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

extension GardenColors on AppPalette {
  /// Fruit color for a ripeness state (ADR-022 §1).
  Color fruit(Ripeness r) => switch (r) {
        Ripeness.unripe => unripe,
        Ripeness.ripening => ripening,
        Ripeness.nearly => nearly,
        Ripeness.ripe => ripe,
        Ripeness.overripe => jammy,
        Ripeness.picked => vine,
      };

  Color sky(SkyPhase p) => switch (p) {
        SkyPhase.dawn => skyDawn,
        SkyPhase.day => skyDay,
        SkyPhase.golden => skyGolden,
        SkyPhase.dusk => skyDusk,
        SkyPhase.night => skyNight,
      };

  /// Ambient ground at clock blend [b]. While blocks remain, the ramp clamps
  /// at dusk so ink stays readable; pass allowNight for the night state
  /// (whose foreground is styled star/cream explicitly).
  Color ambient(SkyBlend b, {bool allowNight = false}) {
    SkyPhase cl(SkyPhase p) =>
        (!allowNight && p == SkyPhase.night) ? SkyPhase.dusk : p;
    return Color.lerp(sky(cl(b.phase)), sky(cl(b.next)), b.t)!;
  }
}
