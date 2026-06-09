import '../data/models.dart';
import 'drift_engine.dart';
import 'drift_copy.dart';

class HomeNowState {
  final bool isResting;
  final bool isDayDone;
  final String currentLabel;
  final int minutesLeft;
  final int budgetMinutes;
  final double progress; // 0..1
  final String nextLabel;
  final String nextTime;
  final String? whisper;

  const HomeNowState({
    required this.isResting, required this.isDayDone, required this.currentLabel,
    required this.minutesLeft, required this.budgetMinutes, required this.progress,
    required this.nextLabel, required this.nextTime, required this.whisper,
  });

  static String _fmt(double dec) {
    final h = dec.floor();
    final m = ((dec - h) * 60).round();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}';
  }

  static HomeNowState from(ResolvedDay day, {required double now}) {
    final live = day.blocks.where((b) => !b.isDropped).toList();
    final whisper = DriftCopy.whisper(day);
    if (live.isEmpty) {
      return HomeNowState(isResting: true, isDayDone: false, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 0, nextLabel: '', nextTime: '', whisper: whisper);
    }
    if (now < live.first.estStart) {
      return HomeNowState(isResting: true, isDayDone: false, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 0, nextLabel: live.first.label, nextTime: _fmt(live.first.estStart), whisper: whisper);
    }
    for (int i = 0; i < live.length; i++) {
      final start = live[i].estStart;
      // Containment uses the next block's start so you stay "in" the current
      // block through any gap before the next one begins.
      final containEnd = i < live.length - 1 ? live[i + 1].estStart : start + live[i].durationMinutes / 60.0;
      if (now >= start && now < containEnd) {
        // Progress / minutes-left are measured against the block's own duration.
        final span = live[i].durationMinutes / 60.0;
        final blockEnd = start + span;
        final left = ((blockEnd - now) * 60).round().clamp(0, 100000);
        return HomeNowState(
          isResting: false, isDayDone: false, currentLabel: live[i].label,
          minutesLeft: left, budgetMinutes: live[i].durationMinutes,
          progress: span <= 0 ? 1.0 : ((now - start) / span).clamp(0.0, 1.0),
          nextLabel: i < live.length - 1 ? live[i + 1].label : '',
          nextTime: i < live.length - 1 ? _fmt(live[i + 1].estStart) : '',
          whisper: whisper,
        );
      }
    }
    return HomeNowState(isResting: false, isDayDone: true, currentLabel: '', minutesLeft: 0,
        budgetMinutes: 0, progress: 1, nextLabel: '', nextTime: '', whisper: whisper);
  }
}
