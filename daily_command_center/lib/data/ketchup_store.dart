import 'package:intl/intl.dart';
import 'models.dart';
import 'store.dart';

/// Per-day pantry records inside the active ProfileDoc (file-per-profile —
/// no stores outside ProfileRepository). Quantity/quality derive from
/// adherence + the drift log; latePicks is the only field captured live.
class KetchupStore {
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  /// Re-derive + persist [day]'s record. [latePickDelta] adjusts the stored
  /// late-pick count (+1 picking a past block, −1 un-picking one).
  static Future<DayKetchup> update(DateTime day,
      {required int picked, required int trackable,
      required List<DriftEvent> driftLog, int latePickDelta = 0}) async {
    final key = _fmt.format(day);
    final doc = await AppStore.repo.loadActive();
    final prevLate = doc.ketchup[key]?.latePicks ?? 0;
    final rec = DayKetchup(
      date: key, picked: picked, trackable: trackable,
      squeezes: driftLog.where((e) => e.event == 'compacted').length,
      drops: driftLog
          .where((e) => e.event == 'killed' || e.event == 'jettisoned')
          .length,
      latePicks: (prevLate + latePickDelta).clamp(0, 999),
    );
    await AppStore.repo.save(doc.copyWith(ketchup: {...doc.ketchup, key: rec}));
    return rec;
  }

  /// Last 7 days oldest→newest. A stored record wins; days without one derive
  /// from adherence + drift log (latePicks unknown → 0); null = no data.
  static Future<List<DayKetchup?>> last7(DateTime today) async {
    final doc = await AppStore.repo.loadActive();
    final base = DateTime(today.year, today.month, today.day);
    final out = <DayKetchup?>[];
    for (int i = 6; i >= 0; i--) {
      final key = _fmt.format(base.subtract(Duration(days: i)));
      final stored = doc.ketchup[key];
      if (stored != null) {
        out.add(stored);
        continue;
      }
      final adh = doc.adherence[key];
      if (adh == null) {
        out.add(null);
        continue;
      }
      final log = doc.states[key]?.driftLog ?? const <DriftEvent>[];
      out.add(DayKetchup(
        date: key, picked: adh['done'] ?? 0, trackable: adh['total'] ?? 0,
        squeezes: log.where((e) => e.event == 'compacted').length,
        drops: log
            .where((e) => e.event == 'killed' || e.event == 'jettisoned')
            .length,
        latePicks: 0,
      ));
    }
    return out;
  }
}
