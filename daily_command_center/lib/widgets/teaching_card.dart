import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

class TeachingCard extends StatelessWidget {
  final String text;
  final VoidCallback onGotIt;
  final VoidCallback onWhy;
  const TeachingCard({super.key, required this.text, required this.onGotIt, required this.onWhy});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: c.panel2, border: Border.all(color: c.terra), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('✦ New thing just happened', style: TextStyle(fontSize: 11, color: c.terra, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: c.cream)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: onWhy, child: Text('Why?', style: TextStyle(color: c.muted))),
          const SizedBox(width: 6),
          FilledButton(onPressed: onGotIt, style: FilledButton.styleFrom(backgroundColor: c.terra),
              child: const Text('Got it')),
        ]),
      ]),
    );
  }
}
