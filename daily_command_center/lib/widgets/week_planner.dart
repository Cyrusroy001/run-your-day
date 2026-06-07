import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../logic/planner.dart';
import '../main.dart';

const _dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayNames = {
  'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
  'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun',
};

class WeekPlanner extends StatefulWidget {
  final WeekPlan plan;
  final String todayKey;
  final void Function(WeekPlan newPlan) onPlanChanged;

  const WeekPlanner({
    super.key,
    required this.plan,
    required this.todayKey,
    required this.onPlanChanged,
  });

  @override
  State<WeekPlanner> createState() => _WeekPlannerState();
}

class _WeekPlannerState extends State<WeekPlanner> {
  String? _caption;
  Timer? _captionTimer;

  int get _trainCount => widget.plan.values.where((p) => p.isTraining).length;

  @override
  void dispose() {
    _captionTimer?.cancel();
    super.dispose();
  }

  void _showCaption(String? msg) {
    _captionTimer?.cancel();
    setState(() => _caption = msg);
    if (msg != null) {
      _captionTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _caption = null);
      });
    }
  }

  void _onSchedule(String day) {
    if (widget.plan[day]!.schedule == DaySchedule.weekend) return;
    widget.onPlanChanged(PlannerLogic.toggleSchedule(widget.plan, day));
  }

  void _onTraining(String day) {
    HapticFeedback.lightImpact();
    final result = PlannerLogic.toggleTraining(widget.plan, day);
    _showCaption(result.message);
    widget.onPlanChanged(result.plan);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PLAN YOUR WEEK',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.sky, fontWeight: FontWeight.w600)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text('$_trainCount training days',
                    key: ValueKey(_trainCount),
                    style: TextStyle(fontSize: 11, color: _trainCount == 4 ? AppColors.moss : AppColors.amber, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._dayOrder.map((day) => _DayRow(
                day: day,
                plan: widget.plan[day]!,
                isToday: day == widget.todayKey,
                onSchedule: () => _onSchedule(day),
                onTraining: () => _onTraining(day),
              )),
          if (_caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_caption!, style: const TextStyle(fontSize: 12, color: AppColors.sky)),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => widget.onPlanChanged(PlannerLogic.defaultWeek()),
            child: const Text('Reset to suggested week',
                style: TextStyle(fontSize: 11.5, color: AppColors.dim, decoration: TextDecoration.underline, decorationColor: AppColors.dim)),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String day;
  final DayPlan plan;
  final bool isToday;
  final VoidCallback onSchedule;
  final VoidCallback onTraining;

  const _DayRow({
    required this.day,
    required this.plan,
    required this.isToday,
    required this.onSchedule,
    required this.onTraining,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend = plan.schedule == DaySchedule.weekend;
    final schedLabel = isWeekend ? 'Weekend' : (plan.schedule == DaySchedule.office ? 'Office' : 'WFH');
    final schedColor = isWeekend ? AppColors.amber : (plan.schedule == DaySchedule.office ? AppColors.terra : AppColors.sky);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: isToday ? AppColors.amber : Colors.transparent, width: 3)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(width: 38, child: Text(_dayNames[day]!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.cream))),
          const SizedBox(width: 8),
          GestureDetector(
            key: Key('sched-$day'),
            onTap: onSchedule,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: schedColor.withValues(alpha: 0.12),
                border: Border.all(color: schedColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(schedLabel, style: TextStyle(fontSize: 12, color: schedColor, fontWeight: FontWeight.w600)),
            ),
          ),
          const Spacer(),
          Text(plan.isTraining ? 'Train' : 'Rest',
              style: TextStyle(fontSize: 11, color: plan.isTraining ? AppColors.moss : AppColors.dim, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          GestureDetector(
            key: Key('train-$day'),
            onTap: onTraining,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: plan.isTraining ? AppColors.terra : AppColors.line,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment: plan.isTraining ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(width: 22, height: 22,
                    decoration: const BoxDecoration(color: AppColors.cream, shape: BoxShape.circle)),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
