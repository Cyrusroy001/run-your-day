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
import 'package:daily_command_center/screens/live_timeline_view.dart';

late Plan _plan;
late Directory _tmp;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _tmp = Directory.systemTemp.createTempSync('live_timeline_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
  });
  tearDown(() => _tmp.deleteSync(recursive: true));

  testWidgets('renders anchor wall + a routine block on an office day', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: _plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pump();                                   // first frame
    await tester.pump(const Duration(milliseconds: 100));  // let _load() complete + setState

    expect(find.textContaining('ANCHOR'), findsWidgets);
    expect(find.text('Deep Focus — AI Building'), findsOneWidget);
    expect(find.textContaining('On track'), findsOneWidget); // zero-drift summary
  });
}
