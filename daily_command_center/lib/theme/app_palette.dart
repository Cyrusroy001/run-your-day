import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ketchup palette — the condiment rule (spec §0):
///   char/raise/raise2 = ground · salt/dim = text · line = hairline
///   tomato = brand · NOW · action (always positive, never a warning)
///   mustard = the ONLY caution tone (squeezes, moves, drops)
///   leaf = done · caught up.  There is no alarm-red anywhere.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color char, raise, raise2, salt, dim, line;
  final Color tomato, tomatoDim, mustard, mustardDim, leaf, leafDim;
  final Color onAccent; // text/icon color on tomato (warm off-white, both themes)

  const AppPalette({
    required this.char, required this.raise, required this.raise2,
    required this.salt, required this.dim, required this.line,
    required this.tomato, required this.tomatoDim,
    required this.mustard, required this.mustardDim,
    required this.leaf, required this.leafDim,
    required this.onAccent,
  });

  static const dark = AppPalette(
    char: Color(0xFF15110F), raise: Color(0xFF1F1915), raise2: Color(0xFF2A211B),
    salt: Color(0xFFF0ECE6), dim: Color(0xFF9A8E83), line: Color(0x17F0ECE6),
    tomato: Color(0xFFD9543E), tomatoDim: Color(0x29D9543E),
    mustard: Color(0xFFDCA03F), mustardDim: Color(0x24DCA03F),
    leaf: Color(0xFF7FB46A), leafDim: Color(0x267FB46A),
    onAccent: Color(0xFFFFF6F2),
  );

  static const light = AppPalette(
    char: Color(0xFFF4F1EC), raise: Color(0xFFFFFFFF), raise2: Color(0xFFECE7DF),
    salt: Color(0xFF221A15), dim: Color(0xFF6E635A), line: Color(0x1A221A15),
    tomato: Color(0xFFB5402C), tomatoDim: Color(0x1AB5402C),
    mustard: Color(0xFFA1701F), mustardDim: Color(0x1FA1701F),
    leaf: Color(0xFF4E7F3A), leafDim: Color(0x1C4E7F3A),
    onAccent: Color(0xFFFFF6F2),
  );

  static ThemeData get darkTheme => _theme(dark, Brightness.dark);
  static ThemeData get lightTheme => _theme(light, Brightness.light);

  static ThemeData _theme(AppPalette p, Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        scaffoldBackgroundColor: p.char,
        cardColor: p.raise,
        colorScheme: ColorScheme.fromSeed(seedColor: p.tomato, brightness: b)
            .copyWith(surface: p.char, primary: p.tomato, outline: p.line),
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
  AppPalette get c => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
