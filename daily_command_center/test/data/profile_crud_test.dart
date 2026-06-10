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

  test('createProfile writes a file, sets active, and seeds a plan', () async {
    final doc = await AppStore.repo.createProfile('Alex P');
    expect(doc.id, 'alex_p');
    expect(doc.displayName, 'Alex P');
    expect(await AppStore.repo.activeProfileIdOrNull(), 'alex_p');
    expect((await AppStore.repo.listProfiles()), contains('alex_p'));
    expect(doc.plan.schemaVersion, 3);
  });

  test('profiles are isolated — logs under one are invisible to another', () async {
    await AppStore.repo.createProfile('Cyrus');
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '10')]);

    await AppStore.repo.createProfile('Alex');
    expect(await AppStore.loadLogs('A'), isEmpty);

    await AppStore.repo.setActiveProfileId('cyrus');
    expect((await AppStore.loadLogs('A')).single.reps, '10');
  });

  test('delete removes the file and clears active if it pointed there', () async {
    await AppStore.repo.createProfile('Cyrus');
    await AppStore.repo.delete('cyrus');
    expect(await AppStore.repo.listProfiles(), isNot(contains('cyrus')));
    expect(await AppStore.repo.activeProfileIdOrNull(), isNull);
  });
}
