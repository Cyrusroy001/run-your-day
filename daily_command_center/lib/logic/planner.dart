import 'dart:math';
import '../data/models.dart';

class PlannerLogic {
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _weekendDays = {'sat', 'sun'};

  static WeekPlan defaultWeek() {
    final base = <String, DayPlan>{
      'mon': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'tue': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'wed': const DayPlan(schedule: DaySchedule.wfh,     isTraining: false),
      'thu': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'fri': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'sat': const DayPlan(schedule: DaySchedule.weekend, isTraining: false),
      'sun': const DayPlan(schedule: DaySchedule.weekend, isTraining: false),
    };
    return _applyBestSpacing(base);
  }

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

  static WeekPlan _applyBestSpacing(WeekPlan plan) {
    final training = _bestTrainingDays();
    return Map.fromEntries(_days.map((d) {
      return MapEntry(d, plan[d]!.copyWith(isTraining: training.contains(d)));
    }));
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

  static ({WeekPlan plan, String? message}) toggleTraining(WeekPlan current, String day) {
    final isOn = current[day]!.isTraining;

    if (isOn) {
      final updated = Map<String, DayPlan>.from(current);
      updated[day] = current[day]!.copyWith(isTraining: false);
      return (plan: updated, message: null);
    }

    final updated = Map<String, DayPlan>.from(current);
    updated[day] = current[day]!.copyWith(isTraining: true);
    final trainingDays = _days.where((d) => updated[d]!.isTraining).toList();

    if (trainingDays.length <= 4) {
      return (plan: updated, message: null);
    }

    String? removed;
    WeekPlan? bestPlan;
    double bestScore = -2;

    for (final candidate in trainingDays) {
      if (candidate == day) continue;
      final trial = Map<String, DayPlan>.from(updated);
      trial[candidate] = updated[candidate]!.copyWith(isTraining: false);
      final score = _spacingScore(_days.where((d) => trial[d]!.isTraining).toList());
      if (score > bestScore) {
        bestScore = score;
        bestPlan = trial;
        removed = candidate;
      }
    }

    final finalPlan = bestPlan ?? updated;
    final msg = removed != null
        ? 'Moved training from ${_capitalize(removed)} for better spacing'
        : null;
    return (plan: finalPlan, message: msg);
  }

  static WeekPlan toggleSchedule(WeekPlan current, String day) {
    assert(!_weekendDays.contains(day), 'Cannot toggle schedule for weekend days');
    final p = current[day]!;
    final updated = Map<String, DayPlan>.from(current);
    updated[day] = p.copyWith(
      schedule: p.schedule == DaySchedule.office ? DaySchedule.wfh : DaySchedule.office,
    );
    return updated;
  }

  static String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
