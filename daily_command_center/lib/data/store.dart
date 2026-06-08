import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import '../logic/planner.dart';
import '../logic/timeline.dart';

class AppStore {
  static const _planKey = 'weekPlan';
  static const _logPrefix = 'log_';

  static Future<WeekPlan> loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_planKey);
    if (raw == null) return PlannerLogic.defaultWeek();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, DayPlan.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return PlannerLogic.defaultWeek();
    }
  }

  static Future<void> savePlan(WeekPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _planKey,
      jsonEncode(plan.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  static Future<List<WorkoutLog>> loadLogs(String workoutKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_logPrefix$workoutKey');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLogs(String workoutKey, List<WorkoutLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_logPrefix$workoutKey',
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  // Compute now-state from the current plan and write to SharedPreferences
  // so the Android home screen widget can read it.
  // Keys are stored with "flutter." prefix by the home_widget package.
  static Future<void> writeWidgetData(WeekPlan plan, String todayKey) async {
    const dayNames = {
      'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
      'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
    };

    final dayPlan = plan[todayKey];
    if (dayPlan == null) return;

    final blocks = buildTimeline(todayKey, dayPlan);
    final times = buildTimes(blocks);
    final now = nowDecimal();

    String currentAction = 'Wind down';
    String nextAction = '';
    int progressPct = 0;

    if (now < times.first) {
      currentAction = 'Still resting';
      nextAction = 'Next · ${blocks.first.time} — ${blocks.first.label}';
    } else {
      for (int i = 0; i < blocks.length; i++) {
        final start = times[i];
        final end = i < blocks.length - 1 ? times[i + 1] : 25.0;
        if (now >= start && now < end) {
          currentAction = blocks[i].label;
          if (i < blocks.length - 1) {
            nextAction = 'Next · ${blocks[i + 1].time} — ${blocks[i + 1].label}';
          }
          progressPct = ((now - start) / (end - start) * 100).round().clamp(0, 100);
          break;
        }
      }
    }

    try {
      await HomeWidget.saveWidgetData<String>('currentAction', currentAction);
      await HomeWidget.saveWidgetData<String>('nextAction', nextAction);
      await HomeWidget.saveWidgetData<String>('dayLabel', dayNames[todayKey] ?? todayKey);
      await HomeWidget.saveWidgetData<int>('progressPct', progressPct);
      await HomeWidget.updateWidget(androidName: 'NowWidgetProvider');
    } catch (_) {
      // Widget not on home screen or platform error — safe to ignore
    }
  }

  // Load the plan, work out today's key, and push now-state to the widget.
  // Shared by the foreground screens and the background WorkManager task so
  // the day-key logic lives in one place.
  static Future<void> refreshWidgetData() async {
    const days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    final plan = await loadPlan();
    final todayKey = days[DateTime.now().weekday % 7];
    await writeWidgetData(plan, todayKey);
  }
}
