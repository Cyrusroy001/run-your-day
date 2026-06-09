import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Guard: no Plan block label should appear as a hardcoded string literal in lib/.
///
/// All user-visible routine block names must come from Plan.label at runtime so
/// that swapping the seed plan (or running a different profile) changes what the
/// UI shows without touching Dart source.
void main() {
  test('lib/ contains no hardcoded Plan block labels', () {
    final planJson = File('assets/seed_plan.json').readAsStringSync();
    final plan = jsonDecode(planJson) as Map<String, dynamic>;

    final labels = <String>{};
    final templates = plan['dayTemplates'] as Map<String, dynamic>;
    for (final template in templates.values) {
      for (final key in ['routineStack', 'anchors']) {
        for (final block in (template[key] as List? ?? [])) {
          final label = (block as Map<String, dynamic>)['label'] as String?;
          if (label != null && label.isNotEmpty) labels.add(label);
        }
      }
    }

    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final label in labels) {
        if (content.contains("'$label'") || content.contains('"$label"')) {
          violations.add('${entity.path}: hardcoded "$label"');
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'Labels must come from Plan at runtime, not be hardcoded:\n'
            '${violations.join('\n')}');
  });
}
