import 'package:intl/intl.dart';
import 'store.dart';

/// One day's adherence for the 7-day strip. `pct` is null when no record exists.
class DayAdherence {
  final DateTime day;
  final double? pct;
  const DayAdherence(this.day, this.pct);
}

/// Per-day done-set and adherence summary, stored inside the active [ProfileDoc]
/// via [AppStore.repo]. Swap [AppStore.repo] in tests for isolation.
class AdherenceStore {
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  static Future<Set<String>> loadDone(DateTime day) async {
    final key = _fmt.format(day);
    final doc = await AppStore.repo.loadActive();
    return (doc.done[key] ?? const []).toSet();
  }

  static Future<void> saveDone(DateTime day, Set<String> done) async {
    final key = _fmt.format(day);
    final doc = await AppStore.repo.loadActive();
    await AppStore.repo.save(doc.copyWith(done: {...doc.done, key: done.toList()}));
  }

  static Future<void> writeAdherence(DateTime day, int done, int total) async {
    final key = _fmt.format(day);
    final doc = await AppStore.repo.loadActive();
    await AppStore.repo.save(doc.copyWith(
      adherence: {...doc.adherence, key: {'done': done, 'total': total}},
    ));
  }

  /// Last 7 days, oldest first, ending today. `pct` null where no record.
  static Future<List<DayAdherence>> last7(DateTime today) async {
    final doc = await AppStore.repo.loadActive();
    final base = DateTime(today.year, today.month, today.day);
    final out = <DayAdherence>[];
    for (int i = 6; i >= 0; i--) {
      final day = base.subtract(Duration(days: i));
      final key = _fmt.format(day);
      final entry = doc.adherence[key];
      double? pct;
      if (entry != null) {
        final total = entry['total'] ?? 0;
        final done = entry['done'] ?? 0;
        pct = total > 0 ? done / total * 100 : null;
      }
      out.add(DayAdherence(day, pct));
    }
    return out;
  }

  /// Average of the days that have data; null if none do.
  static double? weeklyAverage(List<DayAdherence> days) {
    final vals = days.where((d) => d.pct != null).map((d) => d.pct!).toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}
