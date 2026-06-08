import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('profiles_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('loadPlan seeds from asset when the profile file is absent', () async {
    final plan = await AppStore.loadPlan();
    expect(plan.schemaVersion, 3);
    expect(plan.week['mon']!.templateId, 'office');
    // The seed was persisted: the profile file now exists.
    expect(File('${tmp.path}/cyrus.json').existsSync(), true);
  });

  test('savePlan then loadPlan round-trips an edited week', () async {
    final plan = await AppStore.loadPlan();
    final edited = plan.copyWith(week: {
      ...plan.week,
      'tue': plan.week['tue']!.copyWith(training: true),
    });
    await AppStore.savePlan(edited);
    final loaded = await AppStore.loadPlan();
    expect(loaded.week['tue']!.training, true);
  });

  test('logs round-trip through the profile file', () async {
    await AppStore.saveLogs('A', const [WorkoutLog(date: '2026-06-08', reps: '3x12')]);
    final logs = await AppStore.loadLogs('A');
    expect(logs.single.reps, '3x12');
    // Editing the plan must not clobber logs (same file).
    final plan = await AppStore.loadPlan();
    await AppStore.savePlan(plan);
    expect((await AppStore.loadLogs('A')).single.reps, '3x12');
  });

  test('a second profile is isolated from the first', () async {
    await AppStore.saveLogs('A', const [WorkoutLog(date: '2026-06-08', reps: 'cyrus-only')]);
    await AppStore.repo.setActiveProfileId('alex');
    final alexLogs = await AppStore.loadLogs('A'); // seeds alex fresh
    expect(alexLogs, isEmpty);
    expect(File('${tmp.path}/alex.json').existsSync(), true);
  });
}
