import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/jar_shelf.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppPalette.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  // 7 entries oldest -> newest, one null (no data that day).
  final jars = <DayKetchup?>[
    const DayKetchup(date: '2026-06-08', picked: 3, trackable: 3, squeezes: 0, drops: 0, latePicks: 0),
    const DayKetchup(date: '2026-06-09', picked: 2, trackable: 3, squeezes: 1, drops: 0, latePicks: 0),
    null,
    const DayKetchup(date: '2026-06-11', picked: 1, trackable: 3, squeezes: 2, drops: 1, latePicks: 0),
    const DayKetchup(date: '2026-06-12', picked: 3, trackable: 3, squeezes: 0, drops: 0, latePicks: 1),
    const DayKetchup(date: '2026-06-13', picked: 0, trackable: 0, squeezes: 0, drops: 0, latePicks: 0),
    const DayKetchup(date: '2026-06-14', picked: 2, trackable: 2, squeezes: 0, drops: 0, latePicks: 0),
  ];

  testWidgets('mini variant renders all 7 jars without day initials', (t) async {
    await t.pumpWidget(_host(JarShelf(jars: jars, mini: true)));
    final shelf = find.byType(JarShelf);
    expect(find.descendant(of: shelf, matching: find.byType(CustomPaint)),
        findsNWidgets(7));
    expect(find.descendant(of: shelf, matching: find.byType(Text)), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('full variant renders day initials only for non-null jars', (t) async {
    await t.pumpWidget(_host(JarShelf(jars: jars)));
    final shelf = find.byType(JarShelf);
    expect(find.descendant(of: shelf, matching: find.byType(CustomPaint)),
        findsNWidgets(7));
    // 6 non-null entries -> 6 initial labels; the null jar has none.
    expect(find.descendant(of: shelf, matching: find.byType(Text)), findsNWidgets(6));
    expect(t.takeException(), isNull);
  });

  testWidgets('survives 1.3 text scale', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppPalette.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(body: JarShelf(jars: jars)),
      ),
    ));
    expect(t.takeException(), isNull);
  });
}
