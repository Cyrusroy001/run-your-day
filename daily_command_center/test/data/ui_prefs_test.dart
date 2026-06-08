import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/ui_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to dark + 1.0 scale', () async {
    final p = await UiPrefs.load();
    expect(p.themeMode, ThemeMode.dark);
    expect(p.textScale, 1.0);
  });

  test('saves and reloads', () async {
    await UiPrefs.save(const UiPrefs(themeMode: ThemeMode.light, textScale: 1.15));
    final p = await UiPrefs.load();
    expect(p.themeMode, ThemeMode.light);
    expect(p.textScale, closeTo(1.15, 0.001));
  });
}
