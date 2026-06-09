import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/avatar_menu_sheet.dart';

void main() {
  testWidgets('lists rare actions and fires the chosen callback', (tester) async {
    var openedSettings = false;
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: Builder(builder: (ctx) =>
      ElevatedButton(onPressed: () => showAvatarMenu(ctx, name: 'Cyrus', subtitle: 'cyrus_recomp',
        onSwitchProfile: () {}, onOpenSettings: () => openedSettings = true, onOpenGlossary: () {}, onLogout: () {}),
        child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Settings & appearance'), findsOneWidget);
    await tester.tap(find.text('Settings & appearance'));
    await tester.pumpAndSettle();
    expect(openedSettings, true);
  });
}
