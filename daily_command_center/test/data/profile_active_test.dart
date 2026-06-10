import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    activeProfile.value = null;
  });

  test('fresh store → activeProfileIdOrNull is null (logged out)', () async {
    expect(await AppStore.repo.activeProfileIdOrNull(), isNull);
  });

  test('setActiveProfileId sets pointer + notifier; clearActive resets both', () async {
    await AppStore.repo.setActiveProfileId('cyrus');
    expect(await AppStore.repo.activeProfileIdOrNull(), 'cyrus');
    expect(activeProfile.value, 'cyrus');

    await AppStore.repo.clearActive();
    expect(await AppStore.repo.activeProfileIdOrNull(), isNull);
    expect(activeProfile.value, isNull);
  });
}
