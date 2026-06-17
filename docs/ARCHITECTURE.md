# Architecture Overview

Quick reference for navigating the codebase. Read before asking "where does X live?"
Current as of session 11 (v1.1 "the garden" in flight — G0–G7.1 done). The app is branded **ketchup**.

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
│  (android/ — Kotlin)            │  Renders on One UI / Android 16 (ADR-010
└─────────────────────────────────┘  unblocked); v1.1 upgrades it to a painted arc (G9).
```

---

## Flutter app layers

### Data (`lib/data/`) — persistence + platform I/O

| File | What it owns |
|---|---|
| `models.dart` | All data types: `Block` (+ `isTrackable`/`signature`/`isCompacted`/`isDropped`), v3 `Plan`/`DayTemplate`/`Anchor`/`RoutineItem` (+ `copyWith`), `WorkoutDef`/`ExerciseDef`/`Progression`, `WeekEntry`/`WeekEditorConfig`/`TrainingRules`, `DailyState`/`DriftEvent`/`ItemOverride`, `CustomTask`/`RecurringCustomTask`, **`DayKetchup`/`BatchGrade`** (the pantry record — ADR-022), `displayTime()` |
| `profile_repository.dart` | **File-per-profile** store: `ProfileRepository` (dir, create/list/delete, `ensureSeeded`, reset/clear, export/import) + `ProfileDoc`; `activeProfile` `ValueNotifier` + active-id pointer |
| `store.dart` | `AppStore` facade over the active `ProfileDoc` (`loadActive`/`savePlan`/`saveLogs`); writes widget data via `home_widget` (try-catch — ADR-009); `AppStore.repo` is injectable for tests |
| `state_store.dart` | `DailyState` (+ drift log) load/save and recent-window queries via `ProfileRepository` |
| `adherence_store.dart` | Per-day done-set + adherence summary: `loadDone`/`saveDone`, `writeAdherence`, `last7` |
| `ketchup_store.dart` | Pantry records (G3.2): derive + persist `DayKetchup` per day, `last7` jars (stored record wins, else derived from adherence + drift log) |
| `day_actions.dart` | `DayActions.togglePick` — the **one** Pick ✓ write path (done-set + adherence + pantry + widget push), shared by Today + Timeline (G3.3); captures late picks |
| `recurring_store.dart` | `RecurringCustomTask` persistence (C7) |
| `teaching_flags.dart` | One-time "seen" flags for inline teach captions (R5) |
| `notifications.dart` | `NotificationService` — Android channel + scheduling (circuit-breaker fire from ADR-014; the v1 opt-in heads-up + Sunday nudge are wired here — K-notify, shipped) |
| `ui_prefs.dart` | `UiPrefs` (themeMode + textScale), loaded in `main()`, owned by `RemindersApp` |

### Logic (`lib/logic/`) — pure Dart, no Flutter, fully testable

| File | What it owns |
|---|---|
| `assembler.dart` | `TimelineAssembler.assembleDay()` — the **only** place blocks are built from a Plan (folds anchors + routine + custom tasks, applies DailyState). Golden test is the canonical check |
| `timeline.dart` | `buildTimes()` (24h decimals, monotonic + PM disambiguation) + `nowDecimal()` |
| `drift_engine.dart` | `DriftEngine.computeDay()` → `ResolvedDay`: est-start cascade, compaction, jettison, two-way elasticity, circuit-breakers. **`_findCurrent` picks the present-time block** (un-done past tasks are *missed* → kept in the past, not pulled to now) + hard-anchor missed-cleanup (ADR-023) |
| `ripeness.dart` | `Ripeness` enum + `RipenessRules.assign` — time-relative ripeness per block (pure; ADR-022) |
| `sun_clock.dart` | `SkyPhase`/`SkyBlend`/`SunClock` — pure local-clock sun curve (no location); ambient grounds |
| `day_arc.dart` | `DayArc`/`ArcStop` — the day as one arc across the waking window (sun-arc + night detection) |
| `week_modifiers.dart` | `WeekModifiers.of(plan)` — generic 0..N day modifiers ("cages") + rule-generated captions (G7.1) |
| `drift_copy.dart` | Drift copy. Ketchup voice: `ketchupWhisper()` / `isCaughtUp()` (the one-sentence whisper); plus teach strings, `weeklyNudge` |
| `home_now_state.dart` | `HomeNowState.from()` — current/next block + progress for the hero (present-time via the engine; ADR-023) |
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
| `app_palette.dart` | `AppPalette` (`ThemeExtension`) — **garden tokens** (G0.1, ADR-022): grounds `char/raise/raise2/salt/dim/line`; ripeness ramp `unripe/ripening/nearly/ripe/jammy/jammyText`; `vine`(+`vineDim`) = primary action; `ripe` = NOW only; sky `skyDawn/Day/Golden/Dusk/Night/star`; `plotA–D`; `todayTint`; `onAccent`. Mappings `fruit()`/`sky()`/`ambient()`. **Light is the default** (G0.3). Access via `context.c`; guard test forbids new `Color(0x…)` outside this file (ADR-020/021) |
| `transitions.dart` | `fadeThroughRoute` — shared page transition |

### UI (`lib/screens/`, `lib/widgets/`)

| File | What it owns |
|---|---|
| `screens/home_shell.dart` | **The 3-tab shell** (Today · Timeline · Week — G4.3). `NavigationBar`; each tab rebuilds on entry (state lives in the stores). The AuthGate home |
| `screens/today_screen.dart` | **Today tab** (G5.3): ambient sun-clock ground → header → `SunArcCard` → NOW hero (`● RIPE NOW`, `Pick ✓`) → whisper → teach/repeat → `UP NEXT` + `THIS WEEK` jar glance cards → Sunday chip. Night state = `NightCard` (no SunArcCard/labels). FAB = `AddTaskFab` |
| `screens/timeline_screen.dart` | **Timeline tab** (G4.2/G6.2): the living `VineTimeline` over the full day + ADJUST mode (two-row reorder/skip/priority + Undo). Pick via `DayActions.togglePick` |
| `widgets/vine_timeline.dart` | `VineTimeline` + `VineStop` — the vine climbing upward (future above, NOW inline+enlarged, basket folds the walked morning; jammy past fruit offer *pick late*); tension = drift (G6.1). Replaced `elastic_rail.dart` |
| `widgets/sun_arc_card.dart` | `SunArcCard` + `ArcPainter` — the day as one arc (fruit at their hours, walked arc thickens, NOW glow); reused by the widget render (G5.1) |
| `widgets/jar_shelf.dart` | `JarShelf` — 7 pantry jars (fill = picked/trackable, tint = batch grade); `mini` for Today, full for the catch-up (G5.2) |
| `widgets/night_card.dart` | `NightCard` — textless stars + a green bud (day-done metaphor; G5.2) |
| `widgets/add_task_fab.dart` | `AddTaskFab` — shared add→fit→sacrifice flow for Today + Timeline (G4.4) |
| `widgets/widget_arc_card.dart` | `WidgetArcCard` — offscreen render (explicit palette) of the sun-arc / night bud, rasterised for the home-screen widget (G9.1) |
| `screens/week_screen.dart` | **Week tab** — the allotment (plots + detail card; G7.2 in progress). Self-loading (G4.1). *Still hosts `WeekPlanner` until G7.2 lands* |
| `screens/catchup_screen.dart` | Sunday catch-up (S6): bars + summary + "Give it more time" (only review→Plan write) + promotions |
| `screens/how_it_works_screen.dart` | "How ketchup works" — the six static captions (replaced the old glossary) |
| `screens/settings_screen.dart` | Appearance (theme seg + text-size), notification toggles, profile/data actions |
| `screens/onboarding_screen.dart` | 3-step onboarding stub (clones the seed plan) |
| `screens/login_screen.dart` | Local profile picker |
| `screens/auth_gate.dart` | `ValueListenableBuilder(activeProfile)` → `LoginScreen` (null) vs `HomeShell` |
| `widgets/avatar_menu_sheet.dart` | Avatar sheet: Sunday catch-up (Sunday badge) / settings / how-it-works / switch / log out (Plan-my-week row dropped in G4.3 — Week is a tab) |
| `widgets/teach_caption.dart` | One inline ketchup teach caption (seen-flag gated) |
| `widgets/repeat_prompt_card.dart` | "Repeat {task}?" prompt (extracted from the retired live view in K8) |
| `widgets/{add_custom_task,sacrifice_picker,promote_blueprint}_sheet.dart` | Custom-task add / sacrifice picker / blueprint promotion sheets |
| `widgets/week_planner.dart` | One-row-per-day planner (schedule chip + train/rest), hosted by `week_screen` |
| `main.dart` | App entry; `RemindersApp` (MaterialApp, light/dark theme, textScale clamp); WorkManager widget-refresh registration |

> **Retired in K8** (deleted): `home_screen`, `live_timeline_view`, `glossary_screen`, `now_hero_card`, `budget_bar`, `anchor_wall`, `weekly_review_card`, `teaching_card`, and `lib/logic/workouts.dart` (workouts live in `Plan.workouts`). `AppColors` was replaced by `AppPalette` (ADR-020).
> **Retired in v1.1:** `widgets/elastic_rail.dart` (→ `vine_timeline.dart`, G6.2). `widgets/week_planner.dart` retires in G7.2 (→ the allotment).

---

## Storage: file-per-profile (ADR-019)

`<appDocuments>/profiles/<id>.json` holds a `ProfileDoc`:

```text
ProfileDoc { id, displayName, plan: Plan,
  states: Map<'yyyy-MM-dd', DailyState>,   // drift log lives here
  logs: Map<workoutKey, List<WorkoutLog>>,
  done: Map<'yyyy-MM-dd', List<signature>>,
  adherence: Map<'yyyy-MM-dd', {done,total}>,
  ketchup: Map<'yyyy-MM-dd', DayKetchup>,  // the pantry (ADR-022)
  recurringTasks, skippedRepeatIds }
```

Only two things live in **SharedPreferences**: the active-profile pointer (`activeProfileId`) and
the **widget** keys, which `home_widget` writes as **raw** keys (no `flutter.` prefix) into its own
`HomeWidgetPreferences` file, read by `NowWidgetProvider.kt` via `HomeWidgetPlugin.getData`. v1.1 adds
the painted-arc keys: `arcImage` (rendered image path), `hasArcImage` + `nightMode` (bools) — the
native widget shows the arc image on top and falls back to the text-only ripe card when absent.
The seed `assets/seed_plan.json` is the source of truth for the default `cyrus` profile (golden test
fails if the timeline changes).

---

## Data flow

**App open / render** (each `HomeShell` tab loads independently)
```
AuthGate (activeProfile) → HomeShell → tab._load (active ProfileDoc → Plan + DailyState + done)
  → TimelineAssembler.assembleDay(plan, …, state)        // the only block source
  → DriftEngine.computeDay(now)                           // ResolvedDay; _findCurrent = present-time
                                                          //   (missed past tasks stay overripe; ADR-023)
  → Today: DayArc + SunClock → SunArcCard; HomeNowState.from() → hero; KetchupStore.last7 → jars
    Timeline: RipenessRules.assign → VineStops → VineTimeline
  → 30s ticker re-renders so progress/minutes-left stay live
```

**Pick** — Today hero / vine card → `DayActions.togglePick` (the one write path: done-set + adherence +
pantry `DayKetchup` + widget push; late picks captured). Adjust mode (reorder / skip / priority) and
custom-task add write **DailyState only**; the Plan stays pristine (ADR-015). The single review→Plan
write is the catch-up's "Give it more time".

---

## Test coverage

`flutter test` (run from `daily_command_center/`). 229 tests, green. `flutter analyze` =
2 pre-existing infos (main.dart `createState` idiom; `timeline_screen` `onReorder` SDK deprecation).

| Area | Examples |
|---|---|
| `test/logic/` | golden timeline, drift engine (incl. missed-task)/runner, ripeness, sun-clock, day-arc, week-modifiers, weekly review, drift copy, planner, validator, custom-task fitter, assembler |
| `test/data/` | models roundtrips, profile/state/adherence/**ketchup** stores, custom/daily-state |
| `test/screens/` | `today_screen` (sun-arc/hero/jars/night), `timeline_screen` (vine/basket/adjust), `home_shell`, `week_screen`, `catchup_screen`, `auth_gate`, login, onboarding, settings |
| `test/widgets/` | `sun_arc_card`, `jar_shelf`, `night_card`, `vine_timeline`, custom-task/sacrifice/promote sheets |
| `test/theme/` | `app_palette` (garden token values) |
| `test/guard/` | no hardcoded life strings; **no Color literal outside app_palette**; **no ⚠/Reflowed/budget/engine jargon on UI lines** (ADR-021) |

---

## Key invariants (do not break)

See CONTINUE.md "Key invariants" for the full list. The load-bearing ones: file-per-profile storage;
`TimelineAssembler` is the only block source (golden test is the net); `buildTimes` monotonic + PM
disambiguation; adherence counts trackable blocks only (`cls != 'work' && cls != 'chill'`); all color
via `context.c` tokens (guarded); `writeWidgetData` stays try-catch.
