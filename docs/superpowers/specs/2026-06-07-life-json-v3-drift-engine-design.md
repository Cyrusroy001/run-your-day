# Life JSON v3 — Drift-Aware Execution Engine & Product Vision

**Date:** 2026-06-07
**Status:** Approved design
**Applies to:** `daily_command_center/` (Flutter app + Android widget)
**Supersedes:** [`2026-06-05-plan-driven-core-design.md`](2026-06-05-plan-driven-core-design.md) (schema v1) and folds in [`../plans/schema-improvement-gemini.md`](../plans/schema-improvement-gemini.md) (the v3 sketch). Both were never implemented; this is the design that ships.

---

## 1. Product vision (the moat)

Reminders 2 becomes a **reusable, configurable life-execution app for any lifestyle** — not Cyrus's hardcoded dashboard. The end-to-end flow:

1. **Install → interview.** A new user installs the app and answers a branching **interview tree**: easy taps/sliders, deep insight. We first ask *which areas of life they want to improve* (fitness, focus/career, nutrition, sleep, habits) and then drill in with targeted questions per chosen area.
2. **Interview → Life JSON.** The answers populate a rich **Life JSON** (this schema, v3) — the structured contract describing the user's constraints, energy patterns, fixed real-world boundaries, and goals.
3. **Life JSON → AI-synthesized routine.** An AI agent reads the Life JSON once and synthesizes a fully personalized daily routine — workout, meals, focus blocks, habits — as a complete v3 plan, applicable only to the domains the user opted into.
4. **Routine → execution.** The Flutter app + Android widget act as a **local, lifestyle-agnostic execution engine**: they render the plan, compute drift-aware times, compact under pressure, and enforce guardrails — knowing nothing about the user's specific career or goals.
5. **Reconfigure.** The user can edit the **master Life JSON** to correct or tune anything the AI produced — from an in-app **control panel** and the **home-screen widget**.

> **The moat is the schema.** The Life JSON must be *so* expressive and well-structured that the AI's output is unusually good and accurate, and so that a generic engine can execute *any* user's plan without per-user code. Everything in this spec exists to make that JSON rich, unambiguous, and executable.

### Where this spec sits in the roadmap

| # | Sub-project | Status |
|---|---|---|
| **1** | **Core — plan-driven app + v3 drift engine** | ← *this spec* (merges old sub-project 1 with the drift engine) |
| 2 | In-app control panel / Life-JSON editor | later |
| 3 | Interview tree (data-defined branching questions → answers) | later |
| 4 | AI generation (answers → prompt → Claude → validated Life JSON) | later |
| 5 | Onboarding flow (stitches 3→4→"here's your plan", edit/regenerate) | later |

**This spec covers sub-project 1 only.** Onboarding, the interview, AI generation, and the friendly editor UI are explicitly out of scope here. The app ships running on **Cyrus's hand-authored v3 seed**; new lifestyles get their own v3 JSON later via the interview + AI path. Nothing downstream is meaningful until a generic engine can execute an arbitrary v3 plan, so the core is the keystone and ships first.

---

## 2. Core concept: "Content is data, interaction is logic"

All of Cyrus's life — templates, blocks, workouts, progression, week shape, nutrition, goals — moves out of Dart into a **Life JSON** (`assets/seed_plan.json`). The Dart logic operates on that JSON generically. On top of the v1 "render from data" idea, v3 adds a **drift-aware execution engine** so the day adapts to real-world disruption instead of silently going stale.

**Three engine rules** (detailed in §4):

- **Rule 1 — Dual-time:** every item shows a computed **Est Start** *and* a fixed **Duration budget**.
- **Rule 2 — Micro-compaction:** when the day drifts, flexible items shrink toward their `minDuration` to protect fixed anchors.
- **Rule 3 — Circuit-breaker:** an item that drifts past its ceiling is auto-cancelled, the next item is promoted, a high-priority notification fires, and the event is written to a **drift log** the user reviews on Sundays.

---

## 3. The Life JSON v3 schema (the data contract)

v3 keeps every concrete field from v1 (workouts with progression ladders, nutrition, goals, week, weekEditor, training rules) and restructures a day template into **`anchors` + `routineStack`**, adding per-item drift metadata.

```jsonc
{
  "schemaVersion": 3,
  "meta": {
    "title": "Recomp + career switch",
    "timezone": "Asia/Kolkata",
    "lifestyleArchetype": "cyrus_recomp",     // free-form profile tag (AI sets this per user)
    "generatedAt": "2026-06-07T09:00:00+05:30",
    "improvementAreas": ["fitness", "focus", "nutrition", "sleep"],  // which life domains this plan covers
    "equipment": ["2× 5kg dumbbells", "bench machine", "treadmill"]
  },

  // ── Named day shapes. Replaces the office/wfh/weekend enum. AI authors as many as a lifestyle needs. ──
  "dayTemplates": {
    "office": {
      "label": "Office day",
      "colorKey": "terra",

      // Fixed real-world boundaries. The engine NEVER drifts these; compaction protects them.
      "anchors": [
        { "id": "work",  "kind": "work",  "label": "Work — 2:00 to 8:00", "start": "14:00", "end": "20:00", "hard": true },
        { "id": "sleep", "kind": "chill", "label": "Sleep target",        "start": "23:15",                  "hard": false }
      ],

      // Flexible items. Each carries a seed `start` (hybrid time model) AND a drift budget.
      // Est Start = seed start until the user runs late, then it cascades forward.
      "routineStack": [
        { "id": "wake",    "kind": "meal",  "label": "Wake · water · sunlight", "desc": "Light breakfast: banana + milk/eggs.",
          "start": "8:00",  "idealDuration": 30, "minDuration": 20, "priority": 1 },
        { "id": "focus",   "kind": "focus", "label": "Deep Focus — AI Building", "desc": "Sharpest hour. Phone in another room.",
          "start": "8:30",  "idealDuration": 75, "minDuration": 45, "priority": 2, "maxDriftMinutes": 60, "dropStrategy": "scale_to_min" },
        { "id": "snack",   "kind": "meal",  "label": "Break + snack", "desc": "Coffee, few nuts. Reset.",
          "start": "9:45",  "idealDuration": 15, "minDuration": 10, "priority": 6 },
        { "id": "train",   "kind": "train", "label": "Train", "desc": "Tap to open workout.",
          "start": "10:00", "idealDuration": 60, "minDuration": 40, "priority": 3,
          "condition": "isTrainingDay", "maxDriftMinutes": 90, "dropStrategy": "kill_and_notify" },
        { "id": "study",   "kind": "goal",  "label": "Extra Study Block", "desc": "No training → bigger AI push or extra DSA.",
          "goalId": "dsa", "start": "10:00", "idealDuration": 60, "minDuration": 30, "priority": 3, "condition": "isRestDay" },
        { "id": "brunch",  "kind": "meal",  "label": "Shower + brunch", "desc": "Big protein meal — office lunch at 3.",
          "start": "11:00", "idealDuration": 45, "minDuration": 30, "priority": 4 },
        { "id": "dsa",     "kind": "goal",  "label": "DSA Practice (45 min)", "desc": "1–2 problems. Keep coding sharp.",
          "goalId": "dsa", "start": "11:30", "idealDuration": 45, "minDuration": 25, "priority": 5, "maxDriftMinutes": 45, "dropStrategy": "scale_to_min" },
        { "id": "commute", "kind": "work",  "label": "Walk to office (10 min)", "start": "13:50", "idealDuration": 10, "minDuration": 10, "priority": 1 }
        // evening items (dinner, chill, wind-down) flow after the work anchor toward the sleep ceiling
      ]
    },

    "wfh":     { "label": "Work from home", "colorKey": "sky",   "anchors": [ /* … */ ], "routineStack": [ /* … */ ] },
    "weekend": { "label": "Weekend",        "colorKey": "amber", "anchors": [ /* … */ ], "routineStack": [ /* … */ ] }
  },

  // ── The 7-day week: which template + whether a workout lands. User edits this from the planner. ──
  "week": {
    "mon": { "templateId": "office",  "training": true  },
    "tue": { "templateId": "office",  "training": false },
    "wed": { "templateId": "wfh",     "training": true  },
    "thu": { "templateId": "office",  "training": false },
    "fri": { "templateId": "office",  "training": true  },
    "sat": { "templateId": "weekend", "training": true, "workoutId": "BENCH" },
    "sun": { "templateId": "weekend", "training": false }
  },

  // ── Drives the quick week toggle (full any-template freedom comes with the editor, sub-project 2). ──
  "weekEditor": { "toggleTemplates": ["office", "wfh"], "lockedDays": ["sat", "sun"] },

  // ── Training rules. Replaces hardcoded "4 days / no consecutive". ──
  "training": { "frequencyPerWeek": 4, "avoidConsecutive": true, "rotation": ["A", "B", "BENCH", "CARDIO"] },

  // ── Workouts. Replaces workouts.dart. Progression is data and respects fixed weights. ──
  "workouts": {
    "A": {
      "title": "Full Body A",
      "why": "Hits every major muscle once…",
      "exercises": [
        {
          "name": "Goblet squat", "sets": "3–4", "repRange": [15, 20], "cue": "Lower slow — 3s down", "tempo": "3s eccentric", "loggable": true,
          "progression": {
            "method": "double", "addLoad": false,
            "escalation": ["slow the negative to 4–5s", "add 1.5-rep partials", "harder variation: pause at bottom", "harder variation: single-leg / deficit"]
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

### Per-item drift fields (new in v3)

| Field | Meaning |
|---|---|
| `start` | **Seed/preferred** clock time. Day-1 Est Start. Cascades forward once the user runs late. |
| `idealDuration` / `minDuration` | The execution **budget** (minutes). Compaction shrinks `ideal → min`, never below `min`. |
| `priority` | Lower = more important. Compaction sheds time from **high-priority-number (less important)** items first. |
| `maxDriftMinutes` | Optional drift ceiling. If Est Start slips this far past `start`, the circuit-breaker considers the item breached. Omit ⇒ no hard ceiling. |
| `dropStrategy` | `scale_to_min` (compact toward `minDuration`) or `kill_and_notify` (cancel + notify on breach). |
| `condition` | Small expression replacing v1's `showWhen`: `always` (default), `isTrainingDay`, `isRestDay`. Future-extensible (e.g. `isWeekend`). |
| `kind` | Render/track category: `meal`, `focus`, `train`, `goal`, `work`, `chill` (maps to today's `Block.cls`). |

### Anchors vs routineStack

- **Anchors** — fixed clock boundaries (`start`, optional `end`). `hard: true` = an immovable wall the engine protects at all costs (Cyrus: **Work 14:00–20:00**). `hard: false` = a **soft ceiling** the engine compacts toward but may overrun if it must (Cyrus: **Sleep ~23:15**). Anchors never drift and are never auto-cancelled.
- **routineStack** — everything flexible. Items cascade between/around anchors with computed Est Start + duration budget.

### Key schema decisions (carried from v1, still true)

1. **`condition`** lets one template serve a training and a rest day (train block shows only when training; the rest-day alternative shows only when resting). No duplicate templates.
2. **Which workout lands on a training day** defaults to `training.rotation` cycling across the week's training days *by position*; `week[day].workoutId` overrides (Cyrus: Sat = BENCH). One semantic shift from the original HTML (keyed by schedule type), but the seed pins `workoutId` where needed so nothing changes for Cyrus.
3. **`week` lives inside the plan** — toggle edits mutate this section and re-save the whole plan. No separate storage key.
4. **Progression is data and respects fixed weights** — `addLoad` is true only for the loadable bench machine; the `escalation` ladder encodes "get harder without more weight" (slower negatives → harder variations). Neither the app nor the AI ever tells the user to add weight they don't have.
5. **`weekEditor`** names which templates the quick toggle cycles and which days it locks — the toggle works generically, not hardcoded to literal strings.

---

## 4. The execution engine

The UI keeps calling `buildTimeline`, `PlannerLogic.toggleTraining`, etc.; their bodies stop hardcoding and start reading the `Plan`. A new `DriftEngine` computes the live, drift-aware schedule.

### Rule 1 — Dual-time render

Every rendered item exposes two metrics:

- **Est Start** — computed at runtime. Day-1 (zero drift) it equals the seed `start`. As the user checks items done, the engine cascades: the next item's Est Start = max(its seed `start`, actual completion time of the previous item). This is the "walk forward, never backward" idea extended to live progress; `buildTimes` PM-disambiguation (§ unchanged below) still resolves clock strings to decimals.
- **Duration budget** — the item's current allocation (`idealDuration`, or less after compaction). Shifts the user from "fixed clock slots" to "protecting an action budget."

### Rule 2 — Micro-compaction

When the cascading stack would push a **hard anchor** (Work 2 PM) or overrun the **soft ceiling** (Sleep 11:15), the engine reclaims time:

1. Sum the budget of routine items between *now* and the next protected boundary.
2. If that overflows the boundary, shrink `scale_to_min` items from `idealDuration` toward `minDuration`, **shedding from the least important first** (highest `priority` number), until the stack fits or all such items are at `minDuration`.
3. `kind: work`/anchor items and items without `scale_to_min` are not shrunk.

Compaction is recomputed whenever the user marks an item done/late or the clock advances materially. Each compaction event is recorded in the drift log (§5).

### Rule 3 — Hard drift circuit-breaker

For an item with `maxDriftMinutes` and `dropStrategy: kill_and_notify`: if its Est Start slips more than `maxDriftMinutes` past its seed `start`, the engine **cancels it for the day**, promotes the next valid item, and:

- **Fires a high-priority Android notification** on a dedicated channel with a distinct alert sound — "Training cancelled today (drifted >90 min). Protecting your evening." (This intentionally pulls the Android notification channel into scope; see §8.)
- **Writes a drift-log entry** (§5).

Rationale: stops routines slipping deep into the night, which wrecks sleep hygiene and breaks the next day. The user chose **full circuit-breaker including the OS notification**, plus the persisted log.

### Unchanged on purpose

`buildTimes()` (PM disambiguation, monotonicity) and `nowDecimal()` stay exactly as-is — pure, lifestyle-agnostic, proven. Leaving their tests green is evidence the core time logic wasn't disturbed.

### Planner generalization (from v1)

`planner.dart` is driven by `plan.training.frequencyPerWeek` and `avoidConsecutive`: the brute-force `C(7,4)` spacing search generalizes to `C(7,N)`; `avoidConsecutive:false` skips the spacing constraint; `toggleTraining` caps at `N` and re-spaces.

---

## 5. Drift log + Sunday review

A persisted, rolling **drift log** records every compaction and circuit-breaker event so the user reviews how the week actually went — surfaced in Cyrus's existing **Sunday 5 PM "Weekly Review"** block.

### Entry shape

```jsonc
{ "date": "2026-06-09", "itemId": "train", "label": "Train", "event": "killed",   // "compacted" | "killed"
  "driftMinutes": 105, "fromDuration": 60, "toDuration": null, "note": "drifted past 90-min ceiling" }
```

- Appended on every compaction (`event: "compacted"`, with `fromDuration`/`toDuration`) and circuit-breaker kill (`event: "killed"`, with `driftMinutes`).
- Stored under SharedPreferences key `driftLog` as a JSON list, **capped/rolling** (e.g. last 14 days or N entries) so it never grows unbounded.
- Surfaced in the **Today/Weekly-review surface**: "This week — training auto-cancelled twice (drift >90 min); focus compacted 4×." Gives the user the signal to adjust seed times or budgets in the editor (sub-project 2).

---

## 6. Models (Dart) — change bodies, keep UI-facing signatures

`models.dart` grows the v3 plan types, each with `fromJson`/`toJson`:

- `Plan`, `DayTemplate`, `Anchor`, `RoutineItem`, `WeekEntry`, `TrainingRules`, `WeekEditorConfig`, `WorkoutDef`/`ExerciseDef`, `Progression`, and `DriftEvent`.
- The existing **`Block`** stays as the *resolved runtime* block the UI renders, gaining `estStart` (computed decimal), `durationMinutes`, and a `status` (`pending`/`done`/`dropped`). `RoutineItem`/`Anchor` are the *stored* shapes; the assembler turns them into `Block`s.
- `Block.isTrackable` and `Block.signature` (from the Reminders 2 redesign) are preserved; `kind: work`/`chill` remain passive/untracked, and dropped items are excluded from the adherence denominator.

### `timeline.dart` becomes a data-driven assembler

The hardcoded `if (schedule == wfh) … if (weekend) …` switch is **deleted** and replaced with an assembler that reads `plan.week[dayKey]` → `plan.dayTemplates[templateId]`, filters by `condition`, fills the train slot from `workoutId ?? rotation[trainingDayIndex % len]`, merges anchors + routineStack, and hands the result to the `DriftEngine` for Est Start / compaction / breaker evaluation.

### `workouts.dart` removed

The `const workouts` map and `PlannerLogic.defaultWeek()` are deleted (become seed data). `WorkoutDef`/`ExerciseDef`/`Progression` move to `models.dart`. Code that did `workouts[id]` reads `plan.workouts[id]`.

---

## 7. Migration + storage

### The seed plan

All current hardcoded content — the three `buildTimeline` branches, all four workouts (with progression ladders), the week defaults, training rules, nutrition, the DSA goal — is hand-translated **once** into a bundled asset, `assets/seed_plan.json`, in v3 shape. With **zero drift**, the rendered timeline must be **byte-identical to today** (golden test). The seed doubles as the reference example the AI imitates in sub-project 4. `pubspec.yaml` registers the asset.

### Storage changes (`store.dart`)

| Today | After |
|---|---|
| `weekPlan` key holds a `WeekPlan` | `activePlan` key holds the whole v3 `Plan` JSON |
| `loadPlan()` → `WeekPlan`, falls back to `defaultWeek()` | `loadPlan()` → `Plan`; if `activePlan` absent, load `seed_plan.json`, save it, return it |
| `savePlan(WeekPlan)` | `savePlan(Plan)` — saves the full plan |
| Week toggle builds a new `WeekPlan` | Toggle edits mutate `plan.week` and re-save the plan |
| `writeWidgetData(WeekPlan, day)` | `writeWidgetData(Plan, day)` — reads templates/workouts from the plan; writes the **current Est Start–aware** action |
| — | **new** `driftLog` key (rolling list of `DriftEvent`) |

Adherence keys (`done_<date>`, `adherence_<date>`) from the Reminders 2 redesign are unchanged.

### Preserved for Cyrus

- **Workout history survives:** logs keyed `log_A`, `log_B`, `log_BENCH`, `log_CARDIO`; those ids remain the workout ids in the seed, so existing logs still match.
- The saved `weekPlan` is **not** auto-converted. On first launch the app seeds fresh from `seed_plan.json`, which already encodes his real week — he lands in the same place. A one-person migration converter is throwaway code and is intentionally skipped.

---

## 8. Scope & suggested implementation sequencing

Because the v1 refactor was never built, the implementation is sizable. The writing-plans step should sequence it so each phase is shippable and de-risks the next:

- **Phase A — Plan-driven foundation.** v3 models + `fromJson`/`toJson`, the assembler, `assets/seed_plan.json`, storage swap to `activePlan`. **Golden test**: zero-drift timeline byte-identical to today. Referential-integrity validator (reused as the AI-output checker in sub-project 4). *This de-risks everything.*
- **Phase B — Dual-time + micro-compaction.** `DriftEngine` Est-Start cascade and compaction against hard/soft anchors. Today screen + live card render Est Start + duration budget.
- **Phase C — Circuit-breaker + Android notification.** Breach detection, auto-cancel/promote, dedicated high-priority notification channel + alert sound. (Coordinate with the existing widget/notification blocker in `CONTINUE.md`.)
- **Phase D — Drift log + Sunday review.** Persist `DriftEvent`s, rolling cap, surface the weekly summary in the Sunday review block.

---

## 9. Testing strategy

This is a behavior-preserving refactor *plus* new engine behavior — tests must prove both.

1. **Golden timeline test (write first).** Snapshot the current `buildTimeline` output for all 7 days × {training, rest}. After the refactor (from `seed_plan.json`, **zero drift**), assert byte-identical output. Single test that de-risks the migration.
2. **Seed referential-integrity.** Every `week[].templateId` ∈ `dayTemplates`; every `rotation`/`workoutId` ∈ `workouts`; every `goalId` ∈ `goals`; every anchor/item `id` unique within a template. Reused as the AI-output checker (sub-project 4).
3. **Schema roundtrip + fallback.** `Plan.fromJson(toJson(plan))` round-trips losslessly; malformed/partial plans fall back gracefully (mirrors today's try-catch in `loadPlan`).
4. **Assembler unit tests.** `condition` filtering (training-only/rest-only items appear/hide); train slot fills the rotation workout for the day's position; per-day `workoutId` overrides rotation.
5. **DriftEngine unit tests.** Est-Start cascade (late completion pushes downstream items); compaction sheds least-important first and never below `minDuration`; hard anchor protected; soft ceiling overrun only as last resort; circuit-breaker fires exactly at `> maxDriftMinutes`, cancels the item, promotes the next, and emits one `DriftEvent`.
6. **Drift log.** Compaction and kill events are appended with correct fields; the log respects its rolling cap; the Sunday summary aggregates correctly.
7. **Planner generalization.** `frequencyPerWeek = N` yields exactly N days; `avoidConsecutive:true` → none consecutive; `false` → allowed; `toggleTraining` caps at N and re-spaces.
8. **Untouched on purpose.** `buildTimes` (PM disambiguation, monotonicity) and its tests stay exactly as-is — green = the core time logic wasn't disturbed.

---

## 10. Non-goals (out of scope for this sub-project)

- The interview tree, AI generation, onboarding flow, and the friendly Life-JSON editor / control panel UI (sub-projects 2–5). This spec makes the data editable *in principle* (schema + storage), not via a friendly UI.
- Generalizing the quick week toggle beyond today's behavior (office↔wfh flip, weekend locked) — full per-day template assignment lands with the editor.
- Converting the stale `daily-command-center.html` (edited by an external agent; ignore it).
- Multi-user / cloud sync — still local `shared_preferences`.

---

## 11. Success criteria

- The app, seeded from `seed_plan.json` with **zero drift**, looks and behaves **identically to today** for Cyrus (golden test passes).
- All content (templates, anchors, routine items, workouts, progression, training rules, nutrition, goals, week shape) lives in the Life JSON, not in Dart. `workouts.dart` and `defaultWeek()` are gone.
- The engine computes Est Start, compacts flexible items to protect the Work anchor and Sleep ceiling, and auto-cancels + notifies on a `maxDriftMinutes` breach.
- Every compaction/kill is logged and surfaced in the Sunday review.
- A different lifestyle renders and executes correctly by supplying only a new v3 JSON — no Dart changes.

---

## 12. Open questions

None outstanding. The seed-art / notification-channel specifics are implementation details resolved in Phase C.
