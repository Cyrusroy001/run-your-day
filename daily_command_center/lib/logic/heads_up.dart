import '../data/models.dart';

/// One scheduled heads-up: "{label} in 10 — you're all caught up." (spec: the
/// only notification ketchup sends, opt-in, one per upcoming actionable block).
class HeadsUp {
  final int id;
  final DateTime when;
  final String title;
  final String body;
  const HeadsUp({required this.id, required this.when, required this.title, required this.body});
}

const int headsUpIdBase = 2000;
const int headsUpIdMax = 2040; // reserved id range to cancel before rescheduling
const int sundayNudgeId = 3001;

/// Pure: which heads-ups to fire for today's [blocks], [leadMinutes] before each
/// upcoming actionable block (skips anchors, dropped, and passive work/chill).
/// [now] is the real clock; only future fire-times are returned.
List<HeadsUp> planHeadsUps({
  required List<Block> blocks,
  required DateTime now,
  bool caughtUp = true,
  int? behindMinutes,
  int leadMinutes = 10,
}) {
  final midnight = DateTime(now.year, now.month, now.day);
  final body = caughtUp
      ? "You're all caught up."
      : "Running ~${behindMinutes ?? 15} behind. I'll catch you up.";
  final out = <HeadsUp>[];
  var i = 0;
  for (final b in blocks) {
    if (b.isAnchor || b.isDropped || !b.isTrackable) continue;
    final start = midnight.add(Duration(minutes: (b.estStart * 60).round()));
    final when = start.subtract(Duration(minutes: leadMinutes));
    if (!when.isAfter(now)) continue;
    if (headsUpIdBase + i > headsUpIdMax) break;
    out.add(HeadsUp(id: headsUpIdBase + i, when: when, title: '${b.label} in $leadMinutes', body: body));
    i++;
  }
  return out;
}
