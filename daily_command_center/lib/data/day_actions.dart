import 'adherence_store.dart';
import 'ketchup_store.dart';
import 'models.dart';
import 'store.dart';

/// The one Pick ✓ write path, shared by Today + Timeline: flips the signature
/// in the done-set, persists done + adherence + today's pantry record, and
/// pushes widget data. Returns the new done-set.
class DayActions {
  static Future<Set<String>> togglePick({
    required Block block, // resolved block (engine estStart) — for lateness
    required Set<String> done,
    required List<Block> assembled, // assembler output — for trackable counts
    required List<DriftEvent> driftLog,
    required double now,
    Plan? plan, // null in tests / debug → skip the widget push
    String? todayKey,
  }) async {
    final next = {...done};
    final adding = !next.contains(block.signature);
    adding ? next.add(block.signature) : next.remove(block.signature);
    final day = DateTime.now();
    await AdherenceStore.saveDone(day, next);
    final t = assembled.where((x) => x.isTrackable).toList();
    final picked = t.where((x) => next.contains(x.signature)).length;
    await AdherenceStore.writeAdherence(day, picked, t.length);
    final isLate = block.estStart + block.durationMinutes / 60.0 < now;
    await KetchupStore.update(day,
        picked: picked, trackable: t.length, driftLog: driftLog,
        latePickDelta: isLate ? (adding ? 1 : -1) : 0);
    if (plan != null && todayKey != null) {
      AppStore.writeWidgetData(plan, todayKey).ignore();
    }
    return next;
  }
}
