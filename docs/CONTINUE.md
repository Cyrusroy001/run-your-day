# Continuation Document
**Last updated:** 2026-06-11 (session 8)

If you're an AI agent starting fresh on this project, read this first. It tells you exactly where things stand and what to do next without requiring you to re-derive it from the codebase.

---

## What this project is

A Flutter Android app (`daily_command_center/`), branded **Reminders 2**, that replaced a single HTML file (`daily-command-center.html`). It is Cyrus's personal daily dashboard: a live "Right now" card, a week planner with intelligent training-day spacing, per-day adherence tracking, and an Android home screen widget.

The **product direction** is bigger than Cyrus: a reusable, configurable life-execution app driven by a rich **Life JSON** schema (the moat), with AI-synthesized routines and an eventual conversational onboarding interview. See the roadmap below.

---

## The spec/plan stack (read these for any non-trivial work)

| Doc | What it is | Status |
|---|---|---|
| [`specs/2026-06-05-widget-app-design.md`](superpowers/specs/2026-06-05-widget-app-design.md) | Original Flutter app design | Phase 1 shipped |
| [`specs/2026-06-05-reminders-2-redesign-design.md`](superpowers/specs/2026-06-05-reminders-2-redesign-design.md) | Rebrand + adherence + Today screen + week-planner redesign | Shipped |
| [`specs/2026-06-07-life-json-v3-drift-engine-design.md`](superpowers/specs/2026-06-07-life-json-v3-drift-engine-design.md) | Life JSON v3 + drift-aware engine (the core/moat) | Approved |
| [`plans/2026-06-07-life-json-v3-drift-engine.md`](superpowers/plans/2026-06-07-life-json-v3-drift-engine.md) | **Engine plan** for v3 (5 phases A–E, ~30 TDD tasks) | **A–D done; E superseded by UX layer** |
| [`specs/2026-06-08-reminders-2-ux-design.md`](superpowers/specs/2026-06-08-reminders-2-ux-design.md) + [`plans/2026-06-08-reminders-2-ux-layer.md`](superpowers/plans/2026-06-08-reminders-2-ux-layer.md) | **UX-layer plan** (U0–U7): calm Home, rich Live timeline, Adjust mode, teaching, weekly review, avatar menu, light/dark theme. Mockup: [`specs/2026-06-08-reminders-2-ux-mockup.html`](superpowers/specs/2026-06-08-reminders-2-ux-mockup.html) | **Complete** (U0–U7 done; `feat/reminders-2-redesign`) |
| [`specs/2026-06-07-local-profiles-login-app-shell-design.md`](superpowers/specs/2026-06-07-local-profiles-login-app-shell-design.md) + [`plans/2026-06-07-local-profiles-login-app-shell.md`](superpowers/plans/2026-06-07-local-profiles-login-app-shell.md) | Login (local profile picker), per-profile storage, onboarding, settings/logout | **Complete** on `feat/local-profiles` (see Current state). Plan Phase 0 obsolete, Phase 4 drawer superseded by avatar menu — see **ADR-019** |
| [`DECISIONS.md`](DECISIONS.md) | Architectural decision records (ADR-001…019) | Living |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | File map, data flow, storage key map | Living |

### Roadmap (from the v3 spec)

1. **Core** — plan-driven app + v3 drift engine *(approved; Phase A done — see below)*
2. In-app control panel / Life-JSON editor *(later)*
3. Interview tree *(later)*
4. AI generation (answers → Claude → validated Life JSON) *(later)*
5. Onboarding flow *(later)*

The **local-profiles/login** work pulls a minimal, local-only slice of #3/#5 forward (a profile picker + onboarding *stub*), sequenced to ship **after** the v3 core.

---

## Current state (session 8)

### Branch: `feat/local-profiles` (most complete — strict superset of everything below)

This branch carries the v3 engine (A–D), the UX layer (U0–U7), the custom-task feature (C1–C11), **and** the local-profiles/login feature. It is the new integration head; `feat/custom-tasks` and `feat/reminders-2-redesign` have no unique commits left to merge.

**Local profiles is functionally complete and green (210 tests).** A first-run app seeds `cyrus`; the login screen is a local profile picker; a new name runs the onboarding flow that clones the seed plan; the avatar menu + Settings switch/log out / manage the active profile. End-to-end: create a profile → use it → log out → switch → log back in.

| Area | What shipped | Notes |
|---|---|---|
| Storage | `ProfileRepository` (file-per-profile) + `ProfileDoc`, `AppStore.repo` facade, `activeProfile` notifier | Built in v3 **A7** — see **ADR-019** (file-per-profile won; the planned `ProfileScope` key-prefix was never built) |
| Registry | `ProfileMeta`, `idFor`, create/list/delete, export/import, `clearHistory`/`resetPlan`/`ensureSeeded` | `test/data/profile_*` |
| Routing | `AuthGate` = `ValueListenableBuilder(activeProfile)` → `LoginScreen` (null) vs `HomeScreen` | `main()` seeds + restores the pointer before `runApp` |
| Login | `LoginScreen` picker (injected `profileLoader` seam) | tap existing → activate; new name → `OnboardingScreen` |
| Onboarding | `OnboardingScreen` 3-step flow + `OnboardingLogic.buildPlan`/`commit` | `commit` is the single finish seam (screen + tests) |
| Home/Settings | avatar menu wired to real profile name + log out / switch; Settings PROFILE/DATA sections (export/import to clipboard, reset plan, clear history, delete) | dart:io mutations covered by repo tests; screens verified fake-async-only |

**Plan deviations (do not "fix"):** Plan **Phase 0** (`ProfileScope` key-prefix + legacy migration) is obsolete — storage is file-per-profile. Plan **Phase 4** (AppShell + navigation **Drawer**) is superseded by the **U6 avatar menu** — there is no drawer. Plan **Phase 6** (visual polish pass) is the only optional remainder. See ADR-019.

### Engine plan — phase status

| Phase | Scope | Status |
|---|---|---|
| A (A1–A11) | Plan-driven foundation, v3 models, assembler, profile storage | ✅ committed |
| B (B1–B6) | `DriftEngine` — est-start cascade, compaction, jettison, two-way elasticity | ✅ committed (`8ce03ab`) |
| C (C1–C4) | Circuit-breaker (cutoff + maxDrift) → `NotificationService` + `DriftRunner` | ✅ committed (`50512db`) |
| D1 | Drift-log rolling cap (50 events/day) | ✅ committed (`760d494`) |
| D2 | `WeeklyReview.summarize` aggregation (plain-language sentence) | ✅ committed (`a3b7f6b`) |
| D3 | Weekly-summary card on Today screen | ✅ committed (`4da84d7`; **interim — superseded by `WeeklyReviewCard` in U3.1; `today_screen.dart` deleted in U7.2**) |
| E (E1–E5) | Interactive sandbox (drag/swipe/priority/undo) | ❌ **superseded** by UX U4/U5 (Adjust mode in `LiveTimelineView`) — do not build |

### v3 Phase A — what was built

| Task | What | Tests |
|---|---|---|
| A1 | `assets/seed_plan.json` — full v3 blueprint for Cyrus | Asset registered in pubspec |
| A2–A6 | Complete v3 model layer: `Plan`, `DayTemplate`/`Anchor`/`RoutineItem`, `WorkoutDef`/`ExerciseDef`/`Progression`, `WeekEntry`, `DailyState`/`DriftEvent`/`ItemOverride`, extended `Block` + `displayTime()` | 21 tests |
| A9 | `PlanValidator` — referential integrity checks (templateId in week ∈ dayTemplates, workoutId ∈ workouts, etc.) | seed passes, error cases tested |
| A10 | `TimelineAssembler.assembleDay()` — data-driven from Plan; golden test byte-identical to the old hardcoded timeline | golden test (all 4 templates) |
| A7 | **File-per-profile `ProfileRepository`** + `ProfileDoc` (Plan + states + logs + done + adherence in one JSON file) + `AppStore` facade | 4 tests, multi-profile isolation |
| A8 | `StateStore` — DailyState + drift log via ProfileRepository | 5 tests |
| A11 | **Full app cutover** — all screens/widgets wired to `Plan`; dead code deleted | 62 tests total |

### A11 cutover — what was deleted / replaced

- `lib/logic/workouts.dart` — deleted (workouts live in `Plan.workouts` from seed JSON)
- `lib/logic/timeline.dart` — stripped to `buildTimes()` + `nowDecimal()` only; `buildTimeline()` and all its hardcoded block constants gone
- `models.dart` — `DaySchedule` enum, `DayPlan` class, `WeekPlan` typedef removed
- `AdherenceStore` — no longer uses SharedPreferences; routes through `AppStore.repo` (file-per-profile)
- `PlannerLogic` — now operates on `Plan`/`WeekEntry`; API is `applyBestSpacing(Plan)`, `toggleTraining(Plan, day)`, `toggleSchedule(Plan, day)`
- All screens/widgets (`HomeScreen`, `TodayScreen`, `NowCard`, `WeekPlanner`) — accept `Plan`, call `TimelineAssembler.assembleDay`

### Storage architecture (implemented)

**File-per-profile:** `<appDocuments>/profiles/<id>.json` holds a `ProfileDoc`:

```text
ProfileDoc {
  id, displayName, plan: Plan,
  states: Map<'yyyy-MM-dd', DailyState>,   // drift log lives here
  logs: Map<workoutKey, List<WorkoutLog>>,
  done: Map<'yyyy-MM-dd', List<String>>,   // block signatures
  adherence: Map<'yyyy-MM-dd', {done, total}>
}
```
Active profile id is a global pointer in SharedPreferences. `AppStore.repo` is injectable (swap for temp dir in tests). Default profile `cyrus` is seeded from `assets/seed_plan.json` on first launch.

### App status — WORKING

Runs on the phone (Samsung S21 FE, Android 16 / API 36). Dev loop is wireless ADB + `flutter run` (below).

### Android widget — WORKING (was broken; fixed in session 3)

**Root cause was fixed:** `NowWidgetProvider.kt` was reading from `FlutterSharedPreferences` (`flutter.*` prefix) when it should read from `HomeWidgetPreferences` (raw keys) via `HomeWidgetPlugin.getData(context)`. Widget now shows live data.

**15-minute refresh:** WorkManager drives actual 15-min periodic refresh (`callbackDispatcher` in `main.dart`). The XML `updatePeriodMillis` is 1800000 (30 min, the Android floor) as a fallback; WorkManager is the real driver.

---

## What to do next

The engine, UX layer, custom-task feature, **and local-profiles/login** are all complete on `feat/local-profiles` (210 tests green). The branch is shippable. Candidate next steps (in rough priority order):

### 1. Merge `feat/local-profiles` → `main`

This is now the most complete branch and a strict superset of `feat/custom-tasks`, `feat/reminders-2-redesign`, and `feature/plan-driven-core` (all have 0 unique commits relative to it). It is the single merge candidate.

### 2. (Optional) Local-profiles Phase 6 — visual polish

Plan Phase 6: smooth section transitions, login/onboarding/avatar-menu refinement. Cosmetic only; the feature is functionally done. Skip unless polishing for a release.

### 3. Resume the product roadmap (from the v3 spec)

Profiles pulled a minimal local slice of onboarding forward. The larger arcs remain: **(2)** in-app control panel / Life-JSON editor, **(3)** interview tree, **(4)** AI generation (answers → Claude → validated Life JSON), **(5)** full onboarding flow. `OnboardingLogic.commit` is the seam the real interview/AI will replace.

---

### Completed work (for reference)

All UX-layer tasks are done:
- **U0** `UiPrefs` + `AppPalette` ThemeExtension + `RemindersApp` rewrite
- **U1** `PriorityLevel`, `DriftCopy`, `HomeNowState`
- **U2** `BudgetBar`, `AnchorWall`
- **U3** `LiveTimelineView` (read-only), `WeeklyReviewCard`
- **U4/U5** Adjust mode (`_adjusting`, reorder, remove-for-today, priority chips, Undo) + `TeachingCard`
- **U6** `NowHeroCard`, `AvatarMenuSheet`, `GlossaryScreen`, `SettingsScreen`, `HomeScreen` rebuild, `WeekPlanner` migration
- **U7** guard test, retire `now_card.dart`/`today_screen.dart`/`AppColors`, docs

Custom-task feature (C1–C11) is done on `feat/custom-tasks` — spec [`specs/2026-06-09-custom-tasks-design.md`](superpowers/specs/2026-06-09-custom-tasks-design.md), plan [`plans/2026-06-09-custom-tasks.md`](superpowers/plans/2026-06-09-custom-tasks.md):

- **C1–C6** Phase 1 — single-day injection: `CustomTask` model, assembler fold at priority 0, `CustomTaskFitter` sacrifice ranking, `AddCustomTaskSheet`, `SacrificePickerSheet`, FAB + amber row wiring
- **C7–C9** Phase 2 — recurrence: `RecurringCustomTask` + `RecurringStore`, assembler fold, repeat-prompt card (+1/+2/+3/+7)
- **C10–C11** Phase 3 — blueprint promotion: Sunday review surfaces frequent tasks, `PromoteToBlueprintSheet` writes new `RoutineItem`s into the plan (first in-app plan write)

Session 7 follow-ups (also on `feat/custom-tasks`): home-card quick-complete + live progress ring, Android widget redesign (progress bar, done strip, minutes-left), WFH day drops commute / home meal labels.

Local-profiles/login is done on `feat/local-profiles` — spec [`specs/2026-06-07-local-profiles-login-app-shell-design.md`](superpowers/specs/2026-06-07-local-profiles-login-app-shell-design.md), plan [`plans/2026-06-07-local-profiles-login-app-shell.md`](superpowers/plans/2026-06-07-local-profiles-login-app-shell.md). See the table under **Current state** for the per-area breakdown and the plan-deviation notes (Phase 0 obsolete, Phase 4 drawer superseded by the avatar menu).

---

## How to run (dev loop)

Phone: Samsung S21 FE, Android 16 (API 36). Connected via **wireless ADB**.

```powershell
# Step 1 — On phone: Settings → Developer options → Wireless debugging. Reconnect each session:
& "C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe" connect 192.168.1.4:PORT

# Step 2 — Run with hot reload
cd "c:\Users\Cyrus\dev\Claude\Projects\run your day\daily_command_center"
flutter run
```

In the `flutter run` terminal: **`r`** hot reload · **`R`** hot restart · **`q`** quit.

**First-time pairing** (once, or after phone restart):
```powershell
& "C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe" pair 192.168.1.4:PAIR_PORT   # enter 6-digit code
& "C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe" connect 192.168.1.4:CONNECT_PORT
```

`adb` may not be on PATH — use the full path above, or add it permanently:
```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools", "User")
```
Firewall rule for adb is already in place. Run tests: `flutter test` (from `daily_command_center/`).

---

## Active blockers / constraints

1. **Disk space tight** (~4.6 GB free on C:). NDK was removed from the build (ADR-006) to avoid a ~1.5 GB download. Free space before adding any package with native code.
2. **HTML file is stale** — `daily-command-center.html` at the project root is the old version. Do not edit it for new features.

---

## Key invariants (do not break)

- **File-per-profile storage**: All plan data, daily state, workout logs, done-sets, and adherence live in `profiles/<id>.json` via `ProfileRepository`. Never write profile data directly to SharedPreferences. `AppStore.repo` is injectable for tests — always use `ProfileRepository(baseDir: tmp)` in tests that touch storage.
- **`home_widget` uses raw keys** — `home_widget` does NOT add a `flutter.` prefix. Read from `HomeWidgetPreferences` via `HomeWidgetPlugin.getData(context)` with un-prefixed keys (`currentAction`, `nextAction`, `dayLabel`, `progressPct`). The `shared_preferences` plugin uses a separate file with `flutter.` prefix — do not confuse the two.
- **`buildTimes`** in `timeline.dart` must return strictly monotonically increasing values. The PM disambiguation (walk forward, never backward) is critical — leave it and its test untouched.
- **`writeWidgetData`** in `store.dart` must stay wrapped in try-catch — `home_widget` platform calls throw when no widget is on the home screen (ADR-009).
- **`PlannerLogic.toggleTraining`** always returns a plan with exactly 4 training days and no consecutive training days. Tests enforce this.
- **`TimelineAssembler`** is the only place blocks are assembled from a Plan. Never hard-code block lists in screens. The golden test (`test/logic/golden_timeline_test.dart`) is the canonical correctness check — keep it green.
- **Adherence counts trackable blocks only** (`cls != 'work' && cls != 'chill'`). Block identity is `signature = '$time|$label'`.
- **Seed plan**: `assets/seed_plan.json` is the source of truth for the default plan. If you change the seed, re-run the golden test — it will fail if the timeline changes, which is a deliberate safety net.
