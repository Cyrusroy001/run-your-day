import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

/// "How ketchup works" (spec S9) — the whole manual on one screen. Six ideas,
/// the same captions users meet inline, in brand voice. Replaces the old
/// GlossaryScreen + the teaching framework.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  // (glyph, caption) — the garden manual, universal vocabulary only.
  static const _entries = <(String, String)>[
    ('🍒', "Every block is a fruit on today's vine. Green means later, apricot means soon — red means now."),
    ('🥫', 'Fall behind and ketchup squeezes the flexible blocks. Overripe fruit is what the sauce is made from.'),
    ('◉', 'Anchors wear a dashed ring. They hold their time no matter what.'),
    ('🧺', 'Pick ✓ drops a block into the basket. Missed one? It hangs jammy below — pick it late, it still counts.'),
    ('☀', 'The sky follows the clock, never your drift. Light always means time.'),
    ('🫙', 'Sunday bottles the week into jars — how much you picked, and how smooth the batch was.'),
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
        for (final (glyph, caption) in _entries)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.vineDim,
              border: Border.all(color: c.vine.withValues(alpha: .3)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(glyph, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(caption,
                    style: TextStyle(fontSize: 12.8, height: 1.45, color: c.salt)),
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
