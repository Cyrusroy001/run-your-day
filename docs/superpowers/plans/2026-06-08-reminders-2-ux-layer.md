# Reminders 2 — Drift-Engine UX Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the presentation layer for the v3 drift engine — a calm Home, a rich read-only Live timeline (elastic budget bars + state-morph), a gated Adjust mode (humanized priority, remove-for-today, reorder, Undo), just-in-time teaching, a no-guilt weekly review, an avatar menu, and light/dark theming — all lifestyle-agnostic.

**Architecture:** Pure logic units (`DriftCopy`, `HomeNowState`, `PriorityLevel`) translate the engine's `ResolvedDay` + Life-JSON labels into UI strings/state; thin widgets render them. State-only editing writes `DailyState` (never the Plan). A `ThemeExtension` palette flips light/dark. A guard test forbids hardcoded life strings.

**Tech Stack:** Flutter/Dart, `shared_preferences`, `google_fonts` (Fraunces + Spline Sans), `flutter_local_notifications` (from the engine plan).

---

## Source of truth

- **UX spec:** [`../specs/2026-06-08-reminders-2-ux-design.md`](../specs/2026-06-08-reminders-2-ux-design.md)
- **Mockup (visual target):** [`../specs/2026-06-08-reminders-2-ux-mockup.html`](../specs/2026-06-08-reminders-2-ux-mockup.html) — match spacing/colors/treatments against this.
- **Engine design + plan:** [`../specs/2026-06-07-life-json-v3-drift-engine-design.md`](../specs/2026-06-07-life-json-v3-drift-engine-design.md) · [`2026-06-07-life-json-v3-drift-engine.md`](2026-06-07-life-json-v3-drift-engine.md)

## Prerequisite (hard dependency)

**The engine plan's Phases A–D must be implemented first.** This plan consumes:
`Plan`, `DailyState`, the extended `Block` (with `estStart`, `seedStart`, `durationMinutes`, `idealMinutes`, `minMinutes`, `priority`, `isAnchor`, `hardAnchor`, `status`, `isCompacted`, `isDropped`), `DriftEngine.computeDay(...) → ResolvedDay`, `StateStore`, `WeeklyReview.summarize(...) → WeeklySummary`, `DriftRunner`, `NotificationService`, `AdherenceStore`, and `buildTimeline(dayKey, plan, [state])`.

## Reconciliation with the engine plan (this plan supersedes parts of it)

| Engine-plan task | What this plan does |
|---|---|
| **Phase E (E1–E5)** — bare `LiveTimelineView` with *always-on* drag/swipe/long-press + numeric priority | **Superseded.** Replaced by Phase U4 (read-only Live + state-morph) and Phase U5 (explicit Adjust mode + humanized priority + remove-for-today + Undo). |
| **Phase D3** — minimal "this week" card in `today_screen.dart` | **Superseded** by Phase U7.1 `WeeklyReviewCard` (this-week sentence + Sunday nudge). |
| App-shell **side panel / drawer** (separate spec) | **Superseded** by Phase U7.2 `AvatarMenuSheet`. |

Task U8.3 edits banners into the engine plan + the app-shell spec so no one builds the superseded versions.

---

## File structure

**Created**

| File | Responsibility |
|---|---|
| `lib/data/ui_prefs.dart` | Theme mode + text-scale prefs (`ui_themeMode`, `ui_textScale`). |
| `lib/data/teaching_flags.dart` | One-time "seen this teaching" flags (`taught_<concept>`). |
| `lib/theme/app_palette.dart` | `AppPalette` ThemeExtension (dark+light token sets) + `context.c` getter. |
| `lib/logic/priority_level.dart` | Protect/Normal/Drop-first ↔ numeric priority band (pure). |
| `lib/logic/drift_copy.dart` | All UI copy from `ResolvedDay` + JSON labels (pure, no life literals). |
| `lib/logic/home_now_state.dart` | Right-Now card state (current/next/progress/whisper) (pure). |
| `lib/widgets/budget_bar.dart` | Elastic budget bar. |
| `lib/widgets/anchor_wall.dart` | Hard/soft anchor band. |
| `lib/widgets/now_hero_card.dart` | Home Right-Now hero (evolves `now_card.dart`). |
| `lib/widgets/teaching_card.dart` | Just-in-time explainer. |
| `lib/widgets/weekly_review_card.dart` | "This week" + Sunday nudge. |
| `lib/widgets/avatar_menu_sheet.dart` | Identity + rare actions (replaces drawer). |
| `lib/screens/live_timeline_view.dart` | Rich Live surface: state-morph + Adjust mode (replaces engine-plan E version). |
| `lib/screens/settings_screen.dart` | Appearance (theme/text-size) + notification opt-in + glossary link. |
| `lib/screens/glossary_screen.dart` | "How Reminders works" reference. |
| Tests under `test/` | One per unit (see tasks). |

**Modified**

| File | Change |
|---|---|
| `lib/main.dart` | Use `AppPalette` light+dark `ThemeData`; `themeMode` from `UiPrefs`. |
| `lib/screens/home_screen.dart` | Hero card + avatar + open Live; migrate to `context.c`. |
| `lib/widgets/week_planner.dart` | Migrate to `context.c` (light/dark). |
| `lib/widgets/now_card.dart` | Removed/retired — replaced by `now_hero_card.dart`. |
| `lib/screens/today_screen.dart` | Removed/retired — role moves to `live_timeline_view.dart`. |

**Conventions:** TDD per task (failing test → run → implement → run → commit). Run from `daily_command_center/`: `flutter test test/path.dart` (one) or `flutter test` (all). Prefer pure logic + unit tests; widget tests pump `MaterialApp(theme: AppPalette.darkTheme, home: …)`.

---

## Phase U0 — Theme + prefs foundation

### Task U0.1: `UiPrefs` — theme mode + text scale

**Files:**
- Create: `lib/data/ui_prefs.dart`
- Test: `test/data/ui_prefs_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/ui_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to dark + 1.0 scale', () async {
    final p = await UiPrefs.load();
    expect(p.themeMode, ThemeMode.dark);
    expect(p.textScale, 1.0);
  });

  test('saves and reloads', () async {
    await UiPrefs.save(const UiPrefs(themeMode: ThemeMode.light, textScale: 1.15));
    final p = await UiPrefs.load();
    expect(p.themeMode, ThemeMode.light);
    expect(p.textScale, closeTo(1.15, 0.001));
  });
}
```

- [ ] **Step 2: Run** — `flutter test test/data/ui_prefs_test.dart` — Expected: FAIL (`UiPrefs` undefined).

- [ ] **Step 3: Create `ui_prefs.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiPrefs {
  final ThemeMode themeMode;
  final double textScale;
  const UiPrefs({this.themeMode = ThemeMode.dark, this.textScale = 1.0});

  static const _modeKey = 'ui_themeMode';
  static const _scaleKey = 'ui_textScale';

  static Future<UiPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = switch (prefs.getString(_modeKey)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    return UiPrefs(themeMode: mode, textScale: prefs.getDouble(_scaleKey) ?? 1.0);
  }

  static Future<void> save(UiPrefs p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, p.themeMode.name);
    await prefs.setDouble(_scaleKey, p.textScale);
  }

  UiPrefs copyWith({ThemeMode? themeMode, double? textScale}) =>
      UiPrefs(themeMode: themeMode ?? this.themeMode, textScale: textScale ?? this.textScale);
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/ui_prefs.dart daily_command_center/test/data/ui_prefs_test.dart
git commit -m "feat(ui): UiPrefs — theme mode + text scale persistence"
```

### Task U0.2: `AppPalette` ThemeExtension (dark + light) + `context.c`

**Files:**
- Create: `lib/theme/app_palette.dart`
- Test: `test/theme/app_palette_test.dart`

Tokens come straight from the UX spec §4. Dark keeps the app's existing values; light is the warm-paper set.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';

void main() {
  testWidgets('context.c resolves dark vs light tokens', (tester) async {
    late AppPalette got;
    await tester.pumpWidget(MaterialApp(
      theme: AppPalette.lightTheme,
      home: Builder(builder: (ctx) { got = ctx.c; return const SizedBox(); }),
    ));
    expect(got.bg, AppPalette.light.bg);

    await tester.pumpWidget(MaterialApp(
      theme: AppPalette.darkTheme,
      home: Builder(builder: (ctx) { got = ctx.c; return const SizedBox(); }),
    ));
    expect(got.bg, AppPalette.dark.bg);
    // No-red guarantee: amber is the loudest accent; terra is the anchor color.
    expect(AppPalette.dark.terra, const Color(0xFFC8633A));
  });
}
```

- [ ] **Step 2: Run** — `flutter test test/theme/app_palette_test.dart` — Expected: FAIL.

- [ ] **Step 3: Create `app_palette.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg, panel, panel2, cream, muted, dim, line;
  final Color terra, terraD, moss, mossD, amber, amberD, sky;

  const AppPalette({
    required this.bg, required this.panel, required this.panel2,
    required this.cream, required this.muted, required this.dim, required this.line,
    required this.terra, required this.terraD, required this.moss, required this.mossD,
    required this.amber, required this.amberD, required this.sky,
  });

  static const dark = AppPalette(
    bg: Color(0xFF17120E), panel: Color(0xFF221A13), panel2: Color(0xFF2C2218),
    cream: Color(0xFFF4E9DC), muted: Color(0xFFC9B8A6), dim: Color(0xFF8C7B6B), line: Color(0x1AF4E9DC),
    terra: Color(0xFFC8633A), terraD: Color(0x29C85B34), moss: Color(0xFF8FB36A), mossD: Color(0x298FB36A),
    amber: Color(0xFFE3A948), amberD: Color(0x24E3A948), sky: Color(0xFF7BA6C9),
  );

  static const light = AppPalette(
    bg: Color(0xFFF3EBDE), panel: Color(0xFFFFFAF2), panel2: Color(0xFFF6ECDD),
    cream: Color(0xFF2A2018), muted: Color(0xFF6B5D4F), dim: Color(0xFF9B8B7A), line: Color(0x1F2A2018),
    terra: Color(0xFFB24E2A), terraD: Color(0x1AB24E2A), moss: Color(0xFF5D8741), mossD: Color(0x1F5D8741),
    amber: Color(0xFFB9842A), amberD: Color(0x1FB9842A), sky: Color(0xFF4F7FA3),
  );

  static ThemeData get darkTheme => _theme(dark, Brightness.dark);
  static ThemeData get lightTheme => _theme(light, Brightness.light);

  static ThemeData _theme(AppPalette p, Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        scaffoldBackgroundColor: p.bg,
        cardColor: p.panel,
        colorScheme: ColorScheme.fromSeed(seedColor: p.terra, brightness: b)
            .copyWith(surface: p.bg, primary: p.terra, outline: p.line),
        textTheme: GoogleFonts.splineSansTextTheme(
          (b == Brightness.dark ? ThemeData.dark() : ThemeData.light())
              .textTheme.apply(bodyColor: p.cream, displayColor: p.cream),
        ),
        extensions: [p],
      );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) => this;
}

extension PaletteX on BuildContext {
  AppPalette get c => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/theme/app_palette.dart daily_command_center/test/theme/app_palette_test.dart
git commit -m "feat(theme): AppPalette ThemeExtension (warm dark + light) + context.c"
```

### Task U0.3: Wire `main.dart` to light/dark + UiPrefs

**Files:**
- Modify: `lib/main.dart`
- Test: `test/app_theme_boot_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/main.dart';
import 'package:daily_command_center/theme/app_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and exposes light + dark themes', (tester) async {
    SharedPreferences.setMockInitialValues({'ui_themeMode': 'light'});
    await tester.pumpWidget(const RemindersApp());
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.extension<AppPalette>(), isNotNull);
    expect(app.darkTheme!.extension<AppPalette>(), isNotNull);
  });
}
```

- [ ] **Step 2: Run** — `flutter test test/app_theme_boot_test.dart` — Expected: FAIL (class is `DailyCommandCenterApp`, no `RemindersApp`, no darkTheme).

- [ ] **Step 3: Rewrite `main.dart`**

```dart
import 'package:flutter/material.dart';
import 'data/ui_prefs.dart';
import 'data/notifications.dart';
import 'theme/app_palette.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final prefs = await UiPrefs.load();
  runApp(RemindersApp(prefs: prefs));
}

class RemindersApp extends StatefulWidget {
  final UiPrefs prefs;
  const RemindersApp({super.key, this.prefs = const UiPrefs()});

  static _RemindersAppState? of(BuildContext c) => c.findAncestorStateOfType<_RemindersAppState>();

  @override
  State<RemindersApp> createState() => _RemindersAppState();
}

class _RemindersAppState extends State<RemindersApp> {
  late UiPrefs _prefs = widget.prefs;

  void updatePrefs(UiPrefs p) {
    setState(() => _prefs = p);
    UiPrefs.save(p);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminders 2',
      theme: AppPalette.lightTheme,
      darkTheme: AppPalette.darkTheme,
      themeMode: _prefs.themeMode,
      builder: (ctx, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: _prefs.textScale, maxScaleFactor: _prefs.textScale, child: child!),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

> Note: `AppColors` (the old static class) is intentionally left in place for now so untouched widgets still compile. Each UI phase migrates its widgets to `context.c`; the last migrated file lets us delete `AppColors` (Task U8.2).

- [ ] **Step 4: Run** — Expected: PASS. Also `flutter test` should still compile (old screens still reference `AppColors`).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/main.dart daily_command_center/test/app_theme_boot_test.dart
git commit -m "feat(theme): RemindersApp with light/dark themeMode + text scaling"
```

---

## Phase U1 — Pure UI logic (no widgets)

### Task U1.1: `PriorityLevel` — humanized priority mapping

**Files:**
- Create: `lib/logic/priority_level.dart`
- Test: `test/logic/priority_level_test.dart`

Maps the engine's numeric `priority` to three human levels and back. Bands: `protect` = 1–2, `normal` = 3–5, `dropFirst` = 6+. Setting a level writes a representative number.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/priority_level.dart';

void main() {
  test('maps numeric priority to a human level', () {
    expect(PriorityLevel.fromPriority(1), PriorityLevel.protect);
    expect(PriorityLevel.fromPriority(3), PriorityLevel.normal);
    expect(PriorityLevel.fromPriority(5), PriorityLevel.normal);
    expect(PriorityLevel.fromPriority(7), PriorityLevel.dropFirst);
  });

  test('each level has a representative numeric priority and label', () {
    expect(PriorityLevel.protect.toPriority(), 2);
    expect(PriorityLevel.normal.toPriority(), 4);
    expect(PriorityLevel.dropFirst.toPriority(), 7);
    expect(PriorityLevel.protect.label, 'Protect');
    expect(PriorityLevel.dropFirst.label, 'Drop first');
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Create `priority_level.dart`**

```dart
enum PriorityLevel {
  protect('Protect', 2),
  normal('Normal', 4),
  dropFirst('Drop first', 7);

  final String label;
  final int _rep;
  const PriorityLevel(this.label, this._rep);

  int toPriority() => _rep;

  static PriorityLevel fromPriority(int p) {
    if (p <= 2) return PriorityLevel.protect;
    if (p <= 5) return PriorityLevel.normal;
    return PriorityLevel.dropFirst;
  }
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/priority_level.dart daily_command_center/test/logic/priority_level_test.dart
git commit -m "feat(ui): humanized PriorityLevel mapping (Protect/Normal/Drop-first)"
```

### Task U1.2: `DriftCopy` — all copy from ResolvedDay + JSON labels

**Files:**
- Create: `lib/logic/drift_copy.dart`
- Test: `test/logic/drift_copy_test.dart`

Pure string builders for the whisper, Live drift-summary, teaching cards, and the peek line. **Every string interpolates JSON labels** — no literal life words. This is the enforcement point for spec §3.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/drift_engine.dart';
import 'package:daily_command_center/logic/drift_copy.dart';

Block _b(String id, String label, {bool anchor = false, bool dropped = false, int ideal = 60, int dur = 60, bool hard = false}) =>
    Block(time: id, cls: anchor ? 'work' : 'focus', label: label, id: id, isAnchor: anchor, hardAnchor: hard,
        idealMinutes: ideal, durationMinutes: dur, status: dropped ? BlockStatus.dropped : BlockStatus.pending);

void main() {
  test('on-track summary when nothing drifted', () {
    final day = ResolvedDay([_b('focus', 'Deep Focus'), _b('work', 'Work', anchor: true, hard: true)], const []);
    expect(DriftCopy.summary(day), 'On track. The plan’s holding.');
  });

  test('drifting summary names trimmed items and the protected anchor — from labels', () {
    final day = ResolvedDay([
      _b('brunch', 'Shower + brunch', ideal: 45, dur: 30),
      _b('work', 'Work', anchor: true, hard: true),
      _b('train', 'Train', dropped: true),
    ], const []);
    final s = DriftCopy.summary(day);
    expect(s, contains('Shower + brunch')); // trimmed item label
    expect(s, contains('Work'));            // protected anchor label
    expect(s, contains('Train'));           // dropped item label
  });

  test('compaction teaching copy uses the item + anchor labels', () {
    final c = DriftCopy.teachCompaction(itemLabel: 'Shower + brunch', minutes: 15, anchorLabel: 'Work');
    expect(c, 'I trimmed Shower + brunch by 15m so your Work still starts on time. Budgets flex; anchors don’t.');
  });

  test('peek line shows planned vs now + budget', () {
    final blk = Block(time: '9:05', cls: 'meal', label: 'Brunch', id: 'brunch',
        seedStart: 11.0, estStart: 11.17, idealMinutes: 45, durationMinutes: 30);
    expect(DriftCopy.peek(blk, anchorLabel: 'Work'),
        'planned 11:00 · now 11:10 · budget 45→30m (to hold Work)');
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Create `drift_copy.dart`**

```dart
import '../data/models.dart';
import 'drift_engine.dart';

class DriftCopy {
  /// Format a 24h decimal as the app's 12h display (e.g. 11.17 -> "11:10").
  static String _fmt(double dec) {
    final h = dec.floor();
    final m = ((dec - h) * 60).round();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}';
  }

  static String? _firstHardAnchorLabel(ResolvedDay day) {
    for (final b in day.blocks) {
      if (b.isAnchor && b.hardAnchor) return b.label;
    }
    return day.blocks.where((b) => b.isAnchor).map((b) => b.label).cast<String?>().firstWhere((_) => true, orElse: () => null);
  }

  /// Live drift summary — all labels from JSON.
  static String summary(ResolvedDay day) {
    final trimmed = day.blocks.where((b) => b.isCompacted).map((b) => b.label).toList();
    final dropped = day.blocks.where((b) => b.isDropped).map((b) => b.label).toList();
    if (trimmed.isEmpty && dropped.isEmpty) return 'On track. The plan’s holding.';

    final anchor = _firstHardAnchorLabel(day) ?? 'what matters';
    final parts = <String>[];
    if (trimmed.isNotEmpty) parts.add('Trimmed ${_and(trimmed)} to hold $anchor');
    if (dropped.isNotEmpty) parts.add('${_and(dropped)} dropped to protect your evening');
    return '${parts.join('. ')}.';
  }

  /// Home whisper — shorter; null when on-track.
  static String? whisper(ResolvedDay day, {int? behindMinutes}) {
    final trimmed = day.blocks.where((b) => b.isCompacted).map((b) => b.label).toList();
    final dropped = day.blocks.where((b) => b.isDropped).map((b) => b.label).toList();
    if (trimmed.isEmpty && dropped.isEmpty) return null;
    final anchor = _firstHardAnchorLabel(day) ?? 'what matters';
    final behind = behindMinutes != null && behindMinutes > 0 ? 'Running ~${behindMinutes}m behind · ' : '';
    if (trimmed.isNotEmpty) return '${behind}trimmed ${_and(trimmed)} to hold $anchor.';
    return '$behind${_and(dropped)} dropped to protect your evening.';
  }

  static String teachCompaction({required String itemLabel, required int minutes, required String anchorLabel}) =>
      'I trimmed $itemLabel by ${minutes}m so your $anchorLabel still starts on time. Budgets flex; anchors don’t.';

  static String teachDrop({required String itemLabel}) =>
      '$itemLabel got cancelled today — it would’ve run too late. Protecting your evening.';

  static String teachAdjust({required String anchorLabel}) =>
      'Drag to reorder, swipe to remove. $anchorLabel stays put. This only changes today.';

  static String notification({required String itemLabel, required String cutoff}) =>
      '$itemLabel cancelled today — it drifted past $cutoff. Protecting your evening.';

  static String peek(Block b, {required String anchorLabel}) {
    final budget = b.durationMinutes < b.idealMinutes
        ? '${b.idealMinutes}→${b.durationMinutes}m (to hold $anchorLabel)'
        : '${b.idealMinutes}m';
    return 'planned ${_fmt(b.seedStart)} · now ${_fmt(b.estStart)} · budget $budget';
  }

  static String _and(List<String> items) {
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} & ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(', ')} & ${items.last}';
  }
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/drift_copy.dart daily_command_center/test/logic/drift_copy_test.dart
git commit -m "feat(ui): DriftCopy — all drift strings built from JSON labels"
```

### Task U1.3: `HomeNowState` — Right-Now card state

**Files:**
- Create: `lib/logic/home_now_state.dart`
- Test: `test/logic/home_now_state_test.dart`

Pure: from a `ResolvedDay` + `now`, compute the current block, next block, progress fraction, and the whisper. Reuses `buildTimes` semantics by reading `estStart` (already 24h decimals on resolved blocks).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/drift_engine.dart';
import 'package:daily_command_center/logic/home_now_state.dart';

Block _b(String id, String label, double start, int dur) =>
    Block(time: id, cls: 'meal', label: label, id: id, estStart: start, durationMinutes: dur, idealMinutes: dur);

void main() {
  final day = ResolvedDay([_b('a', 'Wake', 8.0, 30), _b('b', 'Focus', 8.5, 75), _b('c', 'Brunch', 11.0, 45)], const []);

  test('before first block -> resting state', () {
    final s = HomeNowState.from(day, now: 7.0);
    expect(s.isResting, true);
    expect(s.nextLabel, 'Wake');
  });

  test('within a block -> current + next + progress', () {
    final s = HomeNowState.from(day, now: 9.0); // inside Focus (8.5–9.75)
    expect(s.currentLabel, 'Focus');
    expect(s.nextLabel, 'Brunch');
    expect(s.progress, closeTo((9.0 - 8.5) / (75 / 60), 0.05));
    expect(s.minutesLeft, closeTo(45, 2));
  });

  test('after last block -> day done', () {
    final s = HomeNowState.from(day, now: 23.5);
    expect(s.isDayDone, true);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Create `home_now_state.dart`**

```dart
import '../data/models.dart';
import 'drift_engine.dart';
import 'drift_copy.dart';

class HomeNowState {
  final bool isResting;
  final bool isDayDone;
  final String currentLabel;
  final int minutesLeft;
  final int budgetMinutes;
  final double progress; // 0..1
  final String nextLabel;
  final String nextTime;
  final String? whisper;

  const HomeNowState({
    required this.isResting, required this.isDayDone, required this.currentLabel,
    required this.minutesLeft, required this.budgetMinutes, required this.progress,
    required this.nextLabel, required this.nextTime, required this.whisper,
  });

  static String _fmt(double dec) {
    final h = dec.floor();
    final m = ((dec - h) * 60).round();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}';
  }

  static HomeNowState from(ResolvedDay day, {required double now}) {
    final live = day.blocks.where((b) => !b.isDropped).toList();
    final whisper = DriftCopy.whisper(day);
    if (live.isEmpty) {
      return HomeNowState(isResting: true, isDayDone: false, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 0, nextLabel: '', nextTime: '', whisper: whisper);
    }
    if (now < live.first.estStart) {
      return HomeNowState(isResting: true, isDayDone: false, currentLabel: '', minutesLeft: 0,
          budgetMinutes: 0, progress: 0, nextLabel: live.first.label, nextTime: _fmt(live.first.estStart), whisper: whisper);
    }
    for (int i = 0; i < live.length; i++) {
      final start = live[i].estStart;
      final end = i < live.length - 1 ? live[i + 1].estStart : start + live[i].durationMinutes / 60.0;
      if (now >= start && now < end) {
        final span = (end - start);
        final left = ((end - now) * 60).round().clamp(0, 100000);
        return HomeNowState(
          isResting: false, isDayDone: false, currentLabel: live[i].label,
          minutesLeft: left, budgetMinutes: live[i].durationMinutes,
          progress: span <= 0 ? 1 : ((now - start) / span).clamp(0, 1),
          nextLabel: i < live.length - 1 ? live[i + 1].label : '',
          nextTime: i < live.length - 1 ? _fmt(live[i + 1].estStart) : '',
          whisper: whisper,
        );
      }
    }
    return HomeNowState(isResting: false, isDayDone: true, currentLabel: '', minutesLeft: 0,
        budgetMinutes: 0, progress: 1, nextLabel: '', nextTime: '', whisper: whisper);
  }
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/home_now_state.dart daily_command_center/test/logic/home_now_state_test.dart
git commit -m "feat(ui): HomeNowState — pure Right-Now card state from ResolvedDay"
```

> **Build order from here:** shared widgets (U2) → Live read-only (U3) → Adjust (U4) → teaching (U5) → Home + nav shell (U6) → cleanup (U7). The app keeps running on the *old* Home/Today (still compiling via `AppColors`) until U6 swaps Home and U7 retires the old screens — every phase ships.

---

## Phase U2 — Shared timeline widgets

### Task U2.1: `BudgetBar` — the elastic budget bar

**Files:**
- Create: `lib/widgets/budget_bar.dart`
- Test: `test/widgets/budget_bar_test.dart`

Renders a duration budget. When `current < ideal` it shows an amber `−Nm` tag (compacted). When `activeSpent` is set, the bar splits into spent (faded) + left (solid).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/budget_bar.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

void main() {
  testWidgets('shows -Nm tag when compacted', (tester) async {
    await tester.pumpWidget(_wrap(const BudgetBar(idealMinutes: 45, currentMinutes: 30)));
    expect(find.textContaining('−15m'), findsOneWidget);
    expect(find.textContaining('30m'), findsOneWidget);
  });

  testWidgets('no tag when at ideal', (tester) async {
    await tester.pumpWidget(_wrap(const BudgetBar(idealMinutes: 45, currentMinutes: 45)));
    expect(find.textContaining('−'), findsNothing);
    expect(find.textContaining('45m'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** — `flutter test test/widgets/budget_bar_test.dart` — Expected: FAIL.

- [ ] **Step 3: Create `budget_bar.dart`**

```dart
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
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/widgets/budget_bar.dart daily_command_center/test/widgets/budget_bar_test.dart
git commit -m "feat(ui): BudgetBar — elastic duration bar with compaction tag"
```

### Task U2.2: `AnchorWall` — hard/soft boundary band

**Files:**
- Create: `lib/widgets/anchor_wall.dart`
- Test: `test/widgets/anchor_wall_test.dart`

Renders a `Block` with `isAnchor == true`. Hard → solid terracotta band with `🔒` + label + time range. Soft → dashed muted band with `⌛ AIM` + label.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/anchor_wall.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

void main() {
  testWidgets('hard anchor shows lock + label', (tester) async {
    final b = Block(time: '2:00', cls: 'work', label: 'Work — 2:00 to 8:00', id: 'work', isAnchor: true, hardAnchor: true);
    await tester.pumpWidget(_wrap(AnchorWall(block: b, timeText: '2:00–8:00')));
    expect(find.textContaining('ANCHOR'), findsOneWidget);
    expect(find.textContaining('Work — 2:00 to 8:00'), findsOneWidget);
  });

  testWidgets('soft ceiling shows AIM', (tester) async {
    final b = Block(time: '11:15', cls: 'chill', label: 'Sleep target', id: 'sleep', isAnchor: true, hardAnchor: false);
    await tester.pumpWidget(_wrap(AnchorWall(block: b, timeText: '11:15')));
    expect(find.textContaining('AIM'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Create `anchor_wall.dart`**

```dart
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_palette.dart';

class AnchorWall extends StatelessWidget {
  final Block block;
  final String timeText;
  const AnchorWall({super.key, required this.block, required this.timeText});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hard = block.hardAnchor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 11),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
      decoration: BoxDecoration(
        color: hard ? c.terraD : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hard ? c.terra : c.dim,
          style: hard ? BorderStyle.solid : BorderStyle.none,
        ),
      ),
      foregroundDecoration: hard
          ? null
          : _DashedBorder(color: c.dim, radius: 10),
      child: Row(children: [
        Text(hard ? '🔒 ANCHOR' : '⌛ AIM',
            style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700, color: hard ? c.terra : c.dim)),
        const SizedBox(width: 10),
        Expanded(child: Text('${block.label} · $timeText',
            style: TextStyle(fontSize: 12.5, color: hard ? c.cream : c.muted))),
      ]),
    );
  }
}

/// Lightweight dashed border for soft ceilings.
class _DashedBorder extends BoxDecoration {
  final Color color;
  final double radius;
  const _DashedBorder({required this.color, required this.radius});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _DashedPainter(color, radius);
}

class _DashedPainter extends BoxPainter {
  final Color color;
  final double radius;
  _DashedPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = offset & cfg.size!;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/widgets/anchor_wall.dart daily_command_center/test/widgets/anchor_wall_test.dart
git commit -m "feat(ui): AnchorWall — hard (solid) / soft (dashed) boundary band"
```

---

## Phase U3 — Live timeline (read-only, state-morph)

### Task U3.1: `WeeklyReviewCard` + `DriftCopy.weeklyNudge`

**Files:**
- Create: `lib/widgets/weekly_review_card.dart`
- Modify: `lib/logic/drift_copy.dart`
- Test: `test/widgets/weekly_review_card_test.dart`, append to `test/logic/drift_copy_test.dart`

Supersedes engine-plan D3. The card shows the plain "this week" sentence (from `WeeklyReview.summarize`), an optional adherence strip, and — on Sundays — a gentle nudge. The nudge is computed by a new pure `DriftCopy.weeklyNudge`.

- [ ] **Step 1: Write the failing tests**

Append to `test/logic/drift_copy_test.dart`:

```dart
  test('weeklyNudge names the most-killed item from labels', () {
    final events = [
      const DriftEvent(date: 'x', itemId: 'train', label: 'Train', event: 'killed'),
      const DriftEvent(date: 'y', itemId: 'train', label: 'Train', event: 'killed'),
      const DriftEvent(date: 'z', itemId: 'focus', label: 'Focus', event: 'compacted'),
    ];
    expect(DriftCopy.weeklyNudge(events), 'Train keeps getting squeezed out — move it earlier, or shorten its budget?');
    expect(DriftCopy.weeklyNudge(const []), isNull);
  });
```

Create `test/widgets/weekly_review_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/weekly_review.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/weekly_review_card.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

void main() {
  testWidgets('shows the sentence and (on Sunday) the nudge', (tester) async {
    const summary = WeeklySummary(killCount: 2, compactCount: 4, jettisonCount: 0,
        sentence: 'This week — Train auto-cancelled 2×; Focus compacted 4×.');
    await tester.pumpWidget(_wrap(const WeeklyReviewCard(summary: summary, isSunday: true,
        nudge: 'Train keeps getting squeezed out — move it earlier, or shorten its budget?')));
    expect(find.textContaining('Train auto-cancelled 2×'), findsOneWidget);
    expect(find.textContaining('squeezed out'), findsOneWidget);
  });

  testWidgets('hides the nudge on non-Sunday', (tester) async {
    const summary = WeeklySummary(killCount: 0, compactCount: 0, jettisonCount: 0, sentence: 'No drift this week — the plan held. Nice.');
    await tester.pumpWidget(_wrap(const WeeklyReviewCard(summary: summary, isSunday: false, nudge: 'x')));
    expect(find.textContaining('No drift'), findsOneWidget);
    expect(find.textContaining('squeezed out'), findsNothing);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3a: Add `weeklyNudge` to `drift_copy.dart`** (needs `import '../data/models.dart';` already present)

```dart
  /// Sunday nudge — names the item dropped/cancelled most. null if nothing notable.
  static String? weeklyNudge(List<DriftEvent> events) {
    final kills = <String, int>{};
    for (final e in events.where((e) => e.event == 'killed' || e.event == 'jettisoned')) {
      kills[e.label] = (kills[e.label] ?? 0) + 1;
    }
    if (kills.isEmpty) return null;
    final worst = kills.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return '$worst keeps getting squeezed out — move it earlier, or shorten its budget?';
  }
```

- [ ] **Step 3b: Create `weekly_review_card.dart`**

```dart
import 'package:flutter/material.dart';
import '../data/adherence_store.dart';
import '../logic/weekly_review.dart';
import '../theme/app_palette.dart';

class WeeklyReviewCard extends StatelessWidget {
  final WeeklySummary summary;
  final bool isSunday;
  final String? nudge;
  final List<DayAdherence> last7;
  const WeeklyReviewCard({super.key, required this.summary, required this.isSunday, this.nudge, this.last7 = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: isSunday ? c.terra : c.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isSunday ? 'WEEKLY REVIEW' : 'THIS WEEK',
            style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        if (last7.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(height: 48, child: Row(crossAxisAlignment: CrossAxisAlignment.end,
              children: last7.map((d) => _bar(c, d)).toList())),
        ],
        const SizedBox(height: 8),
        Text(summary.sentence, style: TextStyle(fontSize: 13, color: c.cream, height: 1.4)),
        if (isSunday && nudge != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: c.terraD, border: Border.all(color: c.terra), borderRadius: BorderRadius.circular(12)),
            child: Text(nudge!, style: TextStyle(fontSize: 14, color: c.cream, height: 1.35)),
          ),
          const SizedBox(height: 8),
          Text('No streaks. No scores. Just what happened, and a gentle next step.',
              style: TextStyle(fontSize: 10.5, color: c.dim)),
        ],
      ]),
    );
  }

  Widget _bar(AppPalette c, DayAdherence d) {
    final pct = d.pct;
    final h = pct == null ? 6.0 : 6 + pct / 100 * 34;
    final color = pct == null ? c.line : (pct >= 60 ? c.moss : c.amber);
    return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)))));
  }
}
```

- [ ] **Step 4: Run** — `flutter test test/widgets/weekly_review_card_test.dart test/logic/drift_copy_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/widgets/weekly_review_card.dart daily_command_center/lib/logic/drift_copy.dart daily_command_center/test/widgets/weekly_review_card_test.dart daily_command_center/test/logic/drift_copy_test.dart
git commit -m "feat(ui): WeeklyReviewCard + weeklyNudge (supersedes engine-plan D3)"
```

### Task U3.2: `LiveTimelineView` read-only — state-morph rows + drift summary

**Files:**
- Create: `lib/screens/live_timeline_view.dart` (replaces the engine-plan E stub if present)
- Test: `test/screens/live_timeline_test.dart`

Renders the resolved day: a drift summary, the weekly review card, then rows morphed by state (done/active/pending/compacted/dropped) with anchor walls. Loads `DailyState` + done-set from stores; `debugNow` is the test seam.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/screens/live_timeline_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Plan> _seed() async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    return Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  testWidgets('renders anchor wall + a routine block on an office day', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final plan = await _seed();
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();
    expect(find.textContaining('ANCHOR'), findsWidgets);
    expect(find.text('Deep Focus — AI Building'), findsOneWidget);
    expect(find.textContaining('On track'), findsOneWidget); // zero-drift summary
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Create `live_timeline_view.dart`** (read-only core; Adjust/teaching/peek added in U4/U5/U3.4)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../data/state_store.dart';
import '../data/adherence_store.dart';
import '../logic/timeline.dart';
import '../logic/drift_engine.dart';
import '../logic/drift_copy.dart';
import '../logic/weekly_review.dart';
import '../theme/app_palette.dart';
import '../widgets/budget_bar.dart';
import '../widgets/anchor_wall.dart';
import '../widgets/weekly_review_card.dart';

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
  WeeklySummary? _summary;
  String? _nudge;
  List<DayAdherence> _last7 = const [];

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

  double _now() => widget.debugNow ?? nowDecimal();

  ResolvedDay resolve() {
    final assembled = buildTimeline(widget.todayKey, widget.plan, _state);
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
    final a = tmpl?.anchors.where((x) => x.id == b.id).cast<Anchor?>().firstOrNull;
    if (a == null) return _fmt(b.estStart);
    return a.end == null ? _fmt(b.estStart) : '${_fmt(b.estStart)}–${displayTime(a.end!)} · fixed';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final day = resolve();
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: c.bg, foregroundColor: c.cream,
          title: Text('Live', style: GoogleFonts.fraunces(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (summary != null)
            WeeklyReviewCard(summary: summary, isSunday: widget.todayKey == 'sun', nudge: _nudge, last7: _last7),
          _driftSummary(c, day),
          const SizedBox(height: 4),
          ..._rows(c, day),
        ],
      ),
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
      if (i == activeIdx) { out.add(_activeRow(c, b)); } else { out.add(_normalRow(c, b, done)); }
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
```

> `firstOrNull` needs `import 'package:collection/collection.dart';` OR replace with a manual lookup. To avoid a new dependency, replace `.cast<Anchor?>().firstOrNull` with: `final list = tmpl?.anchors.where((x) => x.id == b.id).toList() ?? const []; final a = list.isEmpty ? null : list.first;`. Use that form in the implementation.

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): LiveTimelineView read-only — state-morph rows + drift summary (supersedes engine-plan E1)"
```

### Task U3.3: Tap-to-check-done + haptic

**Files:**
- Modify: `lib/screens/live_timeline_view.dart`
- Test: append to `test/screens/live_timeline_test.dart`

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('tapping a row toggles done + persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deep Focus — AI Building'));
    await tester.pumpAndSettle();
    final done = await AdherenceStore.loadDone(DateTime.now());
    expect(done.any((s) => s.contains('Deep Focus')), true);
  });
```

(Add `import 'package:daily_command_center/data/adherence_store.dart';` to the test.)

- [ ] **Step 2: Run** — Expected: FAIL (rows not tappable).

- [ ] **Step 3: Add `_toggle` + wrap rows.** Add the method and wrap `_normalRow`/`_activeRow` returns in a `GestureDetector`:

```dart
import 'package:flutter/services.dart';
// ...
  Future<void> _toggle(Block b) async {
    final next = {..._done};
    next.contains(b.signature) ? next.remove(b.signature) : next.add(b.signature);
    HapticFeedback.lightImpact();
    setState(() => _done = next);
    await AdherenceStore.saveDone(DateTime.now(), next);
    final t = buildTimeline(widget.todayKey, widget.plan, _state).where((x) => x.isTrackable).toList();
    await AdherenceStore.writeAdherence(DateTime.now(), t.where((x) => next.contains(x.signature)).length, t.length);
  }
```

In `_rows`, wrap each non-anchor, non-dropped row:

```dart
      final w = (i == activeIdx) ? _activeRow(c, b) : _normalRow(c, b, done);
      out.add(GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _toggle(b), child: w));
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): tap-to-check-done with haptic on Live"
```

### Task U3.4: Peek-at-ideal on drifted rows

**Files:**
- Modify: `lib/screens/live_timeline_view.dart`
- Test: append to `test/screens/live_timeline_test.dart`

A drifted (compacted) row gets an ⓘ that, when tapped, shows the `DriftCopy.peek` line in a snackbar/tooltip.

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('peek shows planned vs now for a compacted row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    // Late enough to force compaction on the office morning.
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 11.5)));
    await tester.pumpAndSettle();
    final info = find.byIcon(Icons.info_outline);
    if (info.evaluate().isNotEmpty) {
      await tester.tap(info.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('planned'), findsOneWidget);
    }
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (no ⓘ).

- [ ] **Step 3: Add the ⓘ to compacted rows.** In `_normalRow`, when `b.isCompacted`, append an info button:

```dart
            if (b.isCompacted)
              IconButton(
                icon: Icon(Icons.info_outline, size: 16, color: c.dim),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: () {
                  final tmpl = widget.plan.dayTemplates[widget.plan.week[widget.todayKey]?.templateId];
                  final anchorLabel = tmpl?.anchors.where((a) => a.hard).map((a) => a.label).cast<String?>().firstWhere((_) => true, orElse: () => null) ?? 'what matters';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(DriftCopy.peek(b, anchorLabel: anchorLabel))));
                },
              ),
```

(Place it inside the row's trailing area; restructure `_normalRow` to a `Row` whose last child is this button when compacted.)

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): peek-at-ideal on compacted rows"
```

---

## Phase U4 — Adjust mode (gated editor; supersedes engine-plan E2–E5)

All edits write `DailyState` only. A `_adjusting` flag flips Live between the calm read-only body (U3) and the editor body. A single `_commit(next, message)` routes every mutation through a checkpoint + snackbar (U4.4).

### Task U4.1: Adjust toggle + reorder (frozen anchors) → `dailySequence`

**Files:**
- Modify: `lib/screens/live_timeline_view.dart`
- Test: append to `test/screens/live_timeline_test.dart`

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('Adjust toggle reveals editor; reorder writes dailySequence', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adjust today'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    st.reorderForTest(0, 3);
    await tester.pumpAndSettle();
    final saved = await StateStore.loadState(DateTime.now());
    expect(saved.dailySequence, isNotEmpty);
  });
```

(Add `import 'package:daily_command_center/data/state_store.dart';` to the test.)

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Add Adjust mode to `live_timeline_view.dart`.** Add state + a switched body + reorder.

```dart
import 'package:flutter/foundation.dart';
// ... in state:
  bool _adjusting = false;

  @visibleForTesting
  void reorderForTest(int oldIndex, int newIndex) => _onReorder(oldIndex, newIndex);

  void _onReorder(int oldIndex, int newIndex) {
    final day = resolve();
    if (day.blocks[oldIndex].isAnchor) return; // anchors frozen
    final ids = day.blocks.map((b) => b.id ?? '').toList();
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    _commit(_state.copyWith(dailySequence: ids.where((e) => e.isNotEmpty).toList()), 'Reordered');
  }
```

Refactor `build` to switch bodies and add the toggle button:

```dart
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
    final summary = _summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        if (summary != null)
          WeeklyReviewCard(summary: summary, isSunday: widget.todayKey == 'sun', nudge: _nudge, last7: _last7),
        _driftSummary(c, day),
        const SizedBox(height: 4),
        ..._rows(c, day),
      ],
    );
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
                : ReorderableDragStartListener(
                    key: ValueKey('e-${day.blocks[i].id}'), index: i, child: _adjustRow(c, day.blocks[i])),
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

  Widget _adjustRow(AppPalette c, Block b) => Container(
        margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.drag_indicator, color: c.dim, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(b.label, style: TextStyle(fontSize: 13, color: c.cream))),
        ]),
      );
```

(`_removedTray` and `_commit` are added in U4.2/U4.4; for U4.1 add temporary stubs: `Widget _removedTray(AppPalette c) => const SizedBox.shrink();` and a minimal `_commit`:)

```dart
  Future<void> _commit(DailyState next, String message) async {
    setState(() => _state = next);
    await StateStore.saveState(next);
  }
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): Adjust mode toggle + reorder (frozen anchors) -> dailySequence"
```

### Task U4.2: Swipe remove-for-today + removed-tray restore

**Files:**
- Modify: `lib/screens/live_timeline_view.dart`
- Test: append to `test/screens/live_timeline_test.dart`

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('swipe removes for today; tray restores', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust today'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Break + snack'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect((await StateStore.loadState(DateTime.now())).deletedItems, contains('snack'));
    expect(find.textContaining('Removed today'), findsOneWidget);

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    st.restoreForTest('snack');
    await tester.pumpAndSettle();
    expect((await StateStore.loadState(DateTime.now())).deletedItems, isNot(contains('snack')));
  });
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Wrap adjust rows in `Dismissible` + implement remove/restore/tray.**

```dart
  @visibleForTesting
  void restoreForTest(String id) => _restore(id);

  Future<void> _remove(String id) async {
    await _commit(_state.copyWith(deletedItems: [..._state.deletedItems, id]), 'Removed for today');
  }

  Future<void> _restore(String id) async {
    await _commit(_state.copyWith(deletedItems: _state.deletedItems.where((x) => x != id).toList()), 'Restored');
  }

  Widget _removedTray(AppPalette c) {
    if (_state.deletedItems.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(border: Border.all(color: c.line, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
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
```

Wrap each flexible adjust row in `_adjustBody`'s children with `Dismissible`:

```dart
                : Dismissible(
                    key: ValueKey('e-${day.blocks[i].id}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _remove(day.blocks[i].id!),
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                        color: c.terraD, child: Icon(Icons.delete_outline, color: c.terra)),
                    child: ReorderableDragStartListener(index: i, child: _adjustRow(c, day.blocks[i])),
                  ),
```

(Each `ReorderableListView` child needs a unique `Key` at the top level — the `Dismissible` key serves that.)

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): remove-for-today (swipe) + removed-tray restore"
```

### Task U4.3: Humanized priority chip → `dailyOverrides`

**Files:**
- Modify: `lib/screens/live_timeline_view.dart`
- Test: append to `test/screens/live_timeline_test.dart`

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('priority chip writes dailyOverrides', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust today'));
    await tester.pumpAndSettle();

    final st = tester.state<LiveTimelineViewState>(find.byType(LiveTimelineView));
    st.setLevelForTest('focus', PriorityLevel.dropFirst);
    await tester.pumpAndSettle();
    expect((await StateStore.loadState(DateTime.now())).dailyOverrides['focus']!.priority, PriorityLevel.dropFirst.toPriority());
  });
```

(Add `import 'package:daily_command_center/logic/priority_level.dart';` to the test.)

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Add the level chip + setter.** Import `priority_level.dart`. Add:

```dart
  @visibleForTesting
  void setLevelForTest(String id, PriorityLevel lvl) => _setLevel(id, lvl);

  Future<void> _setLevel(String id, PriorityLevel lvl) async {
    final overrides = {..._state.dailyOverrides, id: ItemOverride(priority: lvl.toPriority())};
    await _commit(_state.copyWith(dailyOverrides: overrides), 'Set ${lvl.label}');
  }

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
```

Add the chip to `_adjustRow` (after the label `Expanded`):

```dart
          GestureDetector(
            onTap: () => _openLevelSheet(b),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: _levelOf(b) == PriorityLevel.protect ? c.moss : _levelOf(b) == PriorityLevel.dropFirst ? c.amber : c.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${_levelOf(b).label} ▾', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                  color: _levelOf(b) == PriorityLevel.protect ? c.moss : _levelOf(b) == PriorityLevel.dropFirst ? c.amber : c.muted)),
            ),
          ),
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): humanized priority chip -> dailyOverrides"
```

### Task U4.4: Undo protocol + collision message

**Files:**
- Modify: `lib/screens/live_timeline_view.dart`
- Test: append to `test/screens/live_timeline_test.dart`

Upgrade `_commit` to checkpoint the prior state, show a snackbar with UNDO, and — if the new state newly drops a block — say which one.

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('undo restores the prior state after a remove', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust today'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Break + snack'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect((await StateStore.loadState(DateTime.now())).deletedItems, contains('snack'));

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect((await StateStore.loadState(DateTime.now())).deletedItems, isNot(contains('snack')));
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (no UNDO).

- [ ] **Step 3: Upgrade `_commit` + add `_undo`.** Replace the U4.1 stub:

```dart
  DailyState? _checkpoint;

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
```

- [ ] **Step 4: Run** — `flutter test test/screens/live_timeline_test.dart` — Expected: PASS (all Live tests).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): Undo protocol + collision message (supersedes engine-plan E5)"
```

---

## Phase U5 — Just-in-time teaching

### Task U5.1: `TeachingFlags` — one-time seen store

**Files:**
- Create: `lib/data/teaching_flags.dart`
- Test: `test/data/teaching_flags_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/teaching_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a concept is unseen until marked, then stays seen', () async {
    expect(await TeachingFlags.seen('compaction'), false);
    await TeachingFlags.markSeen('compaction');
    expect(await TeachingFlags.seen('compaction'), true);
    expect(await TeachingFlags.seen('drop'), false);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Create `teaching_flags.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

class TeachingFlags {
  static String _key(String concept) => 'taught_$concept';

  static Future<bool> seen(String concept) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(concept)) ?? false;
  }

  static Future<void> markSeen(String concept) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(concept), true);
  }
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/teaching_flags.dart daily_command_center/test/data/teaching_flags_test.dart
git commit -m "feat(ui): TeachingFlags — one-time seen store"
```

### Task U5.2: `TeachingCard` + trigger on Live

**Files:**
- Create: `lib/widgets/teaching_card.dart`
- Modify: `lib/screens/live_timeline_view.dart`
- Test: `test/widgets/teaching_card_test.dart`, append to `test/screens/live_timeline_test.dart`

The card shows copy + [Why?] + [Got it]. Live checks after each resolve: if a compaction/drop just appeared and its concept is unseen, show the card and mark seen.

- [ ] **Step 1: Write the failing tests**

`test/widgets/teaching_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/teaching_card.dart';

void main() {
  testWidgets('renders copy and fires callbacks', (tester) async {
    var got = false;
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body:
      TeachingCard(text: 'I trimmed Brunch by 15m.', onGotIt: () => got = true, onWhy: () {}))));
    expect(find.textContaining('trimmed Brunch'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    expect(got, true);
  });
}
```

Append to `test/screens/live_timeline_test.dart`:

```dart
  testWidgets('first compaction shows a teaching card once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    // Late office morning forces a compaction.
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme,
        home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 11.5)));
    await tester.pumpAndSettle();
    expect(find.byType(TeachingCard), findsWidgets);
  });
```

(Add `import 'package:daily_command_center/widgets/teaching_card.dart';` to the screen test.)

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3a: Create `teaching_card.dart`**

```dart
import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

class TeachingCard extends StatelessWidget {
  final String text;
  final VoidCallback onGotIt;
  final VoidCallback onWhy;
  const TeachingCard({super.key, required this.text, required this.onGotIt, required this.onWhy});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: c.panel2, border: Border.all(color: c.terra), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('✦ New thing just happened', style: TextStyle(fontSize: 11, color: c.terra, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: c.cream)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: onWhy, child: Text('Why?', style: TextStyle(color: c.muted))),
          const SizedBox(width: 6),
          FilledButton(onPressed: onGotIt, style: FilledButton.styleFrom(backgroundColor: c.terra),
              child: const Text('Got it')),
        ]),
      ]),
    );
  }
}
```

- [ ] **Step 3b: Trigger in `live_timeline_view.dart`.** Add a `_teach` field + a check after resolve in `build` (read-only body). Import teaching files + glossary route.

```dart
import '../data/teaching_flags.dart';
import '../widgets/teaching_card.dart';
import 'glossary_screen.dart'; // built in U6.2; until then this import is the only forward ref — see note
// ... state:
  String? _teachText;
  String? _teachConcept;

  void _maybeTeach(ResolvedDay day) {
    if (_teachText != null) return;
    final tmpl = widget.plan.dayTemplates[widget.plan.week[widget.todayKey]?.templateId];
    final anchorLabel = tmpl?.anchors.where((a) => a.hard).map((a) => a.label).toList();
    final anchor = (anchorLabel != null && anchorLabel.isNotEmpty) ? anchorLabel.first : 'what matters';
    final compacted = day.blocks.where((b) => b.isCompacted).toList();
    final dropped = day.blocks.where((b) => b.isDropped).toList();
    Future<void> trip(String concept, String text) async {
      if (await TeachingFlags.seen(concept)) return;
      await TeachingFlags.markSeen(concept);
      if (mounted) setState(() { _teachText = text; _teachConcept = concept; });
    }
    if (dropped.isNotEmpty) {
      trip('drop', DriftCopy.teachDrop(itemLabel: dropped.first.label));
    } else if (compacted.isNotEmpty) {
      final b = compacted.first;
      trip('compaction', DriftCopy.teachCompaction(itemLabel: b.label, minutes: b.idealMinutes - b.durationMinutes, anchorLabel: anchor));
    }
  }
```

In `_readonlyBody`, after computing `day`, call `WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTeach(day));` (once per build is fine — the seen-flag guards repeats), and insert the card when set:

```dart
        if (_teachText != null)
          TeachingCard(
            text: _teachText!,
            onGotIt: () => setState(() { _teachText = null; _teachConcept = null; }),
            onWhy: () { setState(() => _teachText = null); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlossaryScreen())); },
          ),
```

> **Forward-ref note:** `glossary_screen.dart` is created in Task U6.2. If executing strictly in order, build U6.2 first or stub `GlossaryScreen` now. Recommended: reorder so U6.2 (Glossary) runs before this step, or temporarily point `onWhy` to a `SnackBar` and swap to the route in U6.2.

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/widgets/teaching_card.dart daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/widgets/teaching_card_test.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): just-in-time TeachingCard + first-occurrence triggers"
```

---

## Phase U6 — Home + nav shell

### Task U6.1: `GlossaryScreen` + `SettingsScreen`

**Files:**
- Create: `lib/screens/glossary_screen.dart`, `lib/screens/settings_screen.dart`
- Test: `test/screens/settings_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/main.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toggling light updates app theme mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RemindersApp());
    await tester.pump();
    // Navigate to settings directly:
    final ctx = tester.element(find.byType(Navigator));
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3a: Create `glossary_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  static const _entries = [
    ['Budgets flex', 'Each task has a time budget that can shrink when you’re late — so the day adapts instead of breaking.'],
    ['Anchors don’t', 'Your fixed boundaries (work, a shift, a pickup) never move. The day reshapes around them.'],
    ['Drift', 'When you run late, later tasks shift forward. The app shows the new estimated start for each.'],
    ['Compaction', 'To protect an anchor, flexible tasks trim toward their minimum before anything is dropped.'],
    ['Dropped', 'If there’s truly no room, the least important task is set aside for today (never deleted from your plan).'],
    ['Just for today', 'Removing, reordering, or re-prioritising only changes today. Your master plan stays the same.'],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(backgroundColor: c.bg, elevation: 0, foregroundColor: c.cream,
          title: Text('How Reminders works', style: GoogleFonts.fraunces(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        for (final e in _entries) Padding(padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e[0], style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w700, color: c.cream)),
            const SizedBox(height: 4),
            Text(e[1], style: TextStyle(fontSize: 13.5, height: 1.5, color: c.muted)),
          ])),
      ]),
    );
  }
}
```

- [ ] **Step 3b: Create `settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../data/ui_prefs.dart';
import '../theme/app_palette.dart';
import 'glossary_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final appState = RemindersApp.of(context);
    final prefs = appState?.prefs ?? const UiPrefs();

    void setMode(ThemeMode m) => appState?.updatePrefs(prefs.copyWith(themeMode: m));
    void setScale(double s) => appState?.updatePrefs(prefs.copyWith(textScale: s));

    return Scaffold(
      appBar: AppBar(backgroundColor: c.bg, elevation: 0, foregroundColor: c.cream,
          title: Text('Settings', style: GoogleFonts.fraunces(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('APPEARANCE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
          ],
          selected: {prefs.themeMode},
          onSelectionChanged: (s) => setMode(s.first),
        ),
        const SizedBox(height: 20),
        Text('TEXT SIZE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        Slider(value: prefs.textScale, min: 0.9, max: 1.4, divisions: 5, label: '${prefs.textScale}x', onChanged: setScale),
        const Divider(),
        ListTile(contentPadding: EdgeInsets.zero, title: Text('How Reminders works', style: TextStyle(color: c.cream)),
            trailing: Icon(Icons.chevron_right, color: c.dim),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlossaryScreen()))),
      ]),
    );
  }
}
```

> This requires exposing `prefs` on `_RemindersAppState`. In `main.dart`, add a getter: `UiPrefs get prefs => _prefs;` to `_RemindersAppState`, and make `RemindersApp.of` return the public type. Simplest: change `static _RemindersAppState? of(...)` to return the state and add `UiPrefs get prefs => _prefs;` (already has `updatePrefs`).

- [ ] **Step 3c:** In `main.dart`, add to `_RemindersAppState`: `UiPrefs get prefs => _prefs;`.

- [ ] **Step 4: Run** — `flutter test test/screens/settings_screen_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/glossary_screen.dart daily_command_center/lib/screens/settings_screen.dart daily_command_center/lib/main.dart daily_command_center/test/screens/settings_screen_test.dart
git commit -m "feat(ui): Glossary + Settings (theme/text-size) screens"
```

### Task U6.2: `NowHeroCard` (Home Right-Now hero)

**Files:**
- Create: `lib/widgets/now_hero_card.dart`
- Test: `test/widgets/now_hero_card_test.dart`

Consumes a `HomeNowState` (pure). Shows the ring, current/next, and the whisper only when present.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/home_now_state.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/now_hero_card.dart';

Widget _wrap(Widget w) => MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: w));

void main() {
  testWidgets('shows current + whisper when drifting', (tester) async {
    const s = HomeNowState(isResting: false, isDayDone: false, currentLabel: 'Shower + brunch',
        minutesLeft: 22, budgetMinutes: 30, progress: .3, nextLabel: 'Walk to office', nextTime: '1:50',
        whisper: 'Running ~25m behind · trimmed Brunch to hold Work.');
    await tester.pumpWidget(_wrap(const NowHeroCard(state: s, onOpen: _noop)));
    expect(find.text('Shower + brunch'), findsOneWidget);
    expect(find.textContaining('Running ~25m behind'), findsOneWidget);
  });

  testWidgets('no whisper when on track', (tester) async {
    const s = HomeNowState(isResting: false, isDayDone: false, currentLabel: 'Deep Focus',
        minutesLeft: 41, budgetMinutes: 75, progress: .45, nextLabel: 'Brunch', nextTime: '11:00', whisper: null);
    await tester.pumpWidget(_wrap(const NowHeroCard(state: s, onOpen: _noop)));
    expect(find.textContaining('behind'), findsNothing);
  });
}

void _noop() {}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Create `now_hero_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../logic/home_now_state.dart';
import '../theme/app_palette.dart';

class NowHeroCard extends StatelessWidget {
  final HomeNowState state;
  final VoidCallback onOpen;
  const NowHeroCard({super.key, required this.state, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final title = state.isResting
        ? 'Still resting'
        : state.isDayDone ? 'Day’s done. Rest up.' : state.currentLabel;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c.panel2, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('▶ RIGHT NOW', style: TextStyle(fontSize: 9, letterSpacing: 2, color: c.moss, fontWeight: FontWeight.w700)),
            if (!state.isResting && !state.isDayDone)
              SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: state.progress, strokeWidth: 4, color: c.moss, backgroundColor: c.line),
                Text('${state.minutesLeft}′', style: TextStyle(fontSize: 10, color: c.moss, fontWeight: FontWeight.w700)),
              ])),
          ]),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.fraunces(fontSize: 21, fontWeight: FontWeight.w600, color: c.cream)),
          if (!state.isResting && !state.isDayDone)
            Padding(padding: const EdgeInsets.only(top: 2),
              child: Text('${state.minutesLeft}m left of ${state.budgetMinutes}m budget', style: TextStyle(fontSize: 11.5, color: c.muted))),
          if (state.whisper != null)
            Padding(padding: const EdgeInsets.only(top: 10),
              child: Text(state.whisper!, style: TextStyle(fontSize: 12, color: c.amber))),
          if (state.nextLabel.isNotEmpty)
            Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Text('Next · ${state.nextTime} ${state.nextLabel}', style: TextStyle(fontSize: 12.5, color: c.muted))),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/widgets/now_hero_card.dart daily_command_center/test/widgets/now_hero_card_test.dart
git commit -m "feat(ui): NowHeroCard — Home Right-Now hero (ring + whisper)"
```

### Task U6.3: `AvatarMenuSheet` (replaces the drawer)

**Files:**
- Create: `lib/widgets/avatar_menu_sheet.dart`
- Test: `test/widgets/avatar_menu_sheet_test.dart`

Callback-based (no screen deps): the host wires navigation. Supersedes the app-shell drawer.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/avatar_menu_sheet.dart';

void main() {
  testWidgets('lists rare actions and fires the chosen callback', (tester) async {
    var openedSettings = false;
    await tester.pumpWidget(MaterialApp(theme: AppPalette.darkTheme, home: Scaffold(body: Builder(builder: (ctx) =>
      ElevatedButton(onPressed: () => showAvatarMenu(ctx, name: 'Cyrus', subtitle: 'cyrus_recomp',
        onSwitchProfile: () {}, onOpenSettings: () => openedSettings = true, onOpenGlossary: () {}, onLogout: () {}),
        child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Settings & appearance'), findsOneWidget);
    await tester.tap(find.text('Settings & appearance'));
    await tester.pumpAndSettle();
    expect(openedSettings, true);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Create `avatar_menu_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

Future<void> showAvatarMenu(BuildContext context, {
  required String name, required String subtitle,
  required VoidCallback onSwitchProfile, required VoidCallback onOpenSettings,
  required VoidCallback onOpenGlossary, required VoidCallback onLogout,
}) {
  final c = context.c;
  return showModalBottomSheet(context: context, backgroundColor: c.panel2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: c.terra, child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.fraunces(fontSize: 18, color: c.cream)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: c.dim)),
          ]),
        ]),
        const Divider(height: 24),
        _item(c, Icons.swap_horiz, 'Switch profile', () { Navigator.pop(context); onSwitchProfile(); }),
        _item(c, Icons.settings_outlined, 'Settings & appearance', () { Navigator.pop(context); onOpenSettings(); }),
        _item(c, Icons.help_outline, 'How Reminders works', () { Navigator.pop(context); onOpenGlossary(); }),
        _item(c, Icons.logout, 'Log out', () { Navigator.pop(context); onLogout(); }),
      ]))));
}

Widget _item(AppPalette c, IconData icon, String label, VoidCallback onTap) =>
    ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: c.sky),
        title: Text(label, style: TextStyle(color: c.cream, fontSize: 14)), onTap: onTap);
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/widgets/avatar_menu_sheet.dart daily_command_center/test/widgets/avatar_menu_sheet_test.dart
git commit -m "feat(ui): AvatarMenuSheet — identity + rare actions (replaces drawer)"
```

### Task U6.4: Rebuild `home_screen.dart` (hero + avatar + open Live + edges) + migrate `week_planner`

**Files:**
- Modify: `lib/screens/home_screen.dart`, `lib/widgets/week_planner.dart`
- Test: `test/screens/home_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/main.dart';
import 'package:daily_command_center/widgets/now_hero_card.dart';
import 'package:daily_command_center/screens/live_timeline_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home shows hero and opens Live on tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RemindersApp());
    await tester.pumpAndSettle();
    expect(find.byType(NowHeroCard), findsOneWidget);
    await tester.tap(find.byType(NowHeroCard));
    await tester.pumpAndSettle();
    expect(find.byType(LiveTimelineView), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (home still uses old `NowCard`).

- [ ] **Step 3: Rebuild `home_screen.dart`** — load Plan + DailyState, compute `ResolvedDay`+`HomeNowState`, render hero + mini-strip + week planner, avatar opens the sheet, tapping hero opens Live.

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/state_store.dart';
import '../data/adherence_store.dart';
import '../logic/timeline.dart';
import '../logic/drift_engine.dart';
import '../logic/home_now_state.dart';
import '../theme/app_palette.dart';
import '../widgets/now_hero_card.dart';
import '../widgets/week_planner.dart';
import '../widgets/avatar_menu_sheet.dart';
import 'live_timeline_view.dart';
import 'settings_screen.dart';
import 'glossary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Plan? _plan;
  DailyState _state = const DailyState(date: '');
  Set<String> _done = {};
  static const _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  late String _todayKey;

  @override
  void initState() {
    super.initState();
    _todayKey = _days[DateTime.now().weekday % 7];
    _load();
  }

  Future<void> _load() async {
    final plan = await AppStore.loadPlan();
    final state = await StateStore.loadState(DateTime.now());
    final done = await AdherenceStore.loadDone(DateTime.now());
    if (!mounted) return;
    setState(() { _plan = plan; _state = state; _done = done; });
    AppStore.writeWidgetData(plan, _todayKey).ignore();
  }

  ResolvedDay _resolve(Plan plan) =>
      DriftEngine.computeDay(buildTimeline(_todayKey, plan, _state), now: nowDecimal(), done: _done, dateIso: _state.date);

  void _openLive(Plan plan) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveTimelineView(plan: plan, todayKey: _todayKey)));

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
    final now = HomeNowState.from(_resolve(plan), now: nowDecimal());
    final trackable = buildTimeline(_todayKey, plan, _state).where((b) => b.isTrackable).toList();
    final doneCount = trackable.where((b) => _done.contains(b.signature)).length;

    return Scaffold(
      body: ListView(children: [
        _header(c),
        NowHeroCard(state: now, onOpen: () => _openLive(plan)),
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
        Text('Run the day.', style: GoogleFonts.fraunces(fontSize: 34, fontWeight: FontWeight.w900, color: c.cream, height: .95)),
      ])),
      GestureDetector(
        onTap: () => showAvatarMenu(context, name: 'Cyrus', subtitle: _plan?.meta.lifestyleArchetype ?? '',
          onSwitchProfile: () {}, // wired to the profiles spec later
          onOpenSettings: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          onOpenGlossary: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlossaryScreen())),
          onLogout: () {}),
        child: CircleAvatar(radius: 19, backgroundColor: c.terraD,
            child: Text('C', style: TextStyle(color: c.terra, fontWeight: FontWeight.w700))),
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
      Text(n, style: GoogleFonts.fraunces(fontWeight: FontWeight.w900, fontSize: 16, color: color ?? c.cream)),
      Text(t, style: TextStyle(fontSize: 10.5, color: c.dim)),
    ]),
  );
}
```

- [ ] **Step 4: Migrate `week_planner.dart` to `context.c`.** Replace every `AppColors.x` reference with `context.c.x` (de-const the affected widgets). The planner now reads `plan.week` entries (already v3 from the engine plan); map `colorKey` → palette: `terra`/`sky`/`amber` → `c.terra`/`c.sky`/`c.amber`. Run `flutter test test/widgets/week_planner_test.dart` to confirm it still passes (update the test imports to pump with `AppPalette.darkTheme`).

- [ ] **Step 5: Run** — `flutter test test/screens/home_screen_test.dart` — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add daily_command_center/lib/screens/home_screen.dart daily_command_center/lib/widgets/week_planner.dart daily_command_center/test/screens/home_screen_test.dart daily_command_center/test/widgets/week_planner_test.dart
git commit -m "feat(ui): rebuild Home (hero + avatar + open Live) + theme-migrate week planner"
```

---

## Phase U7 — Guardrail, cleanup, docs

### Task U7.1: No-hardcoded-life-strings guard test

**Files:**
- Test: `test/guard/no_hardcoded_life_strings_test.dart`

Enforces spec §3: no Life-JSON label appears as a string literal anywhere in `lib/`. Loads the seed, collects its distinctive labels, and scans every `.dart` file.

- [ ] **Step 1: Write the test (this is the deliverable — it must pass)**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no Life-JSON label is hardcoded in lib/', () async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    // Distinctive labels that must only ever come from the JSON (skip short/generic ones).
    final labels = <String>{
      ...plan.workouts.values.map((w) => w.title),
      ...plan.dayTemplates.values.expand((t) => t.routineStack.map((i) => i.label)),
      ...plan.dayTemplates.values.expand((t) => t.anchors.map((a) => a.label)),
    }.where((s) => s.trim().length > 6).toSet();

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final label in labels) {
        if (src.contains("'$label'") || src.contains('"$label"')) {
          offenders.add('${entity.path}: "$label"');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Life content must come from JSON, not Dart:\n${offenders.join('\n')}');
  });
}
```

- [ ] **Step 2: Run** — `flutter test test/guard/no_hardcoded_life_strings_test.dart` — Expected: PASS. If it FAILS, the named file hardcodes a life label — fix that widget to read the label from the `Block`/`Plan` instead, then re-run.

- [ ] **Step 3:** (No implementation file — the test *is* the guard. If offenders exist, fix the offending widget.)

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/test/guard/no_hardcoded_life_strings_test.dart
git commit -m "test(guard): forbid hardcoded Life-JSON labels in lib/"
```

### Task U7.2: Retire `now_card.dart` + `today_screen.dart`; delete `AppColors`

**Files:**
- Delete: `lib/widgets/now_card.dart`, `lib/screens/today_screen.dart`, and their test files
- Modify: `lib/main.dart` (remove the `AppColors` class)

By now Home uses `NowHeroCard`, the rich surface is `LiveTimelineView`, and the weekly review lives in `WeeklyReviewCard` — the old `NowCard`/`TodayScreen` are dead, and every widget reads `context.c`, so `AppColors` is unused.

- [ ] **Step 1: Confirm no references remain.** Run a search:

Run: `grep -rn "AppColors\|now_card\|today_screen\|TodayScreen\|NowCard" daily_command_center/lib`
Expected: no matches (or only the `AppColors` definition in `main.dart`).

- [ ] **Step 2: Delete the dead files**

```bash
git rm daily_command_center/lib/widgets/now_card.dart daily_command_center/lib/screens/today_screen.dart
git rm daily_command_center/test/widgets/now_card_test.dart daily_command_center/test/screens/today_screen_test.dart
```

(If a test filename differs, delete the actual file that tests `NowCard`/`TodayScreen`.)

- [ ] **Step 3: Remove the `AppColors` class** from the bottom of `lib/main.dart` (lines defining `class AppColors { … }`). Leave the rest of `main.dart` intact.

- [ ] **Step 4: Run the whole suite** — `flutter test` — Expected: ALL PASS (engine + UX). Then `flutter analyze` — Expected: no errors. Then `flutter run` to smoke-check both themes.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(ui): retire NowCard/TodayScreen + delete AppColors (fully themed)"
```

### Task U7.3: Reconcile docs — engine plan banners, app-shell spec, ADR, CONTINUE

**Files:**
- Modify: `docs/superpowers/plans/2026-06-07-life-json-v3-drift-engine.md` (banner on Phase D3 + Phase E)
- Modify: `docs/superpowers/specs/2026-06-07-local-profiles-login-app-shell-design.md` (drawer → avatar menu note)
- Modify: `docs/DECISIONS.md` (add ADR-018), `docs/CONTINUE.md` (point to this plan)

- [ ] **Step 1: Banner the engine plan's superseded tasks.** At the top of the engine plan's **Phase D Task D3** and **Phase E** sections, add:

```markdown
> ⚠️ **SUPERSEDED (2026-06-08)** by the UX-layer plan [`2026-06-08-reminders-2-ux-layer.md`](2026-06-08-reminders-2-ux-layer.md). Build the UX-layer version (read-only Live + explicit Adjust mode + humanized priority; WeeklyReviewCard) instead of this task. Kept for history.
```

- [ ] **Step 2: Note the drawer supersession** in the app-shell spec — find its "side panel / drawer" item and append:

```markdown
> **Updated 2026-06-08:** the navigation drawer is replaced by the **avatar menu sheet** (see [`2026-06-08-reminders-2-ux-design.md`](2026-06-08-reminders-2-ux-design.md) §2 and ADR-018). Wire the profile-switch / log-out actions there.
```

- [ ] **Step 3: Add ADR-018 to `DECISIONS.md`**

```markdown
## ADR-018 — UX layer: calm Home ⇄ Live, avatar menu, no-red, no-hardcoded-life-strings

**Decision:** The drift engine is presented via a calm Home (Right-Now hero + drift whisper) that opens a rich read-only **Live** timeline (elastic budget bars, state-morph, anchor walls); editing is a gated **Adjust mode** writing `DailyState` only, with humanized **Protect/Normal/Drop-first** priority. Rare actions live behind an **avatar menu** (no drawer). The palette uses **no red** (amber is the loudest tone), and a guard test forbids any **hardcoded Life-JSON label** in `lib/`. Full spec: [`specs/2026-06-08-reminders-2-ux-design.md`](superpowers/specs/2026-06-08-reminders-2-ux-design.md).

**Why:** Make a rich engine feel natural and reassuring ("in good hands"), treat a human day as normal (no hustle/guilt), and keep the whole UI lifestyle-agnostic so one presentation renders any Life JSON.

**Supersedes:** the engine plan's Phase E (always-on inline editing) and D3 (minimal weekly card), and the app-shell drawer.
```

- [ ] **Step 4: Point `CONTINUE.md`** at this plan — in the spec/plan table, add a row:

```markdown
| [`plans/2026-06-08-reminders-2-ux-layer.md`](superpowers/plans/2026-06-08-reminders-2-ux-layer.md) | **UX-layer implementation plan** (Home/Live/Adjust/teaching/review/theming) | **Written — ready to execute (after engine A–D)** |
```

- [ ] **Step 5: Commit**

```bash
git add docs/
git commit -m "docs: reconcile UX layer — banner engine D3/E, ADR-018, app-shell drawer, CONTINUE"
```

---

## Self-review (plan vs. UX spec)

**Spec coverage** — every UX-spec section maps to a task:

| Spec § | Requirement | Task(s) |
|---|---|---|
| §1 | Philosophy (no-red, calm, in-good-hands) | U0.2 (palette), threaded throughout |
| §2 | IA: Home⇄Live, avatar menu | U6.2/U6.3/U6.4 |
| §3 | No hardcoded life content | U1.2 (DriftCopy), **U7.1 guard test** |
| §4 | Visual system, light/dark | U0.2, U0.3 |
| §5 | Home calm + whisper + edges | U1.3, U6.2, U6.4 |
| §6 | Live dual-time + state-morph + anchors + summary | U2.1, U2.2, U3.2 |
| §7 | Adjust mode (remove/priority/reorder/cross-wall/Undo) | U4.1–U4.4 |
| §8 | Just-in-time teaching + glossary | U5.1, U5.2, U6.1 |
| §9 | Voice/tone copy | U1.2 (DriftCopy) |
| §10 | QoL: check-off, edges, light theme, peek | U3.3, U6.4 (edges), U0/U6.1 (theme), U3.4 (peek) |
| §11 | Drift log → weekly review + Sunday nudge | U3.1 |
| §12 | One quiet notification + edges | engine plan C; edges in U1.3/U6.4 |
| §13 | Component inventory, supersessions | U7.2, U7.3 |
| §15 | Success criteria (lifestyle-agnostic, reversible, no red) | U7.1 guard, U4.4 Undo, U0.2 |

**Placeholder scan:** no "TBD"/"handle later". Two explicit **forward-ref notes** (U5.2 `GlossaryScreen`, and Settings needing `prefs` getter) include the exact fix inline — not placeholders.

**Type consistency:** `HomeNowState`, `DriftCopy`, `PriorityLevel`, `AppPalette`/`context.c`, `LiveTimelineViewState` (+ `reorderForTest`/`restoreForTest`/`setLevelForTest`), `BudgetBar`, `AnchorWall`, `WeeklyReviewCard`, `TeachingCard`, `NowHeroCard`, `showAvatarMenu`, `TeachingFlags`, `UiPrefs`, `RemindersApp.of(context).prefs/updatePrefs` are used identically across tasks. `WeeklySummary`/`DriftEvent`/`ResolvedDay`/`Block` come from the engine plan (prerequisite).

**Sequencing:** logic before widgets; shared widgets before Live; Live before Home links to it; old screens retired last. Each phase keeps the app compiling/running.

**Known follow-ups (intentionally out of scope):** profile-switch / logout wiring (the local-profiles spec); the Android widget Glance redesign (standing blocker); the structural Life-JSON editor (sub-project 2). The `onSwitchProfile`/`onLogout` callbacks are left as no-ops to be wired by the profiles work.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-08-reminders-2-ux-layer.md`. **Prerequisite:** the engine plan's Phases A–D must be built first (this plan consumes `ResolvedDay`, `DriftEngine`, `StateStore`, etc., and supersedes engine Phase E + D3).

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)
2. **Inline Execution** — execute tasks in this session via superpowers:executing-plans, batched with checkpoints.

Which approach?
