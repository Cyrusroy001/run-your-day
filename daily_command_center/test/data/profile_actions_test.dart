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

  test('clearHistory wipes logs/done/adherence/states but keeps the plan', () async {
    await AppStore.repo.createProfile('Cyrus');
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '9')]);
    final planBefore = await AppStore.loadPlan();

    await AppStore.repo.clearHistory('cyrus');

    expect(await AppStore.loadLogs('A'), isEmpty);
    expect((await AppStore.loadPlan()).schemaVersion, planBefore.schemaVersion); // plan survives
  });

  test('ensureSeeded creates cyrus on a fresh store but leaves you logged out', () async {
    await AppStore.repo.ensureSeeded();
    expect(await AppStore.repo.listProfiles(), contains('cyrus'));
    expect(await AppStore.repo.activeProfileIdOrNull(), isNull); // login still shown
  });

  test('ensureSeeded is idempotent and never duplicates cyrus', () async {
    await AppStore.repo.ensureSeeded();
    await AppStore.repo.ensureSeeded();
    expect((await AppStore.repo.listProfiles()).where((id) => id == 'cyrus').length, 1);
  });
}
