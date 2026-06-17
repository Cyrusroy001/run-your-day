import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Ketchup guard tests (spec §5):
///  1. No raw Color literal outside app_palette.dart — all color comes from the
///     AppPalette ThemeExtension so themes can be swapped/retuned centrally.
///  2. No banned ban-list jargon in on-screen text (lib/screens + lib/widgets):
///     "⚠", "Reflowed", "budget", "engine". These are checked inside string
///     literals only — the data/logic layers legitimately use identifiers like
///     `budgetMinutes` and `DriftEngine`; the ban is about what reaches the user.
void main() {
  test('no Color(0x…) literal outside app_palette.dart', () {
    final colorLiteral = RegExp(r'Color\(0x');
    final violations = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (e.path.replaceAll(r'\', '/').endsWith('theme/app_palette.dart')) continue;
      final lines = e.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (colorLiteral.hasMatch(lines[i])) violations.add('${e.path}:${i + 1}  ${lines[i].trim()}');
      }
    }
    expect(violations, isEmpty,
        reason: 'Use a context.c token, not a hardcoded Color:\n${violations.join('\n')}');
  });

  test('no banned jargon on code lines in the UI layer', () {
    // ⚠ and Reflowed are never legitimate; budget/engine are banned as display
    // words (word-boundaried, case-sensitive so DriftEngine/budgetMinutes pass).
    // Comments and import directives are skipped — the ban is about what reaches
    // the screen, not documentation referencing the engine or the old budget_bar.
    final banned = RegExp(r'⚠|Reflowed|\bbudget\b|\bengine\b');
    final violations = <String>[];
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final e in Directory(dir).listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final lines = e.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final t = lines[i].trimLeft();
          if (t.startsWith('//') || t.startsWith('*') || t.startsWith('/*')) continue;
          if (t.startsWith('import ') || t.startsWith('export ') || t.startsWith('part ')) continue;
          final code = lines[i].split('//').first; // drop any trailing line comment
          if (banned.hasMatch(code)) violations.add('${e.path}:${i + 1}  ${code.trim()}');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'Ban-list jargon must not reach the screen:\n${violations.join('\n')}');
  });

  test('no lifestyle constants in UI string literals (ADR-022 §8 generality)', () {
    // Template names, schedule words, and goal vocabulary are Life-JSON data.
    // The garden skin may only use universal words (pick, jammy, cage, vine).
    // Onboarding/login are the deferred interview/AI-stub surfaces (pre-garden):
    // they hardcode the seed archetype during the 3-step stub and are replaced
    // when the real interview lands — out of scope for the moat clause for now.
    const exempt = ['onboarding_screen.dart', 'login_screen.dart'];
    final banned = RegExp(r"'[^']*\b(Office|WFH|Weekend|Training|Workout)\b[^']*'");
    final violations = <String>[];
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final e in Directory(dir).listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (exempt.any((f) => e.path.replaceAll(r'\', '/').endsWith(f))) continue;
        final lines = e.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final t = lines[i].trimLeft();
          if (t.startsWith('//') || t.startsWith('*') || t.startsWith('/*')) continue;
          final code = lines[i].split('//').first;
          if (banned.hasMatch(code)) violations.add('${e.path}:${i + 1}  ${code.trim()}');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'Lifestyle words must come from the Life JSON, not code:\n${violations.join('\n')}');
  });
}
