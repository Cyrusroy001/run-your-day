import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/state_store.dart';
import '../data/adherence_store.dart';
import '../data/day_actions.dart';
import '../data/recurring_store.dart';
import '../data/teaching_flags.dart';
import '../data/ui_prefs.dart';
import '../data/notifications.dart';
import '../logic/heads_up.dart';
import '../main.dart' show RemindersApp;
import '../logic/assembler.dart';
import '../logic/timeline.dart';
import '../logic/drift_engine.dart';
import '../logic/drift_copy.dart';
import '../logic/home_now_state.dart';
import '../logic/custom_task_fitter.dart';
import '../logic/priority_level.dart';
import '../logic/weekly_review.dart';
import '../logic/blueprint_promotion.dart';
import '../theme/app_palette.dart';
import '../theme/transitions.dart';
import '../widgets/elastic_rail.dart';
import '../widgets/add_custom_task_sheet.dart';
import '../widgets/sacrifice_picker_sheet.dart';
import '../widgets/promote_blueprint_sheet.dart';
import '../widgets/teach_caption.dart';
import '../widgets/avatar_menu_sheet.dart';
import '../widgets/repeat_prompt_card.dart';
import 'settings_screen.dart';
import 'how_it_works_screen.dart';
import 'week_screen.dart';
import 'catchup_screen.dart';

/// The one ketchup surface: Home + Live merged. States are caughtUp / squeezed /
/// adjusting, driven by the engine's ResolvedDay + an [_adjusting] flag. The hero
/// is the timeline's first live stop, enlarged; the rest is the elastic rail.
class TodayScreen extends StatefulWidget {
  final Plan? debugPlan;
  final double? debugNow;
  final String? debugTodayKey;
  const TodayScreen({super.key, this.debugPlan, this.debugNow, this.debugTodayKey});

  @override
  State<TodayScreen> createState() => TodayScreenState();
}

class TodayScreenState extends State<TodayScreen> {
  Plan? _plan;
  String _displayName = '';
  DailyState _state = const DailyState(date: '');
  Set<String> _done = {};
  bool _adjusting = false;
  DailyState? _checkpoint;
  String? _undoMsg;
  String? _teachText;
  Timer? _ticker;
  WeeklySummary? _summary;
  String? _topSqueezed;
  String? _notifKey; // de-dupes heads-up rescheduling across rebuilds/ticks
  List<DayAdherence> _last7 = const [];
  List<CustomTask> _pendingRepeatTasks = const [];
  List<PromotionCandidate> _promotionCandidates = const [];

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
    String name;
    if (widget.debugPlan != null) {
      plan = widget.debugPlan!;
      name = _displayName.isEmpty ? 'Cyrus' : _displayName;
    } else {
      final doc = await AppStore.repo.loadActive();
      plan = doc.plan;
      name = doc.displayName;
    }
    final state = await StateStore.loadState(now);
    final done = await AdherenceStore.loadDone(now);
    final events = await StateStore.recentDriftEvents(now, days: 7);
    final last7 = await AdherenceStore.last7(now);

    // Yesterday's completed one-off custom tasks → "repeat?" prompts.
    final yesterday = now.subtract(const Duration(days: 1));
    final yState = await StateStore.loadState(yesterday);
    final yDone = await AdherenceStore.loadDone(yesterday);
    final allRecurring = await RecurringStore.loadAll();
    final skippedIds = await _loadSkippedRepeatIds();
    final recurringOriginIds = allRecurring.map((t) => t.originTaskId).toSet();
    final pending = yState.addedItems.where((t) {
      final sig = '${displayTime(t.startTime)}|${t.label}';
      return yDone.contains(sig) && !recurringOriginIds.contains(t.id) && !skippedIds.contains(t.id);
    }).toList();

    var promotions = const <PromotionCandidate>[];
    if (_todayKey == 'sun') {
      final recentStates = await StateStore.recentStates(now, days: 7);
      final existingLabels = plan.dayTemplates.values
          .expand((t) => t.routineStack).map((r) => r.label).toSet();
      promotions = WeeklyReview.promotionCandidates(recentStates)
          .where((c) => !existingLabels.contains(c.label)).toList();
    }

    if (!mounted) return;
    setState(() {
      _plan = plan;
      _displayName = name;
      _state = state;
      _done = done;
      _summary = WeeklyReview.summarize(events);
      _topSqueezed = WeeklyReview.mostSqueezedLabel(events);
      _last7 = last7;
      _pendingRepeatTasks = pending;
      _promotionCandidates = promotions;
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
  void _openAddCustomTask() => showAddCustomTaskSheet(context, onSubmit: _addCustomTask);

  Future<void> _addCustomTask(String label, String time, int durationMinutes) async {
    final plan = _plan;
    final entry = plan?.week[_todayKey];
    if (plan == null || entry == null) return;
    final assembled = _assemble(plan);
    final task = CustomTask(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: label, startTime: time, durationMinutes: durationMinutes, date: _state.date);
    if (CustomTaskFitter.compactionSlack(assembled) >= durationMinutes) {
      await _insertCustomTask(task, drop: const []);
      return;
    }
    final offers = CustomTaskFitter.computeOffers(assembled, durationMinutes);
    if (offers.isEmpty) {
      if (mounted) setState(() => _undoMsg = 'No room today — try a shorter task');
      return;
    }
    if (!mounted) return;
    showSacrificePickerSheet(context, offers: offers, taskLabel: label,
        onConfirm: (offer) => _insertCustomTask(task, drop: offer.drop));
  }

  Future<void> _insertCustomTask(CustomTask task, {required List<Block> drop}) async {
    final dropIds = drop.map((b) => b.id).whereType<String>().toList();
    await _commit(
      _state.copyWith(addedItems: [..._state.addedItems, task], deletedItems: [..._state.deletedItems, ...dropIds]),
      '"${task.label}" added');
  }

  // ── repeat + promotion ─────────────────────────────────────────────────────
  Future<Set<String>> _loadSkippedRepeatIds() async =>
      (await AppStore.repo.loadActive()).skippedRepeatIds.toSet();

  Future<void> _createRecurringTask(CustomTask task, String date) async {
    await RecurringStore.save(RecurringCustomTask(
      id: 'recur_${DateTime.now().millisecondsSinceEpoch}',
      label: task.label, preferredTime: task.startTime, durationMinutes: task.durationMinutes,
      activeDates: [date], originTaskId: task.id));
    if (mounted) setState(() => _pendingRepeatTasks = _pendingRepeatTasks.where((t) => t.id != task.id).toList());
  }

  Future<void> _skipRepeatTask(CustomTask task) async {
    final doc = await AppStore.repo.loadActive();
    if (!doc.skippedRepeatIds.contains(task.id)) {
      await AppStore.repo.save(doc.copyWith(skippedRepeatIds: [...doc.skippedRepeatIds, task.id]));
    }
    if (mounted) setState(() => _pendingRepeatTasks = _pendingRepeatTasks.where((t) => t.id != task.id).toList());
  }

  void _openPromoteSheet(PromotionCandidate cand) {
    final templates = _plan!.dayTemplates.entries.map((e) => (id: e.key, label: e.value.label)).toList();
    showPromoteToBlueprintSheet(context, candidate: cand, templates: templates,
        onConfirm: (label, time, dur, ids) => _applyPromotion(cand, label, time, dur, ids));
  }

  Future<void> _applyPromotion(
      PromotionCandidate cand, String label, String time, int dur, List<String> templateIds) async {
    await AppStore.savePlan(BlueprintPromotion.promote(_plan!,
        label: label, time: time, durationMinutes: dur, templateIds: templateIds));
    for (final r in (await RecurringStore.loadAll()).where((r) => r.label == cand.label)) {
      await RecurringStore.removeById(r.id);
    }
    if (mounted) {
      setState(() => _promotionCandidates =
          _promotionCandidates.where((p) => p.label != cand.label).toList());
    }
  }

  void _dismissPromotion(PromotionCandidate cand) =>
      setState(() => _promotionCandidates = _promotionCandidates.where((p) => p.label != cand.label).toList());

  /// "Give it more time" from the Sunday catch-up — the only review→Plan write
  /// path. Adds [mins] to every routine item carrying [label] across templates.
  Future<void> _giveMoreTime(String label, int mins) async {
    final plan = _plan;
    if (plan == null) return;
    final templates = plan.dayTemplates.map((k, t) => MapEntry(k, t.copyWith(
        routineStack: t.routineStack
            .map((r) => r.label == label ? r.copyWith(idealDuration: r.idealDuration + mins) : r)
            .toList())));
    final updated = plan.copyWith(dayTemplates: templates);
    await AppStore.savePlan(updated);
    if (mounted) setState(() => _plan = updated);
  }

  @visibleForTesting
  Future<void> giveMoreTimeForTest(String label, int mins) => _giveMoreTime(label, mins);

  // ── teaching ───────────────────────────────────────────────────────────────
  void _maybeTeach(ResolvedDay day) {
    if (_teachText != null) return;
    final tmpl = _plan?.dayTemplates[_plan?.week[_todayKey]?.templateId];
    final anchorLabels = tmpl?.anchors.where((a) => a.hard).map((a) => a.label).toList();
    final anchor = (anchorLabels != null && anchorLabels.isNotEmpty) ? anchorLabels.first : 'what matters';
    final dropped = day.blocks.where((b) => b.isDropped).toList();
    final compacted = day.blocks.where((b) => b.isCompacted).toList();
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

  /// Reschedule today's opt-in heads-ups when the plan/state/pref changes. Runs
  /// only in the real app (tests inject debugPlan and have no notification
  /// platform channel). Empty list = a clean cancel when the toggle is off.
  void _maybeScheduleHeadsUps(BuildContext context, ResolvedDay day) {
    if (widget.debugPlan != null) return;
    final prefs = RemindersApp.of(context)?.prefs ?? const UiPrefs();
    final caughtUp = DriftCopy.isCaughtUp(day);
    final sigs = day.blocks.map((b) => b.signature).join(',');
    final key = '${prefs.headsUp}|$caughtUp|$sigs';
    if (key == _notifKey) return;
    _notifKey = key;
    final ups = prefs.headsUp
        ? planHeadsUps(blocks: day.blocks, now: DateTime.now(), caughtUp: caughtUp)
        : const <HeadsUp>[];
    NotificationService.scheduleHeadsUps(ups);
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final plan = _plan;
    if (plan == null) return Scaffold(body: Center(child: CircularProgressIndicator(color: c.vine)));
    final day = _resolve(plan);
    final now = HomeNowState.from(day, now: _now(), done: _done);
    _maybeScheduleHeadsUps(context, day);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _adjusting ? _adjustBody(c, day) : _todayBody(c, day, now),
      ),
      floatingActionButton: _adjusting
          ? null
          : FloatingActionButton(
              heroTag: 'add_custom_task', onPressed: _openAddCustomTask,
              backgroundColor: c.vine, foregroundColor: c.onAccent,
              child: const Icon(Icons.add)),
    );
  }

  // ── TODAY (read-only) ────────────────────────────────────────────────────────
  Widget _todayBody(AppPalette c, ResolvedDay day, HomeNowState now) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTeach(day));
    final blocks = day.blocks;
    final heroIdx = now.currentSignature == null
        ? -1
        : blocks.indexWhere((b) => b.signature == now.currentSignature);
    final railBlocks = heroIdx >= 0 ? blocks.sublist(heroIdx + 1) : blocks;
    final pastDone = (heroIdx >= 0 ? blocks.sublist(0, heroIdx) : const <Block>[])
        .where((b) => b.isTrackable && _done.contains(b.signature)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _header(c),
        if (pastDone.isNotEmpty) _pastPill(c, pastDone),
        _hero(c, day, now),
        _whisper(c, day),
        if (_teachText != null)
          TeachCaption(
            text: _teachText!,
            onDismiss: () => setState(() => _teachText = null),
            onWhy: () {
              setState(() => _teachText = null);
              Navigator.of(context).push(fadeThroughRoute(const HowItWorksScreen()));
            }),
        for (final task in _pendingRepeatTasks)
          RepeatPromptCard(task: task,
              onRepeat: (date) => _createRecurringTask(task, date), onSkip: () => _skipRepeatTask(task)),
        const SizedBox(height: 8),
        ElasticRail(header: 'Rest of today', stops: [
          for (final b in railBlocks)
            RailStop(
              time: _ishTime(b), label: b.label, sub: _sub(b),
              variant: _variant(b),
              durationMinutes: b.durationMinutes <= 0 ? b.idealMinutes : b.durationMinutes,
              locked: b.isAnchor,
              onTap: b.isAnchor ? null : () => _toggle(b)),
        ]),
        const SizedBox(height: 18),
        Center(
          child: OutlinedButton(
            onPressed: () => setState(() => _adjusting = true),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.line), foregroundColor: c.dim,
                shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
            child: Text('ADJUST TODAY',
                style: GoogleFonts.splineSansMono(fontSize: 12, letterSpacing: 1.2, color: c.dim)),
          ),
        ),
      ],
    );
  }

  Widget _header(AppPalette c) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 0, 14),
        child: Row(children: [
          Expanded(
            child: Text(DateFormat('EEEE d MMMM').format(DateTime.now()),
                style: GoogleFonts.bricolageGrotesque(
                    fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: c.salt)),
          ),
          GestureDetector(
            key: const Key('avatar-menu-button'),
            onTap: () => showAvatarMenu(context,
                name: _displayName.isEmpty ? 'Profile' : _displayName,
                subtitle: _plan?.meta.lifestyleArchetype ?? '',
                onPlanWeek: () => Navigator.of(context).push(fadeThroughRoute(WeekScreen(
                    plan: _plan!, todayKey: _todayKey,
                    onChanged: (p) { AppStore.savePlan(p); setState(() => _plan = p); }))),
                onCatchup: _summary == null ? null : () => Navigator.of(context).push(fadeThroughRoute(CatchupScreen(
                    summary: _summary!, last7: _last7, insightLabel: _topSqueezed,
                    promotionCandidates: _promotionCandidates,
                    onPromote: _openPromoteSheet, onDismiss: _dismissPromotion,
                    onGiveMoreTime: _giveMoreTime))),
                catchupBadge: _todayKey == 'sun',
                onSwitchProfile: () => AppStore.repo.clearActive(),
                onOpenSettings: () => Navigator.of(context).push(fadeThroughRoute(const SettingsScreen())),
                onOpenGlossary: () => Navigator.of(context).push(fadeThroughRoute(const HowItWorksScreen())),
                onLogout: () => AppStore.repo.clearActive()),
            child: CircleAvatar(radius: 17, backgroundColor: c.vine,
                child: Text(_displayName.isEmpty ? '?' : _displayName[0].toUpperCase(),
                    style: GoogleFonts.bricolageGrotesque(
                        color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 14))),
          ),
        ]),
      );

  Widget _pastPill(AppPalette c, List<Block> done) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line, style: BorderStyle.solid)),
        child: Row(children: [
          Text('✓✓', style: TextStyle(color: c.vine, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Earlier done — ${done.map((b) => b.label).join(', ')}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: c.dim)),
          ),
        ]),
      );

  Widget _hero(AppPalette c, ResolvedDay day, HomeNowState now) {
    final caughtUp = DriftCopy.isCaughtUp(day);
    if (now.isResting || now.isDayDone) {
      final title = now.isDayDone ? 'Nothing left today.' : (now.nextLabel.isEmpty ? 'Still resting' : 'Up next');
      return _heroShell(c, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.bricolageGrotesque(fontSize: 30, fontWeight: FontWeight.w800, height: 1.05, color: c.salt)),
        if (now.isDayDone) Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('Go be a person.', style: TextStyle(color: c.dim, fontSize: 14))),
        if (!now.isDayDone && now.nextLabel.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('${now.nextTime} · ${now.nextLabel}',
                style: GoogleFonts.splineSansMono(fontSize: 13, color: c.dim))),
      ]));
    }
    final end = _fmt(_now() + now.minutesLeft / 60.0);
    return _heroShell(c, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _nowPill(c),
        const Spacer(),
        Text('until ~$end', style: GoogleFonts.splineSansMono(fontSize: 12, color: c.dim)),
      ]),
      const SizedBox(height: 10),
      Text(now.currentLabel, style: GoogleFonts.bricolageGrotesque(fontSize: 32, fontWeight: FontWeight.w800, height: 1.02, letterSpacing: -0.5, color: c.salt)),
      const SizedBox(height: 12),
      caughtUp ? _chip(c, '✓ all caught up', c.vine, c.vineDim) : _chip(c, '~ squeezed', c.jammyText, c.jammyDim),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(value: now.progress, minHeight: 3,
            backgroundColor: c.line, valueColor: AlwaysStoppedAnimation(c.vine))),
      const SizedBox(height: 12),
      Row(children: [
        Text('${now.minutesLeft} min', style: GoogleFonts.splineSansMono(fontSize: 12.5, color: c.salt, fontWeight: FontWeight.w500)),
        Text(' left', style: GoogleFonts.splineSansMono(fontSize: 12.5, color: c.dim)),
        const Spacer(),
        FilledButton(
          onPressed: now.currentSignature == null ? null : () {
            final b = day.blocks.firstWhere((x) => x.signature == now.currentSignature);
            _toggle(b);
          },
          style: FilledButton.styleFrom(backgroundColor: c.vine, foregroundColor: c.onAccent,
              shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        ),
      ]),
    ]));
  }

  Widget _heroShell(AppPalette c, {required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(color: c.raise, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(22)),
        child: child);

  Widget _nowPill(AppPalette c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: c.ripe, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text('NOW', style: GoogleFonts.splineSansMono(fontSize: 11, letterSpacing: 1.4, color: c.ripe)),
      ]);

  Widget _chip(AppPalette c, String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: GoogleFonts.splineSansMono(fontSize: 11.5, color: fg)),
      );

  Widget _whisper(AppPalette c, ResolvedDay day) {
    final calm = DriftCopy.isCaughtUp(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('~', style: GoogleFonts.splineSansMono(fontSize: 14, color: calm ? c.vine : c.jammyText)),
        const SizedBox(width: 10),
        Expanded(child: Text(DriftCopy.ketchupWhisper(day),
            style: TextStyle(fontSize: 13.5, height: 1.4, color: c.dim))),
      ]),
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
