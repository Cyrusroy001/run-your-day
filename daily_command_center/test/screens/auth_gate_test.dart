import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/screens/auth_gate.dart';
import 'package:daily_command_center/screens/login_screen.dart';
import 'package:daily_command_center/screens/home_screen.dart';

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
    _tmp = Directory.systemTemp.createTempSync('auth_gate_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
    activeProfile.value = null;
  });
  tearDown(() {
    try { _tmp.deleteSync(recursive: true); } on FileSystemException {}
  });

  testWidgets('null active profile → LoginScreen', (tester) async {
    activeProfile.value = null;
    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('non-null active profile → HomeScreen', (tester) async {
    activeProfile.value = 'cyrus';
    await tester.pumpWidget(MaterialApp(
      home: AuthGate(homeBuilder: (_) => HomeScreen(debugPlan: _plan)),
    ));
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
