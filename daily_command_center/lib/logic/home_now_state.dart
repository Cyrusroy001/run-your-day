import '../data/models.dart';
import 'drift_engine.dart';
import 'drift_copy.dart';

class HomeNowState {
  final bool isResting;
  final bool isDayDone;
  final String currentLabel;
  final String? currentSignature; // null when resting or day done
  final int minutesLeft;
  final int budgetMinutes;
  final double progress; // 0..1
  final String nextLabel;
  final String nextTime;
  final String? whisper;

  const HomeNowState({
    required this.isResting, required this.isDayDone, required this.currentLabel,
    this.currentSignature,
    required this.minutesLeft, required this.budgetMinutes, required this.progress,
    required this.nextLabel, required this.nextTime, required this.whisper,
  });

  static String _fmt(double dec) {
    final h = dec.floor();
    final m = ((dec - h) * 60).round();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}';
  }

  /// [done] — signatures already checked off today; these are skipped when
  /// finding the current block so the card advances past completed items.
  static HomeNowState from(ResolvedDay day, {required double now, Set<String> done = const {}}) {
    // Exclude dropped blocks and anchors (anchors aren't trackable tasks).
    final all = day.blocks.where((b) => !b.isDropped && !b.isAnchor).toList();
    final whisper = DriftCopy.whisper(day);
    if (all.isEmpty) {
      return HomeNowState(isResting: true, isDayDone: false, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 0, nextLabel: '', nextTime: '', whisper: whisper);
    }
    if (now < all.first.estStart) {
      return HomeNowState(isResting: true, isDayDone: false, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 0, nextLabel: all.first.label, nextTime: _fmt(all.first.estStart), whisper: whisper);
    }

    // Non-done blocks only — done items are transparent to time-slot logic.
    final live = all.where((b) => !done.contains(b.signature)).toList();
    if (live.isEmpty) {
      return HomeNowState(isResting: false, isDayDone: true, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 1, nextLabel: '', nextTime: '', whisper: whisper);
    }

    // If we've completed some tasks and now is before the next non-done one, show resting.
    if (now < live.first.estStart) {
      return HomeNowState(isResting: true, isDayDone: false, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 0, nextLabel: live.first.label, nextTime: _fmt(live.first.estStart), whisper: whisper);
    }

    // Containment search among non-done blocks: find the block whose time slot contains now.
    int curIdx = -1;
    for (int i = 0; i < live.length; i++) {
      final start = live[i].estStart;
      final containEnd = i < live.length - 1 ? live[i + 1].estStart : start + live[i].durationMinutes / 60.0;
      if (now >= start && now < containEnd) {
        curIdx = i;
        break;
      }
    }

    if (curIdx == -1) {
      // now is past all non-done blocks — day is done.
      return HomeNowState(isResting: false, isDayDone: true, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 1, nextLabel: '', nextTime: '', whisper: whisper);
    }

    final b = live[curIdx];
    final span = b.durationMinutes / 60.0;
    final blockEnd = b.estStart + span;
    final left = ((blockEnd - now) * 60).round().clamp(0, 100000);
    final nextIdx = curIdx + 1;
    return HomeNowState(
      isResting: false, isDayDone: false,
      currentLabel: b.label, currentSignature: b.signature,
      minutesLeft: left, budgetMinutes: b.durationMinutes,
      progress: span <= 0 ? 1.0 : ((now - b.estStart) / span).clamp(0.0, 1.0),
      nextLabel: nextIdx < live.length ? live[nextIdx].label : '',
      nextTime: nextIdx < live.length ? _fmt(live[nextIdx].estStart) : '',
      whisper: whisper,
    );
  }
}
