import '../data/models.dart';
import 'planner.dart';

class OnboardingLogic {
  /// Build a new profile's plan from the bundled [seed]: apply the chosen
  /// template per day, set a personalized title, then place [trainingDays]
  /// spaced across the week.
  static Plan buildPlan({
    required Plan seed,
    required String displayName,
    required Map<String, String> weekChoices,
    required int trainingDays,
  }) {
    final week = <String, WeekEntry>{};
    seed.week.forEach((day, entry) {
      final templateId = weekChoices[day] ?? entry.templateId;
      week[day] = entry.copyWith(templateId: templateId, training: false);
    });

    final titled = Plan(
      schemaVersion: seed.schemaVersion,
      meta: PlanMeta(
        title: "${displayName.trim()}'s plan",
        timezone: seed.meta.timezone,
        lifestyleArchetype: seed.meta.lifestyleArchetype,
        generatedAt: seed.meta.generatedAt,
        improvementAreas: seed.meta.improvementAreas,
        equipment: seed.meta.equipment,
      ),
      dayTemplates: seed.dayTemplates,
      week: week,
      weekEditor: seed.weekEditor,
      training: seed.training,
      workouts: seed.workouts,
      nutrition: seed.nutrition,
      goals: seed.goals,
    );
    return PlannerLogic.setTrainingFrequency(titled, trainingDays);
  }
}
