import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/notifications.dart';
import '../data/state_store.dart';
import 'drift_engine.dart';

typedef Notifier = Future<void> Function(String title, String body);

/// Thin coordinator: runs the pure engine, then fires a notification and
/// persists new `killed` events exactly once (idempotent on repeat ticks).
class DriftRunner {
  final Notifier notify;

  DriftRunner({Notifier? notify}) : notify = notify ?? NotificationService.fireBreach;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  Future<ResolvedDay> run(
    List<Block> blocks, {
    required double now,
    required Set<String> done,
    required DateTime day,
  }) async {
    final dateIso = _fmt.format(day);
    final result = DriftEngine.computeDay(blocks, now: now, done: done, dateIso: dateIso);

    final state = await StateStore.loadState(day);
    final alreadyKilled = state.driftLog
        .where((e) => e.event == 'killed')
        .map((e) => e.itemId)
        .toSet();

    final newKills = result.events
        .where((e) => e.event == 'killed' && !alreadyKilled.contains(e.itemId))
        .toList();

    if (newKills.isNotEmpty) {
      var updated = state;
      for (final k in newKills) {
        updated = updated.copyWith(driftLog: [...updated.driftLog, k]);
        await notify(
          '${k.label} cancelled today',
          'Drifted ${k.driftMinutes ?? '?'} min past plan. Protecting your evening.',
        );
      }
      await StateStore.saveState(updated);
    }

    return result;
  }
}
