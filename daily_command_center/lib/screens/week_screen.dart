import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme/app_palette.dart';
import '../widgets/week_planner.dart';

/// "Plan my week" (spec S5) — the only place the weekly Plan is written. Day
/// templates are user-named Life-JSON strings; confirmation is the WeekPlanner's
/// inline leaf caption (no toasts). Hosted as a tab in the three-tab shell.
class WeekScreen extends StatefulWidget {
  final Plan? debugPlan;
  final String? debugTodayKey;
  const WeekScreen({super.key, this.debugPlan, this.debugTodayKey});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  static const _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  Plan? _plan;
  late final String _todayKey =
      widget.debugTodayKey ?? _days[DateTime.now().weekday % 7];

  @override
  void initState() {
    super.initState();
    _plan = widget.debugPlan;
    if (_plan == null) _load();
  }

  Future<void> _load() async {
    final p = await AppStore.loadPlan();
    if (mounted) setState(() => _plan = p);
  }

  Future<void> _save(Plan p) async {
    setState(() => _plan = p);
    await AppStore.savePlan(p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final plan = _plan;
    if (plan == null) {
      return Center(child: CircularProgressIndicator(color: c.vine));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(2, 8, 2, 30), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: Text('Week', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w700, fontSize: 22, color: c.salt)),
      ),
      WeekPlanner(
        plan: plan,
        todayKey: _todayKey,
        onPlanChanged: _save,
      ),
    ]);
  }
}
