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
