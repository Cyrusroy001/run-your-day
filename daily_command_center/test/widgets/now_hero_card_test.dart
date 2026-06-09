import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/home_now_state.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/now_hero_card.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

void main() {
  testWidgets('shows current + whisper when drifting', (tester) async {
    const s = HomeNowState(isResting: false, isDayDone: false, currentLabel: 'Shower + brunch',
        minutesLeft: 22, budgetMinutes: 30, progress: .3, nextLabel: 'Walk to office', nextTime: '1:50',
        whisper: 'Running ~25m behind · trimmed Brunch to hold Work.');
    await tester.pumpWidget(_wrap(const NowHeroCard(state: s, onOpen: _noop)));
    expect(find.text('Shower + brunch'), findsOneWidget);
    expect(find.textContaining('Running ~25m behind'), findsOneWidget);
  });

  testWidgets('no whisper when on track', (tester) async {
    const s = HomeNowState(isResting: false, isDayDone: false, currentLabel: 'Deep Focus',
        minutesLeft: 41, budgetMinutes: 75, progress: .45, nextLabel: 'Brunch', nextTime: '11:00', whisper: null);
    await tester.pumpWidget(_wrap(const NowHeroCard(state: s, onOpen: _noop)));
    expect(find.textContaining('behind'), findsNothing);
  });
}

void _noop() {}
