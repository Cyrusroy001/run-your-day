import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/main.dart';
import 'package:daily_command_center/screens/settings_screen.dart';
import 'package:daily_command_center/theme/app_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('settings_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
    activeProfile.value = null;
  });
  tearDown(() {
    activeProfile.value = null;
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle-lock on a just-written profile file; OS reclaims later.
    }
  });

  testWidgets('toggling light updates app theme mode', (tester) async {
    await tester.pumpWidget(const RemindersApp());
    await tester.pump();

    // Navigate to settings via the root navigator. We avoid pumpAndSettle:
    // HomeScreen shows an infinite spinner until its async load resolves, which
    // never settles under the test clock. Fixed pumps drive the route in.
    final ctx = tester.element(find.byType(Navigator));
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Light'));
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('PROFILE log out action clears the active profile', (tester) async {
    activeProfile.value = 'cyrus';
    await tester.pumpWidget(
        MaterialApp(theme: AppPalette.darkTheme, home: const SettingsScreen()));
    await tester.pump();

    expect(find.text('Log out / switch profile'), findsOneWidget);
    await tester.tap(find.text('Log out / switch profile'));
    await tester.pump();

    expect(activeProfile.value, isNull); // AuthGate routes back to the login picker
  });
}
