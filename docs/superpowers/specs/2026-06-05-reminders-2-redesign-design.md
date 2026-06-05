# Reminders 2 — Identity, Adherence Tracking & Planner Redesign

**Date:** 2026-06-05
**Status:** Approved
**Applies to:** `daily_command_center/` (Flutter app only)

## Overview

A UX + identity pass on the existing Flutter app. Four pieces:

1. **Rebrand** the app to "Reminders 2" with a custom launcher icon.
2. **Adherence tracking** — mark schedule blocks done from the live card; a green "done" state; a per-day completion count.
3. **A new Today screen** — the full day as a tickable checklist, plus a 7-day adherence trend, opened from a link on the live card.
4. **Redesign "Plan Your Week"** into a roomy one-row-per-day layout with real tap targets, and replace the invisible toast with an inline caption.

The tone of the rebrand is deliberate: a sarcastic nod to the stock Reminders app, positioned as the superior, personalized version.

## Scope

**In scope:** everything above, app-side only.

**Non-goals (explicitly out):**
- The Android home-screen widget (currently broken on Samsung One UI — tracked separately in `CONTINUE.md`). Not touched by this work.
- The workout logger and the Phase-2 timeline workout drawers.
- Cross-device sync (still local `shared_preferences`, as before).

---

## Feature 1 — Rebrand to "Reminders 2"

### Name

The launcher label and in-app title change to **Reminders 2**. Four locations:

| Location | Current | New |
|---|---|---|
| `android/.../AndroidManifest.xml` `android:label` | `Daily Command Center` | `Reminders 2` |
| `android/.../res/values/strings.xml` `app_name` | `Daily Command Center` | `Reminders 2` |
| `lib/main.dart` `MaterialApp.title` | `Daily Command Center` | `Reminders 2` |
| `pubspec.yaml` `description` | (long) | `Reminders 2 — the personal daily dashboard.` |

The in-app header ("CYRUS · DAILY COMMAND CENTER" / "Run The Day.") is **unchanged** — it's the screen heading, not the brand. Only the launcher/app identity changes.

### Icon — "superior check"

A single bold check on a terracotta tile with a small serif "2", matching the app palette.

**Visual definition (so it's reproducible by any rendering method):**
- Canvas 1024×1024.
- Background: vertical gradient terracotta `#D9663D` (top) → `#B8512C` (bottom), full-bleed.
- Foreground: a checkmark in cream `#F2EDE1`, stroke ≈ 90px with rounded caps, centered, occupying the middle ~55% of the canvas.
- A serif numeral "2" in dark `#0E1311`, ≈ 220px tall, lower-right, inside the safe zone.

**Generation:** add `flutter_launcher_icons` as a dev dependency, driven by a 1024px source PNG at `assets/icon/reminders2.png`.
- Legacy icon: rounded-square version (the tile above).
- Adaptive icon (Android 8+): `adaptive_icon_background: "#C25B34"` (a mid terracotta) + a foreground PNG containing the check centered within the 66% safe zone. The "2" is **omitted from the adaptive foreground** to avoid the circular/squircle mask clipping it; it remains on the legacy icon.

The exact source-image production method (SVG→PNG via an installed rasterizer, a Pillow script, or a small Flutter render) is decided at implementation time based on what tooling is present on the machine; the geometry/colors above are the contract. This is a placeholder until the owner supplies custom art.

---

## Feature 2 — "Plan Your Week" redesign (one row per day)

Replaces the cramped 7-column grid (10px training dot, nested gestures) in `lib/widgets/week_planner.dart`.

### Layout

A vertical list of 7 rows inside the existing panel. Each row:

```
[ Mon ]   [ Office ]               Train ( ●——)   ← switch ON
[ Wed ]   [ WFH ]                  Rest  (——● )   ← switch OFF
[ Sat ]   [ Weekend ]             Train ( ●——)
```

- **Day label** — fixed width (~40px), cream, bold. Today's row gets the existing amber left-accent bar.
- **Schedule chip** — a tappable pill. `Office` (terra), `WFH` (sky), `Weekend` (amber). Tapping a non-weekend chip cycles Office ↔ WFH. Weekend chips are fixed (no-op), as today.
- **Train/Rest switch** — a real toggle, target ≈ 48×28px (knob ≈ 22px), labelled `Train` (moss) when on / `Rest` (dim) when off. Tap calls `PlannerLogic.toggleTraining` (unchanged logic). Keeps the existing light haptic.

The two controls are spatially separate — no more nested gesture on a 10px dot.

### Header & footer (kept)
- Header row: `PLAN YOUR WEEK` (left) + `N training days` (right, moss if 4 / amber otherwise).
- Footer: `Reset to suggested week` link (unchanged behavior).

### Inline caption (replaces the toast)

When `toggleTraining` auto-moves a day for spacing, it returns a message. Instead of the (invisible) SnackBar:
- `WeekPlanner` holds the latest message in local state and renders it as a **caption line under the grid**, in sky color, ≈12px (e.g. *"Moved training off Thu for better spacing."*).
- The caption auto-clears after ~4s or on the next interaction.
- The SnackBar block is **removed** from `home_screen.dart`; `onPlanChanged` no longer needs to carry the message up (the planner shows it itself, then calls back with `null`).

---

## Feature 3 — Live card: "Mark done" + "View all"

Changes to `lib/widgets/now_card.dart` and its wiring in `home_screen.dart`.

### Two new affordances
- **Top-right "View all ›" link** — navigates to the new Today screen (`Navigator.push`).
- **"Mark done" button** (bottom-right of the card) — toggles the **current** block's done state for today.

### Green "done" state
The card already computes the current block by time. New rule:
- The current block is "done" when its signature is in today's done set.
- **Done →** the card uses a **green gradient** (`#4F7A3C → #3C5E2D`), shows a small `✓ done` badge by the title, and the button becomes a solid `✓ Done`.
- **Not done →** the existing category gradient and an outline `◯ Mark done` button.
- Tapping toggles (mark / unmark).

**When there is no trackable current block** — i.e. the "Still resting" / "Wind down" states, or the current block is passive (`work`/`chill`, e.g. during the job or chill time) — the **"Mark done" button is hidden** and the green state does not apply. "View all ›" stays visible in all states (it's just navigation).

### API change
`NowCard` currently takes a generic `onTap`. Replace with:
- `Set<String> doneToday` — signatures done today.
- `VoidCallback onViewAll`.
- `void Function(String signature) onToggleDone`.

The whole-card generic tap is removed; only the two explicit controls act (avoids gesture ambiguity). The existing "View Workout →" pill stays as a visual marker on training blocks (its own future action is out of scope).

---

## Feature 4 — Today screen (new, separate)

New file `lib/screens/today_screen.dart`, pushed from the live card's "View all".

### Top — 7-day adherence strip
- A panel showing one bar per day for the last 7 days (oldest→today), each bar height = that day's adherence %, **moss when the day's % ≥ 60, amber below 60**, faded/empty when no data.
- A label: `LAST 7 DAYS` + `X% followed` where X = average of the days that have data (days with no record are excluded from the average, shown faded).

### Below — today's checklist
- Header: `FRIDAY · TODAY` + `X of Y followed` + a progress bar (done ÷ trackable).
- One row per block in today's timeline (`buildTimeline` + `buildTimes`, already built for the live card):
  - **Trackable block** → a checkbox (tap to toggle), time, label. Done → green check, label struck-through + muted. The current block is highlighted with a terra border and a `NOW` tag.
  - **Passive block** (category `work` or `chill` → the job, commute, chill, wind-down, sleep) → faded, **no checkbox**, not counted.

Ticking a row here and "Mark done" on the live card update the **same** state.

---

## Data model & storage

All via `shared_preferences` (already in use).

### Block trackability
Add to `Block` (`lib/data/models.dart`):
```dart
bool get isTrackable => cls != 'work' && cls != 'chill';
```
Trackable categories today: `meal`, `focus`, `dsa`, `train`. Passive: `work` (job + commute), `chill` (chill, wind-down, sleep).

### Block signature
A block's stable identity within a day:
```dart
String get signature => '$time|$label';
```
Stable across timeline rebuilds on the same day/plan. If the plan changes mid-day (e.g. training toggled), unchanged blocks keep their signatures; an added/removed block's done-state simply appears/disappears — acceptable.

### Keys
- `done_<yyyy-MM-dd>` → JSON list of done **signatures** for that date. Reopening the app the same day restores ticks; a new calendar date naturally starts empty (no reset logic needed).
- `adherence_<yyyy-MM-dd>` → JSON `{"done": int, "total": int}`. Rewritten on every toggle **and** when the home screen loads for today (so a day the user opened is recorded even via the live card alone; `total` is recomputed from that day's trackable block count each write).

### Store API
New `AdherenceStore` (in `lib/data/store.dart` or a new `lib/data/adherence_store.dart`):
- `Future<Set<String>> loadDone(DateTime day)`
- `Future<void> saveDone(DateTime day, Set<String> done)`
- `Future<void> writeAdherence(DateTime day, int done, int total)`
- `Future<Map<String, double>> last7(DateTime today)` → `{ 'yyyy-MM-dd': pct }` for the days (of the last 7) that have an `adherence_*` record.

### State ownership
`home_screen` owns `Set<String> _doneToday` (loaded in `initState` for the current date) and the current timeline. It:
- passes `_doneToday` to `NowCard`;
- on toggle (from card or Today screen): updates `_doneToday`, persists via `saveDone`, recomputes done/total and calls `writeAdherence`, `setState`;
- "View all" pushes `TodayScreen(plan, todayKey, doneToday, onToggle)`; the screen mirrors locally for instant feedback and calls `onToggle` back so home stays the single source of truth.

`done` (numerator) = count of `_doneToday` signatures that are trackable in today's timeline. `total` (denominator) = count of trackable blocks in today's timeline.

---

## File-by-file change list

| File | Change |
|---|---|
| `android/.../AndroidManifest.xml`, `res/values/strings.xml` | Rename to "Reminders 2" |
| `pubspec.yaml` | `flutter_launcher_icons` dev dep + config; `assets/icon/`; description |
| `assets/icon/reminders2.png` (+ adaptive foreground) | New icon source art |
| `lib/main.dart` | `MaterialApp.title` → "Reminders 2" |
| `lib/data/models.dart` | `Block.isTrackable`, `Block.signature` getters |
| `lib/data/store.dart` (or new `adherence_store.dart`) | `AdherenceStore` (done set + adherence + last7) |
| `lib/widgets/now_card.dart` | New API (`doneToday`, `onViewAll`, `onToggleDone`); green done state; "View all" + "Mark done" |
| `lib/widgets/week_planner.dart` | Row-per-day layout; schedule chip; train/rest switch; inline caption state |
| `lib/screens/today_screen.dart` | **New** — 7-day strip + today's checklist |
| `lib/screens/home_screen.dart` | Own `_doneToday`; wire card callbacks + navigation; remove SnackBar |
| `test/...` | Update `now_card_test`; add adherence + Today screen + planner-layout tests |

---

## Edge cases

- **App left open across midnight** — `_doneToday` was loaded for the previous date. The 1-minute live-card timer will recompute the current block, but the done set won't auto-reload for the new date until the screen reloads. Minor and rare; acceptable for v1 (a reload-on-resume can be added later if it bites).
- **Plan changed after marking done** — unchanged blocks keep their ticks (signature stable); a removed block's tick is ignored (not in today's timeline); `total` recomputes.
- **Day with no `adherence_*` record** — shown as a faded/empty bar and excluded from the 7-day average.
- **All-passive stretch** — denominators only count trackable blocks, so `total` is always > 0 on a normal day; if somehow 0, show `0 of 0` and a full/!empty bar guarded against divide-by-zero.

## Testing

- **Unit:** `isTrackable` for each category; `signature` format; adherence numerator/denominator (trackable-only); `last7` averaging that ignores missing days; `AdherenceStore` round-trips done sets and survives reload.
- **Widget:** `NowCard` renders green + "Done" when the current block is in `doneToday`, terracotta + "Mark done" otherwise; `TodayScreen` renders passive blocks faded with no checkbox and highlights the current block; `WeekPlanner` shows the inline caption after an auto-move, cycles the schedule chip, and toggles the train switch.
- **Regression:** existing `planner`, `timeline`, `models`, `workouts` tests stay green (their logic is untouched).

## Open questions

None outstanding. Icon source-art production method is an implementation detail (see Feature 1).
