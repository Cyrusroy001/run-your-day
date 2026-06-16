import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/adherence_store.dart';
import 'package:daily_command_center/data/ketchup_store.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('ketchup_store_test');
    AppStore.repo = ProfileRepository(baseDir: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('update derives counts from drift log and accumulates latePicks', () async {
    final day = DateTime(2026, 6, 13);
    const log = [
      DriftEvent(date: '2026-06-13', itemId: 'a', label: 'A', event: 'compacted'),
      DriftEvent(date: '2026-06-13', itemId: 'b', label: 'B', event: 'jettisoned'),
    ];
    var rec = await KetchupStore.update(day,
        picked: 3, trackable: 6, driftLog: log, latePickDelta: 1);
    expect((rec.squeezes, rec.drops, rec.latePicks), (1, 1, 1));
    rec = await KetchupStore.update(day,
        picked: 4, trackable: 6, driftLog: log, latePickDelta: 0);
    expect(rec.latePicks, 1); // persists across updates
    expect(rec.grade, BatchGrade.roughBatch);
  });

  test('last7 prefers stored records, derives from adherence otherwise', () async {
    final today = DateTime(2026, 6, 13);
    await KetchupStore.update(today, picked: 5, trackable: 6, driftLog: const []);
    await AdherenceStore.writeAdherence(today.subtract(const Duration(days: 1)), 2, 4);
    final jars = await KetchupStore.last7(today);
    expect(jars.length, 7);
    expect(jars.last!.picked, 5);          // stored (today)
    expect(jars[5]!.picked, 2);            // derived (yesterday)
    expect(jars[5]!.latePicks, 0);
    expect(jars.first, isNull);            // no data
  });
}
