# Reminders 2 — UX/UI Design Spec (drift-engine presentation layer)

**Date:** 2026-06-08
**Status:** Approved design
**Applies to:** `daily_command_center/` (Flutter app)
**Companion mockup:** [`2026-06-08-reminders-2-ux-mockup.html`](2026-06-08-reminders-2-ux-mockup.html) — open in a browser; toggles light/dark.
**Builds on:** [`2026-06-07-life-json-v3-drift-engine-design.md`](2026-06-07-life-json-v3-drift-engine-design.md) (the engine/architecture) and its plan [`../plans/2026-06-07-life-json-v3-drift-engine.md`](../plans/2026-06-07-life-json-v3-drift-engine.md). This spec is the **presentation layer** for that engine — how the rich core is shown and operated without overwhelming the user.

---

## 1. Philosophy (the design's job)

The engine is powerful — dual-time, micro-compaction, jettison, circuit-breakers, a drift log, an interactive sandbox. The UX's job is to make that power feel **natural and reassuring**, never busy or punishing. Five principles govern every decision:

1. **A human day, not a hustle.** The app treats lateness, rest, and disruption as normal. No streaks, no scores, no optimization pressure. Rest blocks are protected, not "monetized."
2. **Calm by default, intelligence on demand.** The most-used surface (Home) stays quiet until the day actually drifts. Richness lives one tap deeper (Live).
3. **"In good hands" = visible competence, not numbers.** The engine proves itself through plain sentences — *"I trimmed Brunch to hold Work"* — not dashboards. The user should feel a capable assistant is absorbing the chaos for them.
4. **No red, anywhere.** Alarm colors signal failure/guilt, which is hustle culture. **Amber is the loudest tone** the app uses (attention/trimmed). Dropped/past items are muted, never red.
5. **Lifestyle-agnostic to the pixel.** Every label, time, and message is derived from the Life JSON. The same screens render Cyrus, a nurse, a parent, or a student. (Cross-cutting rule, §3.)

---

## 2. Information architecture

**Primary nav is a depth model, not tabs or a drawer: Home ⇄ Live.**

```
┌─ Home (calm glance) ──────────────┐        ┌─ Live (rich, 1 tap) ──────────┐
│ avatar (top-right) → menu sheet   │        │ dual-time timeline            │
│ Right-Now hero card (+ whisper)   │  tap → │ elastic budget bars           │
│ Today mini-strip (done / next)    │ ←back  │ anchor walls · drift summary  │
│ Week planner strip                │        │ "Adjust today" → sandbox      │
└───────────────────────────────────┘        └───────────────────────────────┘
```

- **Home** — the default, calm surface. Glanceable.
- **Live** — the full drift-aware timeline + the editing sandbox. All richness lives here, off the calm path.
- **Avatar menu (replaces the side panel).** A profile avatar at Home's top-right opens a bottom sheet: *Switch profile · Settings & appearance · How Reminders works · Log out*. **This supersedes the navigation drawer** in [`2026-06-07-local-profiles-login-app-shell-design.md`](2026-06-07-local-profiles-login-app-shell-design.md) — see §13. Rationale: we have only two primary surfaces; a hamburger for rare actions adds weight and a reach. Identity + rare actions belong together.

There is no bottom nav and no drawer. The week planner (semi-frequent) stays a strip on Home; everything rare is behind the avatar.

---

## 3. Cross-cutting rule — no hardcoded life content

**Every string the UI shows about a block or anchor is derived from the Life JSON** (`anchor.label`, `anchor.start/end`, `item.label`, `item.desc`, the workout `title`, `goal.label`). The presentation layer knows nothing about "Work," "Train," or "Cyrus." It renders:

- an anchor as a labeled boundary with one meaning bit — `hard` (immovable wall) or soft (ceiling to aim for);
- a routine item as a labeled budget with a humanized importance.

The drift summary reads *"trimmed to hold **{anchor.label}**"*, never the literal word "Work." Teaching cards, notifications, and the weekly nudge all interpolate JSON labels. **Consequence:** a nurse's `Shift` anchor, a parent's `School run`, a student's `Lecture` all render through the identical components (mockup frame 8 proves this). The only Cyrus-specific artifact in the whole system is `assets/seed_plan.json`.

This rule is testable: no widget may contain a literal life-domain string (no `"Work"`, `"Train"`, `"DSA"` in Dart). Copy templates use placeholders filled from the plan.

---

## 4. Visual design system

Evolves the existing palette/typography — does not replace it.

**Type.** `Fraunces` (serif display — warm, editorial, human) for headers and emotional moments; `Spline Sans` (clean sans) for body and data. Both already bundled.

**Color — semantic, warm, no red.**

| Token | Dark | Light | Meaning |
|---|---|---|---|
| `terra` (terracotta) | `#c8633a` | `#b24e2a` | **Anchors** — your fixed, real-world boundaries. The primary accent. |
| `moss` | `#8fb36a` | `#5d8741` | On-track, done, healthy progress. |
| `amber` | `#e3a948` | `#b9842a` | **Loudest tone.** Trimmed/compacted, attention, "at risk." |
| `sky` | `#7ba6c9` | `#4f7fa3` | Quiet section labels / info. |
| `muted` / `dim` | `#c9b8a6` / `#8c7b6b` | `#6b5d4f` / `#9b8b7a` | Past, dropped, secondary text. |
| `bg` / `panel` | warm near-black `#17120e` | warm paper `#f3ebde` | Surfaces (brown-tinted, not cold grey). |

**Banned:** pure red / error-red for routine states. A genuinely destructive confirmation (e.g., delete a profile) may use a restrained warning, but no daily drift state is ever red.

**Signature elements (new):**
- **Elastic budget bar** — a horizontal bar = an item's duration budget. Shrinks visibly on compaction; the active item's bar drains in real time.
- **Drift whisper** — a single amber line that appears only when drifting.
- **Anchor wall** — hard: a solid terracotta full-width band with 🔒 + label + time; soft ceiling: a dashed muted band ("aim by …").
- **Teaching card** — a one-time, in-context explainer.
- **Humanized priority chip** — Protect / Normal / Drop-first.
- **Light theme** — warm-paper variant for bright screens.

**Motion.** Subtle and meaningful (a bar shrinking, a row settling). Respects OS *reduce-motion* (animations become instant state changes).

---

## 5. Surface — Home (calm)

The glance. Top to bottom:

- **Header** — kicker (date), Fraunces title, italic subtitle; **profile avatar** top-right (opens the menu sheet).
- **Right-Now hero card** — the single most-viewed element. Shows the current block, a **draining progress ring** ("41′" / "41m left of 75m budget"), and the next block. **Drift whisper rule:** a one-line amber status appears here *only when the day is actually drifting* (*"Running ~25m behind · trimmed Brunch & DSA to hold Work."*). On an on-track day there is no whisper — Home is exactly as calm as today's app.
- **Today mini-strip** — two pills: "3 / 9 done" and an on-track/reflowed status. Tapping the card or strip opens Live.
- **Week planner strip** — the existing 7-day planner (training-day spacing, schedule chips), lightly restyled for v3 templates and colorKeys.

**State coverage:** before the first block → *"Still resting · first up: {label} {time}"*; all done → *"Everything done — nice."*; day ended → *"Day's done. Rest up."* (See §10 QoL + §11 edges.)

---

## 6. Surface — Live timeline

A single vertical timeline rendering the engine's `ResolvedDay`. Each row exposes **dual-time**: a computed **Est Start** (left, updates as the day moves) and a **budget bar** (duration). A **NOW line** separates past from present. A **drift summary** sits at the top (one line; *"On track. The plan's holding."* when calm).

**State-morph matrix** (how a row looks by state × pressure):

| State | Treatment |
|---|---|
| **Done (past)** | Compressed height, dimmed, label struck through, green check; recedes. |
| **Active (now)** | The one elevated card with a draining bar + high-contrast *"41m left of 75m budget."* The only "loud" element. |
| **Pending · ideal** | Standard row, full budget bar, calm. |
| **Pending · compacted** | Bar visibly shorter + amber `⚠ −15m` tag + a thin amber left edge; meta explains *"30m (saved to hold {anchor})."* |
| **Dropped** | Collapses to a thin struck-through line with a quiet reason: *"dropped to protect {anchor}"* / *"too late to start well."* Muted, never alarming. |
| **Anchor · hard** | Solid terracotta wall: `🔒 {label} · {start}–{end} · fixed`. Visibly blocks the flow above it. |
| **Anchor · soft ceiling** | Dashed muted wall: `⌛ {label} by {time}`. |

**Train rows** keep today's behavior: tap to open the workout drawer (exercises, cues, logger).

The surface answers two glanceable questions at all times: *what am I doing now (and how much budget is left)?* and *what did the day cost (what got trimmed/dropped, and why)?*

---

## 7. Adjust mode (the sandbox)

Editing is **separated from viewing**. Default Live is read-only (plus tap-to-check-done). An **"Adjust today"** button flips the timeline into an explicit edit mode — drag handles appear, rows become reorderable, swipe-to-delete enables. "Done" returns to calm. This prevents accidental edits on a live, reflowing list and keeps the default uncluttered.

**Everything in Adjust mode writes `DailyState` only — the Plan blueprint is never touched.** Structural/default edits (changing an item's default duration, adding templates) belong to the future editor (sub-project 2).

### 7.1 Remove-a-task flow

Framed as **"Remove for today,"** not a destructive delete — tomorrow the task returns (the blueprint is pristine). This kills delete-anxiety.

- **Gesture:** swipe a flexible row left in Adjust → it collapses out. (Calm view has no delete.)
- **Anchors can't be removed** — no swipe affordance on a wall (removing a fixed boundary is a blueprint change).
- **Visible consequence:** freed time re-inflates neighbors — their budget bars grow back toward ideal (two-way elasticity made tangible).
- **Two undo levels:** (1) immediate snackbar *"Removed {label} for today · UNDO"*; (2) a persistent **"Removed today (n) ▾"** tray to restore any item later in the day.
- **Removed ≠ Done:** done counts toward adherence; removed is excluded from the adherence denominator. Different icons.

### 7.2 Set-priority flow (humanized)

- **Three levels** map to the engine's numeric priority: **Drop first** sheds budget and jettisons *before* **Normal**, which goes before **Protect**. No 1–7 number is ever shown.
- **Where:** only in Adjust mode; each row shows a level chip (e.g., *"Normal ▾"*). Calm view shows no priority.
- **Today-only:** writes `dailyOverrides[id]`. Changing the *default* importance is a blueprint edit (sub-project 2).
- **Honest tradeoff, live:** marking *Protect* on a tight day may trim a different item instead — surfaced plainly (*"Protected {Focus} — trimmed {DSA} instead,"* with Undo). *Drop first* may drop the item immediately if already late.
- **Anchors have no priority** (absolute) — no chip on a wall.

### 7.3 Cross-wall dragging + collisions

Flexible items can be dragged **across anchor walls** (e.g., move Train from morning to evening). Anchors are frozen (no drag handle). If a drop overcrowds a zone and forces a lower-priority item to jettison, the drop **completes anyway**, the affected item shows its dropped treatment inline, and a persistent **Undo** snackbar appears (*"{label} dropped to make room · UNDO"*). Undo restores from a checkpoint of the prior `DailyState`.

---

## 8. Teaching the novel concepts (just-in-time)

No upfront tour. A **one-time, dismissible card** fires the *first* time each behavior actually happens, then never repeats (per-concept seen-flags). Copy is JSON-derived.

| Trigger (first occurrence) | Card copy (placeholders from JSON) |
|---|---|
| First compaction | *"I trimmed {item} by {n}m so your {anchor} still starts on time. Budgets flex; anchors don't."* |
| First drop / auto-cancel | *"{item} got cancelled today — it would've run too late. Protecting your evening."* |
| First time opening Adjust | *"Drag to reorder, swipe to remove. {anchor} stays put. This only changes today."* |

Each card has **[Got it]** and **[Why?]** — *Why?* deep-links to the permanent **"How Reminders works"** glossary in the avatar menu (budgets, anchors, drift, compaction, drop rules). The glossary is the always-available reference for anyone who skipped or forgot.

---

## 9. Voice & tone

Plain, short, second-person, present tense. Warm but not chatty. **No guilt, no streaks, no nagging.** Silent during protected downtime (e.g., evening chill). Occasional gentle analogy ("budgets flex like a rubber band; anchors are walls"). Reference blocks/anchors by their JSON labels.

| Situation | Copy |
|---|---|
| On track | "On track. The plan's holding." |
| Drifting | "Running ~{n}m behind. Trimmed {a} & {b} to hold {anchor}." |
| Item compacted | "{item} · ⚠ −{n}m · saved to hold {anchor}." |
| Item dropped | "{item} cancelled today — too late to start well." |
| Past soft ceiling | "Running past your {sleep} target — wind down soon." |
| Day done | "Day's done. Rest up — tomorrow's set." |
| Empty week (review) | "No drift this week — the plan held. Nice." |

---

## 10. Quality-of-life features (all four approved)

1. **Satisfying check-off flow.** Tap or swipe a block to complete with a light haptic; the active card's "Done" advances focus to the next item; an all-caught-up state when everything's checked.
2. **Smart edge/empty states.** Pre-wake, all-done, day-ended, and on-track-vs-behind messages — no blank or awkward screens (see §5, §11).
3. **Light theme + legibility.** A warm-paper light palette toggled in Settings (CLAUDE.md lists this as a likely ask) + a larger-text option. Reuses the color-variable system.
4. **"Peek at ideal" toggle.** Tap a drifted row's ⓘ to see its original plan — *"planned 8:30 · now 9:05 · budget 75→45m (to hold {anchor})"* — making the engine's reasoning legible on demand without cluttering the default view.

---

## 11. Drift log → weekly review (the feedback loop)

Two distinct ideas sit side by side on the review surface; keeping them separate matters:

- **Adherence** (existing) — what *you* did (checked-done), a 7-day bar strip.
- **Drift log** (new) — what the *engine* did *for* you (compaction/drop/cancel), with reasons.

**Surfacing — calm by default:**
1. **"This week" card** — one plain sentence from JSON labels: *"This week: {Train} auto-cancelled 2× · {Focus} trimmed 4× to protect {Work}."* If nothing drifted: the empty-week line (§9). No shaming, no streaks.
2. **Sunday emphasis.** On a template's review block, the card brightens and gains a **gentle nudge** derived from the dominant pattern: *"{Train} keeps getting squeezed out on office days. Move it earlier, or shorten its budget?"* with soft actions (*Move earlier · Shorten · Leave it*) — the bridge to the editor (sub-project 2).
3. **Tap → weekly detail** (optional, later): events grouped by item, each with a one-line "why."

The framing is the product: turn real life ("I keep running late and training dies") into a tunable signal ("your plan asks too much before 2:00") — a coach noticing a pattern, not a teacher marking you down.

---

## 12. Notifications & edge cases (quiet by default)

**Exactly one proactive notification type ships:** the **circuit-breaker alert**, fired only when the engine auto-cancels a `kill_and_notify` item. Dedicated high-priority channel, JSON-derived copy (*"{item} cancelled today — drifted past {cutoff}. Protecting your evening."*), tap → Live. No reminder spam, no "you missed X." "Next-up" reminders are **opt-in** in Settings, off by default. Permission is requested the first time it's relevant, not on a cold launch; if denied, drift is still logged and shown in-app.

**Edge cases (all lifestyle-agnostic):**

| Case | Behavior |
|---|---|
| Before first block | "Still resting · first up: {label} {time}" |
| Everything checked | "Everything done — nice." |
| Day ended | "Day's done. Rest up." |
| Past soft ceiling | "Running past your {sleep} target — wind down soon." |
| Template with no anchors | Timeline renders without walls; engine handles it. |
| Corrupt/missing plan | Fall back to seed; "Couldn't load your plan — restored defaults." |
| Midnight rollover | New day = fresh `DailyState`; yesterday archived. |
| Reduce-motion ON | Bar/cascade animations become instant. |

The app never punishes, never nags, and degrades gracefully into a calm, correct screen.

---

## 13. Component inventory (reuse vs. new) & relationship to the engine plan

This spec layers onto the engine plan's phases; it does not change the engine. Mapping:

**Reused / restyled (existing widgets):**
- `now_card.dart` → Home Right-Now hero + draining ring + **drift whisper** (whisper is new; reads engine `ResolvedDay`).
- `week_planner.dart` → Home week strip (already v3-bound in the plan).
- `today_screen.dart` → folds into / is replaced by the **Live** surface (§6); its adherence strip moves into the weekly review (§11).

**New widgets:**
- `live_timeline_view.dart` (in the plan, Phase E) → gains the full **state-morph matrix** (§6), **budget bars**, **anchor walls**, **drift summary**, **Adjust mode** (§7), **peek-at-ideal** (§10).
- `teaching_card.dart` → just-in-time explainer + seen-flag store (§8).
- `weekly_review_card.dart` → "this week" + Sunday nudge (engine plan Phase D's `weekly_review.dart` provides the data).
- `avatar_menu_sheet.dart` → identity + rare actions (§2); pairs with the profiles/app-shell work.
- Theme: extend `main.dart` `AppColors` into a light/dark `ThemeData` pair (§4, §10).

**Engine-plan phases that gain UI acceptance criteria from this spec:** Phase B/C surfaces (dual-time render, compaction/drop visuals) → §6; Phase D (drift log) → §11; Phase E (sandbox) → §7. The engine plan's Phase E tasks should be re-pointed at *this* spec's Adjust-mode model (read-only default + explicit Adjust + humanized priority), which **revises** the plan's original always-on-inline-editing approach.

**Supersession:** the **avatar menu replaces the navigation drawer** from the local-profiles/app-shell spec; that spec's "side panel (drawer)" item should be updated to "avatar menu sheet." No other part of that spec changes.

---

## 14. Non-goals

- The structural **Life-JSON editor** (changing default durations/priorities, authoring templates) — sub-project 2. Adjust mode edits **today only**.
- The **interview, AI generation, onboarding** flows — sub-projects 3–5.
- The **Android home-screen widget** Glance redesign — still the standing blocker in CONTINUE.md; out of scope here.
- Multi-device sync — local-first only.

---

## 15. Success criteria

- On an on-track day, Home is **as calm as today** (no new noise); drift UI appears only when the day actually drifts.
- A first-time user understands a compaction/drop **the moment it happens**, via one in-context sentence — no manual.
- The same Live timeline, Adjust mode, weekly review, and notification render a **non-Cyrus lifestyle** correctly by supplying only a new Life JSON (no widget contains a literal life string).
- Reshaping the day (reorder/remove/priority) is **always reversible** and never alters the master plan.
- Nothing in the product uses red or shows a streak/score; rest is visibly protected.

---

## 16. Open questions

None outstanding. Visual fidelity is captured in the companion mockup; remaining specifics (exact spacing, animation curves) are implementation details resolved during the build against the mockup.
