import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../logic/planner.dart';
import '../logic/week_modifiers.dart';
import '../theme/app_palette.dart';

/// The allotment (ADR-022 §8) — the only place the weekly Plan is written. 7
/// plots (templates as tinted beds, modifiers as cages) + a detail card whose
/// chips/labels come from the Life JSON. Today = warm tint only, no glyph.
/// Schema-driven: template ids/labels, locked days and modifiers are all data.
class WeekScreen extends StatefulWidget {
  final Plan? debugPlan;
  final String? debugTodayKey;
  const WeekScreen({super.key, this.debugPlan, this.debugTodayKey});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  static const _weekdayKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  static const _order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _names = {
    'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday', 'thu': 'Thursday',
    'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
  };

  Plan? _plan;
  late final String _todayKey =
      widget.debugTodayKey ?? _weekdayKeys[DateTime.now().weekday % 7];
  late String _selected = _todayKey;
  String? _bounceMsg;
  Timer? _bounceTimer;

  @override
  void initState() {
    super.initState();
    _plan = widget.debugPlan;
    if (_plan == null) _load();
  }

  @override
  void dispose() {
    _bounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await AppStore.loadPlan();
    if (mounted) setState(() => _plan = p);
  }

  Future<void> _save(Plan p, {String? bounce}) async {
    setState(() {
      _plan = p;
      _bounceMsg = bounce;
    });
    if (bounce != null) {
      _bounceTimer?.cancel();
      _bounceTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _bounceMsg = null);
      });
    }
    await AppStore.savePlan(p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final plan = _plan;
    if (plan == null) return Center(child: CircularProgressIndicator(color: c.vine));

    return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [
      Text('The allotment', style: GoogleFonts.bricolageGrotesque(
          fontSize: 17, fontWeight: FontWeight.w600, color: c.salt)),
      const SizedBox(height: 4),
      for (final m in WeekModifiers.of(plan))
        Text(m.caption(plan),
            style: GoogleFonts.splineSansMono(fontSize: 11.5, color: c.dim)),
      const SizedBox(height: 12),
      _plotGrid(c, plan),
      const SizedBox(height: 14),
      _detailCard(c, plan),
      const SizedBox(height: 12),
      Center(
        child: GestureDetector(
          onTap: () => _save(PlannerLogic.applyBestSpacing(plan)),
          child: Text('↻ Re-sow the suggested week',
              style: TextStyle(fontSize: 12, color: c.dim,
                  decoration: TextDecoration.underline, decorationColor: c.dim)),
        ),
      ),
    ]);
  }

  Widget _plotGrid(AppPalette c, Plan plan) => Wrap(
        spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
        children: [for (final d in _order) _plot(c, plan, d)],
      );

  Widget _plot(AppPalette c, Plan plan, String day) {
    final entry = plan.week[day]!;
    final isToday = day == _todayKey;
    final tIdx = plan.dayTemplates.keys.toList().indexOf(entry.templateId);
    final tint = [c.plotA, c.plotB, c.plotC, c.plotD][tIdx < 0 ? 0 : tIdx % 4];
    final mods = WeekModifiers.of(plan).where((m) => m.isOn(entry)).toList();
    return GestureDetector(
      key: Key('plot-$day'),
      onTap: () => setState(() => _selected = day),
      child: Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: day == _selected ? c.vine : c.line,
              width: day == _selected ? 2 : 1),
          boxShadow: isToday
              ? [BoxShadow(color: c.todayTint, blurRadius: 10, spreadRadius: 1)]
              : null,
        ),
        child: Stack(children: [
          Center(
            child: Text(day[0].toUpperCase(),
                style: GoogleFonts.bricolageGrotesque(
                    fontSize: 22, fontWeight: FontWeight.w800, color: c.salt)),
          ),
          if (mods.isNotEmpty)
            Positioned(right: 7, top: 5,
                child: Text(mods.map((m) => m.glyph).join(),
                    style: TextStyle(fontSize: 12, color: c.salt))),
        ]),
      ),
    );
  }

  Widget _detailCard(AppPalette c, Plan plan) {
    final locked = plan.weekEditor.lockedDays.contains(_selected);
    final entry = plan.week[_selected]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.raise, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_names[_selected] ?? _selected,
            style: GoogleFonts.bricolageGrotesque(
                fontSize: 16, fontWeight: FontWeight.w700, color: c.salt)),
        const SizedBox(height: 12),
        if (locked)
          Text('held — edit in the plan',
              style: GoogleFonts.splineSansMono(fontSize: 11.5, color: c.dim))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in plan.dayTemplates.entries)
              GestureDetector(
                key: Key('chip-${t.key}'),
                onTap: () => _save(plan.copyWith(week: {
                      ...plan.week,
                      _selected: entry.copyWith(templateId: t.key),
                    })),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: entry.templateId == t.key ? c.vineDim : null,
                    border: Border.all(
                        color: entry.templateId == t.key ? c.vine : c.line),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(t.value.label,
                      style: TextStyle(fontSize: 12, color: c.salt)),
                ),
              ),
          ]),
        for (final m in WeekModifiers.of(plan)) ...[
          const SizedBox(height: 12),
          Row(children: [
            Text(m.glyph, style: TextStyle(fontSize: 14, color: c.salt)),
            const SizedBox(width: 10),
            Expanded(child: Text(m.id,
                style: GoogleFonts.splineSansMono(fontSize: 12, color: c.dim))),
            Switch(
              key: Key('mod-${m.id}'),
              value: m.isOn(entry),
              activeTrackColor: c.vine,
              onChanged: (_) {
                final r = m.toggle(plan, _selected);
                _save(r.plan, bounce: r.message);
              },
            ),
          ]),
        ],
        if (_bounceMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_bounceMsg!,
                style: GoogleFonts.splineSansMono(fontSize: 11, color: c.jammyText)),
          ),
      ]),
    );
  }
}
