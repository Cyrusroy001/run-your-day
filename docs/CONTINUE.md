# Continuation Document
**Last updated:** 2026-06-07 (session 3)

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
| [`specs/2026-06-05-reminders-2-redesign-design.md`](superpowers/specs/2026-06-05-reminders-2-redesign-design.md) | Rebrand + adherence + Today screen + week-planner redesign | **In progress on this branch** |
| [`specs/2026-06-07-life-json-v3-drift-engine-design.md`](superpowers/specs/2026-06-07-life-json-v3-drift-engine-design.md) | Life JSON v3 + drift-aware engine (the core/moat) | Approved |
| [`plans/2026-06-07-life-json-v3-drift-engine.md`](superpowers/plans/2026-06-07-life-json-v3-drift-engine.md) | **Implementation plan** for v3 (5 phases A–E, ~30 TDD tasks) | **Written — ready to execute** |
| [`specs/2026-06-07-local-profiles-login-app-shell-design.md`](superpowers/specs/2026-06-07-local-profiles-login-app-shell-design.md) | Login (local profile picker), per-profile storage, app shell + side panel, onboarding stub | **Approved — next to implement** |
| [`DECISIONS.md`](DECISIONS.md) | Architectural decision records (ADR-001…017) | Living |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | File map, data flow, storage key map | Living |

History only (carry banners pointing to v3): `specs/2026-06-05-plan-driven-core-design.md` (v1, folded into v3) and `plans/schema-improvement-gemini.md` (the v3 sketch, folded into v3).

### Roadmap (from the v3 spec)

1. **Core** — plan-driven app + v3 drift engine *(approved; implementation plan written — see plans table above)*. Dual-JSON state, both `cutoffTime`+`maxDriftMinutes`, and the full interactive sandbox were folded in while planning (ADR-015/016/017, from the external `moat-*-67.md` docs).
2. In-app control panel / Life-JSON editor *(later)*
3. Interview tree *(later)*
4. AI generation (answers → Claude → validated Life JSON) *(later)*
5. Onboarding flow *(later)*

The **local-profiles/login** work pulls a minimal, local-only slice of #3/#5 forward (a profile picker + onboarding *stub*), sequenced to ship **after** the v3 core so it can namespace v3's storage rather than re-plumb it (ADR-019).

---

## Current state (session 3)

### Branch: `feat/reminders-2-redesign`

**Committed:** the rebrand to "Reminders 2" (`5d54595`) plus the spec docs. (Git history exists — the old "no git history" blocker is resolved.)

**Uncommitted working tree (the redesign — implemented, not yet committed):**
- `lib/data/models.dart` — `Block.isTrackable` + `Block.signature` getters.
- `lib/data/adherence_store.dart` *(new)* — per-day done-set + adherence summary + `last7` trend + `weeklyAverage`.
- `lib/screens/today_screen.dart` *(new)* — full-day tickable checklist + 7-day adherence strip.
- `lib/widgets/now_card.dart` — new API (`doneToday`, `onViewAll`, `onToggleDone`), green "done" state, "View all" + "Mark done".
- `lib/widgets/week_planner.dart` — one-row-per-day layout, schedule chip, train/rest switch, inline caption.
- `lib/screens/home_screen.dart` — owns `_doneToday`, wires card callbacks + navigation, removed SnackBar.
- Tests added/updated under `test/` (adherence_store, screens, week_planner, now_card).

**Verify before calling the redesign done:** the launcher-icon art (`flutter_launcher_icons`, Feature 1 of the redesign spec) may still be outstanding; run `flutter test`; then commit the working tree.

### App status — WORKING

Runs on the phone (Samsung S21 FE, Android 16 / API 36). Dev loop is wireless ADB + `flutter run` (below).

### Android widget — BROKEN (long-standing blocker)

Consistently rejected by Samsung One UI ("couldn't add widget") in the launcher process. Stripped to a minimal layout for diagnosis; root cause not confirmed. Detail in ADR-010 and "Widget debugging" below. The widget is **out of scope** for the redesign and the profiles work — the app itself is unaffected.

---

## What to do next

1. **Finish + commit the redesign** if anything is incomplete (verify icon art; `flutter test`; commit).
2. **Build the v3 core (drift engine)** per the written plan `plans/2026-06-07-life-json-v3-drift-engine.md`, sequenced Phase A→E. This is the foundation and lands first.
3. **Then the local-profiles/login feature** per `plans/2026-06-07-local-profiles-login-app-shell.md` (sequenced *after* v3 — see ADR-019). Scope: login screen (local profile picker, no backend), per-profile **key-prefix** storage via `ProfileScope`/`ProfileRepository` (file → export/import backup), app shell + side panel (drawer), onboarding stub, Settings, logout. **Visual polish is a first-class requirement** — use the `frontend-design` skill and the existing palette/fonts.

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

## Widget debugging (when you return to the blocker)

Capture the launcher's crash while adding the widget:
```powershell
& "C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s 192.168.1.4:PORT logcat *:E
```
Look for errors in the Samsung launcher process (`com.sec.android.app.launcher`) around `APPWIDGET_DELETED`. Things to try: add `android:previewLayout="@layout/now_widget"` to `now_widget_info.xml`; plain hex `android:background`; test on an emulator (API 33/34) to rule out Samsung-specific behavior; remove `android:layout_weight` from the title TextView. Full history in ADR-010.

---

## Active blockers / constraints

1. **Widget rejected by Samsung One UI** — see above. App is fine; only the home-screen widget fails.
2. **Disk space tight** (~4.6 GB free on C:). NDK was removed from the build (ADR-006) to avoid a ~1.5 GB download. Free space before adding any package with native code.
3. **HTML file is stale** — `daily-command-center.html` at the project root is the old version (also edited by an external agent). Do not edit it for new features.

---

## Key invariants (do not break)

- `PlannerLogic.toggleTraining` always returns a plan with exactly 4 training days and no consecutive training days. Tests enforce this.
- `buildTimes` in `timeline.dart` must return strictly monotonically increasing values. The PM disambiguation (walk forward, never backward) is critical and proven — leave it and its tests untouched.
- `writeWidgetData` in `store.dart` must stay wrapped in try-catch — `home_widget` platform calls throw when no widget is on the home screen (ADR-009).
- SharedPreferences keys written by `home_widget` use a `flutter.` prefix automatically. `NowWidgetProvider.kt` must read them WITH that prefix: `prefs.getString("flutter.currentAction", ...)`.
- Adherence counts **trackable** blocks only (`cls != 'work' && cls != 'chill'`). Block identity is `signature = '$time|$label'`.
- **When the profiles work lands:** persistence moves to one JSON file per profile under `profiles/<id>.json`, fronted by `ProfileRepository`; the flat keys above become per-profile data — including whatever the v3 engine writes (`activePlan`, `state_<date>`, `driftLog`). See ADR-018/019 and the profiles spec.
