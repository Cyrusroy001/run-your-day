import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One day's adherence for the 7-day strip. `pct` is null when no record exists.
class DayAdherence {
  final DateTime day;
  final double? pct;
  const DayAdherence(this.day, this.pct);
}

/// Per-day done-set and adherence summary, persisted in shared_preferences.
/// Keys: `done_<yyyy-MM-dd>` (list of block signatures),
///       `adherence_<yyyy-MM-dd>` ({done, total}).
class AdherenceStore {
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  static String _doneKey(DateTime d) => 'done_${_fmt.format(d)}';
  static String _adhKey(DateTime d) => 'adherence_${_fmt.format(d)}';

  static Future<Set<String>> loadDone(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_doneKey(day));
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => e as String).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> saveDone(DateTime day, Set<String> done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_doneKey(day), jsonEncode(done.toList()));
  }

  static Future<void> writeAdherence(DateTime day, int done, int total) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adhKey(day), jsonEncode({'done': done, 'total': total}));
  }

  /// Last 7 days, oldest first, ending today. `pct` null where no record.
  static Future<List<DayAdherence>> last7(DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    final base = DateTime(today.year, today.month, today.day);
    final out = <DayAdherence>[];
    for (int i = 6; i >= 0; i--) {
      final day = base.subtract(Duration(days: i));
      final raw = prefs.getString(_adhKey(day));
      double? pct;
      if (raw != null) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final total = (m['total'] as num).toInt();
          final done = (m['done'] as num).toInt();
          pct = total > 0 ? done / total * 100 : null;
        } catch (_) {
          pct = null;
        }
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
