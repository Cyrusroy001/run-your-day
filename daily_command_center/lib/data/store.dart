import 'package:home_widget/home_widget.dart';
import 'models.dart';
import 'profile_repository.dart';
import '../logic/assembler.dart';
import '../logic/timeline.dart';

/// Plan + logs access for the active profile. Thin facade over
/// [ProfileRepository] (file-per-profile). Swap [repo] in tests.
class AppStore {
  static ProfileRepository repo = ProfileRepository();

  static Future<Plan> loadPlan() async => (await repo.loadActive()).plan;

  static Future<void> savePlan(Plan plan) async {
    final doc = await repo.loadActive();
    await repo.save(doc.copyWith(plan: plan));
  }

  static Future<List<WorkoutLog>> loadLogs(String workoutKey) async =>
      (await repo.loadActive()).logs[workoutKey] ?? const [];

  static Future<void> saveLogs(String workoutKey, List<WorkoutLog> logs) async {
    final doc = await repo.loadActive();
    await repo.save(doc.copyWith(logs: {...doc.logs, workoutKey: logs}));
  }

  // Compute now-state from the Plan and push to the home-screen widget.
  static Future<void> writeWidgetData(Plan plan, String todayKey) async {
    const dayNames = {
      'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
      'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
    };
    final entry = plan.week[todayKey];
    if (entry == null) return;
    final blocks = TimelineAssembler.assembleDay(
      plan, entry.templateId, todayKey, training: entry.training,
    );
    if (blocks.isEmpty) return;
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
  // Shared by the foreground screens and the background WorkManager task.
  static Future<void> refreshWidgetData() async {
    const days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    final plan = await loadPlan();
    final todayKey = days[DateTime.now().weekday % 7];
    await writeWidgetData(plan, todayKey);
  }
}
