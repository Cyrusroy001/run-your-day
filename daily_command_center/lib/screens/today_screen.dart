import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/adherence_store.dart';
import '../data/models.dart';
import '../data/state_store.dart';
import '../logic/assembler.dart';
import '../logic/timeline.dart';
import '../logic/weekly_review.dart';
import '../main.dart';

const _dayNames = {
  'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
  'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
};

class TodayScreen extends StatefulWidget {
  final Plan plan;
  final String todayKey;
  final Set<String> doneToday;
  final void Function(String signature) onToggle;
  final double? debugNow;       // test seam; defaults to nowDecimal()
  final WeeklySummary? debugSummary; // test seam; skips async StateStore load

  const TodayScreen({
    super.key,
    required this.plan,
    required this.todayKey,
    required this.doneToday,
    required this.onToggle,
    this.debugNow,
    this.debugSummary,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Set<String> _done;
  List<DayAdherence>? _week;
  WeeklySummary? _summary;

  @override
  void initState() {
    super.initState();
    _done = {...widget.doneToday};
    AdherenceStore.last7(DateTime.now()).then((w) {
      if (mounted) setState(() => _week = w);
    });
    if (widget.debugSummary != null) {
      _summary = widget.debugSummary;
    } else {
      StateStore.recentDriftEvents(DateTime.now(), days: 7).then((events) {
        if (mounted) setState(() => _summary = WeeklyReview.summarize(events));
      });
    }
  }

  void _toggle(String sig) {
    setState(() => _done.contains(sig) ? _done.remove(sig) : _done.add(sig));
    widget.onToggle(sig);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.plan.week[widget.todayKey]!;
    final blocks = TimelineAssembler.assembleDay(
      widget.plan, entry.templateId, widget.todayKey, training: entry.training,
    );
    final times = buildTimes(blocks);
    final now = widget.debugNow ?? nowDecimal();

    int curIdx = -1;
    for (int i = 0; i < blocks.length; i++) {
      final start = times[i];
      final end = i < blocks.length - 1 ? times[i + 1] : 25.0;
      if (now >= start && now < end) {
        curIdx = i;
        break;
      }
    }

    final trackable = blocks.where((b) => b.isTrackable).toList();
    final total = trackable.length;
    final done = trackable.where((b) => _done.contains(b.signature)).length;
    final dayName = _dayNames[widget.todayKey] ?? widget.todayKey;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.cream,
        title: Text('Today', style: GoogleFonts.fraunces(fontWeight: FontWeight.w800, color: AppColors.cream)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _weekStrip(),
          const SizedBox(height: 12),
          _driftCard(),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${dayName.toUpperCase()} · TODAY',
                  style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.sky, fontWeight: FontWeight.w600)),
              Text('$done of $total followed',
                  style: const TextStyle(fontSize: 11, color: AppColors.moss, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : 0,
              backgroundColor: AppColors.panel2,
              color: AppColors.moss,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(blocks.length, (i) => _row(blocks[i], i == curIdx)),
        ],
      ),
    );
  }

  Widget _driftCard() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    final isSunday = widget.todayKey == 'sun';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: isSunday ? AppColors.amber : AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isSunday ? 'WEEKLY REVIEW' : 'THIS WEEK',
            style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.sky, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(s.sentence, style: const TextStyle(fontSize: 13, color: AppColors.cream, height: 1.3)),
      ]),
    );
  }

  Widget _weekStrip() {
    final week = _week;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LAST 7 DAYS',
                  style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.sky, fontWeight: FontWeight.w600)),
              Text(_weekLabel(week),
                  style: const TextStyle(fontSize: 13, color: AppColors.moss, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: week == null
                ? const Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.moss)))
                : Row(crossAxisAlignment: CrossAxisAlignment.end, children: week.map(_bar).toList()),
          ),
        ],
      ),
    );
  }

  String _weekLabel(List<DayAdherence>? week) {
    if (week == null) return '';
    final avg = AdherenceStore.weeklyAverage(week);
    return avg == null ? 'No data yet' : '${avg.round()}% followed';
  }

  Widget _bar(DayAdherence d) {
    final pct = d.pct;
    final h = pct == null ? 8.0 : 8 + pct / 100 * 36;
    final color = pct == null ? AppColors.line : (pct >= 60 ? AppColors.moss : AppColors.amber);
    final letter = DateFormat('E').format(d.day)[0];
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(height: h, margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 4),
          Text(letter, style: const TextStyle(fontSize: 9, color: AppColors.dim)),
        ],
      ),
    );
  }

  Widget _row(Block b, bool isCurrent) {
    if (!b.isTrackable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Opacity(
          opacity: 0.45,
          child: Row(children: [
            const SizedBox(width: 22, child: Text('·', textAlign: TextAlign.center, style: TextStyle(color: AppColors.dim))),
            const SizedBox(width: 10),
            SizedBox(width: 42, child: Text(b.time, style: const TextStyle(fontSize: 11, color: AppColors.dim))),
            Expanded(child: Text(b.label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
          ]),
        ),
      );
    }
    final isDone = _done.contains(b.signature);
    return GestureDetector(
      onTap: () => _toggle(b.signature),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: EdgeInsets.symmetric(vertical: 7, horizontal: isCurrent ? 8 : 0),
        decoration: isCurrent
            ? BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.terra), borderRadius: BorderRadius.circular(10))
            : null,
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isDone ? AppColors.moss : Colors.transparent,
              border: Border.all(color: isDone ? AppColors.moss : (isCurrent ? AppColors.terra : AppColors.dim), width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: isDone ? const Icon(Icons.check, size: 15, color: AppColors.bg) : null,
          ),
          const SizedBox(width: 10),
          SizedBox(width: 42, child: Text(b.time,
              style: TextStyle(fontSize: 11, color: isCurrent ? AppColors.terra : AppColors.dim, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400))),
          Expanded(child: Text(b.label,
              style: TextStyle(
                fontSize: 13.5,
                color: isDone ? AppColors.muted : AppColors.cream,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                decoration: isDone ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.muted,
              ))),
          if (isCurrent) const Text('NOW', style: TextStyle(fontSize: 9, color: AppColors.terra, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
