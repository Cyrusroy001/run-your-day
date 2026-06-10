# Custom Tasks — Design Spec
**Date:** 2026-06-09  
**Status:** Approved for implementation  
**Plan:** [`plans/2026-06-09-custom-tasks.md`](../plans/2026-06-09-custom-tasks.md)

---

## What this is

A way to inject ad-hoc tasks into today's live timeline with a specific time and duration. The system always finds room — it compacts flexible blocks and, if that's still not enough, presents the user with a ranked "sacrifice menu" so they choose what gets dropped. Amber-border UI marks custom tasks so they're visually distinct from the regular routine.

Phase 2 lets the user schedule a repeat for the same task (+1/+2/+3/+7 days). Phase 3 surfaces frequently-repeated custom tasks in Sunday review and lets the user promote them into the permanent Life JSON blueprint.

---

## Core design decisions

**Custom tasks are always priority 0** (above the protect band). No routine block can prevent them from appearing. The constraint is time, not priority — the system always creates the time.

**Initial insertion is interactive.** The user sees what needs to be sacrificed and confirms. This respects autonomy and makes the trade-off visible ("I'm dropping Wind-down to fit this call — that's my choice").

**Recurrence is automatic.** On a repeat day the task inserts itself with auto-jettison (compact → drop lowest-priority until space exists). The user gets an amber teaching card: "Your recurring [X] pushed [Y] and [Z] today."

**Recurrence never exceeds one week out.** The +1/+2/+3/+7 picker limits target dates to within 7 days. Beyond that, the task should be permanent (Phase 3 / blueprint).

**Sunday review is the bridge to permanence.** A task that ran 3+ times in a rolling 7-day window surfaces in the Sunday WeeklyReviewCard with a "Make this permanent?" CTA.

**Promoting to blueprint writes to `Plan.dayTemplates[*].routineStack`.** The promotion flow asks which day types the task should apply to (office / WFH / weekend / all), then appends a `RoutineItem` to the appropriate template stacks and saves the plan. This is the first place the app writes the blueprint at runtime.

---

## Data model

### `CustomTask` (new, in `models.dart`)

```dart
@immutable
class CustomTask {
  final String id;            // 'custom_<ms-timestamp>'
  final String label;
  final String startTime;     // 'HH:mm', 24-hour
  final int durationMinutes;
  final String date;          // 'yyyy-MM-dd'

  const CustomTask({required this.id, required this.label,
    required this.startTime, required this.durationMinutes,
    required this.date});

  factory CustomTask.fromJson(Map<String, dynamic> j) => ...;
  Map<String, dynamic> toJson() => ...;
}
```

### `DailyState` change

Add `final List<CustomTask> addedItems` (defaults to `const []`). Existing `copyWith`, `fromJson`, `toJson` updated to include it. `StateStore` persists it transparently.

### `Block` change

Add `final bool isCustom` (defaults to `false`). Used by the row renderer to show the amber border + CUSTOM badge. No existing serialization changes needed (Block is not persisted — it's assembled from Plan + state on every load).

### `RecurringCustomTask` (new, in `models.dart`)

```dart
@immutable
class RecurringCustomTask {
  final String id;              // 'recur_<ms-timestamp>'
  final String label;
  final String preferredTime;   // 'HH:mm'
  final int durationMinutes;
  final List<String> activeDates; // target 'yyyy-MM-dd', ≤7 entries
  final String originTaskId;    // id of the CustomTask it came from

  const RecurringCustomTask({...});
}
```

### `ProfileDoc` change

Add `final List<RecurringCustomTask> recurringTasks` (defaults to `[]`). `ProfileRepository` serializes it. A new `RecurringStore` facade wraps read/write (same pattern as `StateStore`).

---

## Assembler integration

`TimelineAssembler.assembleDay(plan, templateId, dayKey, training:, state:)` gains a new step after the existing merge:

1. For each `CustomTask` in `state.addedItems` with `task.date == dateIso`:
   - Convert to a `Block` with `priority: 0, isCustom: true, isHardAnchor: false`
   - Use `task.startTime` as the seed start, `task.durationMinutes` as both `idealDuration` and `minDuration`
2. For each `RecurringCustomTask` in `recurringStore.activeFor(dateIso)`:
   - Same conversion at `priority: 0, isCustom: true`
   - These are NOT in `state.addedItems` — they're assembled from the recurring store directly

The drift engine then computes the day normally. Because `priority: 0` custom blocks are above all routine blocks, compaction will squeeze routine blocks around them, never the custom ones.

---

## Sacrifice fitter logic

New file: `lib/logic/custom_task_fitter.dart`

```dart
class SacrificeOffer {
  final List<Block> drop;       // blocks to jettison
  final int freedMinutes;
  final bool isRecommended;
}

class CustomTaskFitter {
  /// Returns ranked sacrifice offers needed to free [neededMinutes].
  /// Candidates: non-anchor, non-custom, non-work blocks, sorted by
  /// priority descending (highest number = drop first).
  static List<SacrificeOffer> computeOffers(
      List<Block> assembled, int neededMinutes);

  /// Slack already available via compaction (sum of idealDuration - minDuration
  /// for flexible blocks in the target window).
  static int compactionSlack(List<Block> assembled, String startTime, int duration);
}
```

Offer ranking:
1. Single-block drops that free ≥ `neededMinutes`, sorted by smallest surplus (tightest fit first)
2. Two-block combos that together free ≥ `neededMinutes`, sorted by lowest total priority score (minimum sacrifice)
3. Three-block combos (rare, shown last)
4. The recommended flag goes on the first entry (usually single-block if one exists, otherwise the tightest two-block combo)

---

## UX flows

### Adding a custom task (Phase 1)

1. User taps **＋ Add task** FAB in `LiveTimelineView` (bottom-right, amber, always visible in both modes)
2. `AddCustomTaskSheet` slides up: label text field, time picker (HH:mm wheel), duration picker (15/30/45/60/90/120 min chips)
3. On "Continue":
   - Engine checks compaction slack in the target window
   - If slack ≥ needed: insert immediately, show amber teaching card "Your routine was compacted to fit this"
   - If slack < needed: open `SacrificePickerSheet`
4. `SacrificePickerSheet` shows ranked offers + "Let me pick…" path
5. User confirms → `_commit(DailyState, 'Added [label]')` with undo

### Sacrifice picker sheet

```
╔══════════════════════════════════════════╗
║  To fit "Call mom · 45 min"             ║
║  Need to free 15 more minutes            ║
╠══════════════════════════════════════════╣
║  ● Drop Wind-down            frees 30m  ║  ← RECOMMENDED
║  ○ Drop DSA Practice         frees 45m  ║
║  ○ Drop Chill + Wind-down    frees 90m  ║
║                                          ║
║  [Let me pick…]    [Confirm drop →]     ║
╚══════════════════════════════════════════╝
```

"Let me pick…" opens a checklist of all droppable blocks. The "Add" button shows running total freed and activates when freed ≥ needed.

### Custom task row

```
│█│  14:30  Call mom                 45m  CUSTOM │
    amber   label                    dur  badge
    border
```

- Amber left border (4dp, same amber as `c.amber`)
- "CUSTOM" badge (9sp, terra, like the NOW label)
- Otherwise identical to a normal `_normalRow`
- In Adjust mode: draggable, dismissible, has priority chip (locked at protect)

### Repeat prompt (Phase 2)

Day after a custom task, `LiveTimelineView` checks for completed custom tasks from yesterday with no recurrence rule. If found, shows a top-of-list card:

```
╔══════════════════════════════════════════╗
║  ✦ Repeat "Call mom"?                   ║
║  Same time · 45 min                      ║
║  [Today]  [+2]  [+3]  [+7]  [Skip]     ║
╚══════════════════════════════════════════╝
```

Tapping a day option: creates `RecurringCustomTask` with the selected target date(s). Different-time option: shows a mini time-picker inline before confirming.

### Sunday review promotion (Phase 3)

`WeeklyReviewCard` on Sundays shows a section below the weekly summary when recurring or frequently-run custom tasks exist:

```
╔══════════════════════════════════════════╗
║  You ran "Call mom" 4 times this week.  ║
║  Make it part of your routine?          ║
║  [Add to plan →]         [Not yet]      ║
╚══════════════════════════════════════════╝
```

"Add to plan →" opens `PromoteToBlueprintSheet`:
1. Confirm label + time + duration (pre-filled, editable)
2. "Apply to:" chip group — office days / WFH days / weekends / every day
3. "Add to plan" → appends `RoutineItem` to matching `dayTemplates[*].routineStack`, saves plan via `AppStore.savePlan`, removes the recurring task, shows success snackbar

---

## Amber border spec

`isCustom` blocks render with a left border in `c.amber` at 4dp width and `c.amberD` as the row background tint (same translucent amber used for the compacted tag). The "CUSTOM" badge is `c.terra` at 9sp, `FontWeight.w700`, uppercase — same visual language as "NOW" and "ANCHOR".

---

## Notification copy

When a recurring task auto-inserts and drops blocks:

> **"Call mom · 3pm" is in your day**  
> Wind-down was dropped to make room. Tap to review.

When a new custom task is being confirmed (inline copy, not a system notification):

> Added. Wind-down was shortened, DSA Practice was dropped.

---

## What this feature does NOT do

- Custom tasks do not survive midnight (unless recurrence is set). They are ephemeral.
- Custom tasks cannot be added to past days.
- Custom tasks in the Adjust mode have their priority chip locked at "Protect" — they cannot be deprioritised below that.
- The blueprint promotion does not run AI — it creates a `RoutineItem` with the exact label/time/duration the user confirmed. AI-synthesised routine building is a later sub-project.
