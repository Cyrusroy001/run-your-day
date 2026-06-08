import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/logic/assembler.dart';
import 'package:daily_command_center/widgets/now_card.dart';

late Plan _plan;
late Directory _tmp;

Widget _host({
  required Set<String> done,
  required double now,
  void Function(String)? onToggle,
  VoidCallback? onViewAll,
}) =>
    MaterialApp(home: Scaffold(body: NowCard(
      plan: _plan,
      todayKey: 'mon',
      doneToday: done,
      debugNow: now,
      onViewAll: onViewAll ?? () {},
      onToggleDone: onToggle ?? (_) {},
    )));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    _plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _tmp = Directory.systemTemp.createTempSync('now_card_test');
    AppStore.repo = ProfileRepository(baseDir: _tmp);
  });
  tearDown(() => _tmp.deleteSync(recursive: true));

  // 10:30 falls inside mon's 10:00 training block (trackable).
  testWidgets('shows Mark done for a trackable current block', (tester) async {
    await tester.pumpWidget(_host(done: const {}, now: 10.5));
    expect(find.text('◯ Mark done'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('done current block shows green Done + badge', (tester) async {
    final entry = _plan.week['mon']!;
    final train = TimelineAssembler.assembleDay(_plan, entry.templateId, 'mon', training: entry.training)
        .firstWhere((b) => b.isTrain);
    await tester.pumpWidget(_host(done: {train.signature}, now: 10.5));
    expect(find.text('✓ Done'), findsOneWidget);
    expect(find.text('✓ done'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping Mark done reports the current block signature', (tester) async {
    final entry = _plan.week['mon']!;
    final train = TimelineAssembler.assembleDay(_plan, entry.templateId, 'mon', training: entry.training)
        .firstWhere((b) => b.isTrain);
    String? toggled;
    await tester.pumpWidget(_host(done: const {}, now: 10.5, onToggle: (s) => toggled = s));
    await tester.tap(find.text('◯ Mark done'));
    await tester.pump();
    expect(toggled, train.signature);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('passive current block hides Mark done', (tester) async {
    // 14.5 = 2:30pm = "Work — 2:00 to 8:00" (cls work, passive)
    await tester.pumpWidget(_host(done: const {}, now: 14.5));
    expect(find.text('◯ Mark done'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('View all is always present and reports taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(done: const {}, now: 14.5, onViewAll: () => tapped = true));
    await tester.tap(find.text('View all ›'));
    await tester.pump();
    expect(tapped, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
