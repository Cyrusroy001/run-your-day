# Handover Specification: Universal Drift-Aware Execution Engine (Reminders 2)

> ⚠️ **FOLDED IN / SUPERSEDED (2026-06-07).** This v3 sketch has been merged with the (v1) plan-driven core spec into the approved design: [`../specs/2026-06-07-life-json-v3-drift-engine-design.md`](../specs/2026-06-07-life-json-v3-drift-engine-design.md). Its concepts (dual-time, micro-compaction, hard drift circuit-breakers, the generalized schema) live on there with the concrete Cyrus seed, the hybrid seed-time-plus-drift model, anchors = Work + Sleep, and a drift log for the Sunday review. Kept for history; do not implement from this file.

**Date:** 2026-06-05  
**Target Architecture:** Flutter Framework Core + Native Android Home Widget Layer
**Core Principle:** "Content is Data, Interaction is Logic"

---

## 1. System Topology & Core Concept

Reminders 2 does not utilize standard, blank-slate calendar structures. The application relies on a **Plan-Driven Architecture**:
1. **Upstream (Onboarding):** A conversational AI interviews the user about their specific lifestyle archetype, constraints, energy patterns, and goals.
2. **Synthesis:** The AI generates a comprehensive, localized `Plan JSON` structured exactly to that user's life rules.
3. **Downstream (The Client App):** The Flutter mobile app and Android home screen widget act strictly as a local execution engine. The client app remains completely agnostic to the user's career or lifestyle; it simply reads the synthesized JSON schema and dynamically calculates rendering layouts, cascading time-waves, and behavior guardrails.

---

## 2. Core Execution Engine Rules

### Rule 1: The Dual-Time Structural Formula
Every routine block rendered in the Flutter `TodayScreen` list or the Native Android `RemoteViews` Widget must calculate and display two distinct metrics simultaneously:
* **Estimated Start Time (`Est Start`):** Calculated dynamically at runtime. It shifts forward or backward depending on when the previous item was checked off, or based on real-time delays.
* **Execution Budget Duration (`Duration`):** A fixed time allocation for that item (e.g., 45 mins), shifting user psychology from "tracking fixed clock slots" to "protecting an action budget."

### Rule 2: Micro-Compaction Strategy
When real-world disruption causes the schedule to drift, the engine must not simply break. It evaluates upcoming items against any fixed real-world boundaries (e.g., a fixed corporate work block, a flight, a school pick-up anchor) and automatically scales items down from their `idealDuration` toward their explicit `minDuration` to "claw back" lost time.

### Rule 3: Hard Drift Circuit-Breakers
Every item supports an optional `maxDriftMinutes` property. If real-world delays cause an item to slide past its drift ceiling, the engine executes a hard cancellation of that block for the day.
* **The Rationale:** This stops routines from slipping deep into the night, which destroys sleep hygiene and breaks routine value the following day.
* **Notification Requirement:** When the engine automatically cancels a block due to a drift breach, it must fire a high-priority system notification with a distinct audio channel sound to alert the user and cleanly promote the next valid item in the sequence.

---

## 3. Generalized Data Schema (JSON Output Template)

The upstream AI synthesis engine will output variations of this structure. The mobile app must be built to parse and map these exact fields dynamically:

```json
{
  "schemaVersion": 3,
  "meta": {
    "lifestyleArchetype": "dynamic_user_profile"
  },
  "dayTemplates": {
    "high_constraint_day": {
      "label": "High-Constraint Layout",
      "colorKey": "terra",
      "anchors": [
        { "id": "a_fixed_commitment", "label": "Fixed Real-World Boundary", "start": "14:00", "end": "20:00" }
      ],
      "routineStack": [
        { 
          "id": "b_core_routine_1", 
          "kind": "routine", 
          "label": "Baseline Habit", 
          "idealDuration": 15, 
          "minDuration": 15, 
          "priority": 1 
        },
        { 
          "id": "b_focus_block", 
          "kind": "focus", 
          "label": "Deep Cognitive Work", 
          "idealDuration": 90, 
          "minDuration": 45, 
          "priority": 2,
          "maxDriftMinutes": 60,
          "dropStrategy": "scale_to_min"
        },
        { 
          "id": "b_physical_block", 
          "kind": "train", 
          "label": "Physical Training/Recovery", 
          "idealDuration": 60, 
          "minDuration": 40, 
          "priority": 3, 
          "condition": "isTrainingDay",
          "maxDriftMinutes": 90,
          "dropStrategy": "kill_and_notify"
        }
      ]
    }
  }
}
