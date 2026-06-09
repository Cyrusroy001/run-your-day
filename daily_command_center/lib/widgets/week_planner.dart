import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../logic/planner.dart';
import '../theme/app_palette.dart';

const _dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayNames = {
  'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
  'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun',
};

class WeekPlanner extends StatefulWidget {
  final Plan plan;
  final String todayKey;
  final void Function(Plan newPlan) onPlanChanged;

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

  int get _trainCount => widget.plan.week.values.where((e) => e.training).length;

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
    final entry = widget.plan.week[day]!;
    if (entry.templateId.startsWith('weekend')) return;
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
    final c = context.c;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PLAN YOUR WEEK',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: c.sky, fontWeight: FontWeight.w600)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text('$_trainCount training days',
                    key: ValueKey(_trainCount),
                    style: TextStyle(fontSize: 11, color: _trainCount == 4 ? c.moss : c.amber, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._dayOrder.map((day) => _DayRow(
                day: day,
                entry: widget.plan.week[day]!,
                isToday: day == widget.todayKey,
                onSchedule: () => _onSchedule(day),
                onTraining: () => _onTraining(day),
              )),
          if (_caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_caption!, style: TextStyle(fontSize: 12, color: c.sky)),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => widget.onPlanChanged(PlannerLogic.applyBestSpacing(widget.plan)),
            child: Text('Reset to suggested week',
                style: TextStyle(fontSize: 11.5, color: c.dim, decoration: TextDecoration.underline, decorationColor: c.dim)),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String day;
  final WeekEntry entry;
  final bool isToday;
  final VoidCallback onSchedule;
  final VoidCallback onTraining;

  const _DayRow({
    required this.day,
    required this.entry,
    required this.isToday,
    required this.onSchedule,
    required this.onTraining,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isWeekend = entry.templateId.startsWith('weekend');
    final schedLabel = isWeekend ? 'Weekend' : (entry.templateId == 'office' ? 'Office' : 'WFH');
    final schedColor = isWeekend ? c.amber : (entry.templateId == 'office' ? c.terra : c.sky);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: isToday ? c.amber : Colors.transparent, width: 3)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(width: 38, child: Text(_dayNames[day]!,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.cream))),
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
          Text(entry.training ? 'Training' : 'Rest',
              style: TextStyle(fontSize: 11, color: entry.training ? c.moss : c.dim, fontWeight: FontWeight.w600)),
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
                color: entry.training ? c.terra : c.line,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment: entry.training ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(width: 22, height: 22,
                    decoration: BoxDecoration(color: c.cream, shape: BoxShape.circle)),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
