import '../data/models.dart';

/// Referential-integrity checks for a Plan. Returns a list of human-readable
/// problems (empty == valid). Reused as the AI-output checker (sub-project 4).
class PlanValidator {
  static List<String> validate(Plan plan) {
    final errors = <String>[];
    final templateIds = plan.dayTemplates.keys.toSet();
    final workoutIds = plan.workouts.keys.toSet();
    final goalIds = plan.goals.map((g) => g.id).toSet();

    plan.week.forEach((day, entry) {
      if (!templateIds.contains(entry.templateId)) {
        errors.add('week[$day].templateId "${entry.templateId}" is not a known template');
      }
      if (entry.workoutId != null && !workoutIds.contains(entry.workoutId)) {
        errors.add('week[$day].workoutId "${entry.workoutId}" is not a known workout');
      }
    });

    for (final id in plan.training.rotation) {
      if (!workoutIds.contains(id)) errors.add('training.rotation has unknown workout "$id"');
    }

    plan.dayTemplates.forEach((tid, tmpl) {
      final ids = <String>{};
      for (final a in tmpl.anchors) {
        if (!ids.add(a.id)) errors.add('template "$tid" has duplicate id "${a.id}"');
      }
      for (final item in tmpl.routineStack) {
        if (!ids.add(item.id)) errors.add('template "$tid" has duplicate id "${item.id}"');
        if (item.workoutId != null && !workoutIds.contains(item.workoutId)) {
          errors.add('template "$tid" item "${item.id}" workoutId "${item.workoutId}" unknown');
        }
        if (item.goalId != null && !goalIds.contains(item.goalId)) {
          errors.add('template "$tid" item "${item.id}" goalId "${item.goalId}" unknown');
        }
      }
    });

    return errors;
  }
}
