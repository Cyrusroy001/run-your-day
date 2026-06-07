Project Context: Reminders 2 — Drift-Aware Architecture & Roadmap
Date: June 7, 2026
Target Audience: AI Developer Agents, Engineering Team
Current Stage: Finalizing Core Architecture (Sub-project 1)

1. Core Philosophy: The Moat
Reminders 2 is not a standard calendar or static to-do list. It is a local, lifestyle-agnostic execution engine.

Content is Data, Interaction is Logic: All user routines, goals, and constraints are defined in declarative JSON. The app engine computes the day dynamically.

Biologically Realistic Scheduling: The engine expects human behavior (delays, context-switching) and elegantly degrades the schedule rather than breaking or cascading endlessly.

2. The Dual-JSON Architecture (Plan vs. State)
To ensure the user's master blueprint remains pristine while allowing daily flexibility, the system relies on a Strict Separation of Concerns via two distinct JSON structures.

A. The Blueprint (Life JSON / Plan JSON)
Purpose: The ideal, long-term contract. It contains the user's templates, anchor times, default task budgets, workout progressions, and default priorities.

Mutation: Edited rarely via the "Life JSON Editor" or updated by the AI after an interview.

Example Data: "My ideal morning routine has a focus block of 60 mins, minimum 45 mins, priority 2."

B. The Execution Log (State JSON / Data JSON)
Purpose: The ephemeral daily reality. It stores today's actual start times, completion statuses, daily priority overrides, and the historical drift log.

Mutation: Updated constantly by the user tapping in the UI (e.g., checking off tasks, changing today's priority for a specific task). Can be wiped completely without destroying the user's baseline routine.

Example Data: ```jsonc
{
"date": "2026-06-07",
"dailyOverrides": {
"focus": { "priority": 1 } // User bumped this up from default 2 just for today
},
"driftLog": [ ... ],
"adherence": [ ... ]
}


**Runtime Merge Logic:** When the Flutter app renders `buildTimeline()`, it deeply merges the two. If `StateJSON.dailyOverrides[taskId]` exists, it patches the `LifeJSON` default for that specific execution cycle.

---

## 3. The Drift Engine: Operations & Physics
The core of the app is the `DriftEngine`, which applies a specific set of rules to handle delays and schedule compression.

* **Rule 1 — Dual-Time Model:** Every flexible block has an **Est Start** (computed dynamically) and a **Duration Budget** (shrinks under pressure).
* **Rule 2 — Systemic Buffers:** Back-to-back human scheduling is impossible. The engine injects a silent `transitionBufferMinutes` (e.g., 5 mins) between tasks so minor delays don't instantly trigger alerts.
* **Rule 3 — Micro-Compaction:** When delays push flexible items against a **Hard Anchor** (e.g., Work starts at 14:00), the engine shrinks the flexible items from their `idealDuration` down to their `minDuration`.
* **Rule 4 — Shedding by Priority:** Compaction targets the highest `priority` number (least important) tasks first. (Note: users can adjust these priorities on the fly via the UI, stored in the `State JSON`).
* **Rule 5 — Two-Way Elasticity:** If the user finishes a compacted task *early*, the engine actively recalculates and pushes subsequent tasks back up from their `minDuration` toward their `idealDuration`.
* **Rule 6 — The Jettison Protocol:** If all flexible items hit their `minDuration` and the stack *still* breaches a hard anchor, the engine completely drops/cancels the least important block to protect the anchor. 
* **Rule 7 — Absolute Cutoffs (Circuit Breaker):** Instead of relative drift, blocks can have a `cutoffTime` (e.g., "Do not start a workout after 20:00"). If Est Start breaches this, the task is killed, a high-priority OS notification fires, and it is logged.

---

## 4. Database Strategy: When to migrate?

**Current State: JSON Files / SharedPreferences**
For Sub-project 1 (Core Engine), keeping the `Plan JSON` and `State JSON` as local device files (parsed into Dart data classes) is the correct move. It is blazing fast, easy to mock, and trivial to pass to an LLM.

**When to move to a Database (SQLite / Isar for Flutter):**
You should migrate to a local database when you hit **Sub-project 2 (Control Panel)** or when the **Drift Log** becomes too large.
* *Why SQLite/Isar?* You will eventually want to query historical data: *"Show me all days where 'DSA Practice' was jettisoned"* or *"Plot my average drift over 30 days"*. JSON requires loading the entire file into memory to do this; a DB allows indexed querying.
* *Architecture Path:* Keep the `Plan JSON` as a JSON blob (since it's a nested document). Move the `State JSON` (drift logs, daily adherence, overrides) into relational database tables. 

**When to move to the Cloud (Supabase / Firebase):**
Do not move to a cloud DB until you explicitly need **cross-device sync** or **web-dashboard access**. Local-first (offline-first) is a massive competitive advantage for speed and reliability. 

---

## 5. Agent Instructions for Implementation
When building or modifying this system, adhere to these constraints:

1. **Dart Data Models:** Create separate model classes for `Plan` and `DailyState`. Create a `TimelineAssembler` class that takes both as inputs and outputs the resolved `List<Block>`.
2. **Immutability:** The `DriftEngine` must act as a pure function where possible: `Engine.computeDay(Plan plan, DailyState state, DateTime currentTime) -> ResolvedDay`. 
3. **Pristine Plan:** User interactions (checking off tasks, dragging priorities, skipping tasks) MUST ONLY mutate the `DailyState` object. The `Plan` object is immutable during daily execution.