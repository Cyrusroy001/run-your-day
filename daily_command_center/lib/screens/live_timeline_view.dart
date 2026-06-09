import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../data/state_store.dart';
import '../data/adherence_store.dart';
import '../data/teaching_flags.dart';
import '../logic/assembler.dart';
import '../logic/timeline.dart';
import '../logic/drift_engine.dart';
import '../logic/drift_copy.dart';
import '../logic/priority_level.dart';
import '../logic/weekly_review.dart';
import '../theme/app_palette.dart';
import '../widgets/budget_bar.dart';
import '../widgets/anchor_wall.dart';
import '../widgets/weekly_review_card.dart';
import '../widgets/teaching_card.dart';
import 'glossary_screen.dart';

class LiveTimelineView extends StatefulWidget {
  final Plan plan;
  final String todayKey;
  final double? debugNow;
  const LiveTimelineView({super.key, required this.plan, required this.todayKey, this.debugNow});

  @override
  State<LiveTimelineView> createState() => LiveTimelineViewState();
}

class LiveTimelineViewState extends State<LiveTimelineView> {
  DailyState _state = const DailyState(date: '');
  Set<String> _done = {};

  /// Exposed for widget tests only.
  Set<String> get doneSignatures => _done;
  WeeklySummary? _summary;
  String? _nudge;
  List<DayAdherence> _last7 = const [];
  bool _adjusting = false;
  DailyState? _checkpoint;
  String? _teachText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await StateStore.loadState(DateTime.now());
    final done = await AdherenceStore.loadDone(DateTime.now());
    final events = await StateStore.recentDriftEvents(DateTime.now(), days: 7);
    final last7 = await AdherenceStore.last7(DateTime.now());
    if (!mounted) return;
    setState(() {
      _state = state;
      _done = done;
      _summary = WeeklyReview.summarize(events);
      _nudge = DriftCopy.weeklyNudge(events);
      _last7 = last7;
    });
  }

  Future<void> _toggle(Block b) async {
    final next = {..._done};
    next.contains(b.signature) ? next.remove(b.signature) : next.add(b.signature);
    HapticFeedback.lightImpact();
    setState(() => _done = next);
    await AdherenceStore.saveDone(DateTime.now(), next);
    final entry = widget.plan.week[widget.todayKey];
    final assembled = entry == null
        ? <Block>[]
        : TimelineAssembler.assembleDay(widget.plan, entry.templateId, widget.todayKey,
            training: entry.training, state: _state);
    final t = assembled.where((x) => x.isTrackable).toList();
    await AdherenceStore.writeAdherence(DateTime.now(), t.where((x) => next.contains(x.signature)).length, t.length);
  }

  double _now() => widget.debugNow ?? nowDecimal();

  ResolvedDay resolve() {
    final entry = widget.plan.week[widget.todayKey];
    final assembled = entry == null
        ? <Block>[]
        : TimelineAssembler.assembleDay(widget.plan, entry.templateId, widget.todayKey,
            training: entry.training, state: _state);
    return DriftEngine.computeDay(assembled, now: _now(), done: _done, dateIso: _state.date);
  }

  String _fmt(double dec) {
    final h = dec.floor();
    final m = ((dec - h) * 60).round();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}';
  }

  String _anchorTimeText(Block b) {
    final tmpl = widget.plan.dayTemplates[widget.plan.week[widget.todayKey]?.templateId];
    final list = tmpl?.anchors.where((x) => x.id == b.id).toList() ?? const [];
    final a = list.isEmpty ? null : list.first;
    if (a == null) return _fmt(b.estStart);
    return a.end == null ? _fmt(b.estStart) : '${_fmt(b.estStart)}–${displayTime(a.end!)} · fixed';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final day = resolve();
    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: c.bg, foregroundColor: c.cream,
        title: Text(_adjusting ? 'Reshape' : 'Live', style: GoogleFonts.fraunces(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => setState(() => _adjusting = !_adjusting),
              child: Text(_adjusting ? 'Done' : 'Adjust today', style: TextStyle(color: c.terra, fontWeight: FontWeight.w600))),
        ],
      ),
      body: _adjusting ? _adjustBody(c, day) : _readonlyBody(c, day),
    );
  }

  Widget _readonlyBody(AppPalette c, ResolvedDay day) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTeach(day));
    final summary = _summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        if (summary != null)
          WeeklyReviewCard(summary: summary, isSunday: widget.todayKey == 'sun', nudge: _nudge, last7: _last7),
        if (_teachText != null)
          TeachingCard(
            text: _teachText!,
            onGotIt: () => setState(() => _teachText = null),
            onWhy: () {
              setState(() => _teachText = null);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlossaryScreen()));
            },
          ),
        _driftSummary(c, day),
        const SizedBox(height: 4),
        ..._rows(c, day),
      ],
    );
  }

  /// On first occurrence of a compaction/drop, surface a one-time explainer.
  void _maybeTeach(ResolvedDay day) {
    if (_teachText != null) return;
    final tmpl = widget.plan.dayTemplates[widget.plan.week[widget.todayKey]?.templateId];
    final anchorLabels = tmpl?.anchors.where((a) => a.hard).map((a) => a.label).toList();
    final anchor = (anchorLabels != null && anchorLabels.isNotEmpty) ? anchorLabels.first : 'what matters';
    final compacted = day.blocks.where((b) => b.isCompacted).toList();
    final dropped = day.blocks.where((b) => b.isDropped).toList();
    Future<void> trip(String concept, String text) async {
      if (await TeachingFlags.seen(concept)) return;
      await TeachingFlags.markSeen(concept);
      if (mounted) setState(() => _teachText = text);
    }
    if (dropped.isNotEmpty) {
      trip('drop', DriftCopy.teachDrop(itemLabel: dropped.first.label));
    } else if (compacted.isNotEmpty) {
      final b = compacted.first;
      trip('compaction', DriftCopy.teachCompaction(
          itemLabel: b.label, minutes: b.idealMinutes - b.durationMinutes, anchorLabel: anchor));
    }
  }

  // ── Adjust mode (writes DailyState only; routed through _commit) ───────────

  @visibleForTesting
  Future<void> reorderForTest(int oldIndex, int newIndex) => _onReorder(oldIndex, newIndex);
  @visibleForTesting
  Future<void> removeForTest(String id) => _remove(id);
  @visibleForTesting
  Future<void> restoreForTest(String id) => _restore(id);
  @visibleForTesting
  Future<void> setLevelForTest(String id, PriorityLevel lvl) => _setLevel(id, lvl);
  @visibleForTesting
  Future<void> undoForTest() => _undo();
  @visibleForTesting
  DailyState get stateForTest => _state;

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final day = resolve();
    if (day.blocks[oldIndex].isAnchor) return; // anchors frozen
    final ids = day.blocks.map((b) => b.id ?? '').toList();
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    await _commit(_state.copyWith(dailySequence: ids.where((e) => e.isNotEmpty).toList()), 'Reordered');
  }

  Future<void> _remove(String id) =>
      _commit(_state.copyWith(deletedItems: [..._state.deletedItems, id]), 'Removed for today');

  Future<void> _restore(String id) =>
      _commit(_state.copyWith(deletedItems: _state.deletedItems.where((x) => x != id).toList()), 'Restored');

  Future<void> _setLevel(String id, PriorityLevel lvl) => _commit(
      _state.copyWith(dailyOverrides: {..._state.dailyOverrides, id: ItemOverride(priority: lvl.toPriority())}),
      'Set ${lvl.label}');

  PriorityLevel _levelOf(Block b) =>
      PriorityLevel.fromPriority(_state.dailyOverrides[b.id]?.priority ?? b.priority);

  void _openLevelSheet(Block b) {
    final c = context.c;
    showModalBottomSheet(context: context, backgroundColor: c.panel, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Importance today · ${b.label}', style: TextStyle(color: c.cream))),
        for (final lvl in PriorityLevel.values)
          ListTile(title: Text(lvl.label, style: TextStyle(color: c.cream)),
              onTap: () { Navigator.pop(context); _setLevel(b.id!, lvl); }),
      ]),
    ));
  }

  Future<void> _commit(DailyState next, String message) async {
    // Collision: did this newly drop a block?
    final beforeDropped = resolve().blocks.where((b) => b.isDropped).map((b) => b.id).toSet();
    _checkpoint = _state;
    setState(() => _state = next);
    await StateStore.saveState(next);
    final afterDropped = resolve().blocks.where((b) => b.isDropped).toList();
    final newlyDropped = afterDropped.where((b) => !beforeDropped.contains(b.id)).toList();
    final msg = newlyDropped.isNotEmpty ? '${newlyDropped.first.label} dropped to make room' : message;
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      action: SnackBarAction(label: 'UNDO', onPressed: _undo),
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _undo() async {
    final cp = _checkpoint;
    if (cp == null) return;
    setState(() => _state = cp);
    await StateStore.saveState(cp);
    _checkpoint = null;
  }

  Widget _adjustBody(AppPalette c, ResolvedDay day) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('Drag to reorder · swipe to remove · anchors stay put. Only changes today.',
            style: TextStyle(fontSize: 11.5, color: c.dim))),
      Expanded(child: ReorderableListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        onReorder: _onReorder,
        buildDefaultDragHandles: false,
        footer: _removedTray(c),
        children: [
          for (int i = 0; i < day.blocks.length; i++)
            day.blocks[i].isAnchor
                ? KeyedSubtree(key: ValueKey('a-${day.blocks[i].id}'), child: _frozenAnchor(c, day.blocks[i]))
                : Dismissible(
                    key: ValueKey('e-${day.blocks[i].id}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _remove(day.blocks[i].id!),
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                        color: c.terraD, child: Icon(Icons.delete_outline, color: c.terra)),
                    child: ReorderableDragStartListener(index: i, child: _adjustRow(c, day.blocks[i])),
                  ),
        ],
      )),
    ]);
  }

  Widget _frozenAnchor(AppPalette c, Block b) => Container(
        margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: c.terraD, border: Border.all(color: c.terra), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text('🔒', style: TextStyle(color: c.terra)), const SizedBox(width: 10),
          Expanded(child: Text('${b.label} · anchor — can’t move', style: TextStyle(fontSize: 12.5, color: c.terra, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _adjustRow(AppPalette c, Block b) {
    final lvl = _levelOf(b);
    final lvlColor = lvl == PriorityLevel.protect ? c.moss : lvl == PriorityLevel.dropFirst ? c.amber : c.muted;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.drag_indicator, color: c.dim, size: 18), const SizedBox(width: 8),
        Expanded(child: Text(b.label, style: TextStyle(fontSize: 13, color: c.cream))),
        GestureDetector(
          onTap: () => _openLevelSheet(b),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: lvl == PriorityLevel.normal ? c.line : lvlColor),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('${lvl.label} ▾', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: lvlColor)),
          ),
        ),
      ]),
    );
  }

  Widget _removedTray(AppPalette c) {
    if (_state.deletedItems.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('↺ Removed today (${_state.deletedItems.length})', style: TextStyle(fontSize: 12, color: c.muted)),
        const SizedBox(height: 6),
        ..._state.deletedItems.map((id) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(id, style: TextStyle(fontSize: 12, color: c.dim)),
            GestureDetector(onTap: () => _restore(id), child: Text('Restore', style: TextStyle(fontSize: 12, color: c.terra, fontWeight: FontWeight.w600))),
          ]))),
      ]),
    );
  }

  Widget _driftSummary(AppPalette c, ResolvedDay day) {
    final text = DriftCopy.summary(day);
    final ok = text.startsWith('On track');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? c.mossD : c.amberD,
        border: Border.all(color: ok ? c.moss : c.amber),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.4, color: ok ? c.muted : c.cream)),
    );
  }

  List<Widget> _rows(AppPalette c, ResolvedDay day) {
    final out = <Widget>[];
    final activeIdx = day.blocks.indexWhere((b) => !b.isAnchor && !b.isDropped && !_done.contains(b.signature) && _now() >= b.estStart);
    for (int i = 0; i < day.blocks.length; i++) {
      final b = day.blocks[i];
      if (b.isAnchor) { out.add(AnchorWall(block: b, timeText: _anchorTimeText(b))); continue; }
      if (b.isDropped) { out.add(_droppedRow(c, b)); continue; }
      final done = _done.contains(b.signature);
      final w = (i == activeIdx) ? _activeRow(c, b) : _normalRow(c, b, done);
      out.add(GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _toggle(b), child: w));
    }
    return out;
  }

  Widget _normalRow(AppPalette c, Block b, bool done) => Container(
        decoration: b.isCompacted ? BoxDecoration(border: Border(left: BorderSide(color: c.amber, width: 2))) : null,
        padding: EdgeInsets.only(left: b.isCompacted ? 9 : 0, top: 9, bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _check(c, done, false),
          const SizedBox(width: 10),
          SizedBox(width: 42, child: Text(_fmt(b.estStart), style: TextStyle(fontSize: 11, color: c.dim))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.label, style: TextStyle(fontSize: 13.5,
                color: done ? c.muted : c.cream,
                decoration: done ? TextDecoration.lineThrough : null, decorationColor: c.dim)),
            if (!done) Padding(padding: const EdgeInsets.only(top: 6), child: BudgetBar(idealMinutes: b.idealMinutes, currentMinutes: b.durationMinutes)),
          ])),
          if (b.isCompacted)
            IconButton(
              icon: Icon(Icons.info_outline, size: 16, color: c.dim),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                final tmpl = widget.plan.dayTemplates[widget.plan.week[widget.todayKey]?.templateId];
                final hardAnchors = tmpl?.anchors.where((a) => a.hard).map((a) => a.label).toList() ?? const [];
                final anchorLabel = hardAnchors.isEmpty ? 'what matters' : hardAnchors.first;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(DriftCopy.peek(b, anchorLabel: anchorLabel))));
              },
            ),
        ]),
      );

  Widget _activeRow(AppPalette c, Block b) {
    final spent = (b.durationMinutes <= 0) ? 0.0 : ((_now() - b.estStart) / (b.durationMinutes / 60.0)).clamp(0.0, 1.0);
    final left = ((b.estStart + b.durationMinutes / 60.0 - _now()) * 60).round().clamp(0, 100000);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.terra), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _check(c, false, true),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.cream)),
          const SizedBox(height: 7),
          BudgetBar(idealMinutes: b.idealMinutes, currentMinutes: b.durationMinutes, activeSpent: spent),
          const SizedBox(height: 4),
          Text('$left m left of ${b.durationMinutes}m budget', style: TextStyle(fontSize: 11.5, color: c.terra, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Widget _droppedRow(AppPalette c, Block b) => Opacity(
        opacity: .5,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            const SizedBox(width: 29),
            Expanded(child: Text('${b.label} · dropped to protect your evening',
                style: TextStyle(fontSize: 12, color: c.dim, decoration: TextDecoration.lineThrough))),
          ])),
      );

  Widget _check(AppPalette c, bool done, bool cur) => Container(
        width: 19, height: 19, margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          color: done ? c.moss : Colors.transparent,
          border: Border.all(color: done ? c.moss : (cur ? c.terra : c.dim), width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: done ? Icon(Icons.check, size: 13, color: c.bg) : null,
      );
}
