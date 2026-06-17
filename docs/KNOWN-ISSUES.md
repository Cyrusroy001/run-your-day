# Known issues — deferred logical debt

Logical/correctness issues found in the drift system + garden surfaces that are
**deliberately deferred** until after the drift "missed-task" fix lands and
**v1.1 ships**. Revisit this list with Cyrus then; add new finds as they surface.

> Not bugs in the "broken build" sense — the app runs. These are places where the
> logic produces a misleading or inaccurate result in edge cases.

Status legend: ⬜ open · 🔭 revisit-after-drift-fix · ✅ done

---

## DL-0 — (the trigger) stale live card / never-missed task — **being fixed now**
Not deferred. The first un-done block was pulled to `now` forever, so a morning
task showed as the live card at 8 PM. Fix in progress: `now` card = present-time
block; passed tasks become "missed" (overripe, late-pickable) and drop at the next
hard anchor. Tracked in the garden work / commits, not here.

---

## DL-1 — Night/"done" shown for a day where nothing was accomplished  ⬜
**Symptom:** a day where you picked nothing still shows the serene "vine fully
climbed" night card once the window passes.
**Root cause:** `DayArc.dayDone` ([lib/logic/day_arc.dart](daily_command_center/lib/logic/day_arc.dart)) and
`HomeNowState.isDayDone` ([lib/logic/home_now_state.dart](daily_command_center/lib/logic/home_now_state.dart))
treat "window passed" identically to "all trackables picked."
**Recommended fix:** keep night *triggering* on window-passed (the day is over), but
pass a `harvested` signal (pick ratio / jammy count) to `NightCard`
([lib/widgets/night_card.dart](daily_command_center/lib/widgets/night_card.dart)) — full-vine
"good night" vs a gentler "the day got away — fresh bed tomorrow." Copy/visual branch.
**Priority:** low. **Sequence:** fold into G10 copy pass. Depends on the drift fix
(it defines missed vs done).

## DL-2 — Done-block time accounting uses scheduled, not actual, duration  ⬜
**Symptom:** finish a 75-min block in 20 min and everything downstream still looks
~55 min later than reality.
**Root cause:** `_cascade` ([lib/logic/drift_engine.dart](daily_command_center/lib/logic/drift_engine.dart))
reserves a done block's full scheduled duration; there is no record of when a pick
actually happened.
**Recommended fix:** cheap first pass — a done block shouldn't reserve time past
`now` (`cursor = min(scheduledEnd, now)`), so finishing early frees the rest of the
day. Accurate version: store a completion timestamp per pick and cascade from it
(needs new state + migration). Verify the `done-items` engine test still passes.
**Priority:** medium. **Sequence:** small follow-up after the drift fix; keep out of
the drift commit so that change stays isolated.

## DL-3 — Circuit-breaker is effectively dormant  🔭
**Symptom:** the cutoff / max-drift "kill" safety net never fires for the real plan.
**Root cause:** it only triggers for `dropStrategy == 'kill_and_notify'`
([lib/logic/drift_engine.dart](daily_command_center/lib/logic/drift_engine.dart) circuit-breaker block),
but seed routine items use `scale_to_min`/none with no `cutoffTime`/`maxDriftMinutes`.
**Recommended fix:** do **not** add default cutoffs (reintroduces a lifestyle
constant — against the generality invariant). Re-evaluate after the drift fix: the
new hard-anchor "missed cleanup" largely replaces the circuit-breaker's purpose. If
nothing relies on `kill_and_notify`, delete it (and its live tests C1/C2). Otherwise
keep but document why.
**Priority:** low (cleanup). **Sequence:** revisit once missed-task semantics settle.

## DL-4 — Long-duration anchors distort the sun-arc / night window  ⬜
**Symptom:** a `Sleep target` anchor with a long duration blows up the arc span; the
sun-arc and night-window math read wrong (worked around in the G5.3 night test).
**Root cause:** `DayArc.from` ([lib/logic/day_arc.dart](daily_command_center/lib/logic/day_arc.dart))
computes `endH` as the max of `estStart + dur` over **all** blocks, anchors included.
**Recommended fix:** compute `endH` over **non-anchor** blocks only; anchors
contribute a point stop at their start, not span. Tightens the arc to real activity
and lets the G5.3 night test drop its workaround. Traced earlier: the G2.2 `DayArc`
tests stay green (they use focus blocks for `endH`, the work anchor only for
`dayDone`).
**Priority:** medium. **Sequence:** post-v1.1 (Cyrus asked to defer; was a candidate
to bundle with the drift fix but held back to keep that change focused).

## DL-5 — Onboarding hardcodes lifestyle constants (moat-clause gap)  ⬜
**Symptom:** the generality guard (ADR-022 §8) trips on
[lib/screens/onboarding_screen.dart](daily_command_center/lib/screens/onboarding_screen.dart) —
literal `'Office'`/`'WFH'`/`'Weekend'`/`'Training days'` chips. The guard currently
**exempts** `onboarding_screen.dart` + `login_screen.dart` (the deferred interview/
AI-stub surfaces) so the moat clause governs the garden surfaces.
**Recommended fix:** when the real interview/AI onboarding lands (roadmap #3/#5),
source these labels from the seed/plan `dayTemplates` + `training` rules instead of
literals, then drop the guard exemption.
**Priority:** low. **Sequence:** with the interview/AI onboarding rebuild, not before.
