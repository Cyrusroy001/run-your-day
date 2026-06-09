import '../data/models.dart';
import 'drift_engine.dart';

class DriftCopy {
  /// Format a 24h decimal as the app's 12h display (e.g. 11.17 -> "11:10").
  static String _fmt(double dec) {
    final h = dec.floor();
    final m = ((dec - h) * 60).round();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}';
  }

  static String? _firstHardAnchorLabel(ResolvedDay day) {
    for (final b in day.blocks) {
      if (b.isAnchor && b.hardAnchor) return b.label;
    }
    return day.blocks.where((b) => b.isAnchor).map((b) => b.label).cast<String?>().firstWhere((_) => true, orElse: () => null);
  }

  /// Live drift summary — all labels from JSON.
  static String summary(ResolvedDay day) {
    final trimmed = day.blocks.where((b) => b.isCompacted).map((b) => b.label).toList();
    final dropped = day.blocks.where((b) => b.isDropped).map((b) => b.label).toList();
    if (trimmed.isEmpty && dropped.isEmpty) return 'On track. The plan’s holding.';

    final anchor = _firstHardAnchorLabel(day) ?? 'what matters';
    final parts = <String>[];
    if (trimmed.isNotEmpty) parts.add('Trimmed ${_and(trimmed)} to hold $anchor');
    if (dropped.isNotEmpty) parts.add('${_and(dropped)} dropped to protect your evening');
    return '${parts.join('. ')}.';
  }

  /// Home whisper — shorter; null when on-track.
  static String? whisper(ResolvedDay day, {int? behindMinutes}) {
    final trimmed = day.blocks.where((b) => b.isCompacted).map((b) => b.label).toList();
    final dropped = day.blocks.where((b) => b.isDropped).map((b) => b.label).toList();
    if (trimmed.isEmpty && dropped.isEmpty) return null;
    final anchor = _firstHardAnchorLabel(day) ?? 'what matters';
    final behind = behindMinutes != null && behindMinutes > 0 ? 'Running ~${behindMinutes}m behind · ' : '';
    if (trimmed.isNotEmpty) return '${behind}trimmed ${_and(trimmed)} to hold $anchor.';
    return '$behind${_and(dropped)} dropped to protect your evening.';
  }

  static String teachCompaction({required String itemLabel, required int minutes, required String anchorLabel}) =>
      'I trimmed $itemLabel by ${minutes}m so your $anchorLabel still starts on time. Budgets flex; anchors don’t.';

  static String teachDrop({required String itemLabel}) =>
      '$itemLabel got cancelled today — it would’ve run too late. Protecting your evening.';

  static String teachAdjust({required String anchorLabel}) =>
      'Drag to reorder, swipe to remove. $anchorLabel stays put. This only changes today.';

  static String notification({required String itemLabel, required String cutoff}) =>
      '$itemLabel cancelled today — it drifted past $cutoff. Protecting your evening.';

  static String peek(Block b, {required String anchorLabel}) {
    final budget = b.durationMinutes < b.idealMinutes
        ? '${b.idealMinutes}→${b.durationMinutes}m (to hold $anchorLabel)'
        : '${b.idealMinutes}m';
    return 'planned ${_fmt(b.seedStart)} · now ${_fmt(b.estStart)} · budget $budget';
  }

  static String _and(List<String> items) {
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} & ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(', ')} & ${items.last}';
  }

  /// Sunday nudge — names the item dropped/cancelled most. null if nothing notable.
  static String? weeklyNudge(List<DriftEvent> events) {
    final kills = <String, int>{};
    for (final e in events.where((e) => e.event == 'killed' || e.event == 'jettisoned')) {
      kills[e.label] = (kills[e.label] ?? 0) + 1;
    }
    if (kills.isEmpty) return null;
    final worst = kills.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return '$worst keeps getting squeezed out — move it earlier, or shorten its budget?';
  }
}
