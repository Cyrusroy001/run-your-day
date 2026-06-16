import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

/// One inline ketchup teaching caption — tomato-tinted, a ~ mark, one dismiss ✕.
/// Shown on the first appearance of a concept, then never again (the host owns
/// the seen-flag). Max one visible at a time. Spec R5 / copy deck §2.
class TeachCaption extends StatelessWidget {
  final String text;
  final VoidCallback onDismiss;
  final VoidCallback? onWhy;
  const TeachCaption({super.key, required this.text, required this.onDismiss, this.onWhy});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      decoration: BoxDecoration(
        color: c.vineDim,
        border: Border.all(color: c.vine.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('~', style: GoogleFonts.splineSansMono(color: c.vine, fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.4, color: c.salt))),
        if (onWhy != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onWhy,
            child: Text('Why?', style: TextStyle(fontSize: 12, color: c.vine, fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onDismiss,
          child: Text('✕', style: GoogleFonts.splineSansMono(color: c.dim, fontSize: 12)),
        ),
      ]),
    );
  }
}
