import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiPrefs {
  final ThemeMode themeMode;
  final double textScale;
  const UiPrefs({this.themeMode = ThemeMode.dark, this.textScale = 1.0});

  static const _modeKey = 'ui_themeMode';
  static const _scaleKey = 'ui_textScale';

  static Future<UiPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = switch (prefs.getString(_modeKey)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    return UiPrefs(themeMode: mode, textScale: prefs.getDouble(_scaleKey) ?? 1.0);
  }

  static Future<void> save(UiPrefs p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, p.themeMode.name);
    await prefs.setDouble(_scaleKey, p.textScale);
  }

  UiPrefs copyWith({ThemeMode? themeMode, double? textScale}) =>
      UiPrefs(themeMode: themeMode ?? this.themeMode, textScale: textScale ?? this.textScale);
}
