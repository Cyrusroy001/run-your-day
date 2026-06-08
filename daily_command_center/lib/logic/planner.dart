import 'dart:math';
import '../data/models.dart';

class PlannerLogic {
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static bool _isWeekend(String templateId) => templateId.startsWith('weekend');

  // Optimal 4 training days with no two consecutive (maximise min gap).
  static List<String> _bestTrainingDays() {
    double bestScore = -1;
    List<int> bestSubset = [0, 2, 4, 6];
    for (int a = 0; a < 4; a++) {
      for (int b = a + 1; b < 5; b++) {
        for (int c = b + 1; c < 6; c++) {
          for (int d = c + 1; d < 7; d++) {
            final gaps = [b - a, c - b, d - c];
            final minGap = gaps.reduce(min);
            if (minGap < 2) continue;
            final avgGap = gaps.reduce((x, y) => x + y) / 3;
            final score = minGap + 0.1 * avgGap;
            if (score > bestScore) {
              bestScore = score;
              bestSubset = [a, b, c, d];
            }
          }
        }
      }
    }
    return bestSubset.map((i) => _days[i]).toList();
  }

  static double _spacingScore(List<String> trainingDays) {
    if (trainingDays.length < 2) return 0;
    final indices = trainingDays.map((d) => _days.indexOf(d)).toList()..sort();
    final gaps = <int>[];
    for (int i = 1; i < indices.length; i++) {
      gaps.add(indices[i] - indices[i - 1]);
    }
    final minGap = gaps.reduce(min);
    if (minGap < 2) return -1.0;
    return minGap + 0.1 * (gaps.reduce((a, b) => a + b) / gaps.length);
  }

  /// Reapply optimal 4-day spacing to [plan], leaving templateIds unchanged.
  static Plan applyBestSpacing(Plan plan) {
    final training = _bestTrainingDays();
    final newWeek = Map.fromEntries(_days.map((d) {
      final entry = plan.week[d]!;
      return MapEntry(d, entry.copyWith(training: training.contains(d)));
    }));
    return plan.copyWith(week: newWeek);
  }

  static ({Plan plan, String? message}) toggleTraining(Plan plan, String day) {
    final entry = plan.week[day]!;

    if (entry.training) {
      return (plan: plan.copyWith(week: {...plan.week, day: entry.copyWith(training: false)}), message: null);
    }

    final updated = {...plan.week, day: entry.copyWith(training: true)};
    final trainingDays = _days.where((d) => updated[d]!.training).toList();

    if (trainingDays.length <= 4) {
      return (plan: plan.copyWith(week: updated), message: null);
    }

    String? removed;
    Map<String, WeekEntry>? bestWeek;
    double bestScore = -2;

    for (final candidate in trainingDays) {
      if (candidate == day) continue;
      final trial = {...updated, candidate: updated[candidate]!.copyWith(training: false)};
      final score = _spacingScore(_days.where((d) => trial[d]!.training).toList());
      if (score > bestScore) {
        bestScore = score;
        bestWeek = trial;
        removed = candidate;
      }
    }

    final finalWeek = bestWeek ?? updated;
    return (
      plan: plan.copyWith(week: finalWeek),
      message: removed != null ? 'Moved training from ${_capitalize(removed)} for better spacing' : null,
    );
  }

  static Plan toggleSchedule(Plan plan, String day) {
    final entry = plan.week[day]!;
    if (_isWeekend(entry.templateId)) return plan; // weekend days locked
    final newTemplateId = entry.templateId == 'office' ? 'wfh' : 'office';
    return plan.copyWith(week: {...plan.week, day: entry.copyWith(templateId: newTemplateId)});
  }

  static String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
