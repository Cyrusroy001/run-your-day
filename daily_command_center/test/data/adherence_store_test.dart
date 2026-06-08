import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/adherence_store.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('adherence_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('done set round-trips', () async {
    final day = DateTime(2026, 6, 5);
    expect(await AdherenceStore.loadDone(day), isEmpty);
    await AdherenceStore.saveDone(day, {'8:00|Wake', '10:00|Train'});
    expect(await AdherenceStore.loadDone(day), {'8:00|Wake', '10:00|Train'});
  });

  test('last7 returns 7 entries oldest->today, null for missing days', () async {
    final today = DateTime(2026, 6, 5);
    await AdherenceStore.writeAdherence(today, 3, 6);
    final week = await AdherenceStore.last7(today);
    expect(week.length, 7);
    expect(week.last.pct, 50.0); // today
    expect(week.first.pct, isNull); // 6 days ago, no record
  });

  test('weeklyAverage ignores days without data', () async {
    final today = DateTime(2026, 6, 5);
    await AdherenceStore.writeAdherence(today, 4, 4); // 100%
    await AdherenceStore.writeAdherence(today.subtract(const Duration(days: 1)), 1, 2); // 50%
    final week = await AdherenceStore.last7(today);
    expect(AdherenceStore.weeklyAverage(week), 75.0);
  });

  test('zero total yields null pct (no divide by zero)', () async {
    final today = DateTime(2026, 6, 5);
    await AdherenceStore.writeAdherence(today, 0, 0);
    final week = await AdherenceStore.last7(today);
    expect(week.last.pct, isNull);
  });

  test('weeklyAverage of all-empty week is null', () async {
    final week = await AdherenceStore.last7(DateTime(2026, 6, 5));
    expect(AdherenceStore.weeklyAverage(week), isNull);
  });
}
