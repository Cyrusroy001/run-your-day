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
  final void Function(WeekPlan newPlan, String? message) onPlanChanged;

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
  int get _trainCount => widget.plan.values.where((p) => p.isTraining).length;

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
              const Text(
                'PLAN YOUR WEEK',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppColors.sky,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '$_trainCount training days',
                  key: ValueKey(_trainCount),
                  style: TextStyle(
                    fontSize: 11,
                    color: _trainCount == 4 ? AppColors.moss : AppColors.amber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _dayOrder.map((day) => _DayCell(
              day: day,
              plan: widget.plan[day]!,
              isToday: day == widget.todayKey,
              onScheduleToggle: () {
                if (widget.plan[day]!.schedule == DaySchedule.weekend) return;
                final updated = PlannerLogic.toggleSchedule(widget.plan, day);
                widget.onPlanChanged(updated, null);
              },
              onTrainingToggle: () {
                HapticFeedback.lightImpact();
                final result = PlannerLogic.toggleTraining(widget.plan, day);
                widget.onPlanChanged(result.plan, result.message);
              },
            )).toList(),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => widget.onPlanChanged(PlannerLogic.defaultWeek(), null),
            child: const Text(
              'Reset to suggested week',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.dim,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.dim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String day;
  final DayPlan plan;
  final bool isToday;
  final VoidCallback onScheduleToggle;
  final VoidCallback onTrainingToggle;

  const _DayCell({
    required this.day,
    required this.plan,
    required this.isToday,
    required this.onScheduleToggle,
    required this.onTrainingToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend = plan.schedule == DaySchedule.weekend;
    final scheduleLabel = isWeekend
        ? 'Wknd'
        : (plan.schedule == DaySchedule.office ? 'Office' : 'WFH');
    final scheduleColor = isWeekend
        ? AppColors.amber
        : (plan.schedule == DaySchedule.office ? AppColors.terra : AppColors.sky);

    return Expanded(
      child: GestureDetector(
        onTap: onScheduleToggle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _dayNames[day]!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scheduleLabel,
                        style: TextStyle(
                          fontSize: 9,
                          color: scheduleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onTrainingToggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: plan.isTraining ? AppColors.terra : Colors.transparent,
                            border: Border.all(
                              color: plan.isTraining ? AppColors.terra : AppColors.dim,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isToday)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: AppColors.amber),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
