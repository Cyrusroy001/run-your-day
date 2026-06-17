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
import '../data/ketchup_store.dart';
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
import '../logic/weekly_review.dart';
import '../logic/blueprint_promotion.dart';
import '../logic/day_arc.dart';
import '../logic/sun_clock.dart';
import '../logic/ripeness.dart';
import '../theme/app_palette.dart';
import '../theme/transitions.dart';
import '../widgets/add_task_fab.dart';
import '../widgets/sun_arc_card.dart';
import '../widgets/jar_shelf.dart';
import '../widgets/night_card.dart';
import '../widgets/promote_blueprint_sheet.dart';
import '../widgets/teach_caption.dart';
import '../widgets/avatar_menu_sheet.dart';
import '../widgets/repeat_prompt_card.dart';
import 'settings_screen.dart';
import 'how_it_works_screen.dart';
import 'catchup_screen.dart';

/// The Today surface: hero + whisper + teach caption + repeat/promotion
/// prompts, driven by the engine's ResolvedDay. The rail + Adjust mode live in
/// [TimelineScreen] (G4.2).
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
  String? _teachText;
  String? _undoMsg; // inline 'no room' caption from AddTaskFab
  Timer? _ticker;
  WeeklySummary? _summary;
  String? _topSqueezed;
  String? _notifKey; // de-dupes heads-up rescheduling across rebuilds/ticks
  List<DayAdherence> _last7 = const []; // for the Sunday catch-up screen
  List<DayKetchup?> _jars = const []; // for the THIS WEEK glance shelf
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
    final jars = await KetchupStore.last7(now);

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
      _jars = jars;
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

  // ── custom tasks ───────────────────────────────────────────────────────────
  Future<void> _commitAdd(CustomTask task, List<String> dropIds) async {
    final next = _state.copyWith(
        addedItems: [..._state.addedItems, task], deletedItems: [..._state.deletedItems, ...dropIds]);
    setState(() => _state = next);
    await StateStore.saveState(next);
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

    // The day as one arc; the sky follows the local clock (never drift). When
    // every trackable is in (or the window has passed) the day reads as night.
    final arc = DayArc.from(day.blocks,
        now: _now(), done: _done, currentSignature: now.currentSignature);
    final blend = SunClock.blendAt(_now());
    final night = arc.dayDone;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedContainer(
        duration: (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
            ? Duration.zero
            : const Duration(milliseconds: 600),
        color: c.ambient(blend, allowNight: night),
        child: SafeArea(
          bottom: false,
          child: _todayBody(c, day, now, arc, blend, night),
        ),
      ),
      floatingActionButton: AddTaskFab(
          dateIso: _state.date,
          assembled: () => _assemble(_plan!),
          onCommit: (task, dropIds) => _commitAdd(task, dropIds),
          onMessage: (m) => setState(() => _undoMsg = m)),
    );
  }

  // ── TODAY (read-only) ────────────────────────────────────────────────────────
  Widget _todayBody(AppPalette c, ResolvedDay day, HomeNowState now,
      DayArc arc, SkyBlend blend, bool night) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTeach(day));

    // Night: the vine has fully climbed — stars + a bud, no tasks, no times.
    if (night) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [_header(c, nightGround: true), const NightCard()],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _header(c),
        SunArcCard(arc: arc, blend: blend),
        const SizedBox(height: 14),
        _hero(c, day, now),
        _whisper(c, day),
        if (_undoMsg != null) _undoCaption(c),
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
        const SizedBox(height: 10),
        _upNextCard(c, day, now),
        const SizedBox(height: 10),
        _weekJarsCard(c),
        if (_todayKey == 'sun' && _summary != null) _sundayChip(c),
      ],
    );
  }

  Widget _header(AppPalette c, {bool nightGround = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 0, 14),
        child: Row(children: [
          Expanded(
            child: Text(DateFormat('EEEE d MMMM').format(DateTime.now()),
                style: GoogleFonts.bricolageGrotesque(
                    fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2,
                    color: nightGround ? c.star : c.salt)),
          ),
          GestureDetector(
            key: const Key('avatar-menu-button'),
            onTap: () => showAvatarMenu(context,
                name: _displayName.isEmpty ? 'Profile' : _displayName,
                subtitle: _plan?.meta.lifestyleArchetype ?? '',
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

  Widget _hero(AppPalette c, ResolvedDay day, HomeNowState now) {
    final caughtUp = DriftCopy.isCaughtUp(day);
    // Day-done is owned by the night card; this branch only catches the rare
    // resting gap (before the day starts, or between picked blocks).
    if (now.isResting || now.isDayDone) {
      final title = now.nextLabel.isEmpty ? 'All caught up' : 'Up next';
      return _heroShell(c, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.bricolageGrotesque(fontSize: 30, fontWeight: FontWeight.w800, height: 1.05, color: c.salt)),
        if (now.nextLabel.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
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
          child: const Text('Pick ✓', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
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
        Text('RIPE NOW', style: GoogleFonts.splineSansMono(fontSize: 11, letterSpacing: 1.4, color: c.ripe)),
      ]);

  Widget _chip(AppPalette c, String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: GoogleFonts.splineSansMono(fontSize: 11.5, color: fg)),
      );

  /// Shared chrome for the glance cards under the hero.
  Widget _glanceCard(AppPalette c, {required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.raise, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.line)),
        child: child,
      );

  Widget _glanceLabel(AppPalette c, String text) => Text(text,
      style: GoogleFonts.splineSansMono(fontSize: 10.5, letterSpacing: 1.3, color: c.dim));

  /// The next two upcoming stops after NOW — fruit dots + ish-times.
  Widget _upNextCard(AppPalette c, ResolvedDay day, HomeNowState now) {
    final upcoming = day.blocks
        .where((b) => !b.isAnchor && !b.isDropped &&
            !_done.contains(b.signature) && b.signature != now.currentSignature &&
            b.estStart > _now())
        .take(2)
        .toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return _glanceCard(c, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _glanceLabel(c, 'UP NEXT'),
      const SizedBox(height: 6),
      for (final b in upcoming)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
                color: c.fruit(b == upcoming.first ? Ripeness.nearly : Ripeness.ripening),
                shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(b.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: c.salt))),
            Text(_ishTime(b), style: GoogleFonts.splineSansMono(fontSize: 12, color: c.dim)),
          ]),
        ),
    ]));
  }

  /// The pantry at a glance — 7 mini jars. Hidden until there's any data.
  Widget _weekJarsCard(AppPalette c) {
    if (_jars.isEmpty || _jars.every((j) => j == null)) return const SizedBox.shrink();
    return _glanceCard(c, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _glanceLabel(c, 'THIS WEEK'),
      const SizedBox(height: 8),
      JarShelf(jars: _jars, mini: true),
    ]));
  }

  /// Sunday-only: a tap into the catch-up (the same route as the avatar menu).
  Widget _sundayChip(AppPalette c) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(fadeThroughRoute(CatchupScreen(
              summary: _summary!, last7: _last7, insightLabel: _topSqueezed,
              promotionCandidates: _promotionCandidates,
              onPromote: _openPromoteSheet, onDismiss: _dismissPromotion,
              onGiveMoreTime: _giveMoreTime))),
          child: _glanceCard(c, child: Row(children: [
            const Text('🫙', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text('Sunday catch-up — bottle your week',
                style: TextStyle(fontSize: 13.5, color: c.salt))),
            Icon(Icons.chevron_right, size: 18, color: c.dim),
          ])),
        ),
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

  Widget _undoCaption(AppPalette c) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(_undoMsg!,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: c.dim))),
          GestureDetector(
            onTap: () => setState(() => _undoMsg = null),
            child: Padding(padding: const EdgeInsets.only(left: 8),
                child: Text('✕', style: TextStyle(fontSize: 12.5, color: c.dim))),
          ),
        ]),
      );
}
