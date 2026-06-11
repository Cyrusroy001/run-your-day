import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/logic/onboarding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('onboarding_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
    activeProfile.value = null;
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    activeProfile.value = null;
  });

  test('buildPlan clones the seed, applies week choices, title, and training count', () async {
    final seed = (await AppStore.repo.load('cyrus')).plan;
    final choices = {
      'mon': 'office', 'tue': 'wfh', 'wed': 'office', 'thu': 'wfh',
      'fri': 'office', 'sat': 'weekend', 'sun': 'weekend_sun',
    };
    final plan = OnboardingLogic.buildPlan(
        seed: seed, displayName: 'Alex', weekChoices: choices, trainingDays: 3);

    expect(plan.meta.title, contains('Alex'));
    expect(plan.week['tue']!.templateId, 'wfh');
    expect(plan.week.values.where((w) => w.training).length, 3);
  });

  test('commit creates an active profile with the built plan saved', () async {
    final seed = (await AppStore.repo.load('cyrus')).plan;
    final id = await OnboardingLogic.commit(
      repo: AppStore.repo,
      seed: seed,
      displayName: 'Alex',
      weekChoices: const {
        'mon': 'office', 'tue': 'wfh', 'wed': 'office', 'thu': 'wfh',
        'fri': 'office', 'sat': 'weekend', 'sun': 'weekend_sun',
      },
      trainingDays: 3,
    );

    expect(id, 'alex');
    expect(activeProfile.value, 'alex'); // pointer + notifier set
    expect(await AppStore.repo.activeProfileIdOrNull(), 'alex'); // persisted
    expect(await AppStore.repo.listProfiles(), contains('alex'));

    final doc = await AppStore.repo.load('alex');
    expect(doc.plan.meta.title, contains('Alex'));
    expect(doc.plan.week['tue']!.templateId, 'wfh');
    expect(doc.plan.week.values.where((w) => w.training).length, 3);
  });
}
