import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiPrefs {
  final ThemeMode themeMode;
  final double textScale;
  final bool headsUp;      // opt-in heads-up before each block
  final bool sundayNudge;  // weekly Sunday catch-up reminder
  const UiPrefs({
    this.themeMode = ThemeMode.dark,
    this.textScale = 1.0,
    this.headsUp = false,
    this.sundayNudge = false,
  });

  static const _modeKey = 'ui_themeMode';
  static const _scaleKey = 'ui_textScale';
  static const _headsUpKey = 'ui_headsUp';
  static const _sundayKey = 'ui_sundayNudge';

  static Future<UiPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = switch (prefs.getString(_modeKey)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    return UiPrefs(
      themeMode: mode,
      textScale: prefs.getDouble(_scaleKey) ?? 1.0,
      headsUp: prefs.getBool(_headsUpKey) ?? false,
      sundayNudge: prefs.getBool(_sundayKey) ?? false,
    );
  }

  static Future<void> save(UiPrefs p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, p.themeMode.name);
    await prefs.setDouble(_scaleKey, p.textScale);
    await prefs.setBool(_headsUpKey, p.headsUp);
    await prefs.setBool(_sundayKey, p.sundayNudge);
  }

  UiPrefs copyWith({ThemeMode? themeMode, double? textScale, bool? headsUp, bool? sundayNudge}) =>
      UiPrefs(
        themeMode: themeMode ?? this.themeMode,
        textScale: textScale ?? this.textScale,
        headsUp: headsUp ?? this.headsUp,
        sundayNudge: sundayNudge ?? this.sundayNudge,
      );
}
