# Architecture Overview

Quick reference for navigating the codebase. Read before asking "where does X live?"

---

## Two-layer system

```
┌─────────────────────────────────┐
│        Flutter App              │  User opens app → reads/writes plan
│  (lib/ — Dart)                  │  Computes now-state → pushes to SharedPrefs
└────────────────┬────────────────┘
                 │ home_widget → HomeWidgetPreferences (raw keys)
┌────────────────▼────────────────┐
│     Android Home Screen Widget  │  Reads SharedPrefs every 30 min
│  (android/ — Kotlin)            │  via HomeWidgetPlugin.getData; ~15 min (WorkManager)
└─────────────────────────────────┘
```

---

## Flutter app layers

### Data (`lib/data/`)

| File | What it owns |
|---|---|
| `models.dart` | All data types: `Block` (incl. `isTrackable` + `signature` getters), `DayPlan`, `DaySchedule`, `WorkoutLog`, `WeekPlan` |
| `store.dart` | Plan + workout-log I/O via SharedPreferences; writes widget data via `home_widget` |
| `adherence_store.dart` | Per-day done-set + adherence summary: `loadDone`/`saveDone`, `writeAdherence`, `last7`, `weeklyAverage` |

### Logic (`lib/logic/`) — pure Dart, no Flutter, fully testable

| File | What it owns |
|---|---|
| `workouts.dart` | `workouts` constant — the 4 workout definitions (A, B, BENCH, CARDIO) with exercises and cues |
| `timeline.dart` | `buildTimeline(day, plan)` → ordered block list; `buildTimes(blocks)` → 24h decimals; `nowDecimal()` → current time |
| `planner.dart` | `PlannerLogic` — spacing algorithm (brute-force C(7,4)=35), `toggleTraining`, `toggleSchedule`, `defaultWeek` |

### UI (`lib/widgets/`, `lib/screens/`)

| File | What it owns |
|---|---|
| `widgets/now_card.dart` | `NowCard` — stateful, self-refreshing (1 min timer). Shows current/next block; green "done" state; "View all ›" + "Mark done" (`doneToday`, `onViewAll`, `onToggleDone`). |
| `widgets/week_planner.dart` | `WeekPlanner` — one-row-per-day layout: schedule chip (Office/WFH/Weekend) + Train/Rest switch (calls `PlannerLogic`); inline caption (replaces SnackBar). |
| `screens/today_screen.dart` | `TodayScreen` — full-day tickable checklist + 7-day adherence strip. Pushed from NowCard's "View all". |
| `screens/home_screen.dart` | `HomeScreen` — loads plan + today's done-set, owns `_doneToday`, assembles NowCard + WeekPlanner, wires toggle/navigation |
| `main.dart` | App entry, `ThemeData`, `AppColors` constants |

---

## Android widget layer (`android/`)

```
android/app/src/main/
├── kotlin/com/cyrus/daily_command_center/
│   ├── MainActivity.kt          ← Flutter activity (auto-generated)
│   └── NowWidgetProvider.kt     ← AppWidgetProvider: reads SharedPrefs, builds RemoteViews
├── res/
│   ├── drawable/widget_background.xml   ← flat terracotta (#D9663D) — gradient+corners REMOVED (see ADR-010)
│   ├── layout/now_widget.xml            ← STRIPPED: label + title + next TextViews only (no ProgressBar)
│   ├── xml/now_widget_info.xml          ← size (4×2), update interval (30 min)
│   └── values/strings.xml               ← app_name, widget_description
└── AndroidManifest.xml          ← widget receiver registered here
```

> **Widget status: BROKEN on Samsung One UI / Android 16.** The layout was stripped to minimum to diagnose a Samsung launcher rejection issue. See CONTINUE.md and ADR-010 for full context before modifying widget files.

---

## Data flow: plan change

```
User taps training dot
  → WeekPlanner calls PlannerLogic.toggleTraining(plan, day)
  → Returns new WeekPlan (always 4 days, no consecutive)
  → WeekPlanner calls onPlanChanged(newPlan, message?)
  → HomeScreen._updatePlan saves to SharedPreferences
  → HomeScreen calls AppStore.writeWidgetData(plan, todayKey)
  → home_widget writes raw keys into its HomeWidgetPreferences file
  → Android widget reads on next refresh (~15 min via WorkManager, or app open)
```

## Data flow: app open / now-card refresh

```
App opens
  → HomeScreen.initState loads plan from SharedPreferences
  → NowCard receives plan, computes timeline via buildTimeline()
  → buildTimes() resolves time strings → 24h decimals
  → nowDecimal() reads device clock
  → NowCard finds current block, next block, progress %
  → NowCard renders gradient card
  → Timer fires every minute → setState → re-render
```

---

## SharedPreferences key map

| Key | Type | Written by | Read by |
|---|---|---|---|
| `weekPlan` | String (JSON) | `AppStore.savePlan` | `AppStore.loadPlan` |
| `log_A`, `log_B`, `log_BENCH`, `log_CARDIO` | String (JSON array) | `AppStore.saveLogs` | `AppStore.loadLogs` |
| `done_<yyyy-MM-dd>` | String (JSON array of block signatures) | `AdherenceStore.saveDone` | `AdherenceStore.loadDone` |
| `adherence_<yyyy-MM-dd>` | String (JSON `{done,total}`) | `AdherenceStore.writeAdherence` | `AdherenceStore.last7` |
| `currentAction` | String | `AppStore.writeWidgetData` | `NowWidgetProvider.kt` |
| `nextAction` | String | `AppStore.writeWidgetData` | `NowWidgetProvider.kt` |
| `dayLabel` | String | `AppStore.writeWidgetData` | `NowWidgetProvider.kt` |
| `progressPct` | Int | `AppStore.writeWidgetData` | `NowWidgetProvider.kt` (read but unused — widget_progress view removed) |

⚠️ The four widget keys above live in a **different file** from the rest of this table. `home_widget` writes them as **raw** keys (no `flutter.` prefix) into its own `HomeWidgetPreferences` file, and `NowWidgetProvider.kt` reads them via `HomeWidgetPlugin.getData(context)`. The other keys are the app's normal `shared_preferences` store (which *does* use a `flutter.` prefix internally, in `FlutterSharedPreferences`). The widget is refreshed ~every 15 min by a WorkManager periodic task (`main.dart`), plus on app open.

---

## Test coverage

| Test file | What it tests |
|---|---|
| `test/data/models_test.dart` | DayPlan/WorkoutLog serialization roundtrips |
| `test/logic/workouts_test.dart` | All 4 workout keys defined, each has title/why/exercises |
| `test/logic/timeline_test.dart` | buildTimes PM disambiguation, monotonicity, workout assignment per day type |
| `test/logic/planner_test.dart` | defaultWeek has 4 days/no consecutive, toggleTraining invariants, toggleSchedule flip |
| `test/data/adherence_store_test.dart` | done-set roundtrip, adherence write, `last7` averaging that ignores missing days |
| `test/widgets/now_card_test.dart` | NowCard renders; green "done" vs "Mark done" state |
| `test/widgets/week_planner_test.dart` | row-per-day layout, schedule chip cycle, train/rest switch, inline caption |
| `test/screens/today_screen_test.dart` | checklist renders, passive blocks faded/no checkbox, current block highlighted |

Run all: `flutter test`

---

## Planned layers (designed, not yet built)

Two approved directions will reshape the data layer. Read their specs/ADRs before building:

- **Local profiles + login + app shell** ([spec](superpowers/specs/2026-06-07-local-profiles-login-app-shell-design.md), ADR-018/019). An `AuthGate` root chooses `LoginScreen` (local profile picker) vs `AppShell` (Scaffold + navigation drawer). Persistence moves to **one JSON file per profile** (`profiles/<id>.json`) fronted by a new `ProfileRepository`; `AppStore`/`AdherenceStore` read/write through the active profile. New profiles run an onboarding stub. The Today monolith splits into drawer destinations (Today / Full Timeline / Week Planner / + placeholders / Settings / Logout).
- **Life JSON v3 drift engine** ([spec](superpowers/specs/2026-06-07-life-json-v3-drift-engine-design.md), [plan](superpowers/plans/2026-06-07-life-json-v3-drift-engine.md), ADR-011…017). Content moves out of Dart into `assets/seed_plan.json`; `timeline.dart` becomes a data-driven assembler; a `DriftEngine` adds dual-time, compaction, and circuit-breakers. State splits into an immutable `activePlan` + ephemeral `state_<date>`/`driftLog` (ADR-015).

The two compose: per-profile files become the container for the engine's `activePlan` + `state_<date>` + `driftLog` (ADR-019). Whichever ships second namespaces its storage per active profile.
