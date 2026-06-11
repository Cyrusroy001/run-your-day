import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  static const _entries = [
    ['Budgets flex', 'Each task has a time budget that can shrink when you’re late — so the day adapts instead of breaking.'],
    ['Anchors don’t', 'Your fixed boundaries (work, a shift, a pickup) never move. The day reshapes around them.'],
    ['Drift', 'When you run late, later tasks shift forward. The app shows the new estimated start for each.'],
    ['Compaction', 'To protect an anchor, flexible tasks trim toward their minimum before anything is dropped.'],
    ['Dropped', 'If there’s truly no room, the least important task is set aside for today (never deleted from your plan).'],
    ['Just for today', 'Removing, reordering, or re-prioritising only changes today. Your master plan stays the same.'],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(backgroundColor: c.bg, elevation: 0, foregroundColor: c.cream,
          title: Text('How Reminders works', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        for (final e in _entries) Padding(padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e[0], style: GoogleFonts.bricolageGrotesque(fontSize: 17, fontWeight: FontWeight.w700, color: c.cream)),
            const SizedBox(height: 4),
            Text(e[1], style: TextStyle(fontSize: 13.5, height: 1.5, color: c.muted)),
          ])),
      ]),
    );
  }
}
