import 'package:flutter/material.dart';
import '../data/adherence_store.dart';
import '../data/models.dart' show displayTime;
import '../logic/weekly_review.dart';
import '../theme/app_palette.dart';

class WeeklyReviewCard extends StatelessWidget {
  final WeeklySummary summary;
  final bool isSunday;
  final String? nudge;
  final List<DayAdherence> last7;
  final List<PromotionCandidate> promotionCandidates;
  final void Function(PromotionCandidate)? onPromote;
  final void Function(PromotionCandidate)? onDismiss;
  const WeeklyReviewCard({
    super.key,
    required this.summary,
    required this.isSunday,
    this.nudge,
    this.last7 = const [],
    this.promotionCandidates = const [],
    this.onPromote,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: isSunday ? c.terra : c.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isSunday ? 'WEEKLY REVIEW' : 'THIS WEEK',
            style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        if (last7.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(height: 48, child: Row(crossAxisAlignment: CrossAxisAlignment.end,
              children: last7.map((d) => _bar(c, d)).toList())),
        ],
        const SizedBox(height: 8),
        Text(summary.sentence, style: TextStyle(fontSize: 13, color: c.cream, height: 1.4)),
        if (isSunday && nudge != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: c.terraD, border: Border.all(color: c.terra), borderRadius: BorderRadius.circular(12)),
            child: Text(nudge!, style: TextStyle(fontSize: 14, color: c.cream, height: 1.35)),
          ),
          const SizedBox(height: 8),
          Text('No streaks. No scores. Just what happened, and a gentle next step.',
              style: TextStyle(fontSize: 10.5, color: c.dim)),
        ],
        if (promotionCandidates.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('YOU DID THESE OFTEN', style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.amber, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Make them part of your plan?', style: TextStyle(fontSize: 12.5, color: c.dim)),
          const SizedBox(height: 8),
          ...promotionCandidates.map((cand) => _promotionRow(c, cand)),
        ],
      ]),
    );
  }

  Widget _promotionRow(AppPalette c, PromotionCandidate cand) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: c.amberD,
          border: Border.all(color: c.amber),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cand.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.cream)),
          const SizedBox(height: 2),
          Text('${cand.count}× this week · ${displayTime(cand.preferredTime)} · ${cand.durationMinutes}m',
              style: TextStyle(fontSize: 11.5, color: c.dim)),
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              onTap: onPromote == null ? null : () => onPromote!(cand),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: c.amber, borderRadius: BorderRadius.circular(999)),
                child: Text('Add to plan →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.bg)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss == null ? null : () => onDismiss!(cand),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('Not yet', style: TextStyle(fontSize: 12, color: c.dim)),
              ),
            ),
          ]),
        ]),
      );

  Widget _bar(AppPalette c, DayAdherence d) {
    final pct = d.pct;
    final h = pct == null ? 6.0 : 6 + pct / 100 * 34;
    final color = pct == null ? c.line : (pct >= 60 ? c.moss : c.amber);
    return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))));
  }
}
