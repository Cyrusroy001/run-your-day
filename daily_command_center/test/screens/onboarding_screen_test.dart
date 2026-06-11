import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/screens/onboarding_screen.dart';
import 'package:daily_command_center/theme/app_palette.dart';

/// Renders the screen and walks the step navigation. The profile-creation path
/// (`_finish` → `OnboardingLogic.commit`) is covered by the logic test in
/// `test/logic/onboarding_test.dart`; doing it here would need `runAsync` for
/// the dart:io save, which surfaces google_fonts' network-fetch future as a
/// test failure. Keeping this test fake-async-only (no `runAsync`) avoids that.
void main() {
  testWidgets('renders the three steps and advances with Next', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppPalette.dark]),
      home: const OnboardingScreen(displayName: 'Alex'),
    ));
    await tester.pumpAndSettle();

    // Step 1 — welcome.
    expect(find.text('Welcome, Alex.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Step 2 — week shape.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your week'), findsOneWidget);

    // Step 3 — training days; primary button flips to Create.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Training days'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });
}
