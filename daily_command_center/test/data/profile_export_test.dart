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
    try {
      AppStore.repo = ProfileRepository(baseDir: tmp2);
      final meta = await AppStore.repo.importProfile(blob);
      expect(meta.id, 'cyrus');
      expect(await AppStore.repo.listProfiles(), contains('cyrus'));

      await AppStore.repo.setActiveProfileId('cyrus');
      expect((await AppStore.loadLogs('A')).single.reps, '12');
    } finally {
      tmp2.deleteSync(recursive: true);
    }
  });

  test('exported blob is valid JSON carrying the ProfileDoc', () async {
    await AppStore.repo.createProfile('Cyrus');
    final blob = await AppStore.repo.exportProfile('cyrus');
    final decoded = jsonDecode(blob) as Map<String, dynamic>;
    expect(decoded['id'], 'cyrus');
    expect(decoded['plan'], isA<Map>());
  });

  test('DayKetchup grades + ProfileDoc.ketchup roundtrip', () async {
    const first = DayKetchup(date: '2026-06-13', picked: 5, trackable: 6,
        squeezes: 0, drops: 0, latePicks: 0);
    const good = DayKetchup(date: '2026-06-13', picked: 5, trackable: 6,
        squeezes: 2, drops: 0, latePicks: 1);
    const rough = DayKetchup(date: '2026-06-13', picked: 2, trackable: 6,
        squeezes: 3, drops: 1, latePicks: 0);
    expect(first.grade, BatchGrade.firstPress);
    expect(good.grade, BatchGrade.goodBatch);
    expect(rough.grade, BatchGrade.roughBatch);
    expect(first.fill, closeTo(5 / 6, 0.001));

    await AppStore.repo.createProfile('Cyrus');
    final plan = (await AppStore.repo.loadActive()).plan;
    final doc = ProfileDoc(id: 'p', displayName: 'P', plan: plan,
        ketchup: const {'2026-06-13': good});
    final back = ProfileDoc.fromJson(doc.toJson());
    expect(back.ketchup['2026-06-13']!.latePicks, 1);
    expect(back.ketchup['2026-06-13']!.grade, BatchGrade.goodBatch);
  });
}
