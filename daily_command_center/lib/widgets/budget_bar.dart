import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

class BudgetBar extends StatelessWidget {
  final int idealMinutes;
  final int currentMinutes;
  final double? activeSpent; // 0..1 of the active item elapsed; null if not active
  const BudgetBar({super.key, required this.idealMinutes, required this.currentMinutes, this.activeSpent});

  bool get _compacted => currentMinutes < idealMinutes;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fillFrac = idealMinutes <= 0 ? 1.0 : (currentMinutes / idealMinutes).clamp(0.0, 1.0);
    final color = _compacted ? c.amber : c.moss;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 7,
            color: c.line,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fillFrac,
              child: activeSpent == null
                  ? Container(color: color)
                  : Row(children: [
                      Expanded(flex: (activeSpent! * 100).round().clamp(0, 100), child: Container(color: color.withValues(alpha: .45))),
                      Expanded(flex: 100 - (activeSpent! * 100).round().clamp(0, 100), child: Container(color: color)),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _compacted ? '⚠ −${idealMinutes - currentMinutes}m · ${currentMinutes}m budget' : '${currentMinutes}m budget',
          style: TextStyle(fontSize: 10.5, color: _compacted ? c.amber : c.dim),
        ),
      ],
    );
  }
}
