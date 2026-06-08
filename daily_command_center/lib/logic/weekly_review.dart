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

  static List<String> _byLabel(List<DriftEvent> events, String verb) {
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.label] = (counts[e.label] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.key} $verb ${e.value}×').toList();
  }
}
