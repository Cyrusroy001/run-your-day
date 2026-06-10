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
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
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
}
