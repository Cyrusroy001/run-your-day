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
  });

  test('idFor normalizes display names', () {
    expect(ProfileRepository.idFor('  Cyrus '), 'cyrus');
    expect(ProfileRepository.idFor('Alex P'), 'alex_p');
  });

  test('listProfileMetas returns id + displayName for each profile file', () async {
    await AppStore.repo.load('cyrus');   // seeds cyrus.json (displayName "Cyrus")
    final metas = await AppStore.repo.listProfileMetas();
    expect(metas.map((m) => m.id), contains('cyrus'));
    expect(metas.firstWhere((m) => m.id == 'cyrus').displayName, 'Cyrus');
    expect(metas.firstWhere((m) => m.id == 'cyrus').archetype, isA<String>());
  });
}
