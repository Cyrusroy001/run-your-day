import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/teaching_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a concept is unseen until marked, then stays seen', () async {
    expect(await TeachingFlags.seen('compaction'), false);
    await TeachingFlags.markSeen('compaction');
    expect(await TeachingFlags.seen('compaction'), true);
    expect(await TeachingFlags.seen('drop'), false);
  });
}
