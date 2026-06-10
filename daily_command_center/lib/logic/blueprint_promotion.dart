import '../data/models.dart';

/// The first *blueprint write* in the app: turns a repeated custom task into a
/// permanent [RoutineItem] in one or more day templates. Pure — returns a new
/// [Plan]; the caller persists it via `AppStore.savePlan`.
class BlueprintPromotion {
  static Plan promote(
    Plan plan, {
    required String label,
    required String time,
    required int durationMinutes,
    required List<String> templateIds,
  }) {
    final item = RoutineItem(
      id: 'custom_${_slug(label)}',
      kind: 'goal', // user-promoted tasks render as goals; tunable in Adjust mode
      label: label,
      start: time,
      idealDuration: durationMinutes,
      minDuration: (durationMinutes * 0.6).round(),
      priority: 4, // normal band
    );

    final templates = {...plan.dayTemplates};
    for (final id in templateIds) {
      final t = templates[id];
      if (t == null) continue; // unknown id — skip silently
      templates[id] = t.copyWith(routineStack: [...t.routineStack, item]);
    }
    return plan.copyWith(dayTemplates: templates);
  }

  /// "Evening  Walk!" -> "evening_walk": lowercase, non-alphanumerics to
  /// underscores, collapse/trim repeats.
  static String _slug(String label) => label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
