import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/state_store.dart';
import '../data/adherence_store.dart';
import '../logic/assembler.dart';
import '../logic/timeline.dart';
import '../logic/drift_engine.dart';
import '../logic/home_now_state.dart';
import '../theme/app_palette.dart';
import '../theme/transitions.dart';
import '../widgets/now_hero_card.dart';
import '../widgets/week_planner.dart';
import '../widgets/avatar_menu_sheet.dart';
import 'live_timeline_view.dart';
import 'settings_screen.dart';
import 'glossary_screen.dart';

class HomeScreen extends StatefulWidget {
  /// Test seam: when provided, the screen renders this plan immediately and
  /// skips the async profile load (real dart:io can't complete under the test
  /// clock, and runAsync would force a google_fonts load that throws in tests).
  final Plan? debugPlan;
  const HomeScreen({super.key, this.debugPlan});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Plan? _plan;
  String _displayName = '';
  DailyState _state = const DailyState(date: '');
  Set<String> _done = {};
  static const _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  late String _todayKey;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _todayKey = _days[DateTime.now().weekday % 7];
    _plan = widget.debugPlan;
    _load();
    // Refresh every 30 s so the progress ring and "minutes left" stay live.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.debugPlan != null) return; // tests inject the plan directly
    final doc = await AppStore.repo.loadActive();
    final state = await StateStore.loadState(DateTime.now());
    final done = await AdherenceStore.loadDone(DateTime.now());
    if (!mounted) return;
    setState(() { _plan = doc.plan; _displayName = doc.displayName; _state = state; _done = done; });
    AppStore.writeWidgetData(doc.plan, _todayKey).ignore();
  }

  List<Block> _assemble(Plan plan) {
    final entry = plan.week[_todayKey];
    return entry == null
        ? const []
        : TimelineAssembler.assembleDay(plan, entry.templateId, _todayKey,
            training: entry.training, state: _state);
  }

  ResolvedDay _resolve(Plan plan) =>
      DriftEngine.computeDay(_assemble(plan), now: nowDecimal(), done: _done, dateIso: _state.date);

  Future<void> _openLive(Plan plan) async {
    await Navigator.of(context).push(
        fadeThroughRoute(LiveTimelineView(plan: plan, todayKey: _todayKey)));
    // Reload done + state after returning so home card reflects any check-offs.
    if (mounted) _load();
  }

  /// Quick-complete the current task directly from the home card.
  Future<void> _toggleCurrentTask(String signature) async {
    final next = {..._done};
    next.contains(signature) ? next.remove(signature) : next.add(signature);
    HapticFeedback.lightImpact();
    setState(() => _done = next);
    await AdherenceStore.saveDone(DateTime.now(), next);
    final plan = _plan;
    if (plan == null) return;
    final trackable = _assemble(plan).where((b) => b.isTrackable).toList();
    await AdherenceStore.writeAdherence(
        DateTime.now(), trackable.where((b) => next.contains(b.signature)).length, trackable.length);
    AppStore.writeWidgetData(plan, _todayKey).ignore();
  }

  void _updatePlan(Plan plan) {
    AppStore.savePlan(plan);
    setState(() => _plan = plan);
    AppStore.writeWidgetData(plan, _todayKey).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final plan = _plan;
    if (plan == null) return Scaffold(body: Center(child: CircularProgressIndicator(color: c.terra)));
    final now = HomeNowState.from(_resolve(plan), now: nowDecimal(), done: _done);
    final trackable = _assemble(plan).where((b) => b.isTrackable).toList();
    final doneCount = trackable.where((b) => _done.contains(b.signature)).length;

    return Scaffold(
      body: ListView(children: [
        _header(c),
        NowHeroCard(
          state: now,
          onOpen: () => _openLive(plan),
          onToggleDone: now.currentSignature != null
              ? () => _toggleCurrentTask(now.currentSignature!)
              : null,
        ),
        _miniStrip(c, doneCount, trackable.length, now.whisper != null),
        WeekPlanner(plan: plan, todayKey: _todayKey, onPlanChanged: _updatePlan),
        const SizedBox(height: 50),
      ]),
    );
  }

  Widget _header(AppPalette c) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 52, 20, 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat('EEEE · d MMMM').format(DateTime.now()).toUpperCase(),
            style: TextStyle(fontSize: 10, letterSpacing: 3, color: c.terra, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Run the day.', style: GoogleFonts.bricolageGrotesque(fontSize: 34, fontWeight: FontWeight.w900, color: c.cream, height: .95)),
      ])),
      GestureDetector(
        key: const Key('avatar-menu-button'),
        onTap: () => showAvatarMenu(context,
          name: _displayName.isEmpty ? 'Profile' : _displayName,
          subtitle: _plan?.meta.lifestyleArchetype ?? '',
          // Switch + log out both return to the login picker (a no-active-profile
          // state); the picker is where the user re-selects or adds a profile.
          onSwitchProfile: () => AppStore.repo.clearActive(),
          onOpenSettings: () => Navigator.of(context).push(fadeThroughRoute(const SettingsScreen())),
          onOpenGlossary: () => Navigator.of(context).push(fadeThroughRoute(const GlossaryScreen())),
          onLogout: () => AppStore.repo.clearActive()),
        child: CircleAvatar(radius: 19, backgroundColor: c.terraD,
            child: Text(_displayName.isEmpty ? '?' : _displayName[0].toUpperCase(),
                style: TextStyle(color: c.terra, fontWeight: FontWeight.w700))),
      ),
    ]),
  );

  Widget _miniStrip(AppPalette c, int done, int total, bool drifting) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      Expanded(child: _pill(c, '$done / $total', 'done today')),
      const SizedBox(width: 8),
      Expanded(child: _pill(c, drifting ? 'Reflowed' : 'On track', drifting ? 'engine adjusted' : 'no drift',
          color: drifting ? c.amber : c.moss)),
    ]),
  );

  Widget _pill(AppPalette c, String n, String t, {Color? color}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(n, style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900, fontSize: 16, color: color ?? c.cream)),
      Text(t, style: TextStyle(fontSize: 10.5, color: c.dim)),
    ]),
  );
}
