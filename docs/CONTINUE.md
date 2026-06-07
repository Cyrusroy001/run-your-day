# Continuation Document
**Last updated:** 2026-06-07 (session 3 — Life JSON v3 design approved)

If you're an AI agent starting fresh on this project, read this first. It tells you exactly where things stand and what to do next without requiring you to re-derive it from the codebase.

---

## ⭐ Current direction (session 3): Life JSON v3 drift engine

The project's north star is now a **reusable, configurable life-execution app**: a new user does an interview → a rich **Life JSON** → an AI synthesizes a personalized routine → the app executes it. **The moat is the schema.** See the approved design: [`docs/superpowers/specs/2026-06-07-life-json-v3-drift-engine-design.md`](superpowers/specs/2026-06-07-life-json-v3-drift-engine-design.md).

**This sub-project (the core)** makes the app fully plan-driven from a **Life JSON v3** and adds a drift-aware engine: dual-time (Est Start + duration budget), micro-compaction (shrink flexible items to protect fixed anchors), and a circuit-breaker (auto-cancel + Android notification + drift log on a `maxDriftMinutes` breach). Anchors for Cyrus: **Work 2–8 PM (hard), Sleep ~11:15 (soft ceiling)**. Time model is **hybrid**: seed clock times that drift only when the user runs late, so day-1 is byte-identical to today (golden test).

**Status:** design approved; **implementation not started.** Next step is the writing-plans skill → a phased plan (A: plan-driven foundation + seed + golden test · B: dual-time + compaction · C: circuit-breaker + notification · D: drift log + Sunday review). See ADR-011…014 in [`DECISIONS.md`](DECISIONS.md). The superseded v1 schema spec and the gemini v3 sketch carry banners pointing here.

Note: the Reminders 2 redesign (rebrand + adherence/done tracking + Today screen) is a separate, already-designed UX pass — its `done_<date>`/`adherence_<date>` keys and `Block.isTrackable`/`signature` are preserved by v3.

---

## What this project is

A Flutter Android app (`daily_command_center/`) that replaced a single HTML file (`daily-command-center.html`). The app is Cyrus's personal daily dashboard: a live "Right now" card, a week planner with intelligent training-day spacing, and an Android home screen widget.

Full design spec: [`docs/superpowers/specs/2026-06-05-widget-app-design.md`](superpowers/specs/2026-06-05-widget-app-design.md)
Full implementation plan: [`docs/superpowers/plans/2026-06-05-flutter-widget-app.md`](superpowers/plans/2026-06-05-flutter-widget-app.md)
Architectural decisions: [`docs/DECISIONS.md`](DECISIONS.md)

---

## Current state (as of end of session 2)

### Flutter app — WORKING

The app runs correctly on the phone (Samsung S21 FE, Android 16 / API 36). Dev loop is wireless ADB + `flutter run` (see How to run below).

| File | Status |
|---|---|
| `lib/data/models.dart` | Done |
| `lib/data/store.dart` | Done — writeWidgetData is now fire-and-forget with try-catch (see ADR-009) |
| `lib/logic/workouts.dart` | Done |
| `lib/logic/timeline.dart` | Done |
| `lib/logic/planner.dart` | Done |
| `lib/widgets/now_card.dart` | Done — NowCard, progress bar, workout button |
| `lib/widgets/week_planner.dart` | Done — 7-day grid, schedule + training toggles |
| `lib/screens/home_screen.dart` | Done — NowCard + WeekPlanner assembled |
| `lib/main.dart` | Done — theme + AppColors |
| All tests | Pass |

### Android widget — BROKEN (active blocker)

The widget consistently fails on Samsung One UI (Android 16). The pattern observed via `adb logcat`:

```
APPWIDGET_ENABLED → APPWIDGET_UPDATE → updateAppWidget() → APPWIDGET_UPDATE_OPTIONS → APPWIDGET_DELETED
```

The widget is received, `NowWidgetProvider.onUpdate` runs successfully, `appWidgetManager.updateAppWidget` is called — then the Samsung launcher immediately removes it with "couldn't add widget". The error happens in the **launcher process**, not our app process, so it doesn't appear in our logcat.

**What's been tried:**
1. Changed `ProgressBar style="?android:attr/progressBarStyleHorizontal"` → `@android:style/Widget.ProgressBar.Horizontal` (theme attr → direct style ref — valid fix but didn't resolve the issue)
2. Removed the `ProgressBar` entirely from the layout
3. Replaced gradient+corners background with a flat solid color (removed `<corners>` which conflicts with One UI's own widget container rounding)
4. Removed `android:letterSpacing` from label TextView (not supported in older RemoteViews)

**Current widget layout** (`android/.../res/layout/now_widget.xml`) is now minimal: flat terracotta background, label TextView, title TextView (weighted), next-action TextView. No ProgressBar, no corners, no gradient.

**Current `NowWidgetProvider.kt`** sets label, title, next text, and tap PendingIntent. No `setProgressBar` call (view removed).

**Most likely remaining cause:** Samsung One UI on Android 16 may require `android:previewLayout` in `now_widget_info.xml` or may enforce stricter RemoteViews compatibility. The exact error is in the launcher process — not yet captured.

**Next debugging step:** Run full unfiltered error logcat while adding the widget to capture the launcher's crash:
```powershell
& "C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s 192.168.1.4:PORT logcat *:E
```
Look for errors in the Samsung launcher process (com.sec.android.app.launcher or similar) around the time of APPWIDGET_DELETED.

**Things to try next:**
1. Add `android:previewLayout="@layout/now_widget"` to `now_widget_info.xml`
2. Try `android:background` as a plain hex color string instead of a drawable reference
3. Test on Android emulator (API 33 or 34) to rule out Samsung-specific issues
4. Check if the issue reproduces without `android:layout_weight` on the title TextView

---

## What's next after widget is fixed

### Phase 2 (not started)
- **Timeline view** — scrollable day timeline inside the app, matching the HTML version's block layout with workout drawers
- **Workout logger** — per-workout entry form (sets/reps, weight, waist, note) + history list
- **Day tabs** — tabs for selecting a day (Mon–Sun), with workout pill badge on training days
- **Full home screen** — currently shows NowCard + WeekPlanner; needs timeline + logger sections below

---

## Active blockers

1. **Widget rejected by Samsung One UI** — see above. The app works fine; only the home screen widget fails.

2. **Disk space tight** (~4.6 GB free on C:). NDK was removed from build config to avoid a 1.5 GB download. If any future package needs native code, free space first.

3. **No git history** — project was created in a single session without commits. Run this to initialize:
   ```powershell
   cd "c:\Users\Cyrus\dev\Claude\Projects\run your day\daily_command_center"
   git init && git add . && git commit -m "feat: Phase 1 — Flutter app, NowCard, WeekPlanner, Android widget (WIP)"
   ```

4. **HTML file is stale** — `daily-command-center.html` at project root is the old version. Don't edit it for new features.

---

## How to run (dev loop)

Phone: Samsung S21 FE, Android 16 (API 36). Connected via **wireless ADB**.

```powershell
# Step 1 — On phone: Settings → Developer options → Wireless debugging
# Note the IP:port shown. Re-connect each session:
& "C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe" connect 192.168.1.4:PORT

# Step 2 — Run with hot reload
cd "c:\Users\Cyrus\dev\Claude\Projects\run your day\daily_command_center"
flutter run
```

In the `flutter run` terminal:
- **`r`** — hot reload (instant UI changes, keeps state)
- **`R`** — hot restart (full restart, resets state)
- **`q`** — quit

**Note:** `adb` may not be in PATH. If `adb` is not recognized, use the full path:
`C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe`

To add it to PATH permanently:
```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools", "User")
```
Then reopen the terminal.

**First-time pairing** (only needed once, or after phone restart):
```powershell
# Enable Wireless debugging on phone → tap "Pair device with pairing code"
& "C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe" pair 192.168.1.4:PAIR_PORT
# Enter 6-digit code shown on phone
# Then connect using the main Wireless debugging port (different from pair port)
& "C:\Users\Cyrus\AppData\Local\Android\Sdk\platform-tools\adb.exe" connect 192.168.1.4:CONNECT_PORT
```

Firewall rule for adb was already added — no need to redo it.

---

## Key invariants (do not break)

- `PlannerLogic.toggleTraining` always returns a plan with exactly 4 training days and no consecutive training days. Tests enforce this.
- `buildTimes` in `timeline.dart` must return strictly monotonically increasing values. The PM disambiguation logic (walking forward, never backward) is critical.
- `writeWidgetData` in `store.dart` must stay wrapped in try-catch — HomeWidget platform calls can throw when no widget is on the home screen.
- SharedPreferences keys written by `home_widget` use a `flutter.` prefix automatically. `NowWidgetProvider.kt` must read them WITH that prefix: `prefs.getString("flutter.currentAction", ...)`.
