import '../data/models.dart';
import 'planner.dart';

/// A generic per-day plan modifier — the schema's 0..N goal tracks rendered as
/// "cages" on the allotment (ADR-022 §8: a heavy-load modifier → a cage; the
/// glyph is universal vocabulary, lifestyle words stay in the data). v3 carries
/// exactly one (TrainingRules), but every surface renders from this list so that
/// 0 goals and N goals both degrade gracefully.
class WeekModifier {
  final String id;
  final String glyph;
  final bool Function(WeekEntry) isOn;
  final ({Plan plan, String? message}) Function(Plan, String day) toggle;
  final String Function(Plan) caption;
  const WeekModifier({required this.id, required this.glyph,
      required this.isOn, required this.toggle, required this.caption});
}

class WeekModifiers {
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static List<WeekModifier> of(Plan plan) {
    if (plan.training.frequencyPerWeek <= 0) return const [];
    return [
      WeekModifier(
        id: 'training',
        glyph: '⌗',
        isOn: (e) => e.training,
        toggle: PlannerLogic.toggleTraining,
        caption: _trainingCaption,
      ),
    ];
  }

  /// Generated from the rule itself (frequencyPerWeek + avoidConsecutive), e.g.
  /// "4 caged · well spaced ✓" / "4 caged · at limit" / "3 caged · 1 to place".
  static String _trainingCaption(Plan plan) {
    final n = plan.week.values.where((e) => e.training).length;
    final target = plan.training.frequencyPerWeek;
    if (n >= target) {
      return _wellSpaced(plan) ? '$n caged · well spaced ✓' : '$n caged · at limit';
    }
    return '$n caged · ${target - n} to place';
  }

  static bool _wellSpaced(Plan plan) {
    if (!plan.training.avoidConsecutive) return true;
    final idx = [
      for (var i = 0; i < _days.length; i++)
        if (plan.week[_days[i]]?.training ?? false) i
    ];
    for (var i = 1; i < idx.length; i++) {
      if (idx[i] - idx[i - 1] < 2) return false;
    }
    return true;
  }
}
