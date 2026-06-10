import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/screens/login_screen.dart';
import 'package:daily_command_center/theme/app_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('login_screen_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
    activeProfile.value = null;
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // Inject a synchronous-completing loader to avoid dart:io under fake-async.
  Future<List<ProfileMeta>> Function() loaderWith(List<ProfileMeta> metas) =>
      () async => metas;

  testWidgets('lists existing profiles', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
      home: LoginScreen(profileLoader: loaderWith([
        const ProfileMeta(id: 'cyrus', displayName: 'Cyrus', archetype: 'Office professional'),
      ])),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cyrus'), findsOneWidget);
  });

  testWidgets('tapping a profile sets it active', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
      home: LoginScreen(profileLoader: loaderWith([
        const ProfileMeta(id: 'cyrus', displayName: 'Cyrus', archetype: ''),
      ])),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cyrus'));
    await tester.pumpAndSettle();
    expect(activeProfile.value, 'cyrus');
  });
}
