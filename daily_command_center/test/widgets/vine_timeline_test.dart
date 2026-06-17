import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/ripeness.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/vine_timeline.dart';

/// Holds the unfurl state so the basket toggle can be exercised.
class _Harness extends StatefulWidget {
  final List<VineStop> future;
  final VineStop? now;
  final List<VineStop> past;
  final int pickedCount, jammyCount;
  const _Harness({
    required this.future, required this.now, required this.past,
    required this.pickedCount, required this.jammyCount,
  });
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _unfurled = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: AppPalette.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: VineTimeline(
              future: widget.future, now: widget.now, past: widget.past,
              pickedCount: widget.pickedCount, jammyCount: widget.jammyCount,
              tension: 0.0, unfurled: _unfurled,
              onToggleUnfurl: () => setState(() => _unfurled = !_unfurled),
            ),
          ),
        ),
      );
}

void main() {
  testWidgets('vine: basket counts, hero sizing, climb order, unfurl + late pick', (tester) async {
    var pickedLate = 0;
    final future = const [
      VineStop(time: '2:00', label: 'later', ripeness: Ripeness.unripe),
      VineStop(time: '1:00', label: 'next', ripeness: Ripeness.nearly),
    ];
    const now = VineStop(time: '12:00', label: 'now', ripeness: Ripeness.ripe);
    final past = [
      const VineStop(time: '9:00', label: 'picked', ripeness: Ripeness.picked),
      VineStop(time: '10:00', label: 'missed', ripeness: Ripeness.overripe,
          onPick: () => pickedLate++),
    ];

    await tester.pumpWidget(_Harness(
        future: future, now: now, past: past, pickedCount: 1, jammyCount: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // settle entry motion

    // Basket folds the morning beneath a count.
    expect(find.textContaining('1 picked · 1 jammy'), findsOneWidget);

    // Walked fruit are hidden until the basket is opened.
    expect(find.text('picked'), findsNothing);
    expect(find.text('missed'), findsNothing);

    // NOW is enlarged relative to an ordinary future stop.
    final nowSize = tester.widget<Text>(find.text('now')).style!.fontSize!;
    final nextSize = tester.widget<Text>(find.text('next')).style!.fontSize!;
    expect(nowSize, greaterThan(nextSize));

    // The vine climbs upward: later (top) → next → now (just above the basket).
    final laterY = tester.getCenter(find.text('later')).dy;
    final nextY = tester.getCenter(find.text('next')).dy;
    final nowY = tester.getCenter(find.text('now')).dy;
    expect(laterY, lessThan(nextY));
    expect(nextY, lessThan(nowY));

    // Open the basket → walked fruit appear; the jammy one offers a late pick.
    await tester.tap(find.byKey(const Key('vine-basket')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('picked'), findsOneWidget);
    expect(find.text('missed'), findsOneWidget);
    expect(find.text('pick late?'), findsOneWidget);

    await tester.tap(find.text('pick late?'));
    await tester.pump();
    expect(pickedLate, 1);
  });
}
