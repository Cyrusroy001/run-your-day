import 'package:flutter/material.dart';
import '../data/adherence_store.dart';
import '../logic/weekly_review.dart';
import '../theme/app_palette.dart';

class WeeklyReviewCard extends StatelessWidget {
  final WeeklySummary summary;
  final bool isSunday;
  final String? nudge;
  final List<DayAdherence> last7;
  const WeeklyReviewCard({super.key, required this.summary, required this.isSunday, this.nudge, this.last7 = const []});

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
      ]),
    );
  }

  Widget _bar(AppPalette c, DayAdherence d) {
    final pct = d.pct;
    final h = pct == null ? 6.0 : 6 + pct / 100 * 34;
    final color = pct == null ? c.line : (pct >= 60 ? c.moss : c.amber);
    return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))));
  }
}
