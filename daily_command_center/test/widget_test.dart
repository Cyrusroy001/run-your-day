import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyCommandCenterApp());
    expect(find.byType(DailyCommandCenterApp), findsOneWidget);
  });
}
