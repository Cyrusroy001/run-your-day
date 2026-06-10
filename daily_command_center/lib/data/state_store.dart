import 'package:intl/intl.dart';
import 'models.dart';
import 'store.dart';

/// Thin façade over [ProfileRepository] for daily-state operations.
/// All reads/writes go through [AppStore.repo] so tests can inject a temp dir.
class StateStore {
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  static Future<DailyState> loadState(DateTime day) async {
    final key = _fmt.format(day);
    final doc = await AppStore.repo.loadActive();
    return doc.states[key] ?? DailyState(date: key);
  }

  static Future<void> saveState(DailyState state) async {
    final doc = await AppStore.repo.loadActive();
    await AppStore.repo.save(doc.copyWith(
      states: {...doc.states, state.date: state},
    ));
  }

  static const int _maxPerDay = 50;

  /// Append a single drift event to the day's log, capped at [_maxPerDay].
  static Future<void> appendDriftEvent(DateTime day, DriftEvent event) async {
    final key = _fmt.format(day);
    final doc = await AppStore.repo.loadActive();
    final existing = doc.states[key] ?? DailyState(date: key);
    var log = [...existing.driftLog, event];
    if (log.length > _maxPerDay) log = log.sublist(log.length - _maxPerDay);
    final updated = existing.copyWith(driftLog: log);
    await AppStore.repo.save(doc.copyWith(
      states: {...doc.states, key: updated},
    ));
  }

  /// All drift events across the last [days] days (oldest first).
  static Future<List<DriftEvent>> recentDriftEvents(DateTime today, {int days = 7}) async {
    final doc = await AppStore.repo.loadActive();
    final base = DateTime(today.year, today.month, today.day);
    final out = <DriftEvent>[];
    for (int i = days - 1; i >= 0; i--) {
      final key = _fmt.format(base.subtract(Duration(days: i)));
      final state = doc.states[key];
      if (state != null) out.addAll(state.driftLog);
    }
    return out;
  }

  /// The DailyStates that exist across the last [days] days (oldest first).
  static Future<List<DailyState>> recentStates(DateTime today, {int days = 7}) async {
    final doc = await AppStore.repo.loadActive();
    final base = DateTime(today.year, today.month, today.day);
    final out = <DailyState>[];
    for (int i = days - 1; i >= 0; i--) {
      final key = _fmt.format(base.subtract(Duration(days: i)));
      final state = doc.states[key];
      if (state != null) out.add(state);
    }
    return out;
  }
}
