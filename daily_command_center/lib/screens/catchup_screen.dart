import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/adherence_store.dart';
import '../data/models.dart' show displayTime;
import '../logic/weekly_review.dart';
import '../theme/app_palette.dart';

/// Sunday catch-up (spec S6) — no grades, no streaks, no red days. A count, a
/// shape, and one optional action: "Give it more time" writes +minutes back into
/// the Plan (the only review→Plan write path — the loop that tunes the engine).
class CatchupScreen extends StatefulWidget {
  final WeeklySummary summary;
  final List<DayAdherence> last7;
  final String? insightLabel; // most-squeezed item this week
  final int giveMinutes;
  final List<PromotionCandidate> promotionCandidates;
  final void Function(PromotionCandidate)? onPromote;
  final void Function(PromotionCandidate)? onDismiss;
  final void Function(String label, int minutes)? onGiveMoreTime;

  const CatchupScreen({
    super.key,
    required this.summary,
    this.last7 = const [],
    this.insightLabel,
    this.giveMinutes = 15,
    this.promotionCandidates = const [],
    this.onPromote,
    this.onDismiss,
    this.onGiveMoreTime,
  });

  @override
  State<CatchupScreen> createState() => _CatchupScreenState();
}

class _CatchupScreenState extends State<CatchupScreen> {
  bool _gaveTime = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final showInsight = widget.insightLabel != null && widget.onGiveMoreTime != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.close, color: c.dim),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Text('Your week,\ncaught up.',
              style: GoogleFonts.bricolageGrotesque(fontSize: 30, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -0.5, color: c.salt)),
          const SizedBox(height: 18),
          if (widget.last7.isNotEmpty) _bars(c),
          const SizedBox(height: 16),
          Text(widget.summary.sentence, style: TextStyle(fontSize: 14, height: 1.45, color: c.dim)),
          if (showInsight) ...[
            const SizedBox(height: 18),
            _insightCard(c),
          ],
          if (widget.promotionCandidates.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('YOU DID THESE OFTEN',
                style: GoogleFonts.splineSansMono(fontSize: 11, letterSpacing: 1.2, color: c.mustard)),
            const SizedBox(height: 6),
            ...widget.promotionCandidates.map((cand) => _promotionRow(c, cand)),
          ],
        ]),
      ),
    );
  }

  Widget _bars(AppPalette c) => SizedBox(
        height: 74,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final d in widget.last7)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: d.pct == null ? 8 : 8 + d.pct! / 100 * 50,
                    decoration: BoxDecoration(
                      color: d.pct == null ? c.line : (d.pct! >= 60 ? c.leaf : c.mustard),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      );

  Widget _insightCard(AppPalette c) {
    if (_gaveTime) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.leafDim, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.leaf.withValues(alpha: .4))),
        child: Text('✓ Gave ${widget.insightLabel} ${widget.giveMinutes} more minutes next week.',
            style: TextStyle(fontSize: 13.5, color: c.leaf)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.raise, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(style: TextStyle(fontSize: 13.5, height: 1.4, color: c.dim), children: [
          TextSpan(text: '~ ', style: TextStyle(color: c.mustard, fontFamily: GoogleFonts.splineSansMono().fontFamily)),
          TextSpan(text: widget.insightLabel, style: TextStyle(color: c.salt)),
          const TextSpan(text: ' kept getting squeezed this week. Want '),
          TextSpan(text: '${widget.giveMinutes} more minutes', style: TextStyle(color: c.salt)),
          const TextSpan(text: ' for it next week?'),
        ])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () {
                widget.onGiveMoreTime!(widget.insightLabel!, widget.giveMinutes);
                setState(() => _gaveTime = true);
              },
              style: FilledButton.styleFrom(backgroundColor: c.tomato, foregroundColor: const Color(0xFFFFF6F2), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text('Give it more time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(side: BorderSide(color: c.line), foregroundColor: c.salt, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text('Keep as is', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _promotionRow(AppPalette c, PromotionCandidate cand) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.mustardDim, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.mustard.withValues(alpha: .5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cand.label, style: GoogleFonts.bricolageGrotesque(fontSize: 14, fontWeight: FontWeight.w600, color: c.salt)),
          const SizedBox(height: 2),
          Text('${cand.count}× this week · ${displayTime(cand.preferredTime)} · ${cand.durationMinutes}m',
              style: GoogleFonts.splineSansMono(fontSize: 11, color: c.dim)),
          const SizedBox(height: 10),
          Row(children: [
            GestureDetector(
              onTap: widget.onPromote == null ? null : () => widget.onPromote!(cand),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: c.mustard, borderRadius: BorderRadius.circular(99)),
                child: Text('Add to plan →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.char)),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: widget.onDismiss == null ? null : () => widget.onDismiss!(cand),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text('Not yet', style: TextStyle(fontSize: 12, color: c.dim))),
            ),
          ]),
        ]),
      );
}
