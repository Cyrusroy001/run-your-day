# Life JSON v3 Drift-Aware Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Reminders 2 Flutter app fully plan-driven from a Life JSON v3, with a drift-aware execution engine (dual-time, micro-compaction, jettison, two-way elasticity, circuit-breaker), a Dual-JSON state model (immutable Plan + ephemeral DailyState), a persisted drift log surfaced in a Sunday review, and an interactive sandbox (drag-reorder, swipe-delete, per-day override, Undo).

**Architecture:** All content moves from hardcoded Dart into `assets/seed_plan.json` (the immutable **Plan** blueprint). A separate **DailyState** (`state_<date>`) holds the day's mutable reality (deletions, reorder, priority overrides, drift log). A `TimelineAssembler` deep-merges the two into resolved `Block`s; a pure `DriftEngine.computeDay(...)` layers Est-Start cascade + compaction + jettison + elasticity + circuit-breaker on top; breaches fire an Android notification and append a `DriftEvent`. Live surfaces render dual-time and let the user reshape **DailyState only** — the Plan stays pristine.

**Tech Stack:** Flutter/Dart, SharedPreferences, `flutter_local_notifications` (Phase C), Android Kotlin notification channel.

---

## Reference docs (read before starting)

- Design spec: [`../specs/2026-06-07-life-json-v3-drift-engine-design.md`](../specs/2026-06-07-life-json-v3-drift-engine-design.md)
- External moat docs (folded in): [`moat-implementation-67.md`](moat-implementation-67.md), [`moat-improvement-67.md`](moat-improvement-67.md)
- Decisions: ADR-011…017 in [`../../DECISIONS.md`](../../DECISIONS.md)
- Status: [`../../CONTINUE.md`](../../CONTINUE.md)

## Three architecture decisions locked for this plan (see ADR-015/016/017)

1. **Dual-JSON state.** Plan is immutable at runtime; all daily mutation lands in `DailyState`. Week toggles are the one structural edit that still touches `plan.week`.
2. **Both drift triggers.** Items may carry `cutoffTime` (absolute wall) and/or `maxDriftMinutes` (relative ceiling). Whichever trips first breaches.
3. **Full sandbox in scope.** Phase E ships drag-reorder, swipe-delete, override, Undo — editing DailyState only.

---

## File structure (what each file owns)

**Created**

| File | Responsibility |
|---|---|
| `daily_command_center/assets/seed_plan.json` | The immutable v3 Plan blueprint (Cyrus's whole life as data). |
| `daily_command_center/lib/logic/assembler.dart` | `TimelineAssembler` — merge Plan + DailyState → ordered `List<Block>` (pre-drift). |
| `daily_command_center/lib/logic/drift_engine.dart` | Pure `DriftEngine.computeDay(...)` → `ResolvedDay` (Est Start, compaction, jettison, elasticity, breaker). |
| `daily_command_center/lib/logic/validator.dart` | `PlanValidator` — referential-integrity checks (reused as AI-output checker in sub-project 4). |
| `daily_command_center/lib/data/state_store.dart` | Load/save `DailyState` (`state_<date>` key) + drift-log append + rolling cap. |
| `daily_command_center/lib/data/notifications.dart` | `NotificationService` — dedicated high-priority channel for circuit-breaker alerts. |
| `daily_command_center/lib/screens/live_timeline_view.dart` | Phase E live surface: dual-time render, state-morph matrix, drag/delete/override/Undo. |
| `daily_command_center/test/...` | One test file per logic unit (see tasks). |

**Modified**

| File | Change |
|---|---|
| `lib/data/models.dart` | Add v3 Plan/DailyState/Drift types; extend `Block` with `estStart`/`durationMinutes`/`idealMinutes`/`status`/`isAnchor`. Delete `DaySchedule`/`DayPlan`/`WeekPlan`. |
| `lib/logic/timeline.dart` | Delete hardcoded `buildTimeline` switch + `workouts.dart` import; new `buildTimeline(dayKey, plan, [state])` delegates to assembler. `buildTimes`/`nowDecimal` untouched. |
| `lib/logic/planner.dart` | Generalize to `plan.training.frequencyPerWeek`/`avoidConsecutive`; operate on `Plan`; delete `defaultWeek()`. |
| `lib/data/store.dart` | `activePlan` key; `loadPlan()`→`Plan` (seed from asset if absent); `savePlan(Plan)`; `writeWidgetData(Plan, day)`. |
| `lib/screens/home_screen.dart` | `Plan? _plan`; calls take `Plan`. |
| `lib/screens/today_screen.dart` | Takes `Plan`; renders via assembler. |
| `lib/widgets/now_card.dart` | Takes `Plan`. |
| `lib/widgets/week_planner.dart` | Takes `Plan`; `_DayRow` reads `WeekEntry` + template label/color. |
| `lib/main.dart` | Init `NotificationService` (Phase C). |
| `pubspec.yaml` | Register `assets/seed_plan.json`; add `flutter_local_notifications` (Phase C). |
| `test/logic/timeline_test.dart` | Golden test + keep `buildTimes` tests. |
| `test/logic/planner_test.dart` | Parameterized; drop `defaultWeek`/`DaySchedule`. |

**Deleted**

- `lib/logic/workouts.dart` (content → seed JSON; classes → models.dart).

---

## Conventions for every task

- **TDD:** write the failing test → run it (confirm fail) → minimal implementation → run (confirm pass) → commit.
- **Run tests:** from `daily_command_center/`: `flutter test test/path/to/file.dart` (single) or `flutter test` (all).
- **Commit** after each green task with the message shown.
- **Times in the seed JSON are 24-hour** (`"14:00"`, `"20:30"`, `"23:15"`). The assembler converts each to the app's existing 12-hour display string (e.g. `"20:30"→"8:30"`) so `Block.time`, `Block.signature`, and the rendered UI stay byte-identical to today. Engine math uses 24-hour decimals directly (unambiguous).

---

## Phase A — Plan-driven foundation (byte-identical to today)

> Outcome: the app renders entirely from `seed_plan.json` via the assembler; zero-drift output is byte-identical to the current hardcoded timeline (golden test). Dual-JSON storage and the integrity validator are in place. Nothing about the engine yet.

### Task A1: Register the seed asset + author `seed_plan.json`

**Files:**
- Modify: `daily_command_center/pubspec.yaml`
- Create: `daily_command_center/assets/seed_plan.json`

- [ ] **Step 1: Register the asset**

In `pubspec.yaml`, under the `flutter:` section, replace the commented `# assets:` block with:

```yaml
  assets:
    - assets/seed_plan.json
```

- [ ] **Step 2: Author the seed** — create `assets/seed_plan.json` with the full Cyrus blueprint. Four templates (`office`, `wfh`, `weekend`, `weekend_sun`); every routine item carries `start` (24h), `idealDuration`, `minDuration`, `priority`, and drift fields where applicable. `work`/`sleep` are anchors.

```json
{
  "schemaVersion": 3,
  "meta": {
    "title": "Recomp + career switch",
    "timezone": "Asia/Kolkata",
    "lifestyleArchetype": "cyrus_recomp",
    "generatedAt": "2026-06-07T09:00:00+05:30",
    "improvementAreas": ["fitness", "focus", "nutrition", "sleep"],
    "equipment": ["2x 5kg dumbbells", "bench machine", "treadmill"]
  },
  "dayTemplates": {
    "office": {
      "label": "Office day",
      "colorKey": "terra",
      "anchors": [
        { "id": "work",  "kind": "work",  "label": "Work — 2:00 to 8:00", "desc": "Fixed block.", "start": "14:00", "end": "20:00", "hard": true },
        { "id": "sleep", "kind": "chill", "label": "Sleep target", "desc": "Pull bedtime earlier in 15-min steps.", "start": "23:15", "hard": false }
      ],
      "routineStack": [
        { "id": "wake",     "kind": "meal",  "label": "Wake · water · sunlight", "desc": "Light breakfast: banana + milk/eggs.", "start": "08:00", "idealDuration": 30, "minDuration": 20, "priority": 1 },
        { "id": "focus",    "kind": "focus", "label": "Deep Focus — AI Building", "desc": "Sharpest hour. Phone in another room.", "start": "08:30", "idealDuration": 75, "minDuration": 45, "priority": 2, "maxDriftMinutes": 60, "dropStrategy": "scale_to_min" },
        { "id": "snack",    "kind": "meal",  "label": "Break + snack", "desc": "Coffee, few nuts. Reset.", "start": "09:45", "idealDuration": 15, "minDuration": 10, "priority": 6 },
        { "id": "train",    "kind": "train", "label": "Train", "desc": "Tap to open workout.", "start": "10:00", "idealDuration": 60, "minDuration": 40, "priority": 3, "condition": "isTrainingDay", "workoutId": "B", "cutoffTime": "20:00", "dropStrategy": "kill_and_notify" },
        { "id": "study",    "kind": "goal",  "label": "Extra Study Block", "desc": "No training → bigger AI push or extra DSA.", "goalId": "dsa", "start": "10:00", "idealDuration": 60, "minDuration": 30, "priority": 3, "condition": "isRestDay" },
        { "id": "dsa",      "kind": "goal",  "label": "DSA Practice (45 min)", "desc": "1–2 problems. Keep coding sharp.", "goalId": "dsa", "start": "11:30", "idealDuration": 45, "minDuration": 25, "priority": 5, "maxDriftMinutes": 45, "dropStrategy": "scale_to_min" },
        { "id": "brunch",   "kind": "meal",  "label": "Shower + brunch", "desc": "Big protein meal — office lunch at 3.", "start": "11:00", "idealDuration": 45, "minDuration": 30, "priority": 4, "condition": "isTrainingDay" },
        { "id": "brunch_r", "kind": "meal",  "label": "Brunch — big protein meal", "desc": "Eggs + dal + curd + soya. Main protein hit.", "start": "11:30", "idealDuration": 45, "minDuration": 30, "priority": 4, "condition": "isRestDay" },
        { "id": "commute",  "kind": "work",  "label": "Walk to office (10 min)", "desc": "", "start": "13:50", "idealDuration": 10, "minDuration": 10, "priority": 1 },
        { "id": "lunch3",   "kind": "meal",  "label": "Lunch at office", "desc": "Dal-bhat + soya or paneer.", "start": "15:00", "idealDuration": 30, "minDuration": 20, "priority": 4 },
        { "id": "snack5",   "kind": "meal",  "label": "Light snack at office", "desc": "Roasted chana, peanuts, or curd.", "start": "17:00", "idealDuration": 15, "minDuration": 10, "priority": 6 },
        { "id": "dinner",   "kind": "meal",  "label": "Dinner", "desc": "Roti + paneer/chicken + saag.", "start": "20:30", "idealDuration": 45, "minDuration": 30, "priority": 4 },
        { "id": "chill",    "kind": "chill", "label": "Chill — protected downtime", "desc": "Yours. No forced work.", "start": "21:15", "idealDuration": 90, "minDuration": 30, "priority": 7 },
        { "id": "wind",     "kind": "chill", "label": "Wind-down", "desc": "Screens dim. Makes the 8am wake work.", "start": "22:45", "idealDuration": 30, "minDuration": 20, "priority": 7 }
      ]
    },
    "wfh": {
      "label": "Work from home",
      "colorKey": "sky",
      "anchors": [
        { "id": "work",  "kind": "work",  "label": "Work — 2:00 to 8:00", "desc": "Fixed block.", "start": "14:00", "end": "20:00", "hard": true },
        { "id": "sleep", "kind": "chill", "label": "Sleep target", "desc": "Pull bedtime earlier in 15-min steps.", "start": "23:15", "hard": false }
      ],
      "routineStack": [
        { "id": "wake",    "kind": "meal",  "label": "Wake · water · sunlight", "desc": "Light breakfast: banana + milk/eggs.", "start": "08:00", "idealDuration": 30, "minDuration": 20, "priority": 1 },
        { "id": "bigproj", "kind": "focus", "label": "BIG Project Block (2 hrs)", "desc": "No commute — push a real AI build.", "start": "08:30", "idealDuration": 120, "minDuration": 60, "priority": 2, "maxDriftMinutes": 60, "dropStrategy": "scale_to_min" },
        { "id": "break",   "kind": "meal",  "label": "Break + snack", "desc": "", "start": "10:30", "idealDuration": 15, "minDuration": 10, "priority": 6 },
        { "id": "train",   "kind": "train", "label": "Train", "desc": "Tap to open workout.", "start": "11:00", "idealDuration": 60, "minDuration": 40, "priority": 3, "condition": "isTrainingDay", "workoutId": "A", "cutoffTime": "20:00", "dropStrategy": "kill_and_notify" },
        { "id": "brunch",  "kind": "meal",  "label": "Shower + brunch", "desc": "Big protein meal", "start": "12:00", "idealDuration": 45, "minDuration": 30, "priority": 4 },
        { "id": "dsa",     "kind": "goal",  "label": "DSA Practice (45 min)", "desc": "1–2 problems. Keep coding sharp.", "goalId": "dsa", "start": "13:00", "idealDuration": 45, "minDuration": 25, "priority": 5, "maxDriftMinutes": 45, "dropStrategy": "scale_to_min" },
        { "id": "commute", "kind": "work",  "label": "Walk to office (10 min)", "desc": "", "start": "13:50", "idealDuration": 10, "minDuration": 10, "priority": 1 },
        { "id": "lunch3",  "kind": "meal",  "label": "Lunch at office", "desc": "Dal-bhat + soya or paneer.", "start": "15:00", "idealDuration": 30, "minDuration": 20, "priority": 4 },
        { "id": "snack5",  "kind": "meal",  "label": "Light snack at office", "desc": "Roasted chana, peanuts, or curd.", "start": "17:00", "idealDuration": 15, "minDuration": 10, "priority": 6 },
        { "id": "dinner",  "kind": "meal",  "label": "Dinner", "desc": "Roti + paneer/chicken + saag.", "start": "20:30", "idealDuration": 45, "minDuration": 30, "priority": 4 },
        { "id": "chill",   "kind": "chill", "label": "Chill — protected downtime", "desc": "Yours. No forced work.", "start": "21:15", "idealDuration": 90, "minDuration": 30, "priority": 7 },
        { "id": "wind",    "kind": "chill", "label": "Wind-down", "desc": "Screens dim. Makes the 8am wake work.", "start": "22:45", "idealDuration": 30, "minDuration": 20, "priority": 7 }
      ]
    },
    "weekend": {
      "label": "Weekend",
      "colorKey": "amber",
      "anchors": [
        { "id": "sleep", "kind": "chill", "label": "Sleep target", "desc": "Pull bedtime earlier in 15-min steps.", "start": "23:15", "hard": false }
      ],
      "routineStack": [
        { "id": "wake",     "kind": "meal",  "label": "Wake · water · sunlight", "desc": "Light breakfast: banana + milk/eggs.", "start": "08:00", "idealDuration": 30, "minDuration": 20, "priority": 1 },
        { "id": "focus",    "kind": "focus", "label": "Focus — AI Building", "desc": "Weekend: relaxed long session.", "start": "09:00", "idealDuration": 90, "minDuration": 45, "priority": 2 },
        { "id": "break",    "kind": "meal",  "label": "Break + snack", "desc": "", "start": "10:30", "idealDuration": 15, "minDuration": 10, "priority": 6 },
        { "id": "train",    "kind": "train", "label": "Train", "desc": "Tap to open workout.", "start": "11:00", "idealDuration": 60, "minDuration": 40, "priority": 3, "condition": "isTrainingDay", "workoutId": "BENCH", "cutoffTime": "20:00", "dropStrategy": "kill_and_notify" },
        { "id": "showermeal","kind": "meal", "label": "Shower + big protein meal", "desc": "", "start": "12:00", "idealDuration": 45, "minDuration": 30, "priority": 4, "condition": "isTrainingDay" },
        { "id": "dsablock", "kind": "goal",  "label": "DSA / project block", "desc": "No training today — extra learning.", "goalId": "dsa", "start": "11:00", "idealDuration": 60, "minDuration": 30, "priority": 3, "condition": "isRestDay" },
        { "id": "bigmeal",  "kind": "meal",  "label": "Big protein meal", "desc": "", "start": "12:00", "idealDuration": 45, "minDuration": 30, "priority": 4, "condition": "isRestDay" },
        { "id": "dsa",      "kind": "goal",  "label": "DSA Practice (45 min)", "desc": "1–2 problems. Keep coding sharp.", "goalId": "dsa", "start": "13:00", "idealDuration": 45, "minDuration": 25, "priority": 5 },
        { "id": "free",     "kind": "chill", "label": "Free afternoon", "desc": "Errands, rest, life.", "start": "14:00", "idealDuration": 240, "minDuration": 60, "priority": 7 },
        { "id": "dinner",   "kind": "meal",  "label": "Dinner", "desc": "Roti + paneer/chicken + saag.", "start": "20:30", "idealDuration": 45, "minDuration": 30, "priority": 4 },
        { "id": "chill",    "kind": "chill", "label": "Chill — protected downtime", "desc": "Yours. No forced work.", "start": "21:15", "idealDuration": 90, "minDuration": 30, "priority": 7 },
        { "id": "wind",     "kind": "chill", "label": "Wind-down", "desc": "Screens dim. Makes the 8am wake work.", "start": "22:45", "idealDuration": 30, "minDuration": 20, "priority": 7 }
      ]
    },
    "weekend_sun": {
      "label": "Weekend",
      "colorKey": "amber",
      "anchors": [
        { "id": "sleep", "kind": "chill", "label": "Sleep target", "desc": "Pull bedtime earlier in 15-min steps.", "start": "23:15", "hard": false }
      ],
      "routineStack": [
        { "id": "wake",     "kind": "meal",  "label": "Wake · water · sunlight", "desc": "Light breakfast: banana + milk/eggs.", "start": "08:00", "idealDuration": 30, "minDuration": 20, "priority": 1 },
        { "id": "focus",    "kind": "focus", "label": "Focus — AI Building", "desc": "Weekend: relaxed long session.", "start": "09:00", "idealDuration": 90, "minDuration": 45, "priority": 2 },
        { "id": "break",    "kind": "meal",  "label": "Break + snack", "desc": "", "start": "10:30", "idealDuration": 15, "minDuration": 10, "priority": 6 },
        { "id": "train",    "kind": "train", "label": "Train", "desc": "Tap to open workout.", "start": "11:00", "idealDuration": 60, "minDuration": 40, "priority": 3, "condition": "isTrainingDay", "workoutId": "CARDIO", "cutoffTime": "20:00", "dropStrategy": "kill_and_notify" },
        { "id": "showermeal","kind": "meal", "label": "Shower + big protein meal", "desc": "", "start": "12:00", "idealDuration": 45, "minDuration": 30, "priority": 4, "condition": "isTrainingDay" },
        { "id": "dsablock", "kind": "goal",  "label": "DSA / project block", "desc": "No training today — extra learning.", "goalId": "dsa", "start": "11:00", "idealDuration": 60, "minDuration": 30, "priority": 3, "condition": "isRestDay" },
        { "id": "bigmeal",  "kind": "meal",  "label": "Big protein meal", "desc": "", "start": "12:00", "idealDuration": 45, "minDuration": 30, "priority": 4, "condition": "isRestDay" },
        { "id": "dsa",      "kind": "goal",  "label": "DSA Practice (45 min)", "desc": "1–2 problems. Keep coding sharp.", "goalId": "dsa", "start": "13:00", "idealDuration": 45, "minDuration": 25, "priority": 5 },
        { "id": "free",     "kind": "chill", "label": "Free afternoon", "desc": "Errands, rest, life.", "start": "14:00", "idealDuration": 180, "minDuration": 60, "priority": 7 },
        { "id": "review",   "kind": "focus", "label": "WEEKLY REVIEW (15 min)", "desc": "Log tracker · read rules · plan next week.", "start": "17:00", "idealDuration": 15, "minDuration": 15, "priority": 2 },
        { "id": "dinner",   "kind": "meal",  "label": "Dinner", "desc": "Roti + paneer/chicken + saag.", "start": "20:30", "idealDuration": 45, "minDuration": 30, "priority": 4 },
        { "id": "chill",    "kind": "chill", "label": "Chill — protected downtime", "desc": "Yours. No forced work.", "start": "21:15", "idealDuration": 90, "minDuration": 30, "priority": 7 },
        { "id": "wind",     "kind": "chill", "label": "Wind-down", "desc": "Screens dim. Makes the 8am wake work.", "start": "22:45", "idealDuration": 30, "minDuration": 20, "priority": 7 }
      ]
    }
  },
  "week": {
    "mon": { "templateId": "office", "training": true },
    "tue": { "templateId": "office", "training": false },
    "wed": { "templateId": "wfh", "training": true },
    "thu": { "templateId": "office", "training": false },
    "fri": { "templateId": "office", "training": true },
    "sat": { "templateId": "weekend", "training": false },
    "sun": { "templateId": "weekend_sun", "training": true }
  },
  "weekEditor": { "toggleTemplates": ["office", "wfh"], "lockedDays": ["sat", "sun"] },
  "training": { "frequencyPerWeek": 4, "avoidConsecutive": true, "rotation": ["A", "B", "BENCH", "CARDIO"] },
  "workouts": {
    "A": {
      "title": "Full Body A",
      "why": "Hits every major muscle once. Squat + push + pull is the backbone — most shape comes from these.",
      "exercises": [
        { "name": "Goblet squat",     "sets": "3–4 × 15–20", "repRange": [15, 20], "cue": "Hug one dumbbell, lower slow 3s", "tempo": "3s eccentric", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["slow the negative to 4–5s", "add 1.5-rep partials", "harder variation: pause at bottom", "harder variation: single-leg / deficit"] } },
        { "name": "Push-ups",          "sets": "3–4 × max",   "cue": "Main chest builder", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["slow the negative", "feet elevated", "archer push-ups"] } },
        { "name": "Bent-over rows",    "sets": "3–4 × 15–20", "repRange": [15, 20], "cue": "Pull to ribs — builds back", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["pause at top", "slower negative"] } },
        { "name": "Romanian deadlift", "sets": "3–4 × 15–20", "repRange": [15, 20], "cue": "Feel the hamstrings", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["slower negative", "single-leg"] } },
        { "name": "Shoulder press",    "sets": "3–4 × 12–15", "repRange": [12, 15], "cue": "Shoulders = the V-shape", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["slower negative", "pause at top"] } },
        { "name": "Plank",             "sets": "3 × max",     "cue": "Core", "loggable": false }
      ]
    },
    "B": {
      "title": "Full Body B",
      "why": "Different angles on the same muscles so they keep getting a fresh challenge with light weights.",
      "exercises": [
        { "name": "Bulgarian split squat", "sets": "3–4 × 12–15 ea", "repRange": [12, 15], "cue": "Rear foot on couch", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["slower negative", "pause at bottom"] } },
        { "name": "Floor press",           "sets": "3–4 × 15–20",    "repRange": [15, 20], "cue": "Press dumbbells up", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["slower negative", "pause on floor"] } },
        { "name": "Single-arm row",        "sets": "3–4 × 15 ea",    "cue": "One knee on couch", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["pause at top", "slower negative"] } },
        { "name": "Calf raises",           "sets": "3–4 × 20–25",    "repRange": [20, 25], "cue": "Rise on toes", "loggable": false },
        { "name": "Curls + triceps",       "sets": "3–4 × 15–20",    "repRange": [15, 20], "cue": "Arm work", "loggable": true, "progression": { "method": "double", "addLoad": false, "escalation": ["slower negative"] } },
        { "name": "Leg raises",            "sets": "3 × 15",         "cue": "Lower abs", "loggable": false }
      ]
    },
    "BENCH": {
      "title": "Bench + Push",
      "why": "The bench machine is your ONE loadable lift — the only place to add real weight weekly.",
      "exercises": [
        { "name": "Bench press (machine)", "sets": "3–4 × 10–12", "repRange": [10, 12], "cue": "Add weight when you hit 12 all sets", "loggable": true, "progression": { "method": "double", "addLoad": true, "escalation": ["add the smallest plate jump"] } },
        { "name": "Incline push-ups",      "sets": "3 × 12–15",   "repRange": [12, 15], "cue": "Upper chest", "loggable": false },
        { "name": "Goblet squat",          "sets": "3 × 15–20",   "repRange": [15, 20], "cue": "Legs", "loggable": false },
        { "name": "Rows",                  "sets": "3 × 15–20",   "repRange": [15, 20], "cue": "Back", "loggable": false },
        { "name": "Core circuit",          "sets": "~10 min",     "cue": "Planks + leg raises", "loggable": false }
      ]
    },
    "CARDIO": {
      "title": "Treadmill + Core",
      "why": "Short bursts burn fat without eating into muscle, and spare a beginner's knees vs long runs.",
      "exercises": [
        { "name": "Warm-up walk", "sets": "5 min",        "cue": "Easy", "loggable": false },
        { "name": "Intervals",    "sets": "10–15 rounds", "cue": "30s brisk/incline, 60s easy", "loggable": false },
        { "name": "Cool-down",    "sets": "5 min",        "cue": "Easy walk", "loggable": false },
        { "name": "Core finish",  "sets": "~8 min",       "cue": "Planks, leg raises, side planks", "loggable": false }
      ]
    }
  },
  "nutrition": { "proteinTargetG": 135, "notes": ["Soya capped ~50g dry/day, rotate sources"] },
  "goals": [ { "id": "dsa", "label": "DSA Practice", "cadence": "daily", "loggable": false } ]
}
```

- [ ] **Step 3: Commit**

```bash
git add daily_command_center/pubspec.yaml daily_command_center/assets/seed_plan.json
git commit -m "feat(plan): add v3 seed_plan.json blueprint + register asset"
```

> Note on the seed week: `mon,wed,fri,sun` train (the current default spacing), `sat` rests. The golden test (Task A8) drives the assembler per `(template, training)` directly, so the workout pinned on each template (`office→B`, `wfh→A`, `weekend→BENCH`, `weekend_sun→CARDIO`) is what it checks — independent of which days the week marks as training.

### Task A2: Workout/exercise/progression models in `models.dart`

**Files:**
- Modify: `daily_command_center/lib/data/models.dart`
- Test: `daily_command_center/test/data/workout_models_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  test('WorkoutDef round-trips through json with progression', () {
    const json = {
      'title': 'Full Body A',
      'why': 'because',
      'exercises': [
        {
          'name': 'Goblet squat', 'sets': '3–4 × 15–20', 'repRange': [15, 20],
          'cue': 'slow', 'tempo': '3s eccentric', 'loggable': true,
          'progression': {'method': 'double', 'addLoad': false, 'escalation': ['a', 'b']}
        }
      ]
    };
    final wo = WorkoutDef.fromJson(json);
    expect(wo.title, 'Full Body A');
    expect(wo.exercises.first.repRange, [15, 20]);
    expect(wo.exercises.first.progression!.addLoad, false);
    expect(wo.exercises.first.progression!.escalation, ['a', 'b']);
    expect(WorkoutDef.fromJson(wo.toJson()).toJson(), wo.toJson());
  });

  test('ExerciseDef tolerates missing optional fields', () {
    final ex = ExerciseDef.fromJson({'name': 'Plank', 'sets': '3 × max', 'cue': 'core'});
    expect(ex.repRange, isNull);
    expect(ex.loggable, false);
    expect(ex.progression, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/workout_models_test.dart`
Expected: FAIL — `WorkoutDef`/`ExerciseDef`/`Progression` not defined in models.dart.

- [ ] **Step 3: Add the classes to `models.dart`** (append near the bottom, before `WorkoutLog`)

```dart
class Progression {
  final String method;
  final bool addLoad;
  final List<String> escalation;
  const Progression({required this.method, this.addLoad = false, this.escalation = const []});

  factory Progression.fromJson(Map<String, dynamic> j) => Progression(
        method: (j['method'] ?? 'double') as String,
        addLoad: (j['addLoad'] ?? false) as bool,
        escalation: ((j['escalation'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {'method': method, 'addLoad': addLoad, 'escalation': escalation};
}

class ExerciseDef {
  final String name;
  final String sets;
  final String cue;
  final List<int>? repRange;
  final String? tempo;
  final bool loggable;
  final Progression? progression;
  const ExerciseDef({
    required this.name, required this.sets, required this.cue,
    this.repRange, this.tempo, this.loggable = false, this.progression,
  });

  factory ExerciseDef.fromJson(Map<String, dynamic> j) => ExerciseDef(
        name: j['name'] as String,
        sets: j['sets'] as String,
        cue: (j['cue'] ?? '') as String,
        repRange: j['repRange'] == null ? null : (j['repRange'] as List).map((e) => (e as num).toInt()).toList(),
        tempo: j['tempo'] as String?,
        loggable: (j['loggable'] ?? false) as bool,
        progression: j['progression'] == null ? null : Progression.fromJson(j['progression'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'name': name, 'sets': sets, 'cue': cue,
        if (repRange != null) 'repRange': repRange,
        if (tempo != null) 'tempo': tempo,
        'loggable': loggable,
        if (progression != null) 'progression': progression!.toJson(),
      };
}

class WorkoutDef {
  final String title;
  final String why;
  final List<ExerciseDef> exercises;
  const WorkoutDef({required this.title, required this.why, required this.exercises});

  factory WorkoutDef.fromJson(Map<String, dynamic> j) => WorkoutDef(
        title: j['title'] as String,
        why: (j['why'] ?? '') as String,
        exercises: (j['exercises'] as List).map((e) => ExerciseDef.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title, 'why': why,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/workout_models_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/models.dart daily_command_center/test/data/workout_models_test.dart
git commit -m "feat(models): add v3 WorkoutDef/ExerciseDef/Progression"
```

### Task A3: Template models — `Anchor`, `RoutineItem`, `DayTemplate`

**Files:**
- Modify: `daily_command_center/lib/data/models.dart`
- Test: `daily_command_center/test/data/template_models_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  test('Anchor parses hard/soft and optional end', () {
    final hard = Anchor.fromJson({'id': 'work', 'kind': 'work', 'label': 'Work', 'start': '14:00', 'end': '20:00', 'hard': true});
    final soft = Anchor.fromJson({'id': 'sleep', 'kind': 'chill', 'label': 'Sleep', 'start': '23:15', 'hard': false});
    expect(hard.hard, true);
    expect(hard.end, '20:00');
    expect(soft.end, isNull);
    expect(Anchor.fromJson(hard.toJson()).toJson(), hard.toJson());
  });

  test('RoutineItem parses drift fields and defaults condition to always', () {
    final item = RoutineItem.fromJson({
      'id': 'train', 'kind': 'train', 'label': 'Train', 'start': '10:00',
      'idealDuration': 60, 'minDuration': 40, 'priority': 3,
      'condition': 'isTrainingDay', 'workoutId': 'B', 'cutoffTime': '20:00', 'dropStrategy': 'kill_and_notify',
    });
    expect(item.idealDuration, 60);
    expect(item.condition, 'isTrainingDay');
    expect(item.workoutId, 'B');
    expect(item.cutoffTime, '20:00');
    final plain = RoutineItem.fromJson({'id': 'x', 'kind': 'meal', 'label': 'y', 'start': '08:00', 'idealDuration': 30, 'minDuration': 20, 'priority': 1});
    expect(plain.condition, 'always');
    expect(plain.maxDriftMinutes, isNull);
    expect(RoutineItem.fromJson(item.toJson()).toJson(), item.toJson());
  });

  test('DayTemplate holds anchors and routineStack', () {
    final t = DayTemplate.fromJson({
      'label': 'Office', 'colorKey': 'terra',
      'anchors': [{'id': 'work', 'kind': 'work', 'label': 'Work', 'start': '14:00', 'end': '20:00', 'hard': true}],
      'routineStack': [{'id': 'wake', 'kind': 'meal', 'label': 'Wake', 'start': '08:00', 'idealDuration': 30, 'minDuration': 20, 'priority': 1}],
    });
    expect(t.anchors.single.id, 'work');
    expect(t.routineStack.single.id, 'wake');
    expect(t.colorKey, 'terra');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/template_models_test.dart`
Expected: FAIL — types not defined.

- [ ] **Step 3: Add the classes to `models.dart`**

```dart
class Anchor {
  final String id;
  final String kind;
  final String label;
  final String desc;
  final String start; // 24h "HH:mm"
  final String? end;  // 24h "HH:mm"
  final bool hard;
  const Anchor({
    required this.id, required this.kind, required this.label, required this.start,
    this.desc = '', this.end, this.hard = true,
  });

  factory Anchor.fromJson(Map<String, dynamic> j) => Anchor(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'work') as String,
        label: j['label'] as String,
        desc: (j['desc'] ?? '') as String,
        start: j['start'] as String,
        end: j['end'] as String?,
        hard: (j['hard'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'kind': kind, 'label': label,
        if (desc.isNotEmpty) 'desc': desc,
        'start': start,
        if (end != null) 'end': end,
        'hard': hard,
      };
}

class RoutineItem {
  final String id;
  final String kind;
  final String label;
  final String desc;
  final String start; // 24h "HH:mm" — seed/preferred Est Start
  final int idealDuration;
  final int minDuration;
  final int priority;
  final int? maxDriftMinutes;
  final String? cutoffTime; // 24h "HH:mm"
  final String? dropStrategy; // 'scale_to_min' | 'kill_and_notify'
  final String condition; // 'always' | 'isTrainingDay' | 'isRestDay'
  final String? workoutId;
  final String? goalId;

  const RoutineItem({
    required this.id, required this.kind, required this.label, required this.start,
    required this.idealDuration, required this.minDuration, required this.priority,
    this.desc = '', this.maxDriftMinutes, this.cutoffTime, this.dropStrategy,
    this.condition = 'always', this.workoutId, this.goalId,
  });

  bool get isTrain => kind == 'train';

  factory RoutineItem.fromJson(Map<String, dynamic> j) => RoutineItem(
        id: j['id'] as String,
        kind: j['kind'] as String,
        label: j['label'] as String,
        desc: (j['desc'] ?? '') as String,
        start: j['start'] as String,
        idealDuration: (j['idealDuration'] as num).toInt(),
        minDuration: (j['minDuration'] as num).toInt(),
        priority: (j['priority'] as num).toInt(),
        maxDriftMinutes: (j['maxDriftMinutes'] as num?)?.toInt(),
        cutoffTime: j['cutoffTime'] as String?,
        dropStrategy: j['dropStrategy'] as String?,
        condition: (j['condition'] ?? 'always') as String,
        workoutId: j['workoutId'] as String?,
        goalId: j['goalId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'kind': kind, 'label': label,
        if (desc.isNotEmpty) 'desc': desc,
        'start': start, 'idealDuration': idealDuration, 'minDuration': minDuration, 'priority': priority,
        if (maxDriftMinutes != null) 'maxDriftMinutes': maxDriftMinutes,
        if (cutoffTime != null) 'cutoffTime': cutoffTime,
        if (dropStrategy != null) 'dropStrategy': dropStrategy,
        if (condition != 'always') 'condition': condition,
        if (workoutId != null) 'workoutId': workoutId,
        if (goalId != null) 'goalId': goalId,
      };
}

class DayTemplate {
  final String label;
  final String colorKey;
  final List<Anchor> anchors;
  final List<RoutineItem> routineStack;
  const DayTemplate({required this.label, required this.colorKey, required this.anchors, required this.routineStack});

  factory DayTemplate.fromJson(Map<String, dynamic> j) => DayTemplate(
        label: j['label'] as String,
        colorKey: (j['colorKey'] ?? 'terra') as String,
        anchors: ((j['anchors'] ?? const []) as List).map((e) => Anchor.fromJson(e as Map<String, dynamic>)).toList(),
        routineStack: ((j['routineStack'] ?? const []) as List).map((e) => RoutineItem.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'label': label, 'colorKey': colorKey,
        'anchors': anchors.map((e) => e.toJson()).toList(),
        'routineStack': routineStack.map((e) => e.toJson()).toList(),
      };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/template_models_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/models.dart daily_command_center/test/data/template_models_test.dart
git commit -m "feat(models): add v3 Anchor/RoutineItem/DayTemplate"
```

### Task A4: Top-level `Plan` + supporting config models

**Files:**
- Modify: `daily_command_center/lib/data/models.dart`
- Test: `daily_command_center/test/data/plan_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Plan round-trips through json losslessly for the seed', () async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(plan.schemaVersion, 3);
    expect(plan.dayTemplates.keys, containsAll(['office', 'wfh', 'weekend', 'weekend_sun']));
    expect(plan.week['mon']!.templateId, 'office');
    expect(plan.week['sat']!.training, false);
    expect(plan.training.frequencyPerWeek, 4);
    expect(plan.workouts['BENCH']!.exercises.first.progression!.addLoad, true);
    expect(plan.goals.single.id, 'dsa');
    // Lossless round-trip
    expect(Plan.fromJson(plan.toJson()).toJson(), plan.toJson());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/plan_model_test.dart`
Expected: FAIL — `Plan` and config types not defined. (If asset loading errors, confirm Task A1 registered the asset.)

- [ ] **Step 3: Add the classes to `models.dart`**

```dart
class PlanMeta {
  final String title;
  final String timezone;
  final String lifestyleArchetype;
  final String generatedAt;
  final List<String> improvementAreas;
  final List<String> equipment;
  const PlanMeta({
    this.title = '', this.timezone = '', this.lifestyleArchetype = '',
    this.generatedAt = '', this.improvementAreas = const [], this.equipment = const [],
  });

  factory PlanMeta.fromJson(Map<String, dynamic> j) => PlanMeta(
        title: (j['title'] ?? '') as String,
        timezone: (j['timezone'] ?? '') as String,
        lifestyleArchetype: (j['lifestyleArchetype'] ?? '') as String,
        generatedAt: (j['generatedAt'] ?? '') as String,
        improvementAreas: ((j['improvementAreas'] ?? const []) as List).map((e) => e as String).toList(),
        equipment: ((j['equipment'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title, 'timezone': timezone, 'lifestyleArchetype': lifestyleArchetype,
        'generatedAt': generatedAt, 'improvementAreas': improvementAreas, 'equipment': equipment,
      };
}

class WeekEntry {
  final String templateId;
  final bool training;
  final String? workoutId;
  const WeekEntry({required this.templateId, required this.training, this.workoutId});

  factory WeekEntry.fromJson(Map<String, dynamic> j) => WeekEntry(
        templateId: j['templateId'] as String,
        training: (j['training'] ?? false) as bool,
        workoutId: j['workoutId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'templateId': templateId, 'training': training,
        if (workoutId != null) 'workoutId': workoutId,
      };

  WeekEntry copyWith({String? templateId, bool? training, String? workoutId}) =>
      WeekEntry(templateId: templateId ?? this.templateId, training: training ?? this.training, workoutId: workoutId ?? this.workoutId);
}

class TrainingRules {
  final int frequencyPerWeek;
  final bool avoidConsecutive;
  final List<String> rotation;
  const TrainingRules({required this.frequencyPerWeek, required this.avoidConsecutive, required this.rotation});

  factory TrainingRules.fromJson(Map<String, dynamic> j) => TrainingRules(
        frequencyPerWeek: (j['frequencyPerWeek'] as num).toInt(),
        avoidConsecutive: (j['avoidConsecutive'] ?? true) as bool,
        rotation: ((j['rotation'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {'frequencyPerWeek': frequencyPerWeek, 'avoidConsecutive': avoidConsecutive, 'rotation': rotation};
}

class WeekEditorConfig {
  final List<String> toggleTemplates;
  final List<String> lockedDays;
  const WeekEditorConfig({this.toggleTemplates = const [], this.lockedDays = const []});

  factory WeekEditorConfig.fromJson(Map<String, dynamic> j) => WeekEditorConfig(
        toggleTemplates: ((j['toggleTemplates'] ?? const []) as List).map((e) => e as String).toList(),
        lockedDays: ((j['lockedDays'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {'toggleTemplates': toggleTemplates, 'lockedDays': lockedDays};
}

class NutritionConfig {
  final int proteinTargetG;
  final List<String> notes;
  const NutritionConfig({this.proteinTargetG = 0, this.notes = const []});

  factory NutritionConfig.fromJson(Map<String, dynamic> j) => NutritionConfig(
        proteinTargetG: (j['proteinTargetG'] ?? 0 as num).toInt(),
        notes: ((j['notes'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {'proteinTargetG': proteinTargetG, 'notes': notes};
}

class GoalDef {
  final String id;
  final String label;
  final String cadence;
  final bool loggable;
  const GoalDef({required this.id, required this.label, this.cadence = 'daily', this.loggable = false});

  factory GoalDef.fromJson(Map<String, dynamic> j) => GoalDef(
        id: j['id'] as String,
        label: j['label'] as String,
        cadence: (j['cadence'] ?? 'daily') as String,
        loggable: (j['loggable'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'cadence': cadence, 'loggable': loggable};
}

class Plan {
  final int schemaVersion;
  final PlanMeta meta;
  final Map<String, DayTemplate> dayTemplates;
  final Map<String, WeekEntry> week;
  final WeekEditorConfig weekEditor;
  final TrainingRules training;
  final Map<String, WorkoutDef> workouts;
  final NutritionConfig nutrition;
  final List<GoalDef> goals;

  const Plan({
    required this.schemaVersion, required this.meta, required this.dayTemplates,
    required this.week, required this.weekEditor, required this.training,
    required this.workouts, required this.nutrition, required this.goals,
  });

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        schemaVersion: (j['schemaVersion'] as num).toInt(),
        meta: PlanMeta.fromJson((j['meta'] ?? const {}) as Map<String, dynamic>),
        dayTemplates: (j['dayTemplates'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, DayTemplate.fromJson(v as Map<String, dynamic>))),
        week: (j['week'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, WeekEntry.fromJson(v as Map<String, dynamic>))),
        weekEditor: WeekEditorConfig.fromJson((j['weekEditor'] ?? const {}) as Map<String, dynamic>),
        training: TrainingRules.fromJson(j['training'] as Map<String, dynamic>),
        workouts: (j['workouts'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, WorkoutDef.fromJson(v as Map<String, dynamic>))),
        nutrition: NutritionConfig.fromJson((j['nutrition'] ?? const {}) as Map<String, dynamic>),
        goals: ((j['goals'] ?? const []) as List).map((e) => GoalDef.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'meta': meta.toJson(),
        'dayTemplates': dayTemplates.map((k, v) => MapEntry(k, v.toJson())),
        'week': week.map((k, v) => MapEntry(k, v.toJson())),
        'weekEditor': weekEditor.toJson(),
        'training': training.toJson(),
        'workouts': workouts.map((k, v) => MapEntry(k, v.toJson())),
        'nutrition': nutrition.toJson(),
        'goals': goals.map((e) => e.toJson()).toList(),
      };

  Plan copyWith({Map<String, WeekEntry>? week}) => Plan(
        schemaVersion: schemaVersion, meta: meta, dayTemplates: dayTemplates,
        week: week ?? this.week, weekEditor: weekEditor, training: training,
        workouts: workouts, nutrition: nutrition, goals: goals,
      );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/plan_model_test.dart`
Expected: PASS (proves the seed parses and round-trips).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/models.dart daily_command_center/test/data/plan_model_test.dart
git commit -m "feat(models): add top-level v3 Plan + config models"
```

### Task A5: DailyState models — `DailyState`, `ItemOverride`, `DriftEvent`

**Files:**
- Modify: `daily_command_center/lib/data/models.dart`
- Test: `daily_command_center/test/data/daily_state_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  test('DailyState round-trips, with empty defaults', () {
    const ds = DailyState(date: '2026-06-08');
    expect(ds.deletedItems, isEmpty);
    expect(ds.dailySequence, isEmpty);
    expect(ds.dailyOverrides, isEmpty);
    expect(ds.driftLog, isEmpty);
    expect(DailyState.fromJson(ds.toJson()).date, '2026-06-08');
  });

  test('DailyState carries overrides and drift events', () {
    final ds = DailyState(
      date: '2026-06-08',
      deletedItems: const ['snack'],
      dailySequence: const ['wake', 'focus', 'train'],
      dailyOverrides: const {'focus': ItemOverride(priority: 1)},
      driftLog: const [DriftEvent(date: '2026-06-08', itemId: 'train', label: 'Train', event: 'killed', driftMinutes: 105)],
    );
    final round = DailyState.fromJson(ds.toJson());
    expect(round.deletedItems, ['snack']);
    expect(round.dailyOverrides['focus']!.priority, 1);
    expect(round.driftLog.single.event, 'killed');
    expect(round.toJson(), ds.toJson());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/daily_state_test.dart`
Expected: FAIL — types not defined.

- [ ] **Step 3: Add the classes to `models.dart`**

```dart
class ItemOverride {
  final int? priority;
  const ItemOverride({this.priority});

  factory ItemOverride.fromJson(Map<String, dynamic> j) => ItemOverride(priority: (j['priority'] as num?)?.toInt());
  Map<String, dynamic> toJson() => {if (priority != null) 'priority': priority};
}

class DriftEvent {
  final String date;
  final String itemId;
  final String label;
  final String event; // 'compacted' | 'killed' | 'jettisoned'
  final int? driftMinutes;
  final int? fromDuration;
  final int? toDuration;
  final String note;
  const DriftEvent({
    required this.date, required this.itemId, required this.label, required this.event,
    this.driftMinutes, this.fromDuration, this.toDuration, this.note = '',
  });

  factory DriftEvent.fromJson(Map<String, dynamic> j) => DriftEvent(
        date: j['date'] as String,
        itemId: j['itemId'] as String,
        label: j['label'] as String,
        event: j['event'] as String,
        driftMinutes: (j['driftMinutes'] as num?)?.toInt(),
        fromDuration: (j['fromDuration'] as num?)?.toInt(),
        toDuration: (j['toDuration'] as num?)?.toInt(),
        note: (j['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'date': date, 'itemId': itemId, 'label': label, 'event': event,
        if (driftMinutes != null) 'driftMinutes': driftMinutes,
        if (fromDuration != null) 'fromDuration': fromDuration,
        if (toDuration != null) 'toDuration': toDuration,
        if (note.isNotEmpty) 'note': note,
      };
}

class DailyState {
  final String date; // yyyy-MM-dd
  final List<String> deletedItems;
  final List<String> dailySequence;
  final Map<String, ItemOverride> dailyOverrides;
  final List<DriftEvent> driftLog;

  const DailyState({
    required this.date,
    this.deletedItems = const [],
    this.dailySequence = const [],
    this.dailyOverrides = const {},
    this.driftLog = const [],
  });

  factory DailyState.fromJson(Map<String, dynamic> j) => DailyState(
        date: j['date'] as String,
        deletedItems: ((j['deletedItems'] ?? const []) as List).map((e) => e as String).toList(),
        dailySequence: ((j['dailySequence'] ?? const []) as List).map((e) => e as String).toList(),
        dailyOverrides: ((j['dailyOverrides'] ?? const {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, ItemOverride.fromJson(v as Map<String, dynamic>))),
        driftLog: ((j['driftLog'] ?? const []) as List).map((e) => DriftEvent.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'deletedItems': deletedItems,
        'dailySequence': dailySequence,
        'dailyOverrides': dailyOverrides.map((k, v) => MapEntry(k, v.toJson())),
        'driftLog': driftLog.map((e) => e.toJson()).toList(),
      };

  DailyState copyWith({
    List<String>? deletedItems, List<String>? dailySequence,
    Map<String, ItemOverride>? dailyOverrides, List<DriftEvent>? driftLog,
  }) => DailyState(
        date: date,
        deletedItems: deletedItems ?? this.deletedItems,
        dailySequence: dailySequence ?? this.dailySequence,
        dailyOverrides: dailyOverrides ?? this.dailyOverrides,
        driftLog: driftLog ?? this.driftLog,
      );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/daily_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/models.dart daily_command_center/test/data/daily_state_test.dart
git commit -m "feat(models): add DailyState/ItemOverride/DriftEvent"
```

### Task A6: Extend `Block` + 24h→display time helper

**Files:**
- Modify: `daily_command_center/lib/data/models.dart`
- Test: `daily_command_center/test/data/block_test.dart`

The resolved runtime `Block` gains engine fields (defaulted so existing `const Block(...)` call-sites still compile) and a `BlockStatus`. A pure `displayTime` helper converts 24h `"HH:mm"` to the app's 12h string so `Block.time`/`signature` stay byte-identical to today.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  test('displayTime converts 24h to the existing 12h display strings', () {
    expect(displayTime('08:00'), '8:00');
    expect(displayTime('09:45'), '9:45');
    expect(displayTime('11:30'), '11:30');
    expect(displayTime('12:00'), '12:00');
    expect(displayTime('13:50'), '1:50');
    expect(displayTime('14:00'), '2:00');
    expect(displayTime('17:00'), '5:00');
    expect(displayTime('20:30'), '8:30');
    expect(displayTime('23:15'), '11:15');
    expect(displayTime('00:30'), '12:30');
  });

  test('Block keeps backward-compatible defaults and adds engine fields', () {
    const b = Block(time: '8:00', cls: 'meal', label: 'Wake');
    expect(b.status, BlockStatus.pending);
    expect(b.isAnchor, false);
    expect(b.durationMinutes, 0);
    expect(b.signature, '8:00|Wake');
    final b2 = b.copyWith(status: BlockStatus.dropped, durationMinutes: 40, idealMinutes: 60, estStart: 10.5, isAnchor: true);
    expect(b2.status, BlockStatus.dropped);
    expect(b2.isCompacted, true); // 40 < 60
    expect(b2.estStart, 10.5);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/block_test.dart`
Expected: FAIL — `displayTime`, `BlockStatus`, new fields not defined.

- [ ] **Step 3: Replace the `Block` class in `models.dart`** and add the helper + enum (top of file). Keep `isTrackable`/`signature`.

```dart
enum BlockStatus { pending, done, dropped }

/// Converts a 24h "HH:mm" seed time to the app's 12h display string
/// (no AM/PM, minutes zero-padded) — e.g. "20:30" -> "8:30", "14:00" -> "2:00".
String displayTime(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:${m.toString().padLeft(2, '0')}';
}

class Block {
  final String time;     // 12h display string (stable; drives signature)
  final String cls;
  final String label;
  final String desc;
  final bool isTrain;
  final String? workout;
  final String? id;      // routine/anchor id (null for legacy const blocks)
  final double estStart; // 24h decimal; 0 until the engine computes it
  final int durationMinutes;
  final int idealMinutes;
  final int priority;
  final bool isAnchor;
  final bool hardAnchor;
  final BlockStatus status;

  const Block({
    required this.time,
    required this.cls,
    required this.label,
    this.desc = '',
    this.isTrain = false,
    this.workout,
    this.id,
    this.estStart = 0,
    this.durationMinutes = 0,
    this.idealMinutes = 0,
    this.priority = 0,
    this.isAnchor = false,
    this.hardAnchor = false,
    this.status = BlockStatus.pending,
  });

  bool get isTrackable => cls != 'work' && cls != 'chill';
  String get signature => '$time|$label';
  bool get isCompacted => !isAnchor && idealMinutes > 0 && durationMinutes < idealMinutes;
  bool get isDropped => status == BlockStatus.dropped;

  Block copyWith({
    String? time, String? cls, String? label, String? desc, bool? isTrain, String? workout, String? id,
    double? estStart, int? durationMinutes, int? idealMinutes, int? priority,
    bool? isAnchor, bool? hardAnchor, BlockStatus? status,
  }) => Block(
        time: time ?? this.time, cls: cls ?? this.cls, label: label ?? this.label, desc: desc ?? this.desc,
        isTrain: isTrain ?? this.isTrain, workout: workout ?? this.workout, id: id ?? this.id,
        estStart: estStart ?? this.estStart, durationMinutes: durationMinutes ?? this.durationMinutes,
        idealMinutes: idealMinutes ?? this.idealMinutes, priority: priority ?? this.priority,
        isAnchor: isAnchor ?? this.isAnchor, hardAnchor: hardAnchor ?? this.hardAnchor, status: status ?? this.status,
      );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/block_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/models.dart daily_command_center/test/data/block_test.dart
git commit -m "feat(models): extend Block with engine fields + displayTime helper"
```

### Task A7: Plan storage (`store.dart`) — Dual-JSON Plan side

**Files:**
- Modify: `daily_command_center/lib/data/store.dart`
- Test: `daily_command_center/test/data/store_test.dart`

`loadPlan()` now returns a `Plan`: if `activePlan` is absent, it loads `assets/seed_plan.json`, saves it, and returns it. `writeWidgetData` takes a `Plan`. (We leave `writeWidgetData`'s body mostly as-is but switch it to the new `buildTimeline(day, plan)` — wired in A9; here we just change the type and the load/save.)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loadPlan seeds from asset when activePlan absent', () async {
    final plan = await AppStore.loadPlan();
    expect(plan.schemaVersion, 3);
    expect(plan.week['mon']!.templateId, 'office');
    // It also persisted the seed so a second load is from storage.
    final again = await AppStore.loadPlan();
    expect(again.dayTemplates.length, plan.dayTemplates.length);
  });

  test('savePlan then loadPlan round-trips an edited week', () async {
    final plan = await AppStore.loadPlan();
    final edited = plan.copyWith(week: {
      ...plan.week,
      'tue': plan.week['tue']!.copyWith(training: true),
    });
    await AppStore.savePlan(edited);
    final loaded = await AppStore.loadPlan();
    expect(loaded.week['tue']!.training, true);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/store_test.dart`
Expected: FAIL — `loadPlan` still returns `WeekPlan`/uses `defaultWeek`.

- [ ] **Step 3: Rewrite the Plan-side of `store.dart`** (the `_planKey`, `loadPlan`, `savePlan`; leave logs untouched; `writeWidgetData` signature changes to `Plan` — its body is finalized in A9). Replace imports of `planner.dart`'s `defaultWeek` usage.

```dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import '../logic/timeline.dart';

class AppStore {
  static const _planKey = 'activePlan';
  static const _logPrefix = 'log_';
  static const _seedAsset = 'assets/seed_plan.json';

  static Future<Plan> loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_planKey);
    if (raw != null) {
      try {
        return Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // fall through to re-seed on corruption
      }
    }
    final seedRaw = await rootBundle.loadString(_seedAsset);
    final plan = Plan.fromJson(jsonDecode(seedRaw) as Map<String, dynamic>);
    await prefs.setString(_planKey, jsonEncode(plan.toJson()));
    return plan;
  }

  static Future<void> savePlan(Plan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey, jsonEncode(plan.toJson()));
  }

  static Future<List<WorkoutLog>> loadLogs(String workoutKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_logPrefix$workoutKey');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLogs(String workoutKey, List<WorkoutLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_logPrefix$workoutKey', jsonEncode(logs.map((e) => e.toJson()).toList()));
  }

  // Finalized in Task A9 (uses buildTimeline(day, plan)).
  static Future<void> writeWidgetData(Plan plan, String todayKey) async {
    const dayNames = {
      'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
      'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
    };
    final blocks = buildTimeline(todayKey, plan);
    if (blocks.isEmpty) return;
    final times = buildTimes(blocks);
    final now = nowDecimal();

    String currentAction = 'Wind down';
    String nextAction = '';
    int progressPct = 0;

    if (now < times.first) {
      currentAction = 'Still resting';
      nextAction = 'Next · ${blocks.first.time} — ${blocks.first.label}';
    } else {
      for (int i = 0; i < blocks.length; i++) {
        final start = times[i];
        final end = i < blocks.length - 1 ? times[i + 1] : 25.0;
        if (now >= start && now < end) {
          currentAction = blocks[i].label;
          if (i < blocks.length - 1) {
            nextAction = 'Next · ${blocks[i + 1].time} — ${blocks[i + 1].label}';
          }
          progressPct = ((now - start) / (end - start) * 100).round().clamp(0, 100);
          break;
        }
      }
    }

    try {
      await HomeWidget.saveWidgetData<String>('currentAction', currentAction);
      await HomeWidget.saveWidgetData<String>('nextAction', nextAction);
      await HomeWidget.saveWidgetData<String>('dayLabel', dayNames[todayKey] ?? todayKey);
      await HomeWidget.saveWidgetData<int>('progressPct', progressPct);
      await HomeWidget.updateWidget(androidName: 'NowWidgetProvider');
    } catch (_) {
      // Widget not on home screen or platform error — safe to ignore
    }
  }
}
```

> This step will leave compile errors in `home_screen.dart` etc. (they still pass `WeekPlan`). That's expected — Task A9 fixes all call-sites. Run only the store test now (`flutter test test/data/store_test.dart`) until A9.

- [ ] **Step 4: Run the store test**

Run: `flutter test test/data/store_test.dart`
Expected: PASS. (`flutter test` as a whole will not yet pass — fixed in A9.)

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/store.dart daily_command_center/test/data/store_test.dart
git commit -m "feat(store): activePlan key, seed-from-asset loadPlan(Plan)"
```

### Task A8: `DailyState` storage (`state_store.dart`)

**Files:**
- Create: `daily_command_center/lib/data/state_store.dart`
- Test: `daily_command_center/test/data/state_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/state_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final day = DateTime(2026, 6, 8);

  test('loadState returns empty DailyState for a fresh day', () async {
    final s = await StateStore.loadState(day);
    expect(s.date, '2026-06-08');
    expect(s.deletedItems, isEmpty);
  });

  test('saveState then loadState round-trips', () async {
    await StateStore.saveState(const DailyState(date: '2026-06-08', deletedItems: ['snack']));
    final s = await StateStore.loadState(day);
    expect(s.deletedItems, ['snack']);
  });

  test('appendDriftEvent persists into the day driftLog', () async {
    await StateStore.appendDriftEvent(day, const DriftEvent(date: '2026-06-08', itemId: 'train', label: 'Train', event: 'killed', driftMinutes: 105));
    final s = await StateStore.loadState(day);
    expect(s.driftLog.single.itemId, 'train');
  });

  test('recentDriftEvents aggregates the last 7 days', () async {
    await StateStore.appendDriftEvent(DateTime(2026, 6, 8), const DriftEvent(date: '2026-06-08', itemId: 'train', label: 'Train', event: 'killed'));
    await StateStore.appendDriftEvent(DateTime(2026, 6, 6), const DriftEvent(date: '2026-06-06', itemId: 'focus', label: 'Focus', event: 'compacted', fromDuration: 75, toDuration: 45));
    final events = await StateStore.recentDriftEvents(DateTime(2026, 6, 8), days: 7);
    expect(events.length, 2);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/state_store_test.dart`
Expected: FAIL — `StateStore` not defined.

- [ ] **Step 3: Create `state_store.dart`**

```dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Loads/saves the ephemeral DailyState (`state_<yyyy-MM-dd>`) — the day's
/// deletions, reorder, overrides, and drift log. The Plan stays immutable.
class StateStore {
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  static String _key(DateTime d) => 'state_${_fmt.format(d)}';

  static Future<DailyState> loadState(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(day));
    if (raw == null) return DailyState(date: _fmt.format(day));
    try {
      return DailyState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return DailyState(date: _fmt.format(day));
    }
  }

  static Future<void> saveState(DailyState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('state_${state.date}', jsonEncode(state.toJson()));
  }

  static Future<void> appendDriftEvent(DateTime day, DriftEvent event) async {
    final state = await loadState(day);
    await saveState(state.copyWith(driftLog: [...state.driftLog, event]));
  }

  /// Drift events from the last [days] days (inclusive of [today]), newest day last.
  static Future<List<DriftEvent>> recentDriftEvents(DateTime today, {int days = 7}) async {
    final base = DateTime(today.year, today.month, today.day);
    final out = <DriftEvent>[];
    for (int i = days - 1; i >= 0; i--) {
      final s = await loadState(base.subtract(Duration(days: i)));
      out.addAll(s.driftLog);
    }
    return out;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/state_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/state_store.dart daily_command_center/test/data/state_store_test.dart
git commit -m "feat(state): DailyState storage + drift-log append/aggregate"
```

### Task A9: `PlanValidator` — referential integrity

**Files:**
- Create: `daily_command_center/lib/logic/validator.dart`
- Test: `daily_command_center/test/logic/validator_test.dart`

Reused as the AI-output checker in sub-project 4. Checks: every `week[].templateId` ∈ `dayTemplates`; every `workoutId` (week + template train items) ∈ `workouts`; every `rotation` id ∈ `workouts`; every `goalId` ∈ `goals`; anchor/item ids unique within a template.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled seed passes validation', () async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(PlanValidator.validate(plan), isEmpty);
  });

  test('flags an unknown templateId in week', () {
    final base = _minimalPlan();
    final broken = base.copyWith(week: {'mon': const WeekEntry(templateId: 'ghost', training: false)});
    final errs = PlanValidator.validate(broken);
    expect(errs.any((e) => e.contains('ghost')), true);
  });
}

Plan _minimalPlan() => Plan(
      schemaVersion: 3,
      meta: const PlanMeta(),
      dayTemplates: {
        'office': const DayTemplate(label: 'Office', colorKey: 'terra', anchors: [], routineStack: []),
      },
      week: {'mon': const WeekEntry(templateId: 'office', training: false)},
      weekEditor: const WeekEditorConfig(),
      training: const TrainingRules(frequencyPerWeek: 4, avoidConsecutive: true, rotation: []),
      workouts: const {},
      nutrition: const NutritionConfig(),
      goals: const [],
    );
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/logic/validator_test.dart`
Expected: FAIL — `PlanValidator` not defined.

- [ ] **Step 3: Create `validator.dart`**

```dart
import '../data/models.dart';

/// Referential-integrity checks for a Plan. Returns a list of human-readable
/// problems (empty == valid). Reused as the AI-output checker (sub-project 4).
class PlanValidator {
  static List<String> validate(Plan plan) {
    final errors = <String>[];
    final templateIds = plan.dayTemplates.keys.toSet();
    final workoutIds = plan.workouts.keys.toSet();
    final goalIds = plan.goals.map((g) => g.id).toSet();

    plan.week.forEach((day, entry) {
      if (!templateIds.contains(entry.templateId)) {
        errors.add('week[$day].templateId "${entry.templateId}" is not a known template');
      }
      if (entry.workoutId != null && !workoutIds.contains(entry.workoutId)) {
        errors.add('week[$day].workoutId "${entry.workoutId}" is not a known workout');
      }
    });

    for (final id in plan.training.rotation) {
      if (!workoutIds.contains(id)) errors.add('training.rotation has unknown workout "$id"');
    }

    plan.dayTemplates.forEach((tid, tmpl) {
      final ids = <String>{};
      for (final a in tmpl.anchors) {
        if (!ids.add(a.id)) errors.add('template "$tid" has duplicate id "${a.id}"');
      }
      for (final item in tmpl.routineStack) {
        if (!ids.add(item.id)) errors.add('template "$tid" has duplicate id "${item.id}"');
        if (item.workoutId != null && !workoutIds.contains(item.workoutId)) {
          errors.add('template "$tid" item "${item.id}" workoutId "${item.workoutId}" unknown');
        }
        if (item.goalId != null && !goalIds.contains(item.goalId)) {
          errors.add('template "$tid" item "${item.id}" goalId "${item.goalId}" unknown');
        }
      }
    });

    return errors;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/logic/validator_test.dart`
Expected: PASS (proves the seed is internally consistent).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/validator.dart daily_command_center/test/logic/validator_test.dart
git commit -m "feat(validator): referential-integrity checks for v3 Plan"
```

### Task A10: `TimelineAssembler` + new `buildTimeline` + GOLDEN TEST

**Files:**
- Create: `daily_command_center/lib/logic/assembler.dart`
- Modify: `daily_command_center/lib/logic/timeline.dart`
- Test: `daily_command_center/test/logic/golden_timeline_test.dart`

The assembler merges Plan + DailyState into an ordered `List<Block>` (pre-drift): filter by `condition`, purge `deletedItems`, fill the train workout, merge anchors + routineStack, apply `dailySequence` order if present (else clock order), convert 24h → display time. The golden test snapshots the **current** hardcoded `buildTimeline` and asserts the assembler reproduces it for every `(template, training)`.

**Strategy:** Temporarily keep the old hardcoded logic available to generate the golden fixture. Easiest: capture expected output as inline literals derived from the current code (listed below), so we don't depend on the old code path.

- [ ] **Step 1: Write the golden test** (drives the assembler per `(templateId, training)`; expected rows transcribed from today's `timeline.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/assembler.dart';

/// Each expected row: time|cls|label|isTrain|workout
List<String> _sig(List<Block> blocks) =>
    blocks.map((b) => '${b.time}|${b.cls}|${b.label}|${b.isTrain}|${b.workout ?? ""}').toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Plan plan;

  setUpAll(() async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('office + training matches today', () {
    final got = _sig(TimelineAssembler.assembleDay(plan, 'office', 'mon', training: true));
    expect(got, [
      '8:00|meal|Wake · water · sunlight|false|',
      '8:30|focus|Deep Focus — AI Building|false|',
      '9:45|meal|Break + snack|false|',
      '10:00|train|Train — Full Body B|true|B',
      '11:00|meal|Shower + brunch|false|',
      '11:30|goal|DSA Practice (45 min)|false|',
      '1:50|work|Walk to office (10 min)|false|',
      '2:00|work|Work — 2:00 to 8:00|false|',
      '3:00|meal|Lunch at office|false|',
      '5:00|meal|Light snack at office|false|',
      '8:30|meal|Dinner|false|',
      '9:15|chill|Chill — protected downtime|false|',
      '10:45|chill|Wind-down|false|',
      '11:15|chill|Sleep target|false|',
    ]);
  });

  test('office + rest matches today', () {
    final got = _sig(TimelineAssembler.assembleDay(plan, 'office', 'tue', training: false));
    expect(got, [
      '8:00|meal|Wake · water · sunlight|false|',
      '8:30|focus|Deep Focus — AI Building|false|',
      '9:45|meal|Break + snack|false|',
      '10:00|goal|Extra Study Block|false|',
      '11:30|goal|DSA Practice (45 min)|false|',
      '11:30|meal|Brunch — big protein meal|false|',
      '1:50|work|Walk to office (10 min)|false|',
      '2:00|work|Work — 2:00 to 8:00|false|',
      '3:00|meal|Lunch at office|false|',
      '5:00|meal|Light snack at office|false|',
      '8:30|meal|Dinner|false|',
      '9:15|chill|Chill — protected downtime|false|',
      '10:45|chill|Wind-down|false|',
      '11:15|chill|Sleep target|false|',
    ]);
  });

  test('wfh + training uses workout A', () {
    final got = _sig(TimelineAssembler.assembleDay(plan, 'wfh', 'wed', training: true));
    expect(got.firstWhere((s) => s.contains('|train|')), '11:00|train|Train — Full Body A|true|A');
    expect(got.first, '8:00|meal|Wake · water · sunlight|false|');
    expect(got.last, '11:15|chill|Sleep target|false|');
  });

  test('weekend sat training uses BENCH; weekend_sun training uses CARDIO + review', () {
    final sat = _sig(TimelineAssembler.assembleDay(plan, 'weekend', 'sat', training: true));
    final sun = _sig(TimelineAssembler.assembleDay(plan, 'weekend_sun', 'sun', training: true));
    expect(sat.firstWhere((s) => s.contains('|train|')), '11:00|train|Train — Bench + Push|true|BENCH');
    expect(sun.firstWhere((s) => s.contains('|train|')), '11:00|train|Train — Treadmill + Core|true|CARDIO');
    expect(sun.any((s) => s.contains('WEEKLY REVIEW')), true);
    expect(sat.any((s) => s.contains('WEEKLY REVIEW')), false);
  });

  test('condition filtering: train shows only on training days', () {
    final rest = _sig(TimelineAssembler.assembleDay(plan, 'wfh', 'wed', training: false));
    expect(rest.any((s) => s.contains('|train|')), false);
  });

  test('deletedItems purge removes a block', () {
    final state = const DailyState(date: '2026-06-08', deletedItems: ['snack']);
    final got = _sig(TimelineAssembler.assembleDay(plan, 'office', 'mon', training: true, state: state));
    expect(got.any((s) => s.contains('Break + snack')), false);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/logic/golden_timeline_test.dart`
Expected: FAIL — `TimelineAssembler` not defined.

- [ ] **Step 3: Create `assembler.dart`**

```dart
import '../data/models.dart';

class TimelineAssembler {
  /// Merge Plan blueprint + DailyState into an ordered List<Block> (pre-drift).
  static List<Block> assembleDay(
    Plan plan,
    String templateId,
    String dayKey, {
    required bool training,
    DailyState state = const DailyState(date: ''),
  }) {
    final tmpl = plan.dayTemplates[templateId];
    if (tmpl == null) return const [];

    final deleted = state.deletedItems.toSet();

    // 1. Filter routine items by condition + deletions; resolve into Blocks.
    final items = <Block>[];
    for (final item in tmpl.routineStack) {
      if (deleted.contains(item.id)) continue;
      if (!_conditionHolds(item.condition, training)) continue;
      items.add(_itemToBlock(plan, item, dayKey, training, state));
    }

    // 2. Anchors -> Blocks (never filtered by condition; never deleted).
    final anchors = tmpl.anchors.map(_anchorToBlock).toList();

    // 3. Merge + order.
    final merged = [...items, ...anchors];
    if (state.dailySequence.isNotEmpty) {
      // Reorder by explicit sequence; unknown/extra ids keep clock order after.
      final order = {for (int i = 0; i < state.dailySequence.length; i++) state.dailySequence[i]: i};
      merged.sort((a, b) {
        final ia = order[a.id] ?? 1 << 20;
        final ib = order[b.id] ?? 1 << 20;
        if (ia != ib) return ia.compareTo(ib);
        return a.estStart.compareTo(b.estStart);
      });
    } else {
      // Stable clock order by 24h decimal (items already authored in order).
      mergeSortStable(merged, (a, b) => a.estStart.compareTo(b.estStart));
    }
    return merged;
  }

  static bool _conditionHolds(String condition, bool training) {
    switch (condition) {
      case 'isTrainingDay':
        return training;
      case 'isRestDay':
        return !training;
      default:
        return true;
    }
  }

  static double _decimal24(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) + int.parse(p[1]) / 60.0;
  }

  static Block _itemToBlock(Plan plan, RoutineItem item, String dayKey, bool training, DailyState state) {
    String label = item.label;
    String? workout;
    bool isTrain = false;
    if (item.isTrain) {
      isTrain = true;
      workout = item.workoutId ?? plan.week[dayKey]?.workoutId;
      final wo = workout != null ? plan.workouts[workout] : null;
      if (wo != null) label = 'Train — ${wo.title}';
    }
    final priority = state.dailyOverrides[item.id]?.priority ?? item.priority;
    // 'goal' kind renders with the existing 'dsa' class used by today's UI.
    final cls = item.kind == 'goal' ? 'dsa' : item.kind;
    return Block(
      time: displayTime(item.start),
      cls: cls,
      label: label,
      desc: item.desc,
      isTrain: isTrain,
      workout: workout,
      id: item.id,
      estStart: _decimal24(item.start),
      durationMinutes: item.idealDuration,
      idealMinutes: item.idealDuration,
      priority: priority,
    );
  }

  static Block _anchorToBlock(Anchor a) => Block(
        time: displayTime(a.start),
        cls: a.kind,
        label: a.label,
        desc: a.desc,
        id: a.id,
        estStart: _decimal24(a.start),
        isAnchor: true,
        hardAnchor: a.hard,
      );

  /// Stable merge-sort (Dart's List.sort is not guaranteed stable).
  static void mergeSortStable<T>(List<T> list, int Function(T, T) cmp) {
    if (list.length < 2) return;
    final mid = list.length ~/ 2;
    final left = list.sublist(0, mid);
    final right = list.sublist(mid);
    mergeSortStable(left, cmp);
    mergeSortStable(right, cmp);
    int i = 0, j = 0, k = 0;
    while (i < left.length && j < right.length) {
      if (cmp(left[i], right[j]) <= 0) {
        list[k++] = left[i++];
      } else {
        list[k++] = right[j++];
      }
    }
    while (i < left.length) list[k++] = left[i++];
    while (j < right.length) list[k++] = right[j++];
  }
}
```

> The `'goal' → 'dsa'` class mapping reproduces today's DSA/study blocks (today used `cls: 'dsa'`). The `weekend`/`weekend_sun` split + per-template pinned `workoutId` reproduces ADR-005 (Sat=BENCH, Sun=CARDIO) without rotation.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/logic/golden_timeline_test.dart`
Expected: PASS — assembler output is byte-identical to today.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/assembler.dart daily_command_center/test/logic/golden_timeline_test.dart
git commit -m "feat(assembler): data-driven TimelineAssembler + golden test"
```

### Task A11: Rewire `buildTimeline`, `planner.dart`, callers + delete dead code

**Files:**
- Modify: `lib/logic/timeline.dart`, `lib/logic/planner.dart`, `lib/data/models.dart`, `lib/data/store.dart`, `lib/screens/home_screen.dart`, `lib/screens/today_screen.dart`, `lib/widgets/now_card.dart`, `lib/widgets/week_planner.dart`, `test/logic/timeline_test.dart`, `test/logic/planner_test.dart`
- Delete: `lib/logic/workouts.dart`

This is the cutover task: every `DayPlan`/`WeekPlan`/`DaySchedule`/`defaultWeek` reference is replaced. Done in one task because the app won't compile until all are consistent.

- [ ] **Step 1: New `timeline.dart`** — delegate to the assembler; keep `buildTimes`/`nowDecimal` verbatim.

```dart
import '../data/models.dart';
import 'assembler.dart';

/// Resolve the day's timeline from the Plan (+ optional DailyState).
List<Block> buildTimeline(String dayKey, Plan plan, [DailyState? state]) {
  final entry = plan.week[dayKey];
  if (entry == null) return const [];
  return TimelineAssembler.assembleDay(
    plan, entry.templateId, dayKey,
    training: entry.training,
    state: state ?? DailyState(date: ''),
  );
}

// Resolve block time strings to 24h decimals.
// Walks forward through the day — never moves backward — to correctly
// disambiguate AM vs PM (e.g. "8:30" after "11:15" → 20.5, not 8.5).
List<double> buildTimes(List<Block> blocks) {
  double prev = 0;
  return blocks.map((b) {
    final parts = b.time.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final candidates = h == 12 ? [12.0 + m / 60] : [h + m / 60, h + 12.0 + m / 60];
    candidates.sort();
    double val = candidates.last;
    for (final c in candidates) {
      if (c >= prev - 0.001) { val = c; break; }
    }
    prev = val;
    return val;
  }).toList();
}

double nowDecimal() {
  final n = DateTime.now();
  return n.hour + n.minute / 60;
}
```

- [ ] **Step 2: New `planner.dart`** — operate on `Plan`, generalize to `training.frequencyPerWeek`/`avoidConsecutive`; delete `defaultWeek()`.

```dart
import 'dart:math';
import '../data/models.dart';

class PlannerLogic {
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static int _freq(Plan plan) => plan.training.frequencyPerWeek;

  static double _spacingScore(List<String> trainingDays, bool avoidConsecutive) {
    if (trainingDays.length < 2) return 0;
    final indices = trainingDays.map((d) => _days.indexOf(d)).toList()..sort();
    final gaps = <int>[];
    for (int i = 1; i < indices.length; i++) {
      gaps.add(indices[i] - indices[i - 1]);
    }
    final minGap = gaps.reduce(min);
    if (avoidConsecutive && minGap < 2) return -1.0;
    return minGap + 0.1 * (gaps.reduce((a, b) => a + b) / gaps.length);
  }

  static ({Plan plan, String? message}) toggleTraining(Plan plan, String day) {
    final entry = plan.week[day]!;
    final week = Map<String, WeekEntry>.from(plan.week);

    if (entry.training) {
      week[day] = entry.copyWith(training: false);
      return (plan: plan.copyWith(week: week), message: null);
    }

    week[day] = entry.copyWith(training: true);
    final trainingDays = _days.where((d) => week[d]!.training).toList();
    final cap = _freq(plan);

    if (trainingDays.length <= cap) {
      return (plan: plan.copyWith(week: week), message: null);
    }

    String? removed;
    Map<String, WeekEntry>? best;
    double bestScore = -2;
    for (final candidate in trainingDays) {
      if (candidate == day) continue;
      final trial = Map<String, WeekEntry>.from(week);
      trial[candidate] = week[candidate]!.copyWith(training: false);
      final score = _spacingScore(_days.where((d) => trial[d]!.training).toList(), plan.training.avoidConsecutive);
      if (score > bestScore) {
        bestScore = score;
        best = trial;
        removed = candidate;
      }
    }

    final finalWeek = best ?? week;
    final msg = removed != null ? 'Moved training from ${_capitalize(removed)} for better spacing' : null;
    return (plan: plan.copyWith(week: finalWeek), message: msg);
  }

  /// Cycle the day's template through weekEditor.toggleTemplates (locked days unchanged).
  static Plan toggleSchedule(Plan plan, String day) {
    if (plan.weekEditor.lockedDays.contains(day)) return plan;
    final order = plan.weekEditor.toggleTemplates;
    if (order.isEmpty) return plan;
    final entry = plan.week[day]!;
    final idx = order.indexOf(entry.templateId);
    final next = order[(idx + 1) % order.length];
    final week = Map<String, WeekEntry>.from(plan.week);
    week[day] = entry.copyWith(templateId: next);
    return plan.copyWith(week: week);
  }

  static String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
```

- [ ] **Step 3: Remove dead types** — delete `DaySchedule`, `DayPlan`, and `typedef WeekPlan` from `models.dart`. Delete the file `lib/logic/workouts.dart`.

- [ ] **Step 4: Update callers.** In `home_screen.dart`, `today_screen.dart`, `now_card.dart`: change the field/param type `WeekPlan` → `Plan`, and any `plan[_todayKey]` (DayPlan) usage to `buildTimeline(_todayKey, plan)` directly (the assembler reads `plan.week` internally). Concretely:
  - `home_screen.dart`: `Plan? _plan;`; `_tally` becomes `_tally(Plan plan, Set<String> done)` and computes `buildTimeline(_todayKey, plan)`; `_updatePlan(Plan newPlan)`; `NowCard`/`WeekPlanner`/`TodayScreen` receive `Plan`.
  - `today_screen.dart`: `final Plan plan;` and `buildTimeline(widget.todayKey, widget.plan)`.
  - `now_card.dart`: `final Plan plan;` and `buildTimeline(widget.todayKey, widget.plan)`.

```dart
// home_screen.dart — replace _tally:
  ({int done, int total}) _tally(Plan plan, Set<String> done) {
    final trackable = buildTimeline(_todayKey, plan).where((b) => b.isTrackable).toList();
    return (
      done: trackable.where((b) => done.contains(b.signature)).length,
      total: trackable.length,
    );
  }
```

- [ ] **Step 5: Update `week_planner.dart`** — read `WeekEntry` + template label/color from the plan.

```dart
// Fields:
//   final Plan plan;  (was WeekPlan)
//   final void Function(Plan newPlan) onPlanChanged;
// _trainCount:
int get _trainCount => widget.plan.week.values.where((e) => e.training).length;

// _onSchedule / _onTraining call PlannerLogic.toggleSchedule(widget.plan, day) / toggleTraining(...)
// "Reset to suggested week" -> reload the seed: call a new AppStore.resetToSeed() OR just re-apply spacing.
// Replace the reset GestureDetector onTap with: widget.onPlanChanged(_resetWeek(widget.plan));
```

Add a `_resetWeek` helper in `week_planner.dart` that re-spaces to `frequencyPerWeek` (replaces the deleted `defaultWeek`):

```dart
Plan _resetWeek(Plan plan) {
  // Turn all training off, then toggle the evenly-spaced default days on.
  var p = plan.copyWith(week: {
    for (final e in plan.week.entries) e.key: e.value.copyWith(training: false),
  });
  for (final d in const ['mon', 'wed', 'fri', 'sun']) {
    p = PlannerLogic.toggleTraining(p, d).plan;
  }
  return p;
}
```

Update `_DayRow` to take a `WeekEntry entry`, plus `String templateLabel`, `Color schedColor`, `bool isLocked`, computed by the parent from `plan.dayTemplates[entry.templateId].label`/`colorKey`. Map `colorKey` → `AppColors` via a small switch (`terra`/`sky`/`amber`). `entry.training` replaces `plan.isTraining`.

- [ ] **Step 6: Update existing tests.**

`test/logic/timeline_test.dart` — keep the three `buildTimes` tests verbatim (they construct `Block`s directly, still valid). Replace the `buildTimeline` group with assembler-driven equivalents OR delete it (golden test now covers it). Minimal change — replace the `buildTimeline` group with:

```dart
  group('buildTimeline (plan-driven)', () {
    late Plan plan;
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final raw = await rootBundle.loadString('assets/seed_plan.json');
      plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    });

    test('mon (office, training) includes a train block = B', () {
      final blocks = buildTimeline('mon', plan);
      final t = blocks.firstWhere((b) => b.isTrain);
      expect(t.workout, 'B');
    });

    test('sat in the seed is a rest day (no train block)', () {
      final blocks = buildTimeline('sat', plan);
      expect(blocks.any((b) => b.isTrain), false);
    });
  });
```

Add imports at top: `import 'dart:convert';` and `import 'package:flutter/services.dart';`.

`test/logic/planner_test.dart` — rewrite against `Plan`. Load the seed; assert toggle invariants generalized:

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Plan plan;
  setUp(() async {
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('toggling never exceeds frequencyPerWeek', () {
    var p = plan;
    for (final day in const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
      if (!p.week[day]!.training) p = PlannerLogic.toggleTraining(p, day).plan;
      final count = p.week.values.where((e) => e.training).length;
      expect(count, lessThanOrEqualTo(p.training.frequencyPerWeek));
    }
  });

  test('toggleSchedule cycles office<->wfh, leaves locked days', () {
    final flipped = PlannerLogic.toggleSchedule(plan, 'mon');
    expect(flipped.week['mon']!.templateId, 'wfh');
    final locked = PlannerLogic.toggleSchedule(plan, 'sat');
    expect(locked.week['sat']!.templateId, 'weekend');
  });
}
```

- [ ] **Step 7: Run the whole suite**

Run: `flutter test`
Expected: PASS — all tests green; app compiles fully on the new types.

- [ ] **Step 8: Smoke-run on device** (optional but recommended)

Run: `flutter run` → verify the home screen, Today screen, and week planner look identical to before.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: cut over app to plan-driven v3 (delete DayPlan/workouts.dart/defaultWeek)"
```

> **Phase A done.** The app renders entirely from `seed_plan.json`; zero-drift output is byte-identical (golden test). Dual-JSON storage + validator are in place. No engine behavior yet.

---

## Phase B — DriftEngine: dual-time, compaction, jettison, elasticity

> Outcome: a pure `DriftEngine.computeDay(blocks, now, doneSignatures)` returns a `ResolvedDay` whose blocks carry computed `estStart`, current `durationMinutes`, and `status`, plus a list of `DriftEvent`s. Anchors are protected; flexible items compact/jettison/re-inflate. No notifications or persistence yet (Phase C/D).

**Engine contract (read before B1):**

- Input: the assembled `List<Block>` (clock-ordered, with `estStart`=seed 24h decimal, `idealMinutes`, `priority`, `isAnchor`/`hardAnchor`), `now` (24h decimal), and the set of done signatures.
- The engine walks the list once to compute `estStart` per block via a forward cursor (never moves backward), inserting a `transitionBufferMinutes` gap between consecutive flexible items. Anchors pin the cursor to their fixed start.
- "Drift" enters via `now`: the first not-done flexible block is the **active** one; if `now` is past its computed `estStart`, the cursor jumps to `now` and everything downstream cascades.
- When a downstream flexible item's running end would cross a **hard anchor's** start, the engine compacts (`scale_to_min` items shrink, least-important first) and, if still overflowing, jettisons the least-important item entirely.
- Two-way elasticity: items naturally re-expand toward `idealMinutes` when the cursor has slack (finishing early), because each item's duration is recomputed from available room each pass.

`transitionBufferMinutes` default = 5 (a top-level engine constant; later configurable via Plan meta).

### Task B1: `ResolvedDay` + Est-Start cascade (anchors pinned)

**Files:**
- Create: `daily_command_center/lib/logic/drift_engine.dart`
- Test: `daily_command_center/test/logic/drift_engine_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/drift_engine.dart';

Block _item(String id, double start, {int ideal = 30, int min = 20, int prio = 3, String drop = 'scale_to_min'}) =>
    Block(time: id, cls: 'focus', label: id, id: id, estStart: start, durationMinutes: ideal, idealMinutes: ideal, priority: prio);

Block _anchor(String id, double start, {bool hard = true}) =>
    Block(time: id, cls: 'work', label: id, id: id, estStart: start, isAnchor: true, hardAnchor: hard);

void main() {
  test('zero-drift: estStart equals seed start (now before first item)', () {
    final blocks = [_item('a', 8.0, ideal: 30), _item('b', 9.0, ideal: 30)];
    final day = DriftEngine.computeDay(blocks, now: 7.0, done: {});
    expect(day.blocks[0].estStart, closeTo(8.0, 0.001));
    expect(day.blocks[1].estStart, closeTo(9.0, 0.001));
    expect(day.events, isEmpty);
  });

  test('anchor keeps its fixed estStart regardless of upstream', () {
    final blocks = [_item('a', 8.0, ideal: 60), _anchor('work', 14.0)];
    final day = DriftEngine.computeDay(blocks, now: 7.0, done: {});
    expect(day.blocks.firstWhere((b) => b.id == 'work').estStart, closeTo(14.0, 0.001));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/logic/drift_engine_test.dart`
Expected: FAIL — `DriftEngine`/`ResolvedDay` not defined.

- [ ] **Step 3: Create `drift_engine.dart`** (B1 scope: cascade + anchors; later tasks extend the same file)

```dart
import '../data/models.dart';

class ResolvedDay {
  final List<Block> blocks;
  final List<DriftEvent> events;
  const ResolvedDay(this.blocks, this.events);
}

class DriftEngine {
  static const int transitionBufferMinutes = 5;

  /// Pure: compute Est Start + durations + status for the day.
  /// [blocks] must be clock-ordered (assembler output). [now] is a 24h decimal.
  static ResolvedDay computeDay(
    List<Block> blocks, {
    required double now,
    required Set<String> done,
    String dateIso = '',
  }) {
    final out = <Block>[];
    final events = <DriftEvent>[];
    final buffer = transitionBufferMinutes / 60.0;

    double cursor = 0; // running clock (24h decimal)
    bool started = false;

    for (final b in blocks) {
      if (b.isAnchor) {
        // Anchors never drift; cursor jumps to anchor end (or start if no end).
        out.add(b.copyWith(estStart: b.estStart, status: BlockStatus.pending));
        final endDecimal = b.estStart; // anchors advance the cursor minimally here; end handled in B4
        cursor = cursor < endDecimal ? endDecimal : cursor;
        continue;
      }

      double est = b.estStart;
      if (started && cursor + buffer > est) {
        est = cursor + buffer;
      }
      final durH = b.durationMinutes / 60.0;
      cursor = est + durH;
      started = true;

      out.add(b.copyWith(
        estStart: est,
        status: done.contains(b.signature) ? BlockStatus.done : BlockStatus.pending,
      ));
    }

    return ResolvedDay(out, events);
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/logic/drift_engine_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/drift_engine.dart daily_command_center/test/logic/drift_engine_test.dart
git commit -m "feat(engine): ResolvedDay + Est-Start cascade with pinned anchors"
```

### Task B2: Transition buffer between flexible items

**Files:**
- Modify: `daily_command_center/lib/logic/drift_engine.dart`
- Test: append to `daily_command_center/test/logic/drift_engine_test.dart`

(The buffer is already in B1's code; this task adds an explicit test to lock the behavior and guard against regressions.)

- [ ] **Step 1: Add the failing test**

```dart
  test('inserts a 5-min transition buffer when items are back-to-back late', () {
    // a runs 8:00 + 60min = 9:00; b seeds 9:00 -> pushed to 9:00 + 5min buffer
    final blocks = [_item('a', 8.0, ideal: 60), _item('b', 9.0, ideal: 30)];
    final day = DriftEngine.computeDay(blocks, now: 8.5, done: {});
    expect(day.blocks[1].estStart, closeTo(9.0 + 5 / 60.0, 0.001));
  });
```

- [ ] **Step 2: Run** — `flutter test test/logic/drift_engine_test.dart` — Expected: this test FAILS only if B1 was implemented without the buffer; if it passes immediately, the buffer is correctly wired. Either way, end green.

- [ ] **Step 3:** If failing, ensure the `cursor + buffer > est` branch from B1 is present.

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/test/logic/drift_engine_test.dart
git commit -m "test(engine): lock transition-buffer behavior"
```

### Task B3: Drift injection from `now` (active item cascade)

**Files:**
- Modify: `daily_command_center/lib/logic/drift_engine.dart`
- Test: append to `drift_engine_test.dart`

- [ ] **Step 1: Add the failing test**

```dart
  test('running late: active item and downstream cascade from now', () {
    // now=10:00 but item a seeds 8:00 (not done) -> a starts at 10:00, b cascades after
    final blocks = [_item('a', 8.0, ideal: 60), _item('b', 9.5, ideal: 30)];
    final day = DriftEngine.computeDay(blocks, now: 10.0, done: {});
    expect(day.blocks[0].estStart, closeTo(10.0, 0.001));          // pulled to now
    expect(day.blocks[1].estStart, closeTo(11.0 + 5 / 60.0, 0.01)); // 10 + 60min + buffer
  });

  test('done items do not absorb now; first not-done is the active anchor of drift', () {
    final blocks = [_item('a', 8.0, ideal: 30), _item('b', 9.0, ideal: 30)];
    final day = DriftEngine.computeDay(blocks, now: 10.0, done: {'a|a'});
    // a is done (keeps seed), b is active -> pulled to now
    expect(day.blocks[1].estStart, closeTo(10.0, 0.001));
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (B1 doesn't pull the active item to `now`).

- [ ] **Step 3: Update `computeDay`** — find the active item (first not-done flexible block) and seed the cursor from `now` there.

```dart
  static ResolvedDay computeDay(
    List<Block> blocks, {
    required double now,
    required Set<String> done,
    String dateIso = '',
  }) {
    final out = <Block>[];
    final events = <DriftEvent>[];
    final buffer = transitionBufferMinutes / 60.0;

    // Index of the active item = first not-done, non-anchor block.
    int activeIdx = blocks.indexWhere((b) => !b.isAnchor && !done.contains(b.signature));

    double cursor = 0;
    bool started = false;

    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.isAnchor) {
        out.add(b.copyWith(status: BlockStatus.pending));
        cursor = cursor < b.estStart ? b.estStart : cursor;
        continue;
      }

      final isDone = done.contains(b.signature);
      double est = b.estStart;

      if (i == activeIdx && now > est) {
        est = now; // pull active item to the real clock
      } else if (started && cursor + buffer > est) {
        est = cursor + buffer;
      }

      final durH = b.durationMinutes / 60.0;
      cursor = est + durH;
      started = true;

      out.add(b.copyWith(estStart: est, status: isDone ? BlockStatus.done : BlockStatus.pending));
    }

    return ResolvedDay(out, events);
  }
```

- [ ] **Step 4: Run** — Expected: PASS (all drift_engine tests).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/drift_engine.dart daily_command_center/test/logic/drift_engine_test.dart
git commit -m "feat(engine): drift injection — cascade from now at the active item"
```

### Task B4: Micro-compaction — protect hard anchors, shed least-important first

**Files:**
- Modify: `daily_command_center/lib/logic/drift_engine.dart`
- Test: append to `drift_engine_test.dart`

When the running cursor would push a flexible item's start past the next **hard anchor's** start, shrink `scale_to_min`-eligible items (here: all flexible items have a `minMinutes`; we add `minMinutes` to `Block`) between `now` and that anchor — highest `priority` number first — toward `minMinutes`, until the stack fits or all are at min. Emit a `compacted` `DriftEvent` per shrunk item.

First, `Block` needs `minMinutes`. Add it in this task (small extension).

- [ ] **Step 1: Add the failing test**

```dart
  test('compaction shrinks least-important item first to protect a hard anchor', () {
    // Two items before a hard anchor at 11:00. Running late at 10:00.
    // a: ideal 60 min 40 prio 2 ; b: ideal 60 min 30 prio 5 (less important)
    final blocks = [
      _itemC('a', 10.0, ideal: 60, min: 40, prio: 2),
      _itemC('b', 10.5, ideal: 60, min: 30, prio: 5),
      _anchor('work', 11.0, hard: true),
    ];
    final day = DriftEngine.computeDay(blocks, now: 10.0, done: {});
    final b = day.blocks.firstWhere((x) => x.id == 'b');
    final a = day.blocks.firstWhere((x) => x.id == 'a');
    // b (less important) should be shrunk before a.
    expect(b.durationMinutes, lessThan(60));
    expect(a.durationMinutes, greaterThanOrEqualTo(b.idealMinutes == 60 ? 40 : 40));
    expect(day.events.any((e) => e.itemId == 'b' && e.event == 'compacted'), true);
  });
```

Add a helper at the top of the test file:

```dart
Block _itemC(String id, double start, {required int ideal, required int min, required int prio}) =>
    Block(time: id, cls: 'focus', label: id, id: id, estStart: start,
        durationMinutes: ideal, idealMinutes: ideal, minMinutes: min, priority: prio);
```

- [ ] **Step 2: Run** — Expected: FAIL (`minMinutes` undefined; no compaction).

- [ ] **Step 3a: Add `minMinutes` to `Block`** in `models.dart` (default 0; thread through `copyWith`), and set it in the assembler (`minMinutes: item.minDuration` in `_itemToBlock`).

```dart
// models.dart Block: add field
final int minMinutes;
// constructor: this.minMinutes = 0,
// copyWith: int? minMinutes,  ... minMinutes: minMinutes ?? this.minMinutes,
```

```dart
// assembler.dart _itemToBlock: add to the Block(...) call
minMinutes: item.minDuration,
```

- [ ] **Step 3b: Add compaction to `computeDay`.** After the cascade pass, run a compaction pass for each hard-anchor window. Replace the body with a two-phase approach:

```dart
  static ResolvedDay computeDay(
    List<Block> blocks, {
    required double now,
    required Set<String> done,
    String dateIso = '',
  }) {
    final events = <DriftEvent>[];
    // Mutable working durations (start at ideal/current).
    final dur = [for (final b in blocks) b.durationMinutes];

    ResolvedDay layout() => _cascade(blocks, dur, now: now, done: done);

    // Initial layout.
    var day = layout();

    // Compaction: for each hard anchor, if items before it overflow, shrink.
    for (int ai = 0; ai < blocks.length; ai++) {
      final anchor = blocks[ai];
      if (!anchor.isAnchor || !anchor.hardAnchor) continue;

      // Indices of flexible, not-done items before this anchor that are still movable.
      bool overflows() {
        final est = day.blocks[ai].estStart;
        // The item just before the anchor ends after the anchor start?
        for (int i = ai - 1; i >= 0; i--) {
          if (blocks[i].isAnchor) break;
          final endH = day.blocks[i].estStart + dur[i] / 60.0;
          if (endH > est + 0.0001) return true;
          break; // only need the last item before the anchor
        }
        return false;
      }

      // Candidate items to shrink: flexible, not done, before the anchor — least important first.
      final candidates = <int>[];
      for (int i = 0; i < ai; i++) {
        if (blocks[i].isAnchor) continue;
        if (done.contains(blocks[i].signature)) continue;
        if (blocks[i].minMinutes < dur[i]) candidates.add(i);
      }
      candidates.sort((x, y) => blocks[y].priority.compareTo(blocks[x].priority)); // high prio number first

      int ci = 0;
      while (overflows() && ci < candidates.length) {
        final i = candidates[ci];
        if (dur[i] > blocks[i].minMinutes) {
          final from = dur[i];
          dur[i] = blocks[i].minMinutes;
          events.add(DriftEvent(
            date: dateIso, itemId: blocks[i].id ?? '', label: blocks[i].label,
            event: 'compacted', fromDuration: from, toDuration: dur[i],
            note: 'compacted to protect ${anchor.label}',
          ));
          day = layout();
        }
        ci++;
      }
    }

    return ResolvedDay(day.blocks, events);
  }

  /// Single forward pass producing estStart per block given working durations [dur].
  static ResolvedDay _cascade(List<Block> blocks, List<int> dur, {required double now, required Set<String> done}) {
    final out = <Block>[];
    final buffer = transitionBufferMinutes / 60.0;
    int activeIdx = blocks.indexWhere((b) => !b.isAnchor && !done.contains(b.signature));
    double cursor = 0;
    bool started = false;

    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.isAnchor) {
        out.add(b.copyWith(status: BlockStatus.pending));
        final end = b.estStart; // soft anchors don't consume time; hard anchor 'end' handled by next item seed
        cursor = cursor < end ? end : cursor;
        continue;
      }
      final isDone = done.contains(b.signature);
      double est = b.estStart;
      if (i == activeIdx && now > est) {
        est = now;
      } else if (started && cursor + buffer > est) {
        est = cursor + buffer;
      }
      cursor = est + dur[i] / 60.0;
      started = true;
      out.add(b.copyWith(estStart: est, durationMinutes: dur[i], status: isDone ? BlockStatus.done : BlockStatus.pending));
    }
    return ResolvedDay(out, const []);
  }
```

> Note: this replaces the B3 single-pass `computeDay` with a layout-and-compact loop calling the extracted `_cascade`. The B1–B3 tests still pass because with no overflow, `dur` stays at ideal and `_cascade` is the same forward pass.

- [ ] **Step 4: Run** — `flutter test test/logic/drift_engine_test.dart` — Expected: PASS (all B1–B4 tests).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/drift_engine.dart daily_command_center/lib/logic/assembler.dart daily_command_center/lib/data/models.dart daily_command_center/test/logic/drift_engine_test.dart
git commit -m "feat(engine): micro-compaction protecting hard anchors (shed least-important first)"
```

### Task B5: Jettison protocol + `DriftEvent`

**Files:**
- Modify: `daily_command_center/lib/logic/drift_engine.dart`
- Test: append to `drift_engine_test.dart`

If, after every eligible item is at `minMinutes`, the stack **still** overflows the hard anchor, drop the least-important not-done item entirely (`status: dropped`, excluded from the timeline length used downstream) and emit a `jettisoned` event. Dropped items contribute zero duration.

- [ ] **Step 1: Add the failing test**

```dart
  test('jettisons the least-important item when min durations still overflow', () {
    // Three 60→60 items (no shrink room) before a hard anchor 30 min away -> must drop.
    final blocks = [
      _itemC('a', 13.0, ideal: 60, min: 60, prio: 2),
      _itemC('b', 13.0, ideal: 60, min: 60, prio: 7), // least important
      _anchor('work', 14.0, hard: true),
    ];
    final day = DriftEngine.computeDay(blocks, now: 13.0, done: {});
    final b = day.blocks.firstWhere((x) => x.id == 'b');
    expect(b.status, BlockStatus.dropped);
    expect(day.events.any((e) => e.itemId == 'b' && e.event == 'jettisoned'), true);
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (no jettison logic).

- [ ] **Step 3: Extend `computeDay`** — after the compaction `while` loop for an anchor, if it still `overflows()`, drop the least-important not-done, not-already-dropped item before the anchor:

```dart
      // After compaction: if still overflowing, jettison least-important items.
      final dropped = <int>{};
      final jettCandidates = <int>[];
      for (int i = 0; i < ai; i++) {
        if (blocks[i].isAnchor) continue;
        if (done.contains(blocks[i].signature)) continue;
        jettCandidates.add(i);
      }
      jettCandidates.sort((x, y) => blocks[y].priority.compareTo(blocks[x].priority));
      int ji = 0;
      while (overflows() && ji < jettCandidates.length) {
        final i = jettCandidates[ji];
        if (!dropped.contains(i)) {
          dropped.add(i);
          dur[i] = 0; // removed from the stack
          events.add(DriftEvent(
            date: dateIso, itemId: blocks[i].id ?? '', label: blocks[i].label,
            event: 'jettisoned', note: 'dropped to protect ${anchor.label}',
          ));
          day = layout(droppedSet: dropped);
        }
        ji++;
      }
```

Thread a `droppedSet` through `layout`/`_cascade` so dropped items render with `status: dropped` and contribute 0 duration:

```dart
    ResolvedDay layout({Set<int> droppedSet = const {}}) => _cascade(blocks, dur, now: now, done: done, dropped: droppedSet);
    var day = layout();
    // ... in the anchor loop, replace `day = layout();` after compaction with `day = layout(droppedSet: dropped);`
```

```dart
  static ResolvedDay _cascade(List<Block> blocks, List<int> dur, {required double now, required Set<String> done, Set<int> dropped = const {}}) {
    // ... same as B4, but:
    //   - skip cursor advance for dropped items
    //   - set status: BlockStatus.dropped for them
    // Inside the loop, for non-anchor b at index i:
    if (dropped.contains(i)) {
      out.add(b.copyWith(durationMinutes: 0, status: BlockStatus.dropped));
      continue;
    }
    // ... otherwise unchanged
  }
```

(Carry `dropped` into `_cascade`'s signature and the active-index calc should skip dropped items: `!dropped.contains(idx)`.)

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/drift_engine.dart daily_command_center/test/logic/drift_engine_test.dart
git commit -m "feat(engine): jettison protocol — drop least-important to save the anchor"
```

### Task B6: Two-way elasticity (re-inflation when ahead)

**Files:**
- Modify: `daily_command_center/lib/logic/drift_engine.dart`
- Test: append to `drift_engine_test.dart`

When the user is **ahead** (the active item's `now` is earlier than its seed start, or a prior item finished early so the cursor has slack), downstream items keep their `idealMinutes` (they never got compacted) — i.e. the engine must not over-shrink and must restore ideal durations on recompute. Because `computeDay` is pure and recomputes `dur` from `idealMinutes` each call, re-inflation is automatic. This task adds a regression test proving a previously-tight day re-inflates once the pressure is gone.

- [ ] **Step 1: Add the failing/│regression test**

```dart
  test('re-inflates to ideal when the schedule is no longer late', () {
    final blocks = [
      _itemC('a', 10.0, ideal: 60, min: 40, prio: 2),
      _itemC('b', 10.5, ideal: 60, min: 30, prio: 5),
      _anchor('work', 11.0, hard: true),
    ];
    // Late -> compaction happens.
    final late = DriftEngine.computeDay(blocks, now: 10.0, done: {});
    expect(late.blocks.firstWhere((x) => x.id == 'b').durationMinutes, lessThan(60));
    // Early/ahead -> recompute restores ideal (fresh call, no shrink needed).
    final ahead = DriftEngine.computeDay(blocks, now: 7.0, done: {});
    expect(ahead.blocks.firstWhere((x) => x.id == 'b').durationMinutes, 60);
    expect(ahead.blocks.firstWhere((x) => x.id == 'a').durationMinutes, 60);
  });
```

- [ ] **Step 2: Run** — Expected: PASS if `dur` is rebuilt from `idealMinutes` each call (it is, per B4). If it FAILS, ensure `computeDay` initializes `dur` from `b.idealMinutes` (not a cached/mutated source).

```dart
// Ensure at the top of computeDay:
final dur = [for (final b in blocks) b.idealMinutes];
```

- [ ] **Step 3:** Apply the `idealMinutes` initialization fix if needed.

- [ ] **Step 4: Run** — Expected: PASS (full engine suite).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/drift_engine.dart daily_command_center/test/logic/drift_engine_test.dart
git commit -m "feat(engine): two-way elasticity — recompute restores ideal durations"
```

> **Phase B done.** The DriftEngine computes dual-time, compacts to protect hard anchors, jettisons as last resort, and re-inflates — all as a pure function emitting `DriftEvent`s. Not yet wired into UI or persistence.

---

## Phase C — Circuit-breaker + Android notification

> Outcome: items breaching `cutoffTime` (absolute) or `maxDriftMinutes` (relative) are killed (`status: dropped`, `event: 'killed'`), the next item promoted, a high-priority Android notification fires on a dedicated channel, and the kill is persisted to the day's drift log. Pure breach detection stays in the engine (testable without platform); the notification + persistence are a thin side-effect layer.

### Task C1: `cutoffTime` breach detection (absolute wall)

**Files:**
- Modify: `daily_command_center/lib/logic/drift_engine.dart`
- Test: append to `drift_engine_test.dart`

The engine needs each block's `cutoffTime` as a 24h decimal. Add `cutoffDecimal` and `maxDriftMinutes` (+ `seedStart` for relative drift) to `Block`, set by the assembler. A `kill_and_notify` item whose computed `estStart` is past its `cutoffDecimal` is dropped with a `killed` event.

- [ ] **Step 1: Add the failing test**

```dart
  test('cutoffTime breach kills the item and emits a killed event', () {
    final train = Block(
      time: 'train', cls: 'train', label: 'Train', id: 'train', isTrain: true,
      estStart: 20.5, durationMinutes: 60, idealMinutes: 60, minMinutes: 40, priority: 3,
      cutoffDecimal: 20.0, dropStrategy: 'kill_and_notify',
    );
    final day = DriftEngine.computeDay([train], now: 20.5, done: {});
    final t = day.blocks.firstWhere((b) => b.id == 'train');
    expect(t.status, BlockStatus.dropped);
    expect(day.events.any((e) => e.itemId == 'train' && e.event == 'killed'), true);
  });

  test('no breach when estStart is before the cutoff', () {
    final train = Block(
      time: 'train', cls: 'train', label: 'Train', id: 'train', isTrain: true,
      estStart: 10.0, durationMinutes: 60, idealMinutes: 60, minMinutes: 40, priority: 3,
      cutoffDecimal: 20.0, dropStrategy: 'kill_and_notify',
    );
    final day = DriftEngine.computeDay([train], now: 10.0, done: {});
    expect(day.blocks.first.status, BlockStatus.pending);
    expect(day.events, isEmpty);
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (`cutoffDecimal`/`dropStrategy` not on `Block`; no breaker).

- [ ] **Step 3a: Extend `Block`** in `models.dart` with `double? cutoffDecimal`, `int? maxDriftMinutes`, `double seedStart` (the original seed estStart, for relative drift), `String? dropStrategy`. Thread through constructor + `copyWith`. In the assembler `_itemToBlock`, set:

```dart
seedStart: _decimal24(item.start),
cutoffDecimal: item.cutoffTime == null ? null : _decimal24(item.cutoffTime!),
maxDriftMinutes: item.maxDriftMinutes,
dropStrategy: item.dropStrategy,
```

- [ ] **Step 3b: Add breach detection to `computeDay`** — after compaction/jettison, scan for breaches on the laid-out `day`:

```dart
    // Circuit-breaker: kill items past cutoff or drift ceiling.
    final killed = <int>{};
    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.isAnchor) continue;
      if (b.dropStrategy != 'kill_and_notify') continue;
      if (done.contains(b.signature)) continue;
      final est = day.blocks[i].estStart;
      final cutoffBreach = b.cutoffDecimal != null && est > b.cutoffDecimal! + 0.0001;
      final driftBreach = b.maxDriftMinutes != null && (est - b.seedStart) * 60.0 > b.maxDriftMinutes! + 0.0001;
      if ((cutoffBreach || driftBreach) && !killed.contains(i)) {
        killed.add(i);
        dur[i] = 0;
        events.add(DriftEvent(
          date: dateIso, itemId: b.id ?? '', label: b.label, event: 'killed',
          driftMinutes: ((est - b.seedStart) * 60.0).round(),
          note: cutoffBreach ? 'past cutoff ${b.cutoffDecimal}' : 'drifted past ${b.maxDriftMinutes}m',
        ));
      }
    }
    if (killed.isNotEmpty) {
      day = layout(droppedSet: {...?_lastDropped, ...killed}); // re-layout with kills dropped
    }
```

> Simplify: thread one combined dropped set (jettisoned ∪ killed) into the final `layout` call. Track it as a single `final allDropped = <int>{}` populated by both jettison and breaker, and call `day = layout(droppedSet: allDropped)` once at the end. Update the jettison block (B5) to add to `allDropped` instead of a local `dropped`.

- [ ] **Step 4: Run** — Expected: PASS (cutoff tests + all prior).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/drift_engine.dart daily_command_center/lib/logic/assembler.dart daily_command_center/lib/data/models.dart daily_command_center/test/logic/drift_engine_test.dart
git commit -m "feat(engine): cutoffTime circuit-breaker (absolute wall)"
```

### Task C2: `maxDriftMinutes` breach (relative ceiling)

**Files:**
- Test: append to `drift_engine_test.dart`

The relative-drift branch is already in C1's code; this task locks it with an explicit test (an item with no cutoff but a drift ceiling).

- [ ] **Step 1: Add the failing/regression test**

```dart
  test('maxDriftMinutes breach kills when drift exceeds the ceiling', () {
    final focus = Block(
      time: 'focus', cls: 'focus', label: 'Deep Focus', id: 'focus',
      seedStart: 8.5, estStart: 8.5, durationMinutes: 75, idealMinutes: 75, minMinutes: 45, priority: 2,
      maxDriftMinutes: 60, dropStrategy: 'kill_and_notify',
    );
    // now = 10:00 -> active item pulled to 10:00; drift = 90 min > 60 ceiling
    final day = DriftEngine.computeDay([focus], now: 10.0, done: {});
    expect(day.blocks.first.status, BlockStatus.dropped);
    expect(day.events.single.event, 'killed');
    expect(day.events.single.driftMinutes, 90);
  });
```

- [ ] **Step 2: Run** — Expected: PASS (already implemented in C1). If FAIL, ensure the `driftBreach` branch uses `(est - b.seedStart)`.

- [ ] **Step 3:** (none, or fix the drift formula.)

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/test/logic/drift_engine_test.dart
git commit -m "test(engine): lock maxDriftMinutes relative breach"
```

### Task C3: `NotificationService` + Android channel

**Files:**
- Modify: `daily_command_center/pubspec.yaml`
- Create: `daily_command_center/lib/data/notifications.dart`
- Modify: `daily_command_center/lib/main.dart`
- Modify (Android): `daily_command_center/android/app/src/main/AndroidManifest.xml`

> Disk note (CONTINUE.md): `flutter_local_notifications` is pure-Dart/Java (no NDK). Safe on the constrained disk. Do NOT re-add `ndkVersion`.

- [ ] **Step 1: Add the dependency** to `pubspec.yaml` under `dependencies:`

```yaml
  flutter_local_notifications: ^18.0.1
```

Run: `flutter pub get` (from `daily_command_center/`). Expected: resolves cleanly.

- [ ] **Step 2: Create `notifications.dart`**

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Dedicated high-priority channel for circuit-breaker (auto-cancel) alerts.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'drift_breaker';
  static const String _channelName = 'Schedule auto-cancels';
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId, _channelName,
      description: 'Fires when the engine auto-cancels a drifted block to protect your evening.',
      importance: Importance.high,
      playSound: true,
    ));
    await androidImpl?.requestNotificationsPermission();
    _ready = true;
  }

  static Future<void> fireBreach(String title, String body, {int id = 1001}) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        importance: Importance.high, priority: Priority.high, playSound: true,
      ),
    );
    await _plugin.show(id, title, body, details);
  }
}
```

- [ ] **Step 3: Init in `main.dart`** — before `runApp`, ensure bindings + init the service:

```dart
// in main():
WidgetsFlutterBinding.ensureInitialized();
await NotificationService.init();
// (add `import 'data/notifications.dart';` and make main() async if not already)
```

- [ ] **Step 4: Android manifest** — ensure the POST_NOTIFICATIONS permission is present in `AndroidManifest.xml` (Android 13+):

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- [ ] **Step 5: Verify build**

Run: `flutter build apk --debug` (or `flutter run`). Expected: builds; on launch the notification permission prompt appears once. No crash.

- [ ] **Step 6: Commit**

```bash
git add daily_command_center/pubspec.yaml daily_command_center/lib/data/notifications.dart daily_command_center/lib/main.dart daily_command_center/android/app/src/main/AndroidManifest.xml
git commit -m "feat(notify): high-priority drift-breaker notification channel"
```

### Task C4: Wire breaches → notification + persist `DriftEvent`

**Files:**
- Create: `daily_command_center/lib/logic/drift_runner.dart`
- Test: `daily_command_center/test/logic/drift_runner_test.dart`

A thin side-effect coordinator: run the pure engine, then for any **new** `killed` event not already in today's drift log, fire a notification and append it. Idempotent (won't re-fire on every minute tick). The notifier is injected so the test can assert without the platform.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/state_store.dart';
import 'package:daily_command_center/logic/drift_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Block _train() => Block(
        time: 'train', cls: 'train', label: 'Train', id: 'train', isTrain: true,
        seedStart: 18.5, estStart: 20.5, durationMinutes: 60, idealMinutes: 60, minMinutes: 40, priority: 3,
        cutoffDecimal: 20.0, dropStrategy: 'kill_and_notify',
      );

  test('a new kill fires once and is persisted; re-run does not double-fire', () async {
    final day = DateTime(2026, 6, 8);
    final fired = <String>[];
    final runner = DriftRunner(notify: (t, b) async => fired.add(t));

    final r1 = await runner.run([_train()], now: 20.5, done: {}, day: day);
    expect(r1.blocks.first.status, BlockStatus.dropped);
    expect(fired.length, 1);
    final logged = (await StateStore.loadState(day)).driftLog;
    expect(logged.where((e) => e.event == 'killed' && e.itemId == 'train').length, 1);

    // Re-run same minute: no new notification, no duplicate log entry.
    await runner.run([_train()], now: 20.6, done: {}, day: day);
    expect(fired.length, 1);
    final logged2 = (await StateStore.loadState(day)).driftLog;
    expect(logged2.where((e) => e.event == 'killed' && e.itemId == 'train').length, 1);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (`DriftRunner` not defined).

- [ ] **Step 3: Create `drift_runner.dart`**

```dart
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/state_store.dart';
import '../data/notifications.dart';
import 'drift_engine.dart';

typedef Notifier = Future<void> Function(String title, String body);

class DriftRunner {
  final Notifier notify;
  DriftRunner({Notifier? notify}) : notify = notify ?? NotificationService.fireBreach;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  /// Run the engine and apply side-effects for NEW killed events.
  Future<ResolvedDay> run(List<Block> blocks, {required double now, required Set<String> done, required DateTime day}) async {
    final dateIso = _fmt.format(day);
    final result = DriftEngine.computeDay(blocks, now: now, done: done, dateIso: dateIso);

    final state = await StateStore.loadState(day);
    final alreadyKilled = state.driftLog.where((e) => e.event == 'killed').map((e) => e.itemId).toSet();

    final newKills = result.events.where((e) => e.event == 'killed' && !alreadyKilled.contains(e.itemId)).toList();
    if (newKills.isNotEmpty) {
      var updated = state;
      for (final k in newKills) {
        updated = updated.copyWith(driftLog: [...updated.driftLog, k]);
        await notify(
          '${k.label} cancelled today',
          'Drifted ${k.driftMinutes ?? '?'} min past plan. Protecting your evening.',
        );
      }
      await StateStore.saveState(updated);
    }
    return result;
  }
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/drift_runner.dart daily_command_center/test/logic/drift_runner_test.dart
git commit -m "feat(engine): DriftRunner — fire+persist new kills idempotently"
```

> **Phase C done.** Breaches (cutoff or drift) kill the item, fire one high-priority notification, and persist a `killed` `DriftEvent` — without double-firing on repeated computes.

---

## Phase D — Drift log rolling cap + Sunday weekly review

> Outcome: the drift log is bounded (won't grow forever), and a plain-language weekly summary ("training auto-cancelled twice; focus compacted 4×") is computed and shown — surfaced in the Sunday `WEEKLY REVIEW` block and on the Today screen.

### Task D1: Rolling cap on persisted drift events

**Files:**
- Modify: `daily_command_center/lib/data/state_store.dart`
- Test: append to `daily_command_center/test/data/state_store_test.dart`

Per-day `DailyState.driftLog` is naturally small, but cap it defensively (e.g. 50 entries/day) and prune `state_<date>` keys older than 21 days on save, so storage stays bounded.

- [ ] **Step 1: Add the failing test**

```dart
  test('driftLog is capped at 50 entries per day', () async {
    final day = DateTime(2026, 6, 8);
    for (int i = 0; i < 60; i++) {
      await StateStore.appendDriftEvent(day, DriftEvent(date: '2026-06-08', itemId: 'x$i', label: 'x', event: 'compacted'));
    }
    final s = await StateStore.loadState(day);
    expect(s.driftLog.length, 50);
    // Keeps the most recent ones.
    expect(s.driftLog.last.itemId, 'x59');
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (no cap).

- [ ] **Step 3: Cap in `appendDriftEvent`**

```dart
  static const int _maxPerDay = 50;

  static Future<void> appendDriftEvent(DateTime day, DriftEvent event) async {
    final state = await loadState(day);
    var log = [...state.driftLog, event];
    if (log.length > _maxPerDay) log = log.sublist(log.length - _maxPerDay);
    await saveState(state.copyWith(driftLog: log));
  }
```

(Optionally add a `pruneOld(today)` that removes `state_<date>` keys older than 21 days; call it from `AppStore.loadPlan` or app start. Keep it simple — not required for the test.)

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/state_store.dart daily_command_center/test/data/state_store_test.dart
git commit -m "feat(state): cap driftLog at 50 entries/day"
```

### Task D2: Weekly summary aggregation

**Files:**
- Create: `daily_command_center/lib/logic/weekly_review.dart`
- Test: `daily_command_center/test/logic/weekly_review_test.dart`

A pure function: given the last 7 days of `DriftEvent`s, produce a small summary object + a plain-language sentence.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/weekly_review.dart';

void main() {
  test('summarizes kills and compactions in plain language', () {
    final events = [
      const DriftEvent(date: '2026-06-02', itemId: 'train', label: 'Train', event: 'killed', driftMinutes: 100),
      const DriftEvent(date: '2026-06-05', itemId: 'train', label: 'Train', event: 'killed', driftMinutes: 110),
      const DriftEvent(date: '2026-06-03', itemId: 'focus', label: 'Deep Focus', event: 'compacted', fromDuration: 75, toDuration: 45),
      const DriftEvent(date: '2026-06-04', itemId: 'focus', label: 'Deep Focus', event: 'compacted', fromDuration: 75, toDuration: 50),
    ];
    final s = WeeklyReview.summarize(events);
    expect(s.killCount, 2);
    expect(s.compactCount, 2);
    expect(s.jettisonCount, 0);
    expect(s.sentence, contains('Train auto-cancelled 2×'));
    expect(s.sentence, contains('Deep Focus compacted 2×'));
  });

  test('empty week yields an encouraging message', () {
    final s = WeeklyReview.summarize(const []);
    expect(s.killCount, 0);
    expect(s.sentence, contains('No drift'));
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (`WeeklyReview` not defined).

- [ ] **Step 3: Create `weekly_review.dart`**

```dart
import '../data/models.dart';

class WeeklySummary {
  final int killCount;
  final int compactCount;
  final int jettisonCount;
  final String sentence;
  const WeeklySummary({required this.killCount, required this.compactCount, required this.jettisonCount, required this.sentence});
}

class WeeklyReview {
  static WeeklySummary summarize(List<DriftEvent> events) {
    final kills = events.where((e) => e.event == 'killed').toList();
    final compacts = events.where((e) => e.event == 'compacted').toList();
    final jetts = events.where((e) => e.event == 'jettisoned').toList();

    if (events.isEmpty) {
      return const WeeklySummary(killCount: 0, compactCount: 0, jettisonCount: 0,
          sentence: 'No drift this week — the plan held. Nice.');
    }

    final parts = <String>[];
    parts.addAll(_byLabel(kills, 'auto-cancelled'));
    parts.addAll(_byLabel(compacts, 'compacted'));
    parts.addAll(_byLabel(jetts, 'dropped'));

    return WeeklySummary(
      killCount: kills.length, compactCount: compacts.length, jettisonCount: jetts.length,
      sentence: 'This week — ${parts.join('; ')}.',
    );
  }

  static List<String> _byLabel(List<DriftEvent> events, String verb) {
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.label] = (counts[e.label] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.key} $verb ${e.value}×').toList();
  }
}
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/weekly_review.dart daily_command_center/test/logic/weekly_review_test.dart
git commit -m "feat(review): weekly drift summary (plain-language)"
```

### Task D3: Surface the weekly summary in the Today screen

**Files:**
- Modify: `daily_command_center/lib/screens/today_screen.dart`
- Test: `daily_command_center/test/screens/weekly_review_widget_test.dart`

Load the last-7-days drift events, summarize, and render a small card above the timeline — emphasized when today is Sunday (the `WEEKLY REVIEW` day).

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/data/state_store.dart';
import 'package:daily_command_center/screens/today_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today screen shows the weekly drift summary', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StateStore.appendDriftEvent(DateTime.now(), const DriftEvent(date: 'x', itemId: 'train', label: 'Train', event: 'killed', driftMinutes: 100));

    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    await tester.pumpWidget(MaterialApp(
      home: TodayScreen(plan: plan, todayKey: 'mon', doneToday: const {}, onToggle: (_) {}),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Train auto-cancelled'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (no summary card).

- [ ] **Step 3: Add the summary card to `today_screen.dart`.** Load events in `initState`, summarize, render between the week strip and the day header.

```dart
// add fields:
WeeklySummary? _summary;

// in initState, after the last7 load:
StateStore.recentDriftEvents(DateTime.now(), days: 7).then((events) {
  if (mounted) setState(() => _summary = WeeklyReview.summarize(events));
});

// add a widget builder:
Widget _driftCard() {
  final s = _summary;
  if (s == null) return const SizedBox.shrink();
  final isSunday = widget.todayKey == 'sun';
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.panel,
      border: Border.all(color: isSunday ? AppColors.amber : AppColors.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isSunday ? 'WEEKLY REVIEW' : 'THIS WEEK',
          style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.sky, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(s.sentence, style: const TextStyle(fontSize: 13, color: AppColors.cream, height: 1.3)),
    ]),
  );
}
// then insert `_driftCard(),` into the ListView children, after `_weekStrip()`.
// add imports: '../logic/weekly_review.dart', '../data/state_store.dart'
```

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/today_screen.dart daily_command_center/test/screens/weekly_review_widget_test.dart
git commit -m "feat(ui): surface weekly drift summary on Today (Sunday-emphasized)"
```

> **Phase D done.** Drift events are bounded, aggregated into a plain-language weekly summary, and surfaced in the app — emphasized on Sundays.

---

## Phase E — Interactive sandbox (DailyState-only editing)

> Outcome: a live timeline surface that renders dual-time + the state-morph matrix (done/active/pending × ideal/compacted/jettisoned/anchor), and lets the user reshape **today** — swipe-delete, drag-reorder across anchor walls, per-day priority override, with an Undo protocol. Every interaction mutates `DailyState` only; the Plan stays pristine (ADR-015/017).

**Live state plumbing (read before E1):** Phase E introduces a `LiveTimelineView` that owns a `DailyState` for today, recomputes via the engine on every change, and persists through `StateStore`. It's reachable from the Today screen (a new "Live" entry point). The engine call path is: `buildTimeline(day, plan, state)` (assembler, applies deletions/reorder/overrides) → `DriftEngine.computeDay(...)` (physics) → render.

### Task E1: `LiveTimelineView` — dual-time render + state-morph matrix

**Files:**
- Create: `daily_command_center/lib/screens/live_timeline_view.dart`
- Test: `daily_command_center/test/screens/live_timeline_test.dart`

Render each block per the matrix: **done** (strikethrough, dim, check), **active** (elevated card, progress bar "X of Ym budget"), **pending-ideal** (standard), **pending-compacted** (dashed border, "⚠️ Compacted — saved Xm"), **dropped** (micro-height, crossed-out, "Dropped to protect anchor"), **anchor** (full-bleed barrier, "🔒 ANCHOR" for hard).

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/screens/live_timeline_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders a hard anchor barrier and a normal block', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    await tester.pumpWidget(MaterialApp(
      home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('ANCHOR'), findsWidgets);          // work anchor barrier
    expect(find.text('Deep Focus — AI Building'), findsOneWidget); // a routine block
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (`LiveTimelineView` not defined).

- [ ] **Step 3: Create `live_timeline_view.dart`** (E1 scope: load state, compute, render the matrix; interactions added in E2–E5)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../data/state_store.dart';
import '../logic/timeline.dart';
import '../logic/drift_engine.dart';
import '../main.dart';

class LiveTimelineView extends StatefulWidget {
  final Plan plan;
  final String todayKey;
  final double? debugNow; // test seam
  const LiveTimelineView({super.key, required this.plan, required this.todayKey, this.debugNow});

  @override
  State<LiveTimelineView> createState() => _LiveTimelineViewState();
}

class _LiveTimelineViewState extends State<LiveTimelineView> {
  DailyState _state = const DailyState(date: '');
  Set<String> _done = {};

  @override
  void initState() {
    super.initState();
    StateStore.loadState(DateTime.now()).then((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  ResolvedDay _resolve() {
    final assembled = buildTimeline(widget.todayKey, widget.plan, _state);
    final now = widget.debugNow ?? nowDecimal();
    return DriftEngine.computeDay(assembled, now: now, done: _done, dateIso: _state.date);
  }

  String _fmt(double dec) {
    final h = dec.floor();
    final m = ((dec - h) * 60).round();
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final day = _resolve();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0, foregroundColor: AppColors.cream,
        title: Text('Live', style: GoogleFonts.fraunces(fontWeight: FontWeight.w800, color: AppColors.cream)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [for (final b in day.blocks) _tile(b)],
      ),
    );
  }

  Widget _tile(Block b) {
    if (b.isAnchor) return _anchorTile(b);
    if (b.isDropped) return _droppedTile(b);
    final est = _fmt(b.estStart);
    final compacted = b.isCompacted;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: compacted ? AppColors.amber : AppColors.line,
          width: compacted ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        SizedBox(width: 48, child: Text(est, style: const TextStyle(fontSize: 12, color: AppColors.dim))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.label, style: const TextStyle(fontSize: 14, color: AppColors.cream, fontWeight: FontWeight.w600)),
          Text(
            compacted
                ? '⚠️ Compacted — ${b.durationMinutes}m (saved ${b.idealMinutes - b.durationMinutes}m of ${b.idealMinutes}m)'
                : '${b.durationMinutes}m budget',
            style: TextStyle(fontSize: 11, color: compacted ? AppColors.amber : AppColors.muted),
          ),
        ])),
      ]),
    );
  }

  Widget _anchorTile(Block b) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.terra.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.terra),
        ),
        child: Row(children: [
          Text(b.hardAnchor ? '🔒 ANCHOR' : '⌛ CEILING',
              style: const TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.terra, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(child: Text('${b.label} · ${_fmt(b.estStart)}',
              style: const TextStyle(fontSize: 12, color: AppColors.cream))),
        ]),
      );

  Widget _droppedTile(Block b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Opacity(
          opacity: 0.5,
          child: Row(children: [
            const SizedBox(width: 48),
            Expanded(child: Text(b.label,
                style: const TextStyle(fontSize: 12, color: AppColors.dim, decoration: TextDecoration.lineThrough))),
            const Text('Dropped to protect anchor', style: TextStyle(fontSize: 10, color: AppColors.dim)),
          ]),
        ),
      );
}
```

Add a "Live" button to `today_screen.dart`'s app bar that pushes `LiveTimelineView(plan: widget.plan, todayKey: widget.todayKey)`.

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/lib/screens/today_screen.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): LiveTimelineView dual-time render + state-morph matrix"
```

### Task E2: Swipe-to-delete → `deletedItems` → re-inflate

**Files:**
- Modify: `daily_command_center/lib/screens/live_timeline_view.dart`
- Test: append to `live_timeline_test.dart`

Wrap flexible (non-anchor) tiles in `Dismissible`. On dismiss, append the item id to `DailyState.deletedItems`, persist, recompute (freed time re-inflates neighbors via the pure engine).

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('swiping a block deletes it and persists to DailyState', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    await tester.pumpWidget(MaterialApp(home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Break + snack'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Break + snack'), findsNothing);
    final saved = await StateStore.loadState(DateTime.now());
    expect(saved.deletedItems, contains('snack'));
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (tiles not dismissible).

- [ ] **Step 3: Make flexible tiles dismissible.** Wrap the result of `_tile(b)` (for non-anchor, non-dropped) in a `Dismissible` keyed by `b.id`:

```dart
  Widget _wrap(Block b) {
    if (b.isAnchor || b.id == null) return _tile(b);
    return Dismissible(
      key: ValueKey('live-${b.id}'),
      direction: DismissDirection.endToStart,
      background: Container(color: AppColors.terra.withValues(alpha: 0.3), alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: AppColors.cream)),
      onDismissed: (_) => _delete(b.id!),
      child: _tile(b),
    );
  }

  Future<void> _delete(String id) async {
    final next = _state.copyWith(deletedItems: [..._state.deletedItems, id]);
    setState(() => _state = next);
    await StateStore.saveState(next);
  }
```

Change the ListView children to `[for (final b in day.blocks) _wrap(b)]`.

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): swipe-to-delete writes deletedItems + re-inflates"
```

### Task E3: Drag-reorder across anchor walls → `dailySequence`

**Files:**
- Modify: `daily_command_center/lib/screens/live_timeline_view.dart`
- Test: append to `live_timeline_test.dart`

Use `ReorderableListView`. Anchors are non-draggable (frozen). On reorder, capture the new full order of ids into `DailyState.dailySequence`, persist, recompute (assembler honors `dailySequence`).

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('reordering writes dailySequence', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    await tester.pumpWidget(MaterialApp(home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();

    final state = _LiveTimelineViewState();
    // Drive the reorder callback directly (gesture-level reorder is flaky in tests):
    final el = tester.state<State<LiveTimelineView>>(find.byType(LiveTimelineView)) as dynamic;
    el.onReorderForTest(0, 3);
    await tester.pumpAndSettle();

    final saved = await StateStore.loadState(DateTime.now());
    expect(saved.dailySequence, isNotEmpty);
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (`onReorderForTest`/reorder not implemented).

- [ ] **Step 3: Switch to `ReorderableListView`** with frozen anchors and a test-visible reorder hook.

```dart
  // Build a reorderable body; anchors get a non-draggable key + ReorderableDragStartListener disabled.
  // Expose a test hook:
  @visibleForTesting
  void onReorderForTest(int oldIndex, int newIndex) => _onReorder(oldIndex, newIndex);

  void _onReorder(int oldIndex, int newIndex) {
    final day = _resolve();
    final ids = day.blocks.map((b) => b.id ?? '').toList();
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = ids.removeAt(oldIndex);
    // Disallow moving anchors (frozen): ignore if the moved block is an anchor.
    if (day.blocks[oldIndex].isAnchor) return;
    ids.insert(newIndex, moved);
    final next = _state.copyWith(dailySequence: ids.where((e) => e.isNotEmpty).toList());
    setState(() => _state = next);
    StateStore.saveState(next);
  }
```

Replace the `ListView` with:

```dart
      body: ReorderableListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        onReorder: _onReorder,
        buildDefaultDragHandles: false,
        children: [
          for (int i = 0; i < day.blocks.length; i++)
            day.blocks[i].isAnchor
                ? KeyedSubtree(key: ValueKey('live-anchor-${day.blocks[i].id}'), child: _tile(day.blocks[i]))
                : ReorderableDragStartListener(
                    key: ValueKey('live-${day.blocks[i].id}'),
                    index: i,
                    child: _wrap(day.blocks[i]),
                  ),
        ],
      ),
```

> Note: import `package:flutter/foundation.dart` for `@visibleForTesting`. Anchors keep a stable key but the `_onReorder` guard prevents moving them.

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): drag-reorder across anchors writes dailySequence"
```

### Task E4: Per-day priority override → `dailyOverrides`

**Files:**
- Modify: `daily_command_center/lib/screens/live_timeline_view.dart`
- Test: append to `live_timeline_test.dart`

A long-press on a block opens a tiny sheet to bump its priority for today. Writes `DailyState.dailyOverrides[id] = ItemOverride(priority: n)`; the assembler already applies overrides (Task A10 `_itemToBlock`). The recompute changes which item compaction sheds first.

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('overriding priority persists to dailyOverrides', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    await tester.pumpWidget(MaterialApp(home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();

    final el = tester.state<State<LiveTimelineView>>(find.byType(LiveTimelineView)) as dynamic;
    el.setPriorityForTest('focus', 1);
    await tester.pumpAndSettle();

    final saved = await StateStore.loadState(DateTime.now());
    expect(saved.dailyOverrides['focus']!.priority, 1);
  });
```

- [ ] **Step 2: Run** — Expected: FAIL.

- [ ] **Step 3: Add override write + a long-press entry point.**

```dart
  @visibleForTesting
  void setPriorityForTest(String id, int priority) => _setPriority(id, priority);

  Future<void> _setPriority(String id, int priority) async {
    final overrides = {..._state.dailyOverrides, id: ItemOverride(priority: priority)};
    final next = _state.copyWith(dailyOverrides: overrides);
    setState(() => _state = next);
    await StateStore.saveState(next);
  }

  void _openPrioritySheet(Block b) {
    showModalBottomSheet(context: context, backgroundColor: AppColors.panel, builder: (_) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Priority for ${b.label} today', style: const TextStyle(color: AppColors.cream)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [for (int p = 1; p <= 7; p++)
            ActionChip(label: Text('$p'), onPressed: () { Navigator.pop(context); _setPriority(b.id!, p); })]),
        ]),
      );
    });
  }
```

Wrap `_tile`'s content in a `GestureDetector(onLongPress: () => _openPrioritySheet(b), child: ...)` for non-anchor blocks.

- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): per-day priority override writes dailyOverrides"
```

### Task E5: Undo protocol (transaction checkpoint + snackbar)

**Files:**
- Modify: `daily_command_center/lib/screens/live_timeline_view.dart`
- Test: append to `live_timeline_test.dart`

Before any mutating action (delete/reorder/override), snapshot the current `DailyState` as a checkpoint. After the action, show a snackbar "[change] · UNDO". Tapping UNDO restores the checkpoint and persists it. Also surfaces the collision case: if a reorder/delete causes a new jettison, the snackbar says which task was dropped.

- [ ] **Step 1: Add the failing test**

```dart
  testWidgets('undo restores the prior DailyState after a delete', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw = await rootBundle.loadString('assets/seed_plan.json');
    final plan = Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    await tester.pumpWidget(MaterialApp(home: LiveTimelineView(plan: plan, todayKey: 'mon', debugNow: 7.0)));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Break + snack'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect((await StateStore.loadState(DateTime.now())).deletedItems, contains('snack'));

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect((await StateStore.loadState(DateTime.now())).deletedItems, isNot(contains('snack')));
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (no checkpoint/snackbar).

- [ ] **Step 3: Add the checkpoint + snackbar.** Introduce `_commit(DailyState next, String message)` that all mutators call:

```dart
  DailyState? _checkpoint;

  Future<void> _commit(DailyState next, String message) async {
    _checkpoint = _state;
    setState(() => _state = next);
    await StateStore.saveState(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      action: SnackBarAction(label: 'UNDO', onPressed: _undo),
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _undo() async {
    final cp = _checkpoint;
    if (cp == null) return;
    setState(() => _state = cp);
    await StateStore.saveState(cp);
    _checkpoint = null;
  }
```

Route `_delete`, `_onReorder`, `_setPriority` through `_commit(next, '<verb> · ')`. For delete, build the message with a collision check — recompute with `next` and see if any block newly has `status == dropped`:

```dart
  Future<void> _delete(String id) async {
    final next = _state.copyWith(deletedItems: [..._state.deletedItems, id]);
    await _commit(next, 'Deleted "$id"');
  }
```

(For the collision/jettison message, after computing `_resolve()` on `next`, if a previously-pending block is now `dropped`, set the message to `'"<label>" was dropped to make room'`.)

- [ ] **Step 4: Run** — Expected: PASS (and the full suite: `flutter test`).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/live_timeline_view.dart daily_command_center/test/screens/live_timeline_test.dart
git commit -m "feat(ui): Undo protocol — checkpoint + snackbar restore"
```

> **Phase E done.** The live surface renders dual-time + the morph matrix and supports swipe-delete, drag-reorder (anchors frozen), per-day override, and Undo — all writing DailyState only.

---

## Final verification + docs

### Task F1: Full suite + device smoke + status docs

- [ ] **Step 1: Run the whole suite** — `flutter test` — Expected: ALL PASS (golden, models, store, state, validator, engine, runner, review, widgets).
- [ ] **Step 2: Smoke-run** — `flutter run` — verify: home/today look identical at zero drift; Live view shows dual-time; deleting/reordering/override behave; a forced late `debugNow` shows compaction/kill.
- [ ] **Step 3: Update `docs/CONTINUE.md`** — flip the v3 section from "implementation not started" to "Phases A–E shipped"; note the new files (assembler, drift_engine, drift_runner, validator, state_store, notifications, weekly_review, live_timeline_view) and any follow-ups (widget Glance layout still blocked per CONTINUE).
- [ ] **Step 4: Commit**

```bash
git add docs/CONTINUE.md
git commit -m "docs: mark Life JSON v3 drift engine (Phases A–E) shipped"
```

---

## Self-review (plan vs. spec)

**Spec coverage** — every v3-spec + moat-doc requirement maps to a task:

| Requirement | Task(s) |
|---|---|
| Content-as-data / seed JSON | A1 |
| v3 models + round-trip | A2–A6 |
| Dual-JSON (Plan immutable + DailyState) | A4, A5, A7, A8 |
| Referential-integrity validator (AI-output checker) | A9 |
| Assembler + golden (byte-identical) | A10 |
| Caller cutover, planner generalization, delete dead code | A11 |
| Dual-time Est Start | B1, B3 |
| Transition buffer | B2 |
| Micro-compaction (shed least-important first) | B4 |
| Jettison protocol | B5 |
| Two-way elasticity | B6 |
| cutoffTime + maxDriftMinutes breakers | C1, C2 |
| OS notification channel | C3 |
| Fire + persist kills idempotently | C4 |
| Drift-log rolling cap | D1 |
| Weekly summary + Sunday review | D2, D3 |
| Live dual-time + morph matrix | E1 |
| Swipe-delete | E2 |
| Drag-reorder (frozen anchors) | E3 |
| Per-day override | E4 |
| Undo protocol + collision message | E5 |

**Type consistency** — `Plan`/`DailyState`/`Block`(extended)/`RoutineItem`/`Anchor`/`DriftEvent`/`ResolvedDay` names are used identically across tasks. `Block` engine fields (`estStart`, `seedStart`, `durationMinutes`, `idealMinutes`, `minMinutes`, `priority`, `cutoffDecimal`, `maxDriftMinutes`, `dropStrategy`, `isAnchor`, `hardAnchor`, `status`) are introduced incrementally (A6, B4, C1) and each addition is paired with its assembler write-site.

**Sequencing** — Phases A–D ship the engine + read-only surfaces and are independently valuable; Phase E (sandbox) and Phase C (notification, the existing blocker) are sequenced last/late so earlier phases ship first.

**Known follow-ups (out of scope, intentionally):** Android home-screen widget Glance layout (still the CONTINUE blocker); full structural Life-JSON editor (sub-project 2); interview/AI/onboarding (sub-projects 3–5); `state_<date>` key pruning is optional (noted in D1).

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-07-life-json-v3-drift-engine.md`. Two execution options:

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)
2. **Inline Execution** — execute tasks in this session via superpowers:executing-plans, batch execution with checkpoints.

Which approach?

