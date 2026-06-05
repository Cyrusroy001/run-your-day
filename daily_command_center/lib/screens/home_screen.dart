import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../main.dart';
import '../widgets/now_card.dart';
import '../widgets/week_planner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeekPlan? _plan;
  static const _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  late String _todayKey;

  @override
  void initState() {
    super.initState();
    _todayKey = _days[DateTime.now().weekday % 7];
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final plan = await AppStore.loadPlan();
    setState(() => _plan = plan);
    AppStore.writeWidgetData(plan, _todayKey).ignore();
  }

  Future<void> _updatePlan(WeekPlan newPlan, String? message) async {
    await AppStore.savePlan(newPlan);
    setState(() => _plan = newPlan);
    AppStore.writeWidgetData(newPlan, _todayKey).ignore();
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2500),
          backgroundColor: AppColors.panel2,
        ),
      );
    }
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
                    onTap: () {},
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
          const Text(
            'CYRUS · DAILY COMMAND CENTER',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 3,
              color: AppColors.terra,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Run The Day.',
            style: GoogleFonts.fraunces(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.cream,
              height: 0.95,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lean & defined — not big. Plan it, then run it.',
            style: GoogleFonts.fraunces(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.moss,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
