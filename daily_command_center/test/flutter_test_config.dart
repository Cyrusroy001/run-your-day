import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Auto-loaded by `flutter test` for every test in this package.
///
/// Disables google_fonts runtime fetching so tests never attempt a network
/// call for a font (which hangs the test isolate in the sandbox). Fonts fall
/// back to the platform default — fine for widget tests, which assert on text
/// and layout, not glyph shapes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
