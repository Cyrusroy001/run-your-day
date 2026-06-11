import '../data/models.dart';
import '../data/profile_repository.dart';
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

  /// Persist a brand-new profile from the onboarding choices and make it active.
  /// Builds the plan from [seed] (injected so the caller owns the asset/IO read),
  /// then creates + activates the profile via [repo]. Returns the new id.
  ///
  /// This is the single seam both the production finish flow and tests run, so
  /// they cannot drift apart.
  static Future<String> commit({
    required ProfileRepository repo,
    required Plan seed,
    required String displayName,
    required Map<String, String> weekChoices,
    required int trainingDays,
  }) async {
    final plan = buildPlan(
      seed: seed,
      displayName: displayName,
      weekChoices: weekChoices,
      trainingDays: trainingDays,
    );
    final doc = await repo.createProfile(displayName, plan: plan);
    return doc.id;
  }
}
