import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../logic/assembler.dart';
import '../logic/timeline.dart';
import '../main.dart';

const _dayNames = {
  'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
  'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
};

class NowCard extends StatefulWidget {
  final Plan plan;
  final String todayKey;
  final Set<String> doneToday;
  final VoidCallback onViewAll;
  final void Function(String signature) onToggleDone;
  final double? debugNow; // test seam; defaults to nowDecimal()

  const NowCard({
    super.key,
    required this.plan,
    required this.todayKey,
    required this.doneToday,
    required this.onViewAll,
    required this.onToggleDone,
    this.debugNow,
  });

  @override
  State<NowCard> createState() => _NowCardState();
}

class _NowCardState extends State<NowCard> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.plan.week[widget.todayKey];
    if (entry == null) return const SizedBox.shrink();

    final blocks = TimelineAssembler.assembleDay(
      widget.plan, entry.templateId, widget.todayKey, training: entry.training,
    );
    final times = buildTimes(blocks);
    final now = widget.debugNow ?? nowDecimal();

    Block? cur;
    Block? next;
    int progressPct = 0;
    for (int i = 0; i < blocks.length; i++) {
      final start = times[i];
      final end = i < blocks.length - 1 ? times[i + 1] : 25.0;
      if (now >= start && now < end) {
        cur = blocks[i];
        next = i < blocks.length - 1 ? blocks[i + 1] : null;
        progressPct = ((now - start) / (end - start) * 100).round().clamp(0, 100);
        break;
      }
      if (now < start) {
        next = blocks[i];
        break;
      }
    }

    final trackableCur = (cur != null && cur.isTrackable) ? cur : null;
    final isDone = trackableCur != null && widget.doneToday.contains(trackableCur.signature);
    final isWorkout = cur?.isTrain ?? false;

    final String title;
    final String desc;
    Color gradStart;
    Color gradEnd;

    if (now < times.first) {
      title = 'Still resting';
      desc = 'Day kicks off at 8:00 with wake + sunlight.';
      gradStart = const Color(0xFF2A3530);
      gradEnd = const Color(0xFF1F2925);
    } else if (cur == null) {
      title = 'Wind down';
      desc = "Day's done — sleep is the priority now.";
      gradStart = const Color(0xFF2A3530);
      gradEnd = const Color(0xFF1F2925);
    } else {
      title = cur.label;
      desc = cur.desc;
      switch (cur.cls) {
        case 'train':
          gradStart = AppColors.terra;
          gradEnd = AppColors.terraDark;
        case 'focus' || 'dsa':
          gradStart = const Color(0xFF3D6F87);
          gradEnd = const Color(0xFF2F5468);
        case 'meal':
          gradStart = const Color(0xFF46603A);
          gradEnd = const Color(0xFF3A5230);
        default:
          gradStart = const Color(0xFF2A3530);
          gradEnd = const Color(0xFF1F2925);
      }
    }
    if (isDone) {
      gradStart = const Color(0xFF4F7A3C);
      gradEnd = const Color(0xFF3C5E2D);
    }

    final nextLine = next != null ? 'Next · ${next.time} — ${next.label}' : '';
    final dayName = _dayNames[widget.todayKey] ?? widget.todayKey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [gradStart, gradEnd]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: gradStart.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(width: 140, height: 140,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Right now · $dayName',
                        style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white70, fontWeight: FontWeight.w600)),
                    GestureDetector(
                      onTap: widget.onViewAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                        child: const Text('View all ›', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(title,
                        style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.05))),
                    if (isDone)
                      Container(
                        margin: const EdgeInsets.only(left: 8, top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
                        child: const Text('✓ done', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 13.5, color: Colors.white70)),
                ],
                if (nextLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                  const SizedBox(height: 8),
                  Text(nextLine, style: const TextStyle(fontSize: 12.5, color: Colors.white60)),
                ],
                if (isWorkout) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                    child: const Text('View Workout →',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
                if (trackableCur != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => widget.onToggleDone(trackableCur.signature),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.cream : Colors.white.withValues(alpha: 0.18),
                        border: isDone ? null : Border.all(color: Colors.white.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(isDone ? '✓ Done' : '◯ Mark done',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: isDone ? const Color(0xFF3C5E2D) : Colors.white)),
                    ),
                  ),
                ],
                if (progressPct > 0 && !isDone) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressPct / 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
