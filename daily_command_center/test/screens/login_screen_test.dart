import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/screens/login_screen.dart';

late Directory _tmp;

// Helper: pump the widget, drain GoogleFonts fake-async HTTP futures (100 ms),
// then call reloadForTest() inside runAsync so the real disk IO runs on the
// real event loop and completes, then pump to apply the setState rebuild.
Future<void> _pumpAndLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100)); // drain fake google_fonts
  final st = tester.state<LoginScreenState>(find.byType(LoginScreen));
  // reloadForTest() starts a fresh _load() call in the real-async zone so the
  // dart:io awaits inside listProfileMetas() can actually resolve.
  await tester.runAsync(() => st.reloadForTest());
  await tester.pump(); // apply the setState rebuild
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _tmp = await Directory.systemTemp.createTemp('login_screen_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
    activeProfile.value = null;
    // Pre-seed cyrus profile file directly (no rootBundle call at pump time).
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final doc = ProfileDoc(id: 'cyrus', displayName: 'Cyrus', plan: plan);
    await AppStore.repo.save(doc);
  });
  tearDown(() {
    if (_tmp.existsSync()) _tmp.deleteSync(recursive: true);
  });

  // Priming render: warms up the google_fonts cache (Fraunces) before
  // runAsync tests so the first real test doesn't trigger a live HTTP fetch.
  testWidgets('(warms up google_fonts cache)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
      home: const LoginScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('lists existing profiles', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
      home: const LoginScreen(),
    ));
    await _pumpAndLoad(tester);
    expect(find.text('Cyrus'), findsOneWidget);
  });

  testWidgets('tapping a profile sets it active', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
      home: const LoginScreen(),
    ));
    await _pumpAndLoad(tester);
    await tester.tap(find.text('Cyrus'));
    await tester.pump();
    expect(activeProfile.value, 'cyrus');
  });
}
