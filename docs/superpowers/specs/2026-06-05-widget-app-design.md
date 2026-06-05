# Widget App Design — Daily Command Center
**Date:** 2026-06-05
**Status:** Approved

## Overview

Transition the existing single-file HTML daily dashboard into a Flutter Android app with real Android home screen widget support. Phase 1 covers: app setup, fixed week planner, the "Now" live section, and the Now home screen widget. Later phases add widgets for timeline, logger, and other sections.

---

## Architecture

### Two layers

**1. Flutter app** — replaces `daily-command-center.html`. A multi-section scrollable screen housing the same dashboard content (Now, week planner, day timeline, workout logger). Each section is a self-contained Flutter widget component.

**2. Android home screen widgets** — powered by the `home_widget` Flutter package. The app writes current state to shared preferences; the Android widget reads from it. Tap opens the Flutter app.

### Data layer

| Old (HTML) | New (Flutter) |
|---|---|
| `localStorage.weekPlan` | `shared_preferences` — `weekPlan` key |
| `localStorage.log_A/B/...` | `hive` — one box per workout type |

`shared_preferences` is readable by both the Flutter app and the Android widget process. `hive` is app-only (logs don't need widget access).

### Project folder structure

```
lib/
  data/
    models.dart        ← DaySchedule, TrainingPlan, WorkoutLog, Block
    store.dart         ← SharedPreferences + Hive read/write wrappers
  logic/
    timeline.dart      ← buildTimeline(), buildTimes(), nowDecimal() — ported from JS
    workouts.dart      ← WORKOUTS constant — ported from JS
    planner.dart       ← week plan logic, spacing algorithm, training toggle
  screens/
    home_screen.dart   ← main scrollable dashboard
  widgets/
    now_card.dart      ← live "right now" card (reused by home screen + widget)
    day_tabs.dart      ← day selector tabs
    timeline_view.dart ← day timeline blocks
    logger_card.dart   ← per-workout logger
android/
  app/src/main/
    res/layout/        ← now_widget.xml (Android widget XML layout)
    res/xml/           ← now_widget_info.xml (widget metadata)
    java/.../          ← NowWidgetProvider.kt (AppWidgetProvider glue)
```

---

## Section 1 — Now Widget (Home Screen)

### What it displays
- Label: "Right now · [Day name]"
- Current activity title (e.g. "Deep Focus")
- Current activity description (one line)
- Next activity line: "Next · 11:30 — Brunch"
- If current block is a workout: small "Open workout →" indicator

### Update mechanism
- The Flutter app computes current/next on every open and writes to `shared_preferences`
- Android widget schedules a refresh every **30 minutes** via `updatePeriodMillis`
- On widget tap: opens the Flutter app to today's timeline

### Widget size
- Medium rectangle: **4×2** Android grid cells
- One size for now; additional sizes can be added later

### Visual style
- Background: terracotta gradient (matches `--terra` from the HTML, `#D9663D` → `#B8512C`)
- Title font: Fraunces serif (loaded as a custom font asset)
- Body/label font: Spline Sans
- White text throughout
- Circular decorative element top-right (matches existing design)

### What the widget does NOT do
- Does not run timeline logic independently — reads last-written app state
- No interactive buttons inside the widget (Android limitation for standard widgets)
- If the app hasn't been opened and 30-min refresh hasn't fired, it shows last known state

---

## Section 2 — Week Planner Redesign

### Data model

Each day has two independent properties:

```dart
class DayPlan {
  DaySchedule schedule; // office | wfh | weekend
  bool isTraining;
}
```

`DaySchedule` is constrained by day of week:
- Mon–Fri: `office` or `wfh`
- Sat–Sun: always `weekend` (not user-changeable)

### Timeline type matrix

| schedule | isTraining | Timeline |
|---|---|---|
| office | true | commute + office hours + gym/training block |
| office | false | commute + office hours + study evening |
| wfh | true | home workout (Workout A) + WFH structure |
| wfh | false | full focus/study day |
| weekend | true | society gym session (BENCH or CARDIO) |
| weekend | false | full rest + recovery day |

### Workout assignment

| Day type | Workout |
|---|---|
| wfh training | Workout A (home dumbbells) |
| office training | Workout B (society/office gym) |
| weekend training (first) | BENCH |
| weekend training (second, if both weekends train) | CARDIO |
| Max 1 weekend training day | enforced |

### Training day rules
1. Always exactly **4 training days** per week
2. No two consecutive training days (this naturally prevents both Sat + Sun from training simultaneously)
3. When user taps to toggle training on a day that would bring count to 5, the algorithm removes the current training day that has the worst spacing, and shows a toast: "Moved training from [day] → [day] for better spacing"

### Default week (fresh install)
`wfh` on Wed, `office` on Thu + Fri, `weekend` on Sat + Sun. Training days auto-assigned by spacing algorithm to e.g. Mon, Wed, Fri, Sun.

### Spacing algorithm

Find the 4-day subset of the 7 that **maximises the minimum gap** between any two consecutive training days. Tie-break by maximising average gap.

```
score(subset) = min gap between consecutive training days
             + 0.1 × average gap   ← tiebreaker
```

Run over all C(7,4) = 35 combinations — small enough to brute-force on every tap.

### Planner UI

Two rows per day cell:
- **Top row**: office/wfh toggle for Mon–Fri (tap to flip; weekends show "Weekend", locked)
- **Bottom row**: training indicator — filled dot = train, empty = rest/study

Training count shown below grid: "4 training days" always in green (rule enforces it).

---

## Section 3 — UI & Design Redesign

The HTML version was functional but rough — cramped spacing, unclear controls, and no visual hierarchy. The Flutter app should feel like a polished personal tool. Design direction: **dark, refined, editorial** — the same color palette but with real breathing room, clear component language, and purposeful motion.

### Color system (carry over, no changes)
```
bg:     #0E1311   (near-black green base)
panel:  #19211D   (card surface)
terra:  #D9663D   (training / CTA)
moss:   #8FB05A   (positive / rest)
amber:  #E0A23A   (today marker / warning)
sky:    #6FA8C7   (focus / DSA)
cream:  #F2EDE1   (primary text)
muted:  #8A978F   (secondary text)
```

### Typography
- Display/headings: **Fraunces** (serif, weight 800–900) — keep
- Body/UI: **Spline Sans** (weight 400–600) — keep
- These are loaded via `google_fonts` package

### Global layout improvements
- Minimum 20px horizontal padding, 24px between sections
- Cards use consistent 16px border-radius and a single subtle border (`#2C3833`)
- No flat lists — every section lives inside a card surface
- Section headers use Fraunces with a small terracotta accent bar to the left

### Now card (in-app)
**Improvements over HTML version:**
- Add a **time-remaining progress bar** at the bottom of the card — thin line that drains as the current block progresses toward the next one. Gives instant sense of "how much time left"
- Show a small clock icon + exact end time alongside the "Next" line
- Workout blocks: replace the small "Open workout ↓" text with a proper pill button: `[ View Workout ]`
- Card min-height so it never collapses when description is short

### Week planner
**Improvements over HTML version:**
- Remove the confusing tap-to-cycle. Replace with two explicit controls per day:
  - A **segmented pill** (Office | WFH) for Mon–Fri schedule type, tappable directly
  - A **toggle dot** below the name — filled = training, hollow = rest — with a long-press to confirm toggle (prevents accidental taps)
- Today's cell gets an amber left border, not just a border-width change
- Training count badge updates with a brief scale animation on change
- "Reset week" becomes a text button at the bottom, less prominent

### Day tabs
**Improvements over HTML version:**
- Make tabs taller (56px min) with more padding
- Show the workout letter (A/B/BENCH/CARDIO) as a small colored pill inside each tab for training days
- Active tab uses a bottom underline accent in addition to background fill
- Today's tab has a persistent amber dot above it regardless of active state

### Timeline blocks
**Improvements over HTML version:**
- Add a thin vertical connecting line between blocks (left side, between the time labels) — makes it read as a proper timeline, not a list
- Block left accent bar → 4px rounded pill instead of a hard flush edge
- Current block ("is-now"): pulsing left accent + subtle amber glow, not just a border change
- Time label uses Fraunces for more character
- Workout blocks: the expand/collapse uses a smooth height animation (AnimatedSize in Flutter)

### Workout drawer (inside timeline block)
**Improvements over HTML version:**
- Exercise rows become proper cards with a light background, not just divider lines
- Sets/reps shown in a pill badge to the right — easier to read at a glance
- The "Why this session" note gets a sky-blue left border card, matching the HTML but with more padding
- Logger section gets a clear divider + "Log this session" heading

### Logger form
**Improvements over HTML version:**
- Date auto-fills to today (user can override)
- Fields arranged in a single-column flow on mobile instead of a cramped 2-column grid
- Save button is full-width, terracotta, with a checkmark icon
- History rows show as compact cards with the date in a pill, not just a plain row

### Motion & feedback
- Page load: Now card fades + slides up first (100ms), then the planner (200ms), then tabs (300ms) — staggered, not simultaneous
- Tap feedback: all tappable cards get a brief scale-down (0.97) on press
- Toast messages (e.g. "Moved training from Sun → Fri") slide up from the bottom with auto-dismiss at 2.5s
- Training toggle confirmation: brief haptic + dot fill animation

---

## Phase 1 Scope

**In scope:**
- Flutter project setup with Android Studio Arctic Fox
- Data layer: `shared_preferences` + `hive`
- Logic port: timeline, workouts, planner (from JS → Dart)
- Week planner with new data model + spacing algorithm
- Now card as a Flutter widget (used in the app)
- Now Android home screen widget via `home_widget` package
- Main home screen with: Now card + week planner (other sections as stubs)

**Out of scope (later phases):**
- Timeline view widget
- Logger widget
- Day tabs widget
- Multi-widget home screen inside the app
- iOS support

---

## Key Packages

| Package | Purpose |
|---|---|
| `home_widget` | Android widget bridge |
| `shared_preferences` | Simple key-value store (plan + widget data) |
| `hive` / `hive_flutter` | Workout log storage |
| `google_fonts` | Fraunces + Spline Sans |
| `intl` | Date formatting |
