import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/adherence_store.dart';
import '../logic/assembler.dart';
import '../main.dart';
import '../widgets/now_card.dart';
import '../widgets/week_planner.dart';
import 'today_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Plan? _plan;
  Set<String> _doneToday = {};
  static const _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  late String _todayKey;

  @override
  void initState() {
    super.initState();
    _todayKey = _days[DateTime.now().weekday % 7];
    _load();
  }

  Future<void> _load() async {
    final plan = await AppStore.loadPlan();
    final done = await AdherenceStore.loadDone(DateTime.now());
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _doneToday = done;
    });
    AppStore.writeWidgetData(plan, _todayKey).ignore();
    _recordAdherence(plan, done);
  }

  ({int done, int total}) _tally(Plan plan, Set<String> done) {
    final entry = plan.week[_todayKey];
    if (entry == null) return (done: 0, total: 0);
    final blocks = TimelineAssembler.assembleDay(plan, entry.templateId, _todayKey, training: entry.training);
    final trackable = blocks.where((b) => b.isTrackable).toList();
    return (
      done: trackable.where((b) => done.contains(b.signature)).length,
      total: trackable.length,
    );
  }

  void _recordAdherence(Plan plan, Set<String> done) {
    final t = _tally(plan, done);
    AdherenceStore.writeAdherence(DateTime.now(), t.done, t.total).ignore();
  }

  Future<void> _updatePlan(Plan newPlan) async {
    await AppStore.savePlan(newPlan);
    setState(() => _plan = newPlan);
    AppStore.writeWidgetData(newPlan, _todayKey).ignore();
    _recordAdherence(newPlan, _doneToday);
  }

  Future<void> _toggleDone(String signature) async {
    final next = {..._doneToday};
    next.contains(signature) ? next.remove(signature) : next.add(signature);
    setState(() => _doneToday = next);
    await AdherenceStore.saveDone(DateTime.now(), next);
    if (_plan != null) _recordAdherence(_plan!, next);
  }

  void _openToday() {
    final plan = _plan;
    if (plan == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TodayScreen(
        plan: plan,
        todayKey: _todayKey,
        doneToday: _doneToday,
        onToggle: _toggleDone,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: plan == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.terra))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(
                  child: NowCard(
                    plan: plan,
                    todayKey: _todayKey,
                    doneToday: _doneToday,
                    onViewAll: _openToday,
                    onToggleDone: _toggleDone,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: WeekPlanner(
                    plan: plan,
                    todayKey: _todayKey,
                    onPlanChanged: _updatePlan,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CYRUS · DAILY COMMAND CENTER',
              style: TextStyle(fontSize: 10, letterSpacing: 3, color: AppColors.terra, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Run The Day.',
              style: GoogleFonts.fraunces(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.cream, height: 0.95, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Lean & defined — not big. Plan it, then run it.',
              style: GoogleFonts.fraunces(fontSize: 15, fontStyle: FontStyle.italic, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(dateStr, style: const TextStyle(fontSize: 13, color: AppColors.moss, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
