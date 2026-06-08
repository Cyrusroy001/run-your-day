# Architectural Decision Records

Each entry: what was decided, why, and what would break if you reversed it.
Read this before proposing architectural changes.

---

## ADR-001 — Migrate HTML → Flutter for Android widget support

**Decision:** Replace `daily-command-center.html` with a Flutter Android app.

**Why:** The HTML file cannot create a native Android home screen widget. Everything else (data model, timeline logic, colors, fonts) was already working in the HTML version. Flutter was chosen over React Native because it's the path-of-least-resistance for an Android widget + Dart is close enough to JS to port the logic directly.

**Do not revert unless:** You're giving up on the home screen widget entirely.

---

## ADR-002 — SharedPreferences for all persistence (no Hive/SQLite)

**Decision:** Use `shared_preferences` for both the week plan and workout logs. The original spec mentioned Hive for logs, but the implementation uses SharedPreferences exclusively.

**Why:** SharedPreferences is the only storage readable by both the Flutter app process *and* the Android `AppWidgetProvider` (Kotlin). Hive files are app-private. Keeping one storage layer also reduces complexity for a solo personal-use app with small data volumes (~KB, not MB).

**Trade-off:** SharedPreferences serializes everything to JSON strings. Not ideal for large datasets, but workout logs will never exceed a few hundred entries.

**Do not switch to Hive/SQLite unless:** The widget no longer needs to read log data directly.

---

## ADR-003 — 4 training days enforced by spacing algorithm

**Decision:** The planner always maintains exactly 4 training days. Toggling a day doesn't just flip it — the algorithm rebalances the full week for maximum spacing, and will displace another day if needed.

**Why:** A beginner (skinny-fat, ~67 kg) needs 48h+ between sessions for recovery. Ad-hoc user toggles would easily create consecutive training days. The algorithm enforces this without user discipline.

**Key invariant:** `PlannerLogic.toggleTraining` always returns a plan with exactly 4 training days and no two consecutive training days. Tests in `test/logic/planner_test.dart` enforce this. Do not change the function signature or relax these constraints.

---

## ADR-004 — Calorie deficit, not surplus (recomposition strategy)

**Decision:** The meal and nutrition guidance in CLAUDE.md and the app targets a **gentle deficit (~200–400 kcal below maintenance)**, NOT a bulk/surplus.

**Why:** For a skinny-fat beginner, a small deficit + high protein (~130–145 g/day) drives simultaneous fat loss and muscle gain (recomposition). A surplus would add fat before building visible muscle, worsening the starting condition. This was a deliberate reversal from an earlier version that suggested eating big.

**Do not switch back to surplus:** Unless body fat is already ≤12% and the goal explicitly changes to muscle gain.

---

## ADR-005 — Saturday = BENCH, Sunday = CARDIO (not user-configurable)

**Decision:** Weekend workout type is fixed: Saturday always gets the bench machine session, Sunday always gets treadmill/cardio.

**Why:** The society gym has a bench machine — that's the only place to add load (progressive overload anchor). BENCH on Saturday means it's earlier in the weekend, fresher. CARDIO on Sunday acts as an active-recovery transition into the work week.

**Where this lives:** `timeline.dart` `_workoutFor()` function. Changing this also requires updating `timeline_test.dart`.

---

## ADR-006 — ndkVersion removed from build.gradle.kts

**Decision:** The line `ndkVersion = flutter.ndkVersion` was removed from `android/app/build.gradle.kts`.

**Why:** The app has no native C++ code. The Flutter Gradle plugin was trying to download NDK 28.2.13676358 (~1.5 GB) on every fresh build. The machine this was built on had only ~4.6 GB free disk, causing build failures. Removing the line prevents the download without affecting app functionality.

**If you need NDK later** (e.g., for a package that uses native code): re-add `ndkVersion = "28.2.13676358"` and ensure you have sufficient disk space.

---

## ADR-007 — JDK 17 set via flutter config, not JAVA_HOME

**Decision:** Flutter's JDK is set with `flutter config --jdk-dir "C:\Program Files\Java\jdk-17.0.4"` rather than changing the system `JAVA_HOME`.

**Why:** `JAVA_HOME` on this machine points to a Java 8 JRE that other tools may depend on. Overriding it system-wide risks breaking those tools. Flutter config is project/user-level and only affects Flutter's Gradle invocations.

**If the build breaks with JVM version errors again:** Run `flutter config --jdk-dir "C:\Program Files\Java\jdk-17.0.4"` to restore this setting.

---

## ADR-008 — Android widget reads app-computed state, not live computation

**Decision:** `NowWidgetProvider.kt` reads pre-computed strings from SharedPreferences. The Flutter app writes these values on every open. The widget does NOT run timeline logic independently.

**Why:** Android `AppWidgetProvider` runs in a restricted background context. Porting the full timeline logic to Kotlin was not worth the duplication. The 30-minute refresh interval + on-app-open update is sufficient for personal use.

**Trade-off:** If the app hasn't been opened in a long time, the widget shows stale data. Acceptable for a personal daily dashboard.

---

## ADR-009 — writeWidgetData is fire-and-forget with try-catch

**Decision:** `AppStore.writeWidgetData` is called with `.ignore()` in `home_screen.dart` and wrapped in `try-catch` internally in `store.dart`.

**Why:** `HomeWidget.updateWidget` and `HomeWidget.saveWidgetData` can throw `PlatformException` when no widget is pinned to the home screen, or when the platform channel fails. These were originally called without `await` (unawaited future) — in Flutter release builds, unhandled async exceptions crash the app. The `.ignore()` + internal try-catch pattern makes widget sync fully non-fatal.

**Do not remove the try-catch:** Widget data sync failing silently is acceptable; the app crashing is not.

---

## ADR-010 — Widget layout stripped to minimum for Samsung One UI diagnosis

**Decision:** `now_widget.xml` was simplified to three TextViews with a flat solid-color background. The following were removed: `ProgressBar`, gradient drawable, `<corners>` radius, `android:letterSpacing`.

**Why:** Samsung One UI on Android 16 (API 36) was immediately removing the widget after placement ("couldn't add widget"). The RemoteViews failure happens in the launcher process, not our app process, so the exact error wasn't captured. Stripping to minimum is a standard diagnosis step — add elements back one at a time until the failure reproduces.

**What was removed and why each was suspect:**
- `ProgressBar` with `?android:attr/progressBarStyleHorizontal` — theme attribute references do not work in RemoteViews (confirmed bug)
- `ProgressBar` with `@android:style/Widget.ProgressBar.Horizontal` — deprecated style, may not exist in all launcher theme contexts
- `<corners android:radius="20dp">` on the background drawable — Samsung One UI applies its own widget container rounding; custom corners on the background can conflict
- `android:letterSpacing` — not supported in all RemoteViews text contexts

**Status:** Widget still fails even with the stripped layout as of end of session 2. The root cause is not yet confirmed. See CONTINUE.md for next debugging steps.

---

## ADR-011 — Life JSON v3 (drift-aware) supersedes the v1 plan-driven schema

**Decision:** The app becomes fully plan-driven from a **Life JSON v3** schema, expanding the never-implemented v1 plan-driven spec with a drift-aware execution engine. Full design: [`docs/superpowers/specs/2026-06-07-life-json-v3-drift-engine-design.md`](superpowers/specs/2026-06-07-life-json-v3-drift-engine-design.md).

**Why:** The product's moat is the schema, not the UI — a rich, executable Life JSON lets one generic engine run *any* user's plan and lets an AI synthesize crazy-good personalized routines from interview answers (later sub-projects). v3 adds dual-time, micro-compaction, and circuit-breakers so the day adapts to real disruption instead of going stale. v1 (concrete but static) and the gemini v3 sketch (abstract drift) are merged here.

**Do not revert unless:** abandoning the configurable/multi-lifestyle direction and going back to Cyrus-hardcoded Dart.

---

## ADR-012 — Hybrid time model: seed times that drift (not pure computed)

**Decision:** Every flexible routine item carries a **seed/preferred `start` clock time** AND a drift budget (`idealDuration`/`minDuration`/`maxDriftMinutes`). Est Start = the seed time on a zero-drift day, and cascades forward only once the user runs late. Only fixed `anchors` keep immovable clock times.

**Why:** Pure computed-from-durations (the gemini doc's literal model) would change Cyrus's familiar timeline on day one. Hybrid preserves today's exact look (golden test: zero-drift = byte-identical) while layering drift behavior on top. User's explicit choice.

**Key invariant:** With an unmodified seed and no late check-offs, the rendered timeline must equal today's `buildTimeline` output exactly.

---

## ADR-013 — Anchors: Work is a hard wall, Sleep is a soft ceiling

**Decision:** In Cyrus's seed, the **Work block (2:00–8:00)** is a `hard: true` anchor (compaction protects it absolutely) and the **Sleep target (~11:15)** is a `hard: false` soft ceiling (compaction targets it but may overrun as a last resort). Commute and meals stay flexible routine items, not anchors.

**Why:** The job is a real-world immovable boundary; the morning routine must compact to never push past 2 PM. Sleep is protected to preserve hygiene but can't be a hard wall (the day sometimes runs long). Making meals anchors would over-constrain compaction.

**Where this lives:** `dayTemplates[*].anchors` in `seed_plan.json`. Changing which blocks are anchors changes compaction behavior.

---

## ADR-014 — Full circuit-breaker (incl. OS notification) + persisted drift log

**Decision:** On a `maxDriftMinutes` breach for a `kill_and_notify` item, the engine cancels the item, promotes the next, **fires a high-priority Android notification on a dedicated channel**, and **appends a `DriftEvent` to a persisted, rolling `driftLog`** surfaced in the Sunday weekly-review block.

**Why:** The user wanted the full headline behavior, not a soft warning — auto-cancellation protects sleep, and the drift log gives a weekly feedback loop ("training got auto-cancelled twice this week") to tune the plan. Pulling the notification channel into scope is deliberate (coordinate with the widget/notification blocker).

**Trade-off:** Adds the Android notification-channel plumbing currently listed as a blocker. Sequenced as Phase C in the implementation plan so earlier phases ship without it.

---

## ADR-015 — Dual-JSON state: immutable Plan + ephemeral DailyState

**Decision:** Split persistence into two independent streams. The **Plan** (Life JSON blueprint) is **read-only during execution** — loaded from `assets/seed_plan.json`, cached under `activePlan`. A separate **DailyState** (`state_<yyyy-MM-dd>`) holds today's mutable reality: `deletedItems`, `dailySequence` (reorder), `dailyOverrides` (per-day priority bumps), and that day's `driftLog`. User interactions (check-off, drag, delete, override) mutate **only** DailyState; the Plan stays pristine. `buildTimeline` deep-merges the two.

**Why:** Keeps the long-term routine clean and AI-regenerable while letting the day flex. DailyState can be wiped without destroying the blueprint. Sets up sub-projects 2–5 (editor, interview, AI gen) cleanly — the AI only ever rewrites the Plan blob. Adopted from the external moat-implementation/improvement-67 docs, chosen over the original v3 plan of mutating `plan.week` in place.

**Supersedes:** the v3-spec note that "week lives inside the plan — toggle edits mutate and re-save the whole plan." Week toggles still edit `plan.week` (a structural change, allowed via the planner), but daily execution state is fully separated.

---

## ADR-016 — Both cutoffTime (absolute) and maxDriftMinutes (relative) drift triggers

**Decision:** The DriftEngine honors **two** circuit-breaker triggers per item: `cutoffTime` (an absolute clock wall, e.g. "no workout after 20:00") and `maxDriftMinutes` (a relative ceiling past the seed `start`). An item may set either or both; whichever trips first fires the breach. Cyrus's seed uses `cutoffTime: "20:00"` on `train` and `maxDriftMinutes` on `focus`/`dsa`.

**Why:** Absolute cutoffs match how people actually reason about late-night activities ("too late to train"); relative ceilings match elastic focus/study blocks. Supporting both costs little and makes the schema more expressive (the moat). The two external docs used `cutoffTime`; the approved v3 spec used `maxDriftMinutes` — both are kept.

---

## ADR-017 — Sub-project 1 scope expanded to include the interactive sandbox

**Decision:** Sub-project 1 now ships the full **DriftEngine** (compaction, **jettison protocol**, **two-way elasticity**, `transitionBufferMinutes`) AND the **interactive sandbox**: drag-drop reorder across anchor walls, swipe-to-delete, per-day priority override, and the **Undo** transaction protocol. Phase E in the plan.

**Why:** The external moat-implementation-67 doc folds live editing into the core so the execution surface is actually usable day-to-day, not just a read-only render. The friendly *structural* Life-JSON editor (full template authoring) remains sub-project 2; Phase E only edits **DailyState**, never the Plan, so it stays consistent with ADR-015.

**Trade-off:** Larger sub-project 1. Sequenced last (Phase E) so the engine + read-only surfaces (Phases A–D) ship and de-risk first.

---

## ADR-018 — "Login" is a local profile picker, not authentication

**Decision:** The login screen is a **local, on-device profile picker** — no passwords, no backend, no network. Typing/picking a name selects a profile; `cyrus` is seeded from today's default data; any new name runs an onboarding *stub* that builds a usable plan. Logout/switch returns to the picker. Full design: [`docs/superpowers/specs/2026-06-07-local-profiles-login-app-shell-design.md`](superpowers/specs/2026-06-07-local-profiles-login-app-shell-design.md).

**Why:** The app is local-only by design (the v3 spec lists multi-user/cloud sync as a non-goal). Real auth needs a server and contradicts that. A profile picker delivers the actual want — multiple isolated identities, a seeded `cyrus`, onboarding for new users — with zero backend, and stays the front door when real accounts are added later. The onboarding stub's only output is "a valid plan," so the future interview tree (sub-project 3) can replace it without touching anything downstream.

**Do not turn into real auth unless:** the project adopts a backend and cross-device sync (a deliberate scope change, not a tweak).

---

## ADR-019 — Per-profile key prefix (revised; profiles sequenced after v3)

**Decision (revised 2026-06-08):** Isolate profiles with a **per-profile SharedPreferences key prefix** (`p_<id>__<base>`), applied centrally in a `ProfileScope` helper that every store routes its key construction through. The active profile is a tiny global pointer (`activeProfileId`); a `ProfileRepository` owns the profile index, create/list/delete, first-run seed/migration, and **export/import**. The "one JSON file per profile" survives only as the **export/import backup format** (gather every `p_<id>__*` key → one JSON blob), not the live backing. **Profiles is sequenced to ship after the v3 core.** Plan: [`docs/superpowers/plans/2026-06-07-local-profiles-login-app-shell.md`](superpowers/plans/2026-06-07-local-profiles-login-app-shell.md).

**Why the reversal:** The original choice was one JSON file per profile (cleaner physical isolation). But reading the v3 plan showed every store is SharedPreferences-key based and v3 *adds* another (`state_store.dart`). File-backing would force v3's stores to be re-plumbed to file IO — duplicate, conflicting work. A central key prefix namespaces **all** existing and future keys (`activePlan`, `state_<date>`, `log_*`, `done_*`, `adherence_*`, drift log) for free, touching each store by one line. The user explicitly chose to build profiles after v3 and avoid the duplicate work.

**Compatibility with the v3 engine (ADR-015):** because v3 lands first, the prefix simply wraps whatever keys exist at that point. Global keys never get prefixed: `activeProfileId`, `profileIndex`, and the `flutter.*` widget keys (the widget shows the active profile's now-state).

**Do not revert to file-per-profile / flatten to global keys unless:** dropping multi-profile support, or abandoning the SharedPreferences-based stores wholesale.
