import '../data/models.dart';

class WeeklySummary {
  final int killCount;
  final int compactCount;
  final int jettisonCount;
  final String sentence;
  const WeeklySummary({
    required this.killCount,
    required this.compactCount,
    required this.jettisonCount,
    required this.sentence,
  });
}

/// A custom task the user has run on enough distinct days that it's worth
/// offering to bake into their permanent blueprint (see C10/C11).
class PromotionCandidate {
  final String label;
  final int count;             // distinct days the task ran in the window
  final String preferredTime;  // 'HH:mm' — from the most recent run
  final int durationMinutes;   // from the most recent run
  const PromotionCandidate({
    required this.label,
    required this.count,
    required this.preferredTime,
    required this.durationMinutes,
  });
}

class WeeklyReview {
  static WeeklySummary summarize(List<DriftEvent> events) {
    final kills = events.where((e) => e.event == 'killed').toList();
    final compacts = events.where((e) => e.event == 'compacted').toList();
    final jetts = events.where((e) => e.event == 'jettisoned').toList();

    if (events.isEmpty) {
      return const WeeklySummary(
        killCount: 0, compactCount: 0, jettisonCount: 0,
        sentence: 'No drift this week — the plan held. Nice.',
      );
    }

    final parts = <String>[];
    parts.addAll(_byLabel(kills, 'auto-cancelled'));
    parts.addAll(_byLabel(compacts, 'compacted'));
    parts.addAll(_byLabel(jetts, 'dropped'));

    return WeeklySummary(
      killCount: kills.length,
      compactCount: compacts.length,
      jettisonCount: jetts.length,
      sentence: 'This week — ${parts.join('; ')}.',
    );
  }

  /// The label that drifted most this week (any event type) — the catch-up
  /// screen's "give it more time" insight targets it. Null when nothing drifted.
  static String? mostSqueezedLabel(List<DriftEvent> events) {
    if (events.isEmpty) return null;
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.label] = (counts[e.label] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static List<String> _byLabel(List<DriftEvent> events, String verb) {
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.label] = (counts[e.label] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.key} $verb ${e.value}×').toList();
  }

  /// Scan a window of [DailyState]s for custom tasks the user ran on at least
  /// [minRuns] distinct days — these are worth promoting into the blueprint.
  /// Time/duration reflect the most recent run; results sort by count desc.
  static List<PromotionCandidate> promotionCandidates(
    List<DailyState> states, {
    int minRuns = 3,
  }) {
    // label -> (date -> most-recent task seen on that date)
    final byLabel = <String, Map<String, CustomTask>>{};
    for (final s in states) {
      for (final t in s.addedItems) {
        byLabel.putIfAbsent(t.label, () => {})[t.date] = t;
      }
    }

    final out = <PromotionCandidate>[];
    byLabel.forEach((label, byDate) {
      if (byDate.length < minRuns) return;
      // Most recent run by date key (ISO yyyy-MM-dd sorts lexicographically).
      final latestDate = byDate.keys.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
      final latest = byDate[latestDate]!;
      out.add(PromotionCandidate(
        label: label,
        count: byDate.length,
        preferredTime: latest.startTime,
        durationMinutes: latest.durationMinutes,
      ));
    });

    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }
}
