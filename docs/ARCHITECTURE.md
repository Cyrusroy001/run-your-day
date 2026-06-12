# Architecture Overview

Quick reference for navigating the codebase. Read before asking "where does X live?"
Current as of session 9 (ketchup v1 rebrand). The app is branded **ketchup**.

---

## Two-layer system

```
┌─────────────────────────────────┐
│        Flutter App              │  User opens app → loads active profile's Plan
│  (lib/ — Dart)                  │  → assembles + drift-resolves today → renders;
│                                 │  pushes now-state to home_widget prefs
└────────────────┬────────────────┘
                 │ home_widget → HomeWidgetPreferences (raw keys)
┌────────────────▼────────────────┐
│   Android Home Screen Widget    │  Reads the pushed now-state on refresh.
│  (android/ — Kotlin)            │  DEFERRED for v1 (broken on Samsung One UI /
└─────────────────────────────────┘  Android 16 — ADR-010). Code left untouched.
```

---

## Flutter app layers

### Data (`lib/data/`) — persistence + platform I/O

| File | What it owns |
|---|---|
| `models.dart` | All data types: `Block` (+ `isTrackable`/`signature`/`isCompacted`/`isDropped`), v3 `Plan`/`DayTemplate`/`Anchor`/`RoutineItem` (+ `copyWith`), `WorkoutDef`/`ExerciseDef`/`Progression`, `WeekEntry`, `DailyState`/`DriftEvent`/`ItemOverride`, `CustomTask`/`RecurringCustomTask`, `displayTime()` |
| `profile_repository.dart` | **File-per-profile** store: `ProfileRepository` (dir, create/list/delete, `ensureSeeded`, reset/clear, export/import) + `ProfileDoc`; `activeProfile` `ValueNotifier` + active-id pointer |
| `store.dart` | `AppStore` facade over the active `ProfileDoc` (`loadActive`/`savePlan`/`saveLogs`); writes widget data via `home_widget` (try-catch — ADR-009); `AppStore.repo` is injectable for tests |
| `state_store.dart` | `DailyState` (+ drift log) load/save and recent-window queries via `ProfileRepository` |
| `adherence_store.dart` | Per-day done-set + adherence summary: `loadDone`/`saveDone`, `writeAdherence`, `last7` |
| `recurring_store.dart` | `RecurringCustomTask` persistence (C7) |
| `teaching_flags.dart` | One-time "seen" flags for inline teach captions (R5) |
| `notifications.dart` | `NotificationService` — Android channel + scheduling (circuit-breaker fire from ADR-014; the v1 opt-in heads-up gets wired here in **K-notify**) |
| `ui_prefs.dart` | `UiPrefs` (themeMode + textScale), loaded in `main()`, owned by `RemindersApp` |

### Logic (`lib/logic/`) — pure Dart, no Flutter, fully testable

| File | What it owns |
|---|---|
| `assembler.dart` | `TimelineAssembler.assembleDay()` — the **only** place blocks are built from a Plan (folds anchors + routine + custom tasks, applies DailyState). Golden test is the canonical check |
| `timeline.dart` | `buildTimes()` (24h decimals, monotonic + PM disambiguation) + `nowDecimal()` |
| `drift_engine.dart` | `DriftEngine.computeDay()` → `ResolvedDay`: est-start cascade, compaction, jettison, two-way elasticity, circuit-breakers |
| `drift_copy.dart` | Drift copy. Ketchup voice: `ketchupWhisper()` / `isCaughtUp()` (the one-sentence whisper); plus teach strings, `weeklyNudge` |
| `home_now_state.dart` | `HomeNowState.from()` — current/next block + progress for the hero |
| `priority_level.dart` | `PriorityLevel` (Protect/Normal/Drop first) ↔ numeric priority |
| `weekly_review.dart` | `WeeklyReview.summarize()` (`WeeklySummary`), `promotionCandidates()`, `mostSqueezedLabel()` |
| `custom_task_fitter.dart` | `CustomTaskFitter` — slack + sacrifice offers for ad-hoc task injection (C-series) |
| `blueprint_promotion.dart` | `BlueprintPromotion.promote()` — writes a recurring custom task into the Plan |
| `planner.dart` | `PlannerLogic` — week spacing (4 training days, no consecutive), `toggleTraining`/`toggleSchedule` |
| `validator.dart` | `PlanValidator` — referential integrity of a Plan |
| `onboarding.dart` | `OnboardingLogic.buildPlan`/`commit` — the seam the future interview/AI replaces |
| `drift_runner.dart` | Background drift evaluation + notification fire (ADR-014) |

### Theme (`lib/theme/`)

| File | What it owns |
|---|---|
| `app_palette.dart` | `AppPalette` (`ThemeExtension`) — **ketchup tokens**: `char/raise/raise2/salt/dim/line` + `tomato/tomatoDim/mustard/mustardDim/leaf/leafDim` + `onAccent`. Access via `context.c`. Dark default + light. The temp Reminders-2 aliases were removed in K8 — guard test forbids new `Color(0x…)` literals here-outside (ADR-020/021) |
| `transitions.dart` | `fadeThroughRoute` — shared page transition |

### UI (`lib/screens/`, `lib/widgets/`)

| File | What it owns |
|---|---|
| `screens/today_screen.dart` | **The one ketchup surface** (Home + Live merged). States caughtUp/squeezed/adjusting. Header (date+avatar) → past-pill → NOW hero → whisper → teach caption → repeat prompts → ElasticRail → ADJUST. Adjust mode = two-row cards (reorder/skip/priority + persistent Undo). FAB = add custom task. The AuthGate home |
| `widgets/elastic_rail.dart` | `ElasticRail` + `RailStop` — the signature rail: spine height ∝ duration (clamp 56–120), variants normal/squeeze/anchor/skip/done, tap-to-done, AnimatedSize/AnimatedContainer motion |
| `screens/week_screen.dart` | "Plan my week" (off Home; hosts `WeekPlanner`) |
| `screens/catchup_screen.dart` | Sunday catch-up (S6): bars + summary + "Give it more time" (only review→Plan write) + promotions |
| `screens/how_it_works_screen.dart` | "How ketchup works" — the six static captions (replaced the old glossary) |
| `screens/settings_screen.dart` | Appearance (theme seg + text-size), notification toggles, profile/data actions |
| `screens/onboarding_screen.dart` | 3-step onboarding stub (clones the seed plan) |
| `screens/login_screen.dart` | Local profile picker |
| `screens/auth_gate.dart` | `ValueListenableBuilder(activeProfile)` → `LoginScreen` (null) vs `TodayScreen` |
| `widgets/avatar_menu_sheet.dart` | Avatar sheet: Plan my week / Sunday catch-up (Sunday badge) / settings / how-it-works / switch / log out |
| `widgets/teach_caption.dart` | One inline ketchup teach caption (seen-flag gated) |
| `widgets/repeat_prompt_card.dart` | "Repeat {task}?" prompt (extracted from the retired live view in K8) |
| `widgets/{add_custom_task,sacrifice_picker,promote_blueprint}_sheet.dart` | Custom-task add / sacrifice picker / blueprint promotion sheets |
| `widgets/week_planner.dart` | One-row-per-day planner (schedule chip + train/rest), hosted by `week_screen` |
| `main.dart` | App entry; `RemindersApp` (MaterialApp, light/dark theme, textScale clamp); WorkManager widget-refresh registration |

> **Retired in K8** (deleted): `home_screen`, `live_timeline_view`, `glossary_screen`, `now_hero_card`, `budget_bar`, `anchor_wall`, `weekly_review_card`, `teaching_card`, and `lib/logic/workouts.dart` (workouts live in `Plan.workouts`). `AppColors` was replaced by `AppPalette` (ADR-020).

---

## Storage: file-per-profile (ADR-019)

`<appDocuments>/profiles/<id>.json` holds a `ProfileDoc`:

```text
ProfileDoc { id, displayName, plan: Plan,
  states: Map<'yyyy-MM-dd', DailyState>,   // drift log lives here
  logs: Map<workoutKey, List<WorkoutLog>>,
  done: Map<'yyyy-MM-dd', List<signature>>,
  adherence: Map<'yyyy-MM-dd', {done,total}>,
  recurringTasks, skippedRepeatIds }
```

Only two things live in **SharedPreferences**: the active-profile pointer (`activeProfileId`) and
the four **widget** keys, which `home_widget` writes as **raw** keys (no `flutter.` prefix) into its
own `HomeWidgetPreferences` file, read by `NowWidgetProvider.kt` via `HomeWidgetPlugin.getData`.
The seed `assets/seed_plan.json` is the source of truth for the default `cyrus` profile (golden test
fails if the timeline changes).

---

## Data flow

**App open / Today render**
```
AuthGate (activeProfile) → TodayScreen._load (active ProfileDoc → Plan + DailyState + done)
  → TimelineAssembler.assembleDay(plan, …, state)        // the only block source
  → DriftEngine.computeDay(now)                           // ResolvedDay (est-start, squeezes, drops)
  → HomeNowState.from() drives the hero; ResolvedDay→RailStop drives the ElasticRail
  → 30s ticker re-renders so progress/minutes-left stay live
```

**User interactions (today only)** — tap a rail card / hero Done → `_toggle` (done-set + adherence).
Adjust mode (reorder / skip / priority) and custom-task add write **DailyState only**; the Plan stays
pristine (ADR-015). The single review→Plan write is the catch-up's "Give it more time".

---

## Test coverage

`flutter test` (run from `daily_command_center/`). 192 tests, green.

| Area | Examples |
|---|---|
| `test/logic/` | golden timeline, drift engine/runner, weekly review, drift copy, planner, validator, custom-task fitter, assembler |
| `test/data/` | models roundtrips, profile/state/adherence stores, custom/daily-state |
| `test/screens/` | `today_screen` (hero + rail + adjust + give-more-time), `catchup_screen`, `auth_gate`, login, onboarding, settings |
| `test/widgets/` | `elastic_rail`, week planner, custom-task/sacrifice/promote sheets |
| `test/theme/` | `app_palette` (token values) |
| `test/guard/` | no hardcoded life strings; **no Color literal outside app_palette**; **no ⚠/Reflowed/budget/engine jargon on UI lines** (ADR-021) |

---

## Key invariants (do not break)

See CONTINUE.md "Key invariants" for the full list. The load-bearing ones: file-per-profile storage;
`TimelineAssembler` is the only block source (golden test is the net); `buildTimes` monotonic + PM
disambiguation; adherence counts trackable blocks only (`cls != 'work' && cls != 'chill'`); all color
via `context.c` tokens (guarded); `writeWidgetData` stays try-catch.
