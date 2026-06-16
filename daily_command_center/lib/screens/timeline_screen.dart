import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/state_store.dart';
import '../data/adherence_store.dart';
import '../data/day_actions.dart';
import '../logic/assembler.dart';
import '../logic/timeline.dart';
import '../logic/drift_engine.dart';
import '../logic/priority_level.dart';
import '../theme/app_palette.dart';
import '../widgets/elastic_rail.dart';
import '../widgets/add_task_fab.dart';

/// The timeline rail + Adjust mode, split out of Today (G4.2). Pure move — the
/// vine look lands in G6. Today keeps its own read-only "rest of today" rail;
/// this screen shows the FULL day and lets you reorder/skip/prioritize.
class TimelineScreen extends StatefulWidget {
  final Plan? debugPlan;
  final double? debugNow;
  final String? debugTodayKey;
  const TimelineScreen({super.key, this.debugPlan, this.debugNow, this.debugTodayKey});

  @override
  State<TimelineScreen> createState() => TimelineScreenState();
}

class TimelineScreenState extends State<TimelineScreen> {
  Plan? _plan;
  DailyState _state = const DailyState(date: '');
  Set<String> _done = {};
  bool _adjusting = false;
  DailyState? _checkpoint;
  String? _undoMsg;
  Timer? _ticker;

  static const _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  late String _todayKey;

  /// Test seams.
  Set<String> get doneSignatures => _done;
  @visibleForTesting
  DailyState get stateForTest => _state;
  @visibleForTesting
  Future<void> loadForTest() => _load();
  @visibleForTesting
  List<Block> get blocksForTest => _resolve(_plan!).blocks;

  @override
  void initState() {
    super.initState();
    _todayKey = widget.debugTodayKey ?? _days[DateTime.now().weekday % 7];
    _plan = widget.debugPlan;
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    Plan plan;
    if (widget.debugPlan != null) {
      plan = widget.debugPlan!;
    } else {
      final doc = await AppStore.repo.loadActive();
      plan = doc.plan;
    }
    final state = await StateStore.loadState(now);
    final done = await AdherenceStore.loadDone(now);

    if (!mounted) return;
    setState(() {
      _plan = plan;
      _state = state;
      _done = done;
    });
    if (widget.debugPlan == null) AppStore.writeWidgetData(plan, _todayKey).ignore();
  }

  // ── engine ───────────────────────────────────────────────────────────────
  double _now() => widget.debugNow ?? nowDecimal();

  List<Block> _assemble(Plan plan) {
    final entry = plan.week[_todayKey];
    return entry == null
        ? const []
        : TimelineAssembler.assembleDay(plan, entry.templateId, _todayKey,
            training: entry.training, state: _state);
  }

  ResolvedDay _resolve(Plan plan) =>
      DriftEngine.computeDay(_assemble(plan), now: _now(), done: _done, dateIso: _state.date);

  Future<void> _toggle(Block b) async {
    final plan = _plan;
    if (plan == null) return;
    HapticFeedback.lightImpact();
    final next = await DayActions.togglePick(
        block: b, done: _done, assembled: _assemble(plan),
        driftLog: _state.driftLog, now: _now(),
        plan: widget.debugPlan == null ? plan : null, todayKey: _todayKey);
    if (mounted) setState(() => _done = next);
  }

  // ── time + label formatting ────────────────────────────────────────────────
  String _fmt(double dec) {
    final h = dec.floor();
    final m = ((dec - h) * 60).round();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}';
  }

  /// ish-time rule (spec): flexible & on-the-hour & not drifted → "{h}-ish";
  /// engine-moved estimate → "~{time}"; anchors / custom / exact → exact.
  String _ishTime(Block b) {
    final exact = _fmt(b.estStart);
    if (b.isAnchor || b.isCustom) return exact;
    if ((b.estStart - b.seedStart).abs() >= 1 / 60) return '~$exact';
    final m = ((b.estStart - b.estStart.floor()) * 60).round();
    if (m == 0) {
      final h = b.estStart.floor();
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12-ish';
    }
    return exact;
  }

  String _durLabel(int m) {
    if (m <= 0) return '';
    if (m % 60 == 0) return '${m ~/ 60} h';
    if (m > 60) return '${(m / 60).toStringAsFixed(1)} h';
    return '$m min';
  }

  Anchor? _anchorFor(Block b) {
    final tmpl = _plan?.dayTemplates[_plan?.week[_todayKey]?.templateId];
    final list = tmpl?.anchors.where((a) => a.id == b.id).toList() ?? const [];
    return list.isEmpty ? null : list.first;
  }

  String _sub(Block b) {
    if (b.isAnchor) {
      final a = _anchorFor(b);
      return (a?.end == null) ? 'held' : 'held · ${_fmt(b.estStart)} → ${displayTime(a!.end!)}';
    }
    if (b.isDropped) return 'skipped today';
    if (b.isCompacted) return '−${b.idealMinutes - b.durationMinutes} min · ${b.durationMinutes} min';
    return _durLabel(b.durationMinutes);
  }

  RailVariant _variant(Block b) {
    if (_done.contains(b.signature)) return RailVariant.done;
    if (b.isDropped) return RailVariant.skip;
    if (b.isAnchor) return RailVariant.anchor;
    if (b.isCompacted) return RailVariant.squeeze;
    return RailVariant.normal;
  }

  // ── adjust mode (writes DailyState only) ───────────────────────────────────
  PriorityLevel _levelOf(Block b) =>
      PriorityLevel.fromPriority(_state.dailyOverrides[b.id]?.priority ?? b.priority);

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final day = _resolve(_plan!);
    if (day.blocks[oldIndex].isAnchor) return;
    final ids = day.blocks.map((b) => b.id ?? '').toList();
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    await _commit(_state.copyWith(dailySequence: ids.where((e) => e.isNotEmpty).toList()), 'Reordered');
  }

  Future<void> _remove(Block b) =>
      _commit(_state.copyWith(deletedItems: [..._state.deletedItems, b.id!]), '${b.label} skipped today');

  Future<void> _setLevel(Block b, PriorityLevel lvl) => _commit(
      _state.copyWith(dailyOverrides: {..._state.dailyOverrides, b.id!: ItemOverride(priority: lvl.toPriority())}),
      'Set ${lvl.label}');

  Future<void> _commit(DailyState next, String message) async {
    final beforeDropped = _resolve(_plan!).blocks.where((b) => b.isDropped).map((b) => b.id).toSet();
    _checkpoint = _state;
    setState(() => _state = next);
    await StateStore.saveState(next);
    final afterDropped = _resolve(_plan!).blocks.where((b) => b.isDropped).toList();
    final newlyDropped = afterDropped.where((b) => !beforeDropped.contains(b.id)).toList();
    if (!mounted) return;
    setState(() => _undoMsg =
        newlyDropped.isNotEmpty ? '${newlyDropped.first.label} dropped to make room' : message);
  }

  Future<void> _undo() async {
    final cp = _checkpoint;
    if (cp == null) return;
    setState(() { _state = cp; _undoMsg = null; });
    await StateStore.saveState(cp);
    _checkpoint = null;
  }

  @visibleForTesting
  Future<void> removeForTest(Block b) => _remove(b);
  @visibleForTesting
  Future<void> undoForTest() => _undo();
  @visibleForTesting
  Future<void> setLevelForTest(Block b, PriorityLevel lvl) => _setLevel(b, lvl);

  // ── custom tasks ───────────────────────────────────────────────────────────
  Future<void> _commitAdd(CustomTask task, List<String> dropIds) => _commit(
      _state.copyWith(addedItems: [..._state.addedItems, task], deletedItems: [..._state.deletedItems, ...dropIds]),
      '"${task.label}" added');

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final plan = _plan;
    if (plan == null) return Scaffold(body: Center(child: CircularProgressIndicator(color: c.vine)));
    final day = _resolve(plan);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _adjusting ? _adjustBody(c, day) : _railBody(c, day),
      ),
      floatingActionButton: _adjusting
          ? null
          : AddTaskFab(
              dateIso: _state.date,
              assembled: () => _assemble(_plan!),
              onCommit: (task, dropIds) => _commitAdd(task, dropIds),
              onMessage: (m) => setState(() => _undoMsg = m)),
    );
  }

  // ── TIMELINE (read-only rail over the full day) ─────────────────────────────
  Widget _railBody(AppPalette c, ResolvedDay day) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 0, 14),
          child: Row(children: [
            Text('Timeline', style: GoogleFonts.bricolageGrotesque(
                fontSize: 17, fontWeight: FontWeight.w600, color: c.salt)),
            const Spacer(),
            OutlinedButton(
              onPressed: () => setState(() => _adjusting = true),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.line), foregroundColor: c.dim,
                  shape: const StadiumBorder()),
              child: Text('ADJUST', style: GoogleFonts.splineSansMono(
                  fontSize: 12, letterSpacing: 1.2, color: c.dim)),
            ),
          ]),
        ),
        ElasticRail(stops: [
          for (final b in day.blocks)
            RailStop(
              time: _ishTime(b), label: b.label, sub: _sub(b),
              variant: _variant(b),
              durationMinutes: b.durationMinutes <= 0 ? b.idealMinutes : b.durationMinutes,
              locked: b.isAnchor,
              onTap: b.isAnchor ? null : () => _toggle(b)),
        ]),
      ],
    );
  }

  // ── ADJUST mode (two-row cards, no Stack overlap) ───────────────────────────
  Widget _adjustBody(AppPalette c, ResolvedDay day) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
        child: Row(children: [
          Text('Adjusting today', style: GoogleFonts.bricolageGrotesque(fontSize: 17, fontWeight: FontWeight.w600, color: c.salt)),
          const Spacer(),
          FilledButton(
            onPressed: () => setState(() => _adjusting = false),
            style: FilledButton.styleFrom(backgroundColor: c.vine, foregroundColor: c.onAccent,
                shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8)),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        child: Align(alignment: Alignment.centerLeft,
          child: Text('Drag ≡ to reorder · skip removes today only',
              style: GoogleFonts.splineSansMono(fontSize: 11, color: c.dim))),
      ),
      Expanded(
        child: ReorderableListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          onReorder: _onReorder,
          buildDefaultDragHandles: false,
          children: [
            for (int i = 0; i < day.blocks.length; i++)
              day.blocks[i].isAnchor
                  ? KeyedSubtree(key: ValueKey('a-${day.blocks[i].id}'), child: _lockedRow(c, day.blocks[i]))
                  : KeyedSubtree(key: ValueKey('e-${day.blocks[i].id}'), child: _adjustCard(c, day.blocks[i], i)),
          ],
        ),
      ),
      if (_undoMsg != null) _undoBar(c),
    ]);
  }

  Widget _lockedRow(AppPalette c, Block b) => Container(
        margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.salt)),
        child: Row(children: [
          Text('◉', style: TextStyle(color: c.dim, fontSize: 12)), const SizedBox(width: 8),
          Expanded(child: Text(b.label, style: GoogleFonts.bricolageGrotesque(fontSize: 15, fontWeight: FontWeight.w600, color: c.salt))),
          Text('locked — edit in Plan my week', style: GoogleFonts.splineSansMono(fontSize: 10.5, color: c.dim)),
        ]),
      );

  Widget _adjustCard(AppPalette c, Block b, int i) {
    final lvl = _levelOf(b);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      decoration: BoxDecoration(color: c.raise, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(b.label, style: GoogleFonts.bricolageGrotesque(fontSize: 15, fontWeight: FontWeight.w600, color: c.salt))),
          ReorderableDragStartListener(index: i,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text('≡', style: TextStyle(color: c.dim, fontSize: 18, letterSpacing: 1)))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _prioControl(c, b, lvl),
          const Spacer(),
          GestureDetector(
            onTap: () => _remove(b),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: c.line)),
              child: Text('✕ skip', style: GoogleFonts.splineSansMono(fontSize: 10.5, color: c.dim)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _prioControl(AppPalette c, Block b, PriorityLevel cur) {
    Widget seg(PriorityLevel lvl, String label) {
      final on = lvl == cur;
      final warn = lvl == PriorityLevel.dropFirst;
      final fg = !on ? c.dim : (warn ? c.jammyText : c.vine);
      final bg = !on ? null : (warn ? c.jammyDim : c.vineDim);
      return GestureDetector(
        onTap: () => _setLevel(b, lvl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          color: bg,
          child: Text(label, style: GoogleFonts.splineSansMono(fontSize: 10.5, color: fg)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: c.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          seg(PriorityLevel.protect, 'Protect'),
          seg(PriorityLevel.normal, 'Normal'),
          seg(PriorityLevel.dropFirst, 'Drop first'),
        ]),
      ),
    );
  }

  Widget _undoBar(AppPalette c) => Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 16), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: c.raise2, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
        child: Row(children: [
          Expanded(child: Text(_undoMsg!, style: TextStyle(fontSize: 13, color: c.salt))),
          GestureDetector(onTap: _undo, child: Text('Undo', style: TextStyle(fontSize: 13, color: c.vine, fontWeight: FontWeight.w600))),
        ]),
      );
}
