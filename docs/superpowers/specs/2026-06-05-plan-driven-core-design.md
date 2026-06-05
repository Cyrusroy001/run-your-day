# Plan-Driven App Core — Design Spec

**Date:** 2026-06-05
**Status:** Approved design (sub-project 1 of 5)
**Scope:** Make the Flutter app render entirely from a configurable Plan JSON, so it can serve any lifestyle instead of Cyrus's hardcoded one.

---

## Vision (the larger goal this serves)

Turn the personal daily-dashboard app into a **reusable, configurable app for any lifestyle**. A new user onboards by answering an intuitive, branching interview (easy taps/sliders, deep insight), and an AI turns those answers into a fully tailored plan — workouts, daily timeline, meals, and habit goals. The app renders and maintains that plan.

**Architecture decided during brainstorming:**

- **Hybrid model:** the AI *seeds* the full plan as data on day one; the app keeps the smart *interactive* behaviors (live "now" card, progress logging, training re-spacing). Content is data; interaction stays logic.
- **Fixed interview, AI only generates:** onboarding questions are a pre-authored branching tree baked into the app (cheap, offline, controllable). The AI is called once at the end to synthesize the plan from collected answers.
- **Scope of a plan:** four life domains — fitness/training, daily timeline/routine, nutrition/meals, and free-form goal/habit tracking. This is exactly what the current app does, generalized.

### Roadmap (each is its own spec → plan → build cycle)

1. **Core — make the app plan-driven** ← *this spec*. Define the Plan JSON schema, refactor logic to render from it, migrate Cyrus's hardcoded life into a seed plan.
2. **In-app Plan Editor** — a user-friendly tab (structured forms, reorderable blocks, exercise + progression editors) to correct AI mistakes and hand-edit any field. Depends only on the schema + storage.
3. **Interview engine** — a fixed branching question-tree (defined as data) + generic UI that outputs a Profile JSON.
4. **AI generation** — Profile JSON → prompt → Claude → validated Plan JSON (reuses the seed as a reference example and the integrity validator from this spec).
5. **Onboarding flow** — stitches interview → generation → "here's your plan," with edit/regenerate.

**This spec covers sub-project 1 only.** Nothing in 2–5 is meaningful until the app can render an arbitrary Plan JSON, so the core is the keystone and ships first.

---

## Problem: content and logic are fused

Today the app hardcodes Cyrus's life in Dart:

- `lib/logic/workouts.dart` — the 4 workouts as `const`.
- `lib/logic/timeline.dart` — wake 8:00, work 2:00–8:00, Indian-veg meals, "DSA"/"AI Building", and an `office/wfh/weekend` schedule enum, with a hand-tuned `buildTimeline` switch.
- `lib/logic/planner.dart` — hardcodes "exactly 4 training days, no consecutive."

To support any lifestyle, **all content moves out of Dart into a Plan JSON**, and the logic operates on that JSON generically. Behavior for Cyrus must stay identical after the refactor.

---

## The Plan JSON schema (the data contract)

```jsonc
{
  "schemaVersion": 1,
  "meta": {
    "title": "Recomp + career switch",
    "timezone": "Asia/Kolkata",
    "generatedAt": "2026-06-05T09:00:00+05:30",
    "equipment": ["2× 5kg dumbbells", "bench machine", "treadmill"]  // records the constraints the plan was built under
  },

  // ── Named day shapes. Replaces the office/wfh/weekend enum. AI authors as many as a lifestyle needs. ──
  "dayTemplates": {
    "office": {
      "label": "Office day",
      "blocks": [
        { "time": "8:00",  "kind": "meal",  "label": "Wake · water · sunlight", "desc": "Light breakfast: banana + milk/eggs." },
        { "time": "8:30",  "kind": "focus", "label": "Deep Focus — AI Building", "desc": "Sharpest hour. Phone away." },
        { "time": "10:00", "kind": "train", "label": "Train", "showWhen": "training" },           // training slot
        { "time": "10:00", "kind": "goal",  "label": "Extra Study Block", "goalId": "dsa", "showWhen": "rest" },
        { "time": "11:00", "kind": "meal",  "label": "Shower + brunch", "desc": "Big protein meal." },
        { "time": "2:00",  "kind": "work",  "label": "Work — 2:00 to 8:00", "desc": "Fixed block." },
        { "time": "8:30",  "kind": "meal",  "label": "Dinner" },
        { "time": "9:15",  "kind": "chill", "label": "Chill — protected downtime" }
        // … full day
      ]
    },
    "wfh":     { "label": "Work from home", "blocks": [ /* … */ ] },
    "weekend": { "label": "Weekend",        "blocks": [ /* … */ ] }
  },

  // ── The 7-day week: which template + whether a workout lands. User edits this with the toggles. ──
  "week": {
    "mon": { "templateId": "office",  "training": true  },
    "tue": { "templateId": "office",  "training": false },
    "wed": { "templateId": "wfh",     "training": true  },
    "thu": { "templateId": "office",  "training": false },
    "fri": { "templateId": "office",  "training": true  },
    "sat": { "templateId": "weekend", "training": true, "workoutId": "BENCH" },  // workoutId override
    "sun": { "templateId": "weekend", "training": false }
  },

  // ── Drives the quick week toggle in sub-project 1 (full any-template freedom comes with the editor). ──
  "weekEditor": {
    "toggleTemplates": ["office", "wfh"],   // tapping a day header cycles these
    "lockedDays": ["sat", "sun"]            // not toggled via the quick toggle
  },

  // ── Training rules. Replaces hardcoded "4 days / no consecutive". ──
  "training": {
    "frequencyPerWeek": 4,
    "avoidConsecutive": true,
    "rotation": ["A", "B", "BENCH", "CARDIO"]   // cycles across training days unless a day pins workoutId
  },

  // ── Workouts. Replaces workouts.dart. ──
  "workouts": {
    "A": {
      "title": "Full Body A",
      "why": "Hits every major muscle once…",
      "exercises": [
        {
          "name": "Goblet squat",
          "sets": "3–4",
          "repRange": [15, 20],
          "cue": "Lower slow — 3s down",
          "tempo": "3s eccentric",
          "loggable": true,
          "progression": {
            "method": "double",        // fill the rep range on all sets, then escalate
            "addLoad": false,          // false for fixed dumbbells; true ONLY for the bench machine
            "escalation": [            // ordered ladder to get harder WITHOUT more weight (negatives first)
              "slow the negative to 4–5s",
              "add 1.5-rep partials",
              "harder variation: pause at bottom",
              "harder variation: single-leg / deficit"
            ]
          }
        }
      ]
    }
    // B, BENCH (addLoad:true), CARDIO …
  },

  // ── Nutrition + free-form goals/habits. ──
  "nutrition": { "proteinTargetG": 135, "notes": ["Soya capped ~50g dry/day, rotate sources"] },
  "goals": [ { "id": "dsa", "label": "DSA Practice", "cadence": "daily", "loggable": false } ]
}
```

### Key schema decisions

1. **`showWhen`** on a block (`"always"` default / `"training"` / `"rest"`) lets one template serve both a training and a rest day — the train block shows only when training; the rest-day alternative (e.g. "Extra Study Block") shows only when resting. Captures the current conditional timeline without duplicate templates.

2. **Which workout lands on a training day** defaults to `training.rotation` cycling across the week's training days *by position*; a `week[day].workoutId` overrides it. This preserves Cyrus's exact mapping (Sat = BENCH) while giving AI-generated plans a simple default. **This is the one semantic shift from today** (today it's keyed by schedule type); the seed pins `workoutId` where needed so nothing changes for Cyrus.

3. **`week` lives inside the plan** — toggle edits mutate this section and re-save the whole plan. No separate storage key.

4. **Progression is data, and respects fixed weights.** Each exercise carries a `repRange`, `tempo`, and a `progression` object with `addLoad` (true only for the loadable bench machine) and an ordered `escalation` ladder (slower negatives → harder variations). This encodes the "double progression" rule and the 5 kg-dumbbell constraint explicitly, so neither the app nor a future AI tells the user to "add weight" they don't have.

5. **`weekEditor`** names which templates the quick toggle cycles and which days it locks, so the existing toggle works generically (not hardcoded to the literal strings `office`/`wfh`/weekend).

---

## Logic generalization (change bodies, keep signatures)

The UI (`now_card.dart`, `week_planner.dart`) keeps calling `buildTimeline`, `PlannerLogic.toggleTraining`, etc. Those functions stop hardcoding and start reading the `Plan`.

### `models.dart` grows the plan types
New `Plan`, `DayTemplate`, `BlockDef`, `WeekEntry`, `TrainingRules`, `WeekEditorConfig`, plus `WorkoutDef`/`ExerciseDef` and a `Progression` type (moved here from `workouts.dart`) — each with `fromJson`/`toJson`. The existing `Block` stays as the *resolved runtime* block the UI renders; `BlockDef` is the *stored template* block. The assembler turns `BlockDef`s into `Block`s.

### `timeline.dart` becomes a data-driven assembler
The hardcoded `if (schedule == wfh) … if (weekend) …` switch is **deleted** and replaced with:

```
buildTimeline(dayKey, plan):
    entry    = plan.week[dayKey]                 // { templateId, training, workoutId? }
    template = plan.dayTemplates[entry.templateId]
    trainingDayIndex = index of dayKey among the week's training days (in mon..sun order)
    blocks = []
    for blockDef in template.blocks:
        if blockDef.showWhen == "training" and not entry.training:  continue
        if blockDef.showWhen == "rest"     and entry.training:      continue
        if blockDef.kind == "train":
            workoutId = entry.workoutId ?? plan.training.rotation[trainingDayIndex % rotation.length]
            emit Block(time: blockDef.time, isTrain: true, workout: workoutId,
                       label: "Train — " + plan.workouts[workoutId].title, ...)
        else:
            emit Block(from blockDef)
    return blocks
```

`buildTimes()` and `nowDecimal()` are **unchanged** — pure, lifestyle-agnostic, and their PM-disambiguation logic (walk forward, never backward) stays exactly as-is.

### `planner.dart` parameterized
Driven by `plan.training.frequencyPerWeek` and `avoidConsecutive`:
- The brute-force `C(7,4)` spacing search generalizes to `C(7,N)`.
- `avoidConsecutive: false` → spacing constraint skipped (lifestyles that want back-to-back days).
- `toggleTraining` caps at `N` and re-spaces, same as today with N instead of 4.

### `workouts.dart` removed
The `const workouts` map is deleted (becomes seed data). `WorkoutDef`/`ExerciseDef` classes move to `models.dart`. Code that did `workouts[id]` now reads `plan.workouts[id]`.

---

## Migration + storage

### The seed plan
All current hardcoded content — the three `buildTimeline` branches, all four workouts (with progression ladders), the week defaults, training rules, nutrition, the DSA goal — is hand-translated **once** into a bundled asset, `assets/seed_plan.json`. When complete, the app must look pixel-identical to today. The seed doubles as the reference example the AI imitates in sub-project 4. `pubspec.yaml` registers the asset.

### Storage changes (`store.dart`)

| Today | After |
|---|---|
| `weekPlan` key holds a `WeekPlan` | `activePlan` key holds the whole `Plan` JSON |
| `loadPlan()` → `WeekPlan`, falls back to `PlannerLogic.defaultWeek()` | `loadPlan()` → `Plan`; if `activePlan` absent, load `seed_plan.json`, save it, return it |
| `savePlan(WeekPlan)` | `savePlan(Plan)` — saves the full plan |
| Week toggle builds a new `WeekPlan` | Toggle edits mutate `plan.week` and re-save the plan |
| `writeWidgetData(WeekPlan, day)` | `writeWidgetData(Plan, day)` — reads templates/workouts from the plan |

### Preserved for Cyrus
- **Workout history survives:** logs keyed `log_A`, `log_B`, `log_BENCH`, `log_CARDIO`; those ids remain the workout ids in the seed, so existing logs still match.
- `PlannerLogic.defaultWeek()` and the `workouts` const are deleted; the seed asset is the source of defaults.

### Migration call
The existing saved `weekPlan` (Cyrus's current office/WFH + training toggles) is **not** auto-converted. On first launch of the new version, the app seeds fresh from `seed_plan.json`, which already encodes his real week — so he lands in the same place. A converter for a one-person migration is throwaway code and is intentionally skipped.

---

## Testing strategy

This is a **behavior-preserving refactor**; tests prove the data-driven app matches the hardcoded one.

1. **Golden timeline test (write first).** Before touching logic, snapshot the current `buildTimeline` output for all 7 days × {training, rest} (each block's time/kind/label/desc/isTrain/workout) into a golden fixture. After the refactor (timelines from `seed_plan.json` via the assembler), assert byte-identical output. This single test de-risks the migration.

2. **Seed referential-integrity test.** Every `week[].templateId` exists in `dayTemplates`; every `rotation` id and `workoutId` exists in `workouts`; every `goalId` referenced exists in `goals`. Catches hand-written typos — **and this validator is reused as the AI-output checker in sub-project 4.**

3. **Schema roundtrip + fallback.** `Plan.fromJson(toJson(plan))` round-trips losslessly for the seed; malformed/partial plans fall back gracefully (mirrors today's try-catch in `loadPlan`).

4. **Assembler unit tests.** `showWhen` filtering (training-only/rest-only blocks appear/hide); train slot fills the rotation workout for the day's position; per-day `workoutId` overrides rotation.

5. **Planner generalization.** Re-parameterized invariants: `frequencyPerWeek = N` yields exactly N days; `avoidConsecutive: true` → no consecutive; `false` → consecutive allowed; `toggleTraining` caps at N and re-spaces.

6. **Untouched on purpose.** `buildTimes` (PM disambiguation, monotonicity) and its tests stay exactly as-is — leaving them green is evidence the core time logic wasn't disturbed.

Updated test files: `models_test.dart` (new types), `workouts_test.dart` (asserts against the seed), `timeline_test.dart` (adds golden), `planner_test.dart` (parameterized).

---

## Non-goals (explicitly out of scope for this sub-project)

- The in-app editor UI (sub-project 2) — this spec only makes the data editable *in principle* (schema + storage), not via a friendly UI.
- The interview, AI generation, and onboarding flow (sub-projects 3–5).
- Any change to the Android widget (still the separate active blocker in `CONTINUE.md`).
- Converting the stale `daily-command-center.html`.
- Generalizing the quick week toggle beyond today's behavior (office↔wfh flip, weekend locked) — full per-day template assignment lands with the editor.

## Success criteria

- The app, seeded from `seed_plan.json`, looks and behaves **identically** to today for Cyrus (golden test passes).
- All content (templates, blocks, workouts, progression, training rules, nutrition, goals, week shape) lives in the Plan JSON, not in Dart.
- The planner works for any `frequencyPerWeek` and `avoidConsecutive` value.
- `workouts.dart` and `PlannerLogic.defaultWeek()` are gone; logic reads from the plan.
- A different week shape (e.g. 5 office + 2 off, or custom templates) renders correctly by editing only the JSON.
