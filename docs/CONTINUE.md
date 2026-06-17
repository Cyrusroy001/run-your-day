# Continuation Document
**Last updated:** 2026-06-17 (session 11 — v1.1 garden in flight: G0–G7.1 done; drift "missed-task" fix landed)

If you're an AI agent starting fresh on this project, read this first. It tells you exactly where things stand and what to do next without requiring you to re-derive it from the codebase.

---

## What this project is

A Flutter Android app (`daily_command_center/`), now branded **ketchup** — "the day planner that catches you up." It replaced a single HTML file (`daily-command-center.html`). It is Cyrus's personal daily dashboard: one merged "Today" surface (an enlarged NOW hero + an elastic timeline rail that visibly *squeezes* when you fall behind), a week planner with intelligent training-day spacing, per-day adherence tracking, and a Sunday catch-up review. (An Android home-screen widget exists but is deferred — see below.)

The **product direction** is bigger than Cyrus: a reusable, configurable life-execution app driven by a rich **Life JSON** schema (the moat), with AI-synthesized routines and an eventual conversational onboarding interview. See the roadmap below.

---

## ⭐ Current focus (session 11 — executing ketchup v1.1 "the garden", branch `feat/ketchup-v1`)

**v1 SHIPPED 2026-06-12:** signed release APK (keystore `C:/Users/Cyrus/ketchup-release.jks` +
`android/key.properties`) installed on the S21 FE and QA'd by Cyrus. **The widget renders on
One UI / Android 16 — ADR-010's blocker is gone.** K-notify + K-ship are done.

**Now: executing the v1.1 garden plan**
([`plans/2026-06-13-ketchup-v1.1-garden-redesign.md`](superpowers/plans/2026-06-13-ketchup-v1.1-garden-redesign.md);
spec + **ADR-022**). One line: ripeness = time (garden palette, vine timeline with a basket, sun-arc
Today, allotment Week, pantry jars, painted-arc widget, ambient sun-clock, night = bud) + the
**generality invariant** (no lifestyle constants; goals are 0..N tracks).

**Phase status:** G0 (palette/tokens) · G1 (ripeness) · G2 (sun-clock + day-arc) · G3 (DayKetchup +
KetchupStore + shared Pick) · G4 (3-tab shell) · G5 (sun-arc Today + jars + night) · G6 (vine timeline;
ElasticRail retired) · G7 (allotment week) · G8 (pantry jars in catch-up) · G9 (painted-arc widget;
debug APK builds) · **G10.1–G10.3 (garden voice, generality guard, verify+docs) — ALL DONE & green
(229 tests; analyze = 2 pre-existing infos).**
**Only G10.4 left: device QA + signed release ship — needs Cyrus + the S21 FE.** Signing already
configured (`android/key.properties` + the keystore); QA checklist is G10.4 in the plan. Worth a device
check of the drift fix (live card = present time) + the garden surfaces + the painted-arc widget.

**Mid-stream drift fix (ADR-023):** the live card is now **present-time** — un-done past tasks become
*missed* (overripe, late-pickable; dropped at the next hard anchor) instead of a stale block riding
`now`. This *did* touch `drift_engine.dart` + `home_now_state.dart` (the garden plan itself leaves
engine/storage/golden untouched). Four related logical issues are parked in
[`KNOWN-ISSUES.md`](KNOWN-ISSUES.md) (DL-1…4) to fix with Cyrus after v1.1 ships.

### Done before this (session 9, v1)

The full UI rebrand **K0–K8 + K-notify + K-ship is DONE and green** (192 tests at K8).
`feat/ketchup-v1` is branched off `feat/local-profiles` and is the integration head. Spec:
[`specs/2026-06-11-ketchup-full-visual-spec-v2.html`](superpowers/specs/2026-06-11-ketchup-full-visual-spec-v2.html);
plan: [`plans/2026-06-12-ketchup-v1-rebrand.md`](superpowers/plans/2026-06-12-ketchup-v1-rebrand.md);
decision: **ADR-021**.

| Phase | Done | What |
|---|---|---|
| K0 | `d7a299b` | ketchup palette tokens, Bricolage Grotesque fonts, app label "ketchup", squiggle icon |
| K1 | `bd64d38` | stripped durations from seed labels (golden re-baselined) |
| K2 | `bd64d38` | `lib/widgets/elastic_rail.dart` — the signature rail (spine ∝ duration; squeeze/anchor/skip/done) |
| K3+K4 | `0a19ccc` | `lib/screens/today_screen.dart` = merged Home+Live + adjust mode (two-row cards) |
| K5+K6+K7 | `d47d1c1` | teach_caption + how_it_works_screen; week_screen; catchup_screen (Sunday review) |
| K8 | `0aa598a` | retired the v1 surfaces, migrated tokens off the temp aliases, guard tests, motion |

**Scope (locked with Cyrus, 2026-06-12):** the Android **widget is deferred past v1** (broken on
Samsung One UI / Android 16, unconfirmed root cause — ADR-010; ketchup spec gates the new widget to
"phase 2"). The **interview / AI-gen / full onboarding / in-app editor / refinement** stack is all
deferred. Delivery target = a **signed release APK** on the S21 FE.

(K-notify + K-ship shipped 2026-06-12; v1 signed APK QA'd on device. v1.1 garden is now in flight —
see the focus block above.)

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
| [`specs/2026-06-11-ketchup-full-visual-spec-v2.html`](superpowers/specs/2026-06-11-ketchup-full-visual-spec-v2.html) + [`plans/2026-06-12-ketchup-v1-rebrand.md`](superpowers/plans/2026-06-12-ketchup-v1-rebrand.md) | **Ketchup v1 rebrand** (K0–K8 + K-notify/K-ship): brand, merged Today, elastic rail, catch-up | **Shipped** (signed APK on device 2026-06-12). See **ADR-021** |
| [`specs/2026-06-12-ketchup-v1.1-garden-redesign-design.md`](superpowers/specs/2026-06-12-ketchup-v1.1-garden-redesign-design.md) + [`plans/2026-06-13-ketchup-v1.1-garden-redesign.md`](superpowers/plans/2026-06-13-ketchup-v1.1-garden-redesign.md) | **Ketchup v1.1 "the garden"**: ripeness palette, 3 tabs, vine+basket Timeline, sun-arc Today, allotment Week, pantry jars, painted widget, generality invariant | **Executing** (G0–G7.1 done; G7.2→G10 left). See **ADR-022** |
| [`KNOWN-ISSUES.md`](KNOWN-ISSUES.md) | Deferred logical debt DL-1…4 (post-v1.1) | Backlog |
| — drift live-card fix — | Present-time current block; missed tasks overripe→dropped at hard anchor | **Done** (session 11). See **ADR-023** |
| [`DECISIONS.md`](DECISIONS.md) | Architectural decision records (ADR-001…021) | Living |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | File map, data flow, storage key map | Living |
| [`KNOWN-ISSUES.md`](KNOWN-ISSUES.md) | Deferred logical debt (DL-1…4) to fix with Cyrus after the drift fix + v1.1 ship | Backlog |

### Roadmap (from the v3 spec)

1. **Core** — plan-driven app + v3 drift engine *(approved; Phase A done — see below)*
2. In-app control panel / Life-JSON editor *(later)*
3. Interview tree *(later)*
4. AI generation (answers → Claude → validated Life JSON) *(later)*
5. Onboarding flow *(later)*

The **local-profiles/login** work pulls a minimal, local-only slice of #3/#5 forward (a profile picker + onboarding *stub*), sequenced to ship **after** the v3 core.

---

## Current state (session 8 — historical; superseded by the session-9 focus block above)

> `feat/ketchup-v1` (session 9) is now the integration head and a superset of `feat/local-profiles`.
> The detail below documents the engine/UX/profiles foundation the ketchup rebrand sits on.

### Branch: `feat/local-profiles` (the foundation `feat/ketchup-v1` branched from)

This branch carries the v3 engine (A–D), the UX layer (U0–U7), the custom-task feature (C1–C11), **and** the local-profiles/login feature. It is the new integration head; `feat/custom-tasks` and `feat/reminders-2-redesign` have no unique commits left to merge.

**Local profiles is functionally complete and green (211 tests).** A first-run app seeds `cyrus`; the login screen is a local profile picker; a new name runs the onboarding flow that clones the seed plan; the avatar menu + Settings switch/log out / manage the active profile. End-to-end: create a profile → use it → log out → switch → log back in.

| Area | What shipped | Notes |
|---|---|---|
| Storage | `ProfileRepository` (file-per-profile) + `ProfileDoc`, `AppStore.repo` facade, `activeProfile` notifier | Built in v3 **A7** — see **ADR-019** (file-per-profile won; the planned `ProfileScope` key-prefix was never built) |
| Registry | `ProfileMeta`, `idFor`, create/list/delete, export/import, `clearHistory`/`resetPlan`/`ensureSeeded` | `test/data/profile_*` |
| Routing | `AuthGate` = `ValueListenableBuilder(activeProfile)` → `LoginScreen` (null) vs `HomeScreen` | `main()` seeds + restores the pointer before `runApp` |
| Login | `LoginScreen` picker (injected `profileLoader` seam) | tap existing → activate; new name → `OnboardingScreen` |
| Onboarding | `OnboardingScreen` 3-step flow + `OnboardingLogic.buildPlan`/`commit` | `commit` is the single finish seam (screen + tests) |
| Home/Settings | avatar menu wired to real profile name + log out / switch; Settings PROFILE/DATA sections (export/import to clipboard, reset plan, clear history, delete) | dart:io mutations covered by repo tests; screens verified fake-async-only |

**Plan deviations (do not "fix"):** Plan **Phase 0** (`ProfileScope` key-prefix + legacy migration) is obsolete — storage is file-per-profile. Plan **Phase 4** (AppShell + navigation **Drawer**) is superseded by the **U6 avatar menu** — there is no drawer. Plan **Phase 6** (visual polish) is **done**, adapted to the real architecture: a shared `fadeThroughRoute` transition (`lib/theme/transitions.dart`) on the main pushes, plus an onboarding **Back** affordance + busy/creating state on the final button. See ADR-019.

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

The A11 plan-driven cutover (workouts/timeline gutted into `Plan`), the file-per-profile storage
layout (`ProfileDoc`), and the seed/golden setup are documented in **ARCHITECTURE.md** + ADR-011…019.

### App + widget status

Runs on the phone (Samsung S21 FE, Android 16 / API 36). Dev loop = wireless ADB + `flutter run`.
The home-screen widget reads pushed now-state via `HomeWidgetPlugin.getData` (raw keys), refreshed
~15 min by WorkManager; it was re-themed in session 9 and **confirmed rendering on-device in
session 10** (ADR-010 unblocked). v1.1 upgrades it to the painted-arc design (ADR-022).

---

## What to do next

See **⭐ Current focus (session 10)** above — the immediate work is the **v1.1 garden redesign**:
write the implementation plan from the approved spec (ADR-022), then execute. After that:

### 1. Merge `feat/ketchup-v1` → `main`

`feat/ketchup-v1` is the new integration head — a strict superset of `feat/local-profiles` (which was
itself a superset of `feat/custom-tasks` / `feat/reminders-2-redesign` / `feature/plan-driven-core`).
Merge once v1.1 lands (v1 is already shipped on device from this branch).

### 2. Resume the product roadmap (from the v3 spec)

The larger "for other people" arcs remain, all deferred for v1: **(2)** in-app control panel /
Life-JSON editor, **(3)** interview tree, **(4)** AI generation (answers → Claude → validated Life
JSON), **(5)** full onboarding flow. `OnboardingLogic.commit` is still the seam the real interview/AI
will replace.

---

### Completed work (for reference)

Foundation under the ketchup rebrand (all on `feat/ketchup-v1`'s history; many UX widgets named
here were since retired in K8):
- **UX layer U0–U7** — the calm Today / rich timeline / Adjust mode / weekly review / avatar menu /
  light-dark theme (the presentation layer ketchup v2 superseded). Specs/plans: `2026-06-08-reminders-2-ux-*`.
- **Custom tasks C1–C11** — single-day injection, recurrence, blueprint promotion. `2026-06-09-custom-tasks*`.
- **Local profiles** — file-per-profile, login picker, onboarding stub, settings. `2026-06-07-local-profiles*`.

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

1. **Disk space tight** (~3.65 GB free on C: after the 2026-06-12 clean rebuild). NDK was removed from the build (ADR-006) to avoid a ~1.5 GB download. Free space before adding any package with native code or iterating release builds.
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
