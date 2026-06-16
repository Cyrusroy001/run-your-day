import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/screens/home_shell.dart';
import 'package:daily_command_center/screens/today_screen.dart';
import 'package:daily_command_center/screens/timeline_screen.dart';
import 'package:daily_command_center/screens/week_screen.dart';

late Plan _plan;
late Directory _tmp;
late ProfileRepository _savedRepo;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _tmp = Directory.systemTemp.createTempSync('home_shell_test');
    _savedRepo = AppStore.repo;
    AppStore.repo = ProfileRepository(baseDir: _tmp);
    await AppStore.savePlan(_plan); // seed an active profile so tabs can load
  });
  tearDown(() {
    AppStore.repo = _savedRepo;
    try {
      _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle-lock on a freshly-written profile file; OS reclaims later.
    }
  });

  testWidgets('NavigationBar swaps Today · Timeline · Week tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppPalette.lightTheme, home: const HomeShell()));
    await tester.pump(const Duration(milliseconds: 100)); // active-profile load

    // Today is the default tab.
    expect(find.byType(TodayScreen), findsOneWidget);

    await tester.tap(find.text('Timeline'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TimelineScreen), findsOneWidget);
    expect(find.byType(TodayScreen), findsNothing);

    await tester.tap(find.text('Week'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WeekScreen), findsOneWidget);
    expect(find.byType(TimelineScreen), findsNothing);

    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TodayScreen), findsOneWidget);
  });
}
