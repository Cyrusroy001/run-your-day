import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/main.dart';

void main() {
  testWidgets('app launcher title is "Reminders 2"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DailyCommandCenterApp());
    await tester.pumpAndSettle(); // let async plan-load finish while mounted
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Reminders 2');
    await tester.pumpWidget(const SizedBox()); // dispose NowCard's periodic timer
  });
}
