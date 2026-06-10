import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp();
    AppStore.repo = ProfileRepository(baseDir: tmp);
    activeProfile.value = null;
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('export then import restores a profile losslessly', () async {
    await AppStore.repo.createProfile('Cyrus');
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '12')]);
    final blob = await AppStore.repo.exportProfile('cyrus');

    // Fresh store (new temp dir), then import.
    final tmp2 = await Directory.systemTemp.createTemp();
    AppStore.repo = ProfileRepository(baseDir: tmp2);
    final meta = await AppStore.repo.importProfile(blob);
    expect(meta.id, 'cyrus');
    expect(await AppStore.repo.listProfiles(), contains('cyrus'));

    await AppStore.repo.setActiveProfileId('cyrus');
    expect((await AppStore.loadLogs('A')).single.reps, '12');
    tmp2.deleteSync(recursive: true);
  });

  test('exported blob is valid JSON carrying the ProfileDoc', () async {
    await AppStore.repo.createProfile('Cyrus');
    final blob = await AppStore.repo.exportProfile('cyrus');
    final decoded = jsonDecode(blob) as Map<String, dynamic>;
    expect(decoded['id'], 'cyrus');
    expect(decoded['plan'], isA<Map>());
  });
}
