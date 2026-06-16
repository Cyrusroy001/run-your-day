import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../theme/app_palette.dart';

/// "Repeat {task}?" prompt for a one-off custom task the user completed
/// yesterday — offers to make it recurring on a chosen future date (C7).
class RepeatPromptCard extends StatelessWidget {
  final CustomTask task;
  final void Function(String dateIso) onRepeat;
  final VoidCallback onSkip;
  const RepeatPromptCard({super.key, required this.task, required this.onRepeat, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fmt = DateFormat('yyyy-MM-dd');
    final today = DateTime.now();
    final chips = [
      ('Today', fmt.format(today)),
      ('+2', fmt.format(today.add(const Duration(days: 2)))),
      ('+3', fmt.format(today.add(const Duration(days: 3)))),
      ('+7', fmt.format(today.add(const Duration(days: 7)))),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.jammyDim,
        border: Border.all(color: c.jammy.withValues(alpha: .5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('~', style: GoogleFonts.splineSansMono(color: c.jammyText, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text('Repeat "${task.label}"?',
              style: GoogleFonts.bricolageGrotesque(fontSize: 14, fontWeight: FontWeight.w600, color: c.salt))),
        ]),
        const SizedBox(height: 4),
        Text('${displayTime(task.startTime)} · ${task.durationMinutes}m',
            style: GoogleFonts.splineSansMono(fontSize: 11.5, color: c.dim)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, children: [
          for (final (label, date) in chips)
            GestureDetector(
              onTap: () => onRepeat(date),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: c.jammy), borderRadius: BorderRadius.circular(99)),
                child: Text(label, style: GoogleFonts.splineSansMono(fontSize: 12, color: c.jammyText)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onSkip, child: Text('Skip', style: TextStyle(fontSize: 12, color: c.dim))),
        ),
      ]),
    );
  }
}
