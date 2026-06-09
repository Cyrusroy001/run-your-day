import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../logic/home_now_state.dart';
import '../theme/app_palette.dart';

class NowHeroCard extends StatelessWidget {
  final HomeNowState state;
  final VoidCallback onOpen;
  const NowHeroCard({super.key, required this.state, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final title = state.isResting
        ? 'Still resting'
        : state.isDayDone ? 'Day’s done. Rest up.' : state.currentLabel;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c.panel2, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('▶ RIGHT NOW', style: TextStyle(fontSize: 9, letterSpacing: 2, color: c.moss, fontWeight: FontWeight.w700)),
            if (!state.isResting && !state.isDayDone)
              SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: state.progress, strokeWidth: 4, color: c.moss, backgroundColor: c.line),
                Text('${state.minutesLeft}′', style: TextStyle(fontSize: 10, color: c.moss, fontWeight: FontWeight.w700)),
              ])),
          ]),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.fraunces(fontSize: 21, fontWeight: FontWeight.w600, color: c.cream)),
          if (!state.isResting && !state.isDayDone)
            Padding(padding: const EdgeInsets.only(top: 2),
              child: Text('${state.minutesLeft}m left of ${state.budgetMinutes}m budget', style: TextStyle(fontSize: 11.5, color: c.muted))),
          if (state.whisper != null)
            Padding(padding: const EdgeInsets.only(top: 10),
              child: Text(state.whisper!, style: TextStyle(fontSize: 12, color: c.amber))),
          if (state.nextLabel.isNotEmpty)
            Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Text('Next · ${state.nextTime} ${state.nextLabel}', style: TextStyle(fontSize: 12.5, color: c.muted))),
        ]),
      ),
    );
  }
}
