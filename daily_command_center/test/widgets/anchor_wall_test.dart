import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/anchor_wall.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

void main() {
  testWidgets('hard anchor shows lock + label', (tester) async {
    final b = Block(time: '2:00', cls: 'work', label: 'Work — 2:00 to 8:00', id: 'work', isAnchor: true, hardAnchor: true);
    await tester.pumpWidget(_wrap(AnchorWall(block: b, timeText: '2:00–8:00')));
    expect(find.textContaining('ANCHOR'), findsOneWidget);
    expect(find.textContaining('Work — 2:00 to 8:00'), findsOneWidget);
  });

  testWidgets('soft ceiling shows AIM', (tester) async {
    final b = Block(time: '11:15', cls: 'chill', label: 'Sleep target', id: 'sleep', isAnchor: true, hardAnchor: false);
    await tester.pumpWidget(_wrap(AnchorWall(block: b, timeText: '11:15')));
    expect(find.textContaining('AIM'), findsOneWidget);
  });
}
