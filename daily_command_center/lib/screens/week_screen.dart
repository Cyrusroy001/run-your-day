import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../theme/app_palette.dart';
import '../widgets/week_planner.dart';

/// "Plan my week" (spec S5) — the only place the weekly Plan is written. Day
/// templates are user-named Life-JSON strings; confirmation is the WeekPlanner's
/// inline leaf caption (no toasts). Lives off Home, reached from the avatar menu.
class WeekScreen extends StatefulWidget {
  final Plan plan;
  final String todayKey;
  final ValueChanged<Plan> onChanged;
  const WeekScreen({super.key, required this.plan, required this.todayKey, required this.onChanged});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late Plan _plan = widget.plan;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        elevation: 0, backgroundColor: c.char, foregroundColor: c.salt,
        title: Text('Plan my week', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(2, 8, 2, 30), children: [
        WeekPlanner(
          plan: _plan,
          todayKey: widget.todayKey,
          onPlanChanged: (p) {
            setState(() => _plan = p);
            widget.onChanged(p);
          },
        ),
      ]),
    );
  }
}
