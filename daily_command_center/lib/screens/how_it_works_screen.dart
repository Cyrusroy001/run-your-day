import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

/// "How ketchup works" (spec S9) — the whole manual on one screen. Six ideas,
/// the same captions users meet inline, in brand voice. Replaces the old
/// GlossaryScreen + the teaching framework.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  // (glyph, bold lead, rest)
  static const _entries = <(String, String, String)>[
    ('~', 'Falling behind.', 'When a block runs long, the rest of your day slides. ketchup notices and catches you up.'),
    ('~', 'The squeeze.', 'Flexible blocks give up minutes first — never below their minimum.'),
    ('◉', 'Locked.', 'Anchors never move. ketchup plans around them, not through them.'),
    ('~', 'Protect / Drop first.', 'Your way of telling ketchup what matters when time runs out.'),
    ('~', 'Skip today.', 'Removes a block from today only. The weekly plan never changes from here.'),
    ('~', 'No alarms.', 'Mustard means "ketchup adjusted something," never "you failed." There is nothing to fail.'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        elevation: 0, backgroundColor: c.char, foregroundColor: c.salt,
        title: Text('How ketchup works', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [
        for (final (glyph, lead, rest) in _entries)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.vineDim,
              border: Border.all(color: c.vine.withValues(alpha: .3)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(glyph, style: GoogleFonts.splineSansMono(color: c.vine, fontSize: 14)),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(
                  style: TextStyle(fontSize: 12.8, height: 1.45, color: c.dim),
                  children: [
                    TextSpan(text: '$lead ', style: TextStyle(color: c.salt, fontWeight: FontWeight.w600)),
                    TextSpan(text: rest),
                  ],
                )),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text("That's the whole manual. Six ideas, one screen.",
              style: TextStyle(fontSize: 12.5, color: c.dim)),
        ),
      ]),
    );
  }
}
