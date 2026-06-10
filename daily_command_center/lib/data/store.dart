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
    int minutesLeft = 0;
    int budgetMinutes = 0;

    if (now < times.first) {
      currentAction = 'Still resting';
      nextAction = 'Up next · ${blocks.first.time} ${blocks.first.label}';
    } else {
      for (int i = 0; i < blocks.length; i++) {
        final start = times[i];
        final blockDur = blocks[i].durationMinutes / 60.0;
        final blockEnd = start + blockDur;
        final displayEnd = i < blocks.length - 1 ? times[i + 1] : blockEnd;
        if (now >= start && now < displayEnd) {
          currentAction = blocks[i].label;
          budgetMinutes = blocks[i].durationMinutes;
          minutesLeft = ((blockEnd - now) * 60).round().clamp(0, 9999);
          progressPct = blockDur <= 0 ? 100 : ((now - start) / blockDur * 100).round().clamp(0, 100);
          if (i < blocks.length - 1) {
            nextAction = 'Up next · ${blocks[i + 1].time} ${blocks[i + 1].label}';
          }
          break;
        }
      }
    }

    // Load adherence count for the done strip.
    int doneCount = 0;
    int totalCount = 0;
    try {
      final doc = await repo.loadActive();
      final key = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final adh = doc.adherence[key];
      if (adh != null) {
        doneCount = adh['done'] ?? 0;
        totalCount = adh['total'] ?? 0;
      }
    } catch (_) {}

    try {
      await HomeWidget.saveWidgetData<String>('currentAction', currentAction);
      await HomeWidget.saveWidgetData<String>('nextAction', nextAction);
      await HomeWidget.saveWidgetData<String>('dayLabel', dayNames[todayKey] ?? todayKey);
      await HomeWidget.saveWidgetData<int>('progressPct', progressPct);
      await HomeWidget.saveWidgetData<int>('minutesLeft', minutesLeft);
      await HomeWidget.saveWidgetData<int>('budgetMinutes', budgetMinutes);
      await HomeWidget.saveWidgetData<int>('doneCount', doneCount);
      await HomeWidget.saveWidgetData<int>('totalCount', totalCount);
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
