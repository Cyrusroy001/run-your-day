import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/main.dart';

void main() {
  testWidgets('app launcher title is "Reminders 2"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RemindersApp());
    // Title is on MaterialApp, available on the first frame — no need to wait
    // for the async home load (which shows only a spinner at this point).
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Reminders 2');
    await tester.pumpWidget(const SizedBox()); // dispose; home's mounted-guard handles late load
  });
}
