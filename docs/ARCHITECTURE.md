# Architecture Overview

Quick reference for navigating the codebase. Read before asking "where does X live?"

---

## Two-layer system

```
┌─────────────────────────────────┐
│        Flutter App              │  User opens app → reads/writes plan
│  (lib/ — Dart)                  │  Computes now-state → pushes to SharedPrefs
└────────────────┬────────────────┘
                 │ SharedPreferences (key: flutter.*)
┌────────────────▼────────────────┐
│     Android Home Screen Widget  │  Reads SharedPrefs every 30 min
│  (android/ — Kotlin)            │  Renders RemoteViews (no Flutter)
└─────────────────────────────────┘
```

---

## Flutter app layers

### Data (`lib/data/`)

| File | What it owns |
|---|---|
| `models.dart` | All data types: `Block`, `DayPlan`, `DaySchedule`, `WorkoutLog`, `WeekPlan` |
| `store.dart` | All I/O: load/save plan and logs via SharedPreferences; write widget data via `home_widget` |

### Logic (`lib/logic/`) — pure Dart, no Flutter, fully testable

| File | What it owns |
|---|---|
| `workouts.dart` | `workouts` constant — the 4 workout definitions (A, B, BENCH, CARDIO) with exercises and cues |
| `timeline.dart` | `buildTimeline(day, plan)` → ordered block list; `buildTimes(blocks)` → 24h decimals; `nowDecimal()` → current time |
| `planner.dart` | `PlannerLogic` — spacing algorithm (brute-force C(7,4)=35), `toggleTraining`, `toggleSchedule`, `defaultWeek` |

### UI (`lib/widgets/`, `lib/screens/`)

| File | What it owns |
|---|---|
| `widgets/now_card.dart` | `NowCard` — stateful, self-refreshing (1 min timer). Reads timeline + now-time to show current/next block + progress bar. |
| `widgets/week_planner.dart` | `WeekPlanner` — 7-day grid. Tap cell header = toggle office/WFH. Tap dot = toggle training (calls PlannerLogic). |
| `screens/home_screen.dart` | `HomeScreen` — loads plan from store, assembles NowCard + WeekPlanner, handles plan updates + toasts |
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
  → home_widget writes flutter.* keys to SharedPreferences
  → Android widget reads on next 30-min refresh
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
| `flutter.currentAction` | String | `AppStore.writeWidgetData` | `NowWidgetProvider.kt` |
| `flutter.nextAction` | String | `AppStore.writeWidgetData` | `NowWidgetProvider.kt` |
| `flutter.dayLabel` | String | `AppStore.writeWidgetData` | `NowWidgetProvider.kt` |
| `flutter.progressPct` | Int | `AppStore.writeWidgetData` | `NowWidgetProvider.kt` (read but unused — widget_progress view removed) |

The `flutter.` prefix is automatically added by the `home_widget` package when writing, and must be manually included in the Kotlin `getSharedPreferences` reads.

---

## Test coverage

| Test file | What it tests |
|---|---|
| `test/data/models_test.dart` | DayPlan/WorkoutLog serialization roundtrips |
| `test/logic/workouts_test.dart` | All 4 workout keys defined, each has title/why/exercises |
| `test/logic/timeline_test.dart` | buildTimes PM disambiguation, monotonicity, workout assignment per day type |
| `test/logic/planner_test.dart` | defaultWeek has 4 days/no consecutive, toggleTraining invariants, toggleSchedule flip |
| `test/widgets/now_card_test.dart` | NowCard renders without crash, "Right now" label present |

Run all: `flutter test`
