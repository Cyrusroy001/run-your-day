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
import 'package:daily_command_center/widgets/now_hero_card.dart';
import 'package:daily_command_center/screens/home_screen.dart';
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
    _tmp = Directory.systemTemp.createTempSync('home_screen_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
  });
  tearDown(() {
    try {
      _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle-lock on a just-seeded profile file; OS reclaims later.
    }
  });

  testWidgets('home shows the Right-Now hero and opens Live on tap', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // debugPlan renders the hero immediately (no async load, so no runAsync and
    // therefore no google_fonts throw). The mini-strip + week planner come along.
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme, home: HomeScreen(debugPlan: _plan)));
    await tester.pump();
    expect(find.byType(NowHeroCard), findsOneWidget);

    await tester.tap(find.byType(NowHeroCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // route transition
    expect(find.byType(LiveTimelineView), findsOneWidget);
  });
}
