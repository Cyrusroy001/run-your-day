import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/day_arc.dart';
import 'package:daily_command_center/logic/sun_clock.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/sun_arc_card.dart';

void main() {
  final blocks = [
    const Block(time: '8:00 AM', cls: 'train', label: 'Gym', estStart: 8, durationMinutes: 60),
    const Block(time: '11:30 AM', cls: 'meal', label: 'Brunch', estStart: 11.5, durationMinutes: 30),
  ];

  testWidgets('renders a CustomPaint arc and survives 1.3 text scale', (t) async {
    final arc = DayArc.from(blocks, now: 10, done: {});
    const blend = SkyBlend(SkyPhase.day, SkyPhase.day, 0);

    await t.pumpWidget(MaterialApp(
      theme: AppPalette.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(body: SunArcCard(arc: arc, blend: blend)),
      ),
    ));

    expect(find.byType(CustomPaint), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
