import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg, panel, panel2, cream, muted, dim, line;
  final Color terra, terraD, moss, mossD, amber, amberD, sky;

  const AppPalette({
    required this.bg, required this.panel, required this.panel2,
    required this.cream, required this.muted, required this.dim, required this.line,
    required this.terra, required this.terraD, required this.moss, required this.mossD,
    required this.amber, required this.amberD, required this.sky,
  });

  static const dark = AppPalette(
    bg: Color(0xFF17120E), panel: Color(0xFF221A13), panel2: Color(0xFF2C2218),
    cream: Color(0xFFF4E9DC), muted: Color(0xFFC9B8A6), dim: Color(0xFF8C7B6B), line: Color(0x1AF4E9DC),
    terra: Color(0xFFC8633A), terraD: Color(0x29C85B34), moss: Color(0xFF8FB36A), mossD: Color(0x298FB36A),
    amber: Color(0xFFE3A948), amberD: Color(0x24E3A948), sky: Color(0xFF7BA6C9),
  );

  static const light = AppPalette(
    bg: Color(0xFFF3EBDE), panel: Color(0xFFFFFAF2), panel2: Color(0xFFF6ECDD),
    cream: Color(0xFF2A2018), muted: Color(0xFF6B5D4F), dim: Color(0xFF9B8B7A), line: Color(0x1F2A2018),
    terra: Color(0xFFB24E2A), terraD: Color(0x1AB24E2A), moss: Color(0xFF5D8741), mossD: Color(0x1F5D8741),
    amber: Color(0xFFB9842A), amberD: Color(0x1FB9842A), sky: Color(0xFF4F7FA3),
  );

  static ThemeData get darkTheme => _theme(dark, Brightness.dark);
  static ThemeData get lightTheme => _theme(light, Brightness.light);

  static ThemeData _theme(AppPalette p, Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        scaffoldBackgroundColor: p.bg,
        cardColor: p.panel,
        colorScheme: ColorScheme.fromSeed(seedColor: p.terra, brightness: b)
            .copyWith(surface: p.bg, primary: p.terra, outline: p.line),
        textTheme: GoogleFonts.splineSansTextTheme(
          (b == Brightness.dark ? ThemeData.dark() : ThemeData.light())
              .textTheme.apply(bodyColor: p.cream, displayColor: p.cream),
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
