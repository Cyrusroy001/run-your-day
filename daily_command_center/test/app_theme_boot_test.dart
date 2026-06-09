import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/main.dart';
import 'package:daily_command_center/theme/app_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and exposes light + dark themes', (tester) async {
    SharedPreferences.setMockInitialValues({'ui_themeMode': 'light'});
    await tester.pumpWidget(const RemindersApp());
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.extension<AppPalette>(), isNotNull);
    expect(app.darkTheme!.extension<AppPalette>(), isNotNull);
  });
}
