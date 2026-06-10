# Custom Tasks — Implementation Plan
**Date:** 2026-06-09  
**Branch:** `feat/custom-tasks` (branch off `feat/reminders-2-redesign`)  
**Spec:** [`specs/2026-06-09-custom-tasks-design.md`](../specs/2026-06-09-custom-tasks-design.md)

---

## Prerequisites

Read before starting:
- Spec above (full UX flows, data model, amber UI spec)
- `lib/data/models.dart` — `DailyState`, `Block`, `RoutineItem`
- `lib/logic/assembler.dart` — `TimelineAssembler.assembleDay` signature
- `lib/screens/live_timeline_view.dart` — `_commit`, `_state`, `_done`, `_adjusting`
- `lib/data/state_store.dart` — how DailyState is persisted
- `lib/data/store.dart` — `ProfileDoc`, `ProfileRepository`

**Key invariant:** `TimelineAssembler` is the ONLY place blocks are assembled. Custom tasks enter the pipeline there, not in the screen.

**`_commit` protocol:** any state mutation goes through `_commit(DailyState, message)` in `LiveTimelineView`. It checkpoints, applies state, saves via `StateStore`, shows undo snackbar.

---

## Phase 1 — Single-day injection (ship first, complete feature)

### C1 — `CustomTask` model + `DailyState.addedItems`

**Failing test first.**

```
test/data/custom_task_test.dart
```

Tests:
- `CustomTask` round-trips through `toJson` / `fromJson`
- `DailyState` with `addedItems` round-trips
- `DailyState.copyWith(addedItems: [...])` works

Implementation:
1. Add `CustomTask` to `models.dart`:
   ```dart
   @immutable
   class CustomTask {
     final String id;          // 'custom_<ms>'
     final String label;
     final String startTime;   // 'HH:mm'
     final int durationMinutes;
     final String date;        // 'yyyy-MM-dd'
     const CustomTask({required ...});
     factory CustomTask.fromJson(Map<String,dynamic> j) => ...;
     Map<String,dynamic> toJson() => {...};
   }
   ```
2. Add `final List<CustomTask> addedItems` to `DailyState` (default `const []`)
3. Update `DailyState.fromJson`, `toJson`, `copyWith`
4. `Block` gains `final bool isCustom` (default `false`) — no serialization needed

Commit: `feat(data): CustomTask model + DailyState.addedItems`

---

### C2 — Assembler folds in custom tasks

**Failing test first.**

```
test/logic/custom_task_assembler_test.dart
```

Tests:
- With one `CustomTask` in `state.addedItems`, assembled blocks include a `Block` with `isCustom: true`, `priority: 0`
- Custom block's `time` matches `task.startTime`, `durationMinutes` matches
- Without `addedItems`, output is identical to before (golden test still passes)

Implementation in `assembler.dart`:
```dart
// After existing assembly and state merges, fold in custom tasks:
for (final task in state.addedItems) {
  if (task.date != dateIso) continue;
  result.add(Block(
    id: task.id, label: task.label, time: task.startTime,
    cls: 'custom', durationMinutes: task.durationMinutes,
    minDuration: task.durationMinutes,
    idealDuration: task.durationMinutes,
    priority: 0, isCustom: true, isTrackable: true,
  ));
}
// Re-sort by seed start time
result.sort((a, b) => a.time.compareTo(b.time));
```

Re-run golden test — it must still pass (no `addedItems` in the default state).

Commit: `feat(assembler): fold custom tasks into timeline at priority 0`

---

### C3 — `CustomTaskFitter`

**Failing test first.**

```
test/logic/custom_task_fitter_test.dart
```

Tests:
- `compactionSlack` returns sum of `idealDuration - minDuration` for non-anchor flexible blocks
- `computeOffers` with 1 droppable block ≥ needed → returns single-block offer marked recommended
- With no single block sufficient → returns two-block combo
- Returns empty list only if no droppable blocks exist (should be very rare)
- Anchors and custom blocks are never offered as sacrifice candidates
- Blocks with `priority: 1` (protect band) are never offered

```
lib/logic/custom_task_fitter.dart
```

```dart
@immutable
class SacrificeOffer {
  final List<Block> drop;
  final int freedMinutes;
  final bool isRecommended;
  const SacrificeOffer({required this.drop, required this.freedMinutes, this.isRecommended = false});
}

class CustomTaskFitter {
  static int compactionSlack(List<Block> blocks, String afterTime, int windowMinutes) { ... }

  static List<SacrificeOffer> computeOffers(List<Block> blocks, int neededMinutes) {
    final candidates = blocks
      .where((b) => !b.isHardAnchor && !b.isCustom && b.priority >= 5)
      .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority)); // highest priority-number first

    final offers = <SacrificeOffer>[];
    // Singles
    for (final b in candidates) {
      if (b.idealDuration >= neededMinutes) {
        offers.add(SacrificeOffer(drop: [b], freedMinutes: b.idealDuration));
      }
    }
    // Pairs (if no single suffices OR as additional options)
    for (int i = 0; i < candidates.length; i++) {
      for (int j = i + 1; j < candidates.length; j++) {
        final freed = candidates[i].idealDuration + candidates[j].idealDuration;
        if (freed >= neededMinutes) {
          offers.add(SacrificeOffer(drop: [candidates[i], candidates[j]], freedMinutes: freed));
        }
      }
    }
    // Triples
    // ... (same pattern, limit depth to 3)

    if (offers.isEmpty) return offers;
    // Sort: singles before pairs, tightest fit first within each group
    offers.sort((a, b) {
      if (a.drop.length != b.drop.length) return a.drop.length - b.drop.length;
      return a.freedMinutes - b.freedMinutes;
    });
    return [offers.first.copyWith(isRecommended: true), ...offers.skip(1)];
  }
}
```

Commit: `feat(logic): CustomTaskFitter — sacrifice offer ranking`

---

### C4 — `AddCustomTaskSheet`

```
test/widgets/add_custom_task_sheet_test.dart
```

Tests:
- "Continue" button is disabled when label is empty
- "Continue" fires `onSubmit(label, time, duration)` with the entered values
- Duration chips 15/30/45/60/90/120 are all tappable; selection updates correctly

```
lib/widgets/add_custom_task_sheet.dart
```

```dart
void showAddCustomTaskSheet(BuildContext context, {
  required void Function(String label, String time, int durationMinutes) onSubmit,
}) { ... }
```

Sheet layout:
- Title: "Add a task for today" (Fraunces, 20px)
- Label: `TextField` with autofocus
- Time: scrollable wheel picker (HH / mm, 15-min increments), defaults to nearest future 15-min slot
- Duration: horizontal chip row [15m] [30m] [45m] [60m] [90m] [120m], default 30m
- "Continue →" FilledButton (terra), disabled when label empty

Commit: `feat(widget): AddCustomTaskSheet — label + time + duration entry`

---

### C5 — `SacrificePickerSheet`

```
test/widgets/sacrifice_picker_sheet_test.dart
```

Tests:
- Shows task name and "need to free Nm" header
- Shows all offers from `computeOffers`
- First offer is pre-selected (recommended)
- "Confirm drop" fires `onConfirm(offer)` with selected offer
- "Let me pick…" expands a checklist; "Add" enables when freed ≥ needed
- If offers is empty (edge case): shows "Fits with compaction only" and a single confirm button

```
lib/widgets/sacrifice_picker_sheet.dart
```

```dart
void showSacrificePickerSheet(BuildContext context, {
  required String taskLabel,
  required int neededMinutes,
  required List<SacrificeOffer> offers,
  required void Function(List<Block> toDrop) onConfirm,
}) { ... }
```

Commit: `feat(widget): SacrificePickerSheet — sacrifice selection UI`

---

### C6 — Wire it all into `LiveTimelineView`

```
test/screens/live_timeline_custom_test.dart
```

Tests (use `@visibleForTesting` seams pattern from existing live_timeline_test):
- FAB exists in live view
- Tapping FAB → sheet appears (pump + find sheet)
- Submitting a task that fits with compaction → `stateForTest.addedItems` has the new task
- Submitting a task that needs sacrifice → sacrifice picker shown (mock `computeOffers` via seam)
- After confirming sacrifice → dropped blocks in `stateForTest.deletedItems`, task in `addedItems`
- Custom task row has amber decoration (find widget by key)
- Undo reverses both `addedItems` and any `deletedItems` that were added as sacrifice

Implementation in `live_timeline_view.dart`:

1. Add FAB to `Scaffold`:
   ```dart
   floatingActionButton: FloatingActionButton(
     key: const Key('add-custom-fab'),
     onPressed: _addCustomTask,
     backgroundColor: c.amber,
     child: Icon(Icons.add, color: c.bg),
   ),
   ```

2. `_addCustomTask()`:
   ```dart
   void _addCustomTask() {
     showAddCustomTaskSheet(context, onSubmit: (label, time, dur) async {
       final blocks = _assemble(widget.plan); // current assembled timeline
       final slack = CustomTaskFitter.compactionSlack(blocks, time, dur);
       final needed = dur - slack;
       if (needed <= 0) {
         _insertCustomTask(label, time, dur, toDrop: []);
       } else {
         final offers = CustomTaskFitter.computeOffers(blocks, needed);
         if (!mounted) return;
         showSacrificePickerSheet(context,
           taskLabel: label, neededMinutes: needed, offers: offers,
           onConfirm: (toDrop) => _insertCustomTask(label, time, dur, toDrop: toDrop));
       }
     });
   }
   ```

3. `_insertCustomTask(label, time, dur, {required List<Block> toDrop})`:
   ```dart
   void _insertCustomTask(String label, String time, int dur, {required List<Block> toDrop}) {
     final task = CustomTask(
       id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
       label: label, startTime: time, durationMinutes: dur,
       date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
     );
     final newDeleted = {..._state.deletedItems, ...toDrop.map((b) => b.id)};
     final newState = _state.copyWith(
       addedItems: [..._state.addedItems, task],
       deletedItems: newDeleted.toList(),
     );
     _commit(newState, 'Added ${task.label}');
   }
   ```

4. Custom row rendering: in `_normalRow`, when `block.isCustom`, wrap with amber left border (4dp `c.amber`) and add "CUSTOM" badge after the label.

`@visibleForTesting` seam: `List<CustomTask> get addedItemsForTest => _state.addedItems;`

Commit: `feat(live): custom task injection — FAB, fitter, sacrifice, amber row`

---

## Phase 2 — Recurrence

### C7 — `RecurringCustomTask` model + `RecurringStore`

```
test/data/recurring_custom_task_test.dart
```

Tests:
- Model round-trips through JSON
- `RecurringStore.save` / `loadAll` / `removeForDate` work on a temp-dir repo
- `RecurringStore.activeFor('yyyy-MM-dd')` returns tasks with that date in `activeDates`

```
lib/data/models.dart   (add RecurringCustomTask)
lib/data/recurring_store.dart  (new store)
```

```dart
@immutable
class RecurringCustomTask {
  final String id;              // 'recur_<ms>'
  final String label;
  final String preferredTime;   // 'HH:mm'
  final int durationMinutes;
  final List<String> activeDates; // 'yyyy-MM-dd', sorted, ≤7
  final String originTaskId;
  const RecurringCustomTask({...});
}
```

`RecurringStore` uses `AppStore.repo` (same injectable pattern as `StateStore`).

Commit: `feat(data): RecurringCustomTask model + RecurringStore`

---

### C8 — Assembler includes recurring tasks

```
test/logic/recurring_assembler_test.dart
```

Tests:
- With a `RecurringCustomTask` active for today, assembled blocks include it at priority 0
- Recurring block has `isCustom: true`
- `RecurringStore.activeFor(today)` returning empty → no change to output

Implementation in `assembler.dart`: `assembleDay` takes an optional `recurringTasks` list (injected, same injectable pattern as `state`). Folds them in after `addedItems`. Update `LiveTimelineView._assemble` to pass `await RecurringStore.loadActive(today)`.

Commit: `feat(assembler): fold recurring custom tasks into timeline`

---

### C9 — Repeat prompt card

```
test/screens/repeat_prompt_test.dart
```

Tests:
- When `LiveTimelineView` is opened and yesterday had a completed custom task with no recurrence rule, a "Repeat?" card appears at the top of the list
- Tapping a day chip creates a `RecurringCustomTask` and the card disappears
- Tapping "Skip" dismisses the card and marks the task as "no repeat"

Implementation:
- In `LiveTimelineView.initState`, after loading state: check `yesterday`'s `addedItems` for completed tasks that have no `RecurringCustomTask.originTaskId` pointing to them → collect into `_pendingRepeatTasks`
- Render as `_RepeatPromptCard` at the top of the block list (above `WeeklyReviewCard`)

`_RepeatPromptCard` widget (inline private class in `live_timeline_view.dart`):
```
╔══════════════════════════════════════════╗
║  ✦ Repeat "[label]"?                    ║
║  [label]  [same time · dur]             ║
║  [ Today ]  [ +2 ]  [ +3 ]  [ +7 ]    ║
║  [ Different time… ]     [ Skip ]      ║
╚══════════════════════════════════════════╝
```

"Different time…": opens a minimal time-picker inline (same wheel from `AddCustomTaskSheet`).

Commit: `feat(live): repeat prompt card for yesterday's custom tasks`

---

## Phase 3 — Blueprint promotion

### C10 — Sunday review surfaces custom tasks

```
test/widgets/weekly_review_custom_test.dart
```

Tests:
- `WeeklyReviewCard` with `promotionCandidates` non-empty shows the promotion section
- Each candidate shows label + run-count
- "Add to plan →" fires `onPromote(candidate)`
- "Not yet" fires `onDismiss(candidate)`

Implementation:
- Add `promotionCandidates` and callbacks to `WeeklyReviewCard`'s API
- In `LiveTimelineView`, Sunday: scan last 7 days' `addedItems` across all `DailyState`s to find tasks with label appearing 3+ times → pass as `promotionCandidates`
- A helper `PromotionCandidate(label, count, preferredTime, durationMinutes)` value object

Commit: `feat(review): surface frequent custom tasks for blueprint promotion`

---

### C11 — `PromoteToBlueprintSheet` + plan write

```
test/widgets/promote_blueprint_test.dart
```

Tests:
- Sheet shows pre-filled label, time, duration (all editable)
- "Apply to:" chips toggle correctly (office / WFH / weekend / every day)
- "Add to plan" fires `onConfirm(label, time, dur, templateIds)` 
- Resulting plan has new `RoutineItem` in each specified template's `routineStack`
- `AppStore.savePlan` is called (verify via `AppStore.repo` mock)

Implementation:
1. `lib/widgets/promote_blueprint_sheet.dart` — the sheet UI
2. In the callback, build a `RoutineItem`:
   ```dart
   RoutineItem(
     id: 'custom_${label.toLowerCase().replaceAll(' ', '_')}',
     kind: 'goal',    // user-promoted tasks are "goal" kind
     label: label,
     start: time,
     idealDuration: dur,
     minDuration: (dur * 0.6).round(),
     priority: 4,     // normal band, user can adjust via Adjust mode
   )
   ```
3. Append to `plan.dayTemplates[templateId].routineStack` for each selected template
4. `AppStore.savePlan(updatedPlan)` — plan is now permanently updated
5. Remove corresponding `RecurringCustomTask` entries
6. Show success snackbar: "Added to your [office / all] days blueprint"

Commit: `feat(blueprint): promote custom task to permanent routine (first plan write)`

---

## Summary

| Task | File(s) | Phase |
|---|---|---|
| C1 | `models.dart`, `test/data/custom_task_test.dart` | 1 |
| C2 | `assembler.dart`, `test/logic/custom_task_assembler_test.dart` | 1 |
| C3 | `logic/custom_task_fitter.dart`, test | 1 |
| C4 | `widgets/add_custom_task_sheet.dart`, test | 1 |
| C5 | `widgets/sacrifice_picker_sheet.dart`, test | 1 |
| C6 | `screens/live_timeline_view.dart`, `test/screens/live_timeline_custom_test.dart` | 1 |
| C7 | `models.dart`, `data/recurring_store.dart`, test | 2 |
| C8 | `assembler.dart`, test | 2 |
| C9 | `screens/live_timeline_view.dart` (`_RepeatPromptCard`), test | 2 |
| C10 | `widgets/weekly_review_card.dart`, test | 3 |
| C11 | `widgets/promote_blueprint_sheet.dart`, `screens/live_timeline_view.dart`, test | 3 |

---

## Watch-outs

- **`computeOffers` depth**: limit pair/triple search to first 8 candidates to avoid O(n³) in pathological cases.
- **Golden test**: C2 changes the assembler. The golden test uses a plain `DailyState()` (no `addedItems`) so it should still pass — but run it explicitly after C2.
- **`assembleDay` signature change**: `recurringTasks` in C8 should be an optional named parameter with default `const []` so all existing callers (including tests) continue to work without changes.
- **Priority 0 and the engine**: `DriftEngine` currently assumes minimum priority is 1. Check `compaction.dart` and `jettison.dart` — ensure `priority: 0` blocks are treated as undroppable (never jettisoned, never compacted).
- **`_assemble` in `home_screen.dart`**: also calls `TimelineAssembler.assembleDay`. It needs `state.addedItems` to be available. `HomeScreen._load()` already loads `DailyState` — confirm `addedItems` comes through correctly.
- **Date matching**: custom tasks store their `date` as `yyyy-MM-dd`. The assembler must filter `task.date == dateIso` (the ISO key for the day being assembled). Don't use `DateTime.now()` inside the assembler — always use the passed-in `dateIso`.
