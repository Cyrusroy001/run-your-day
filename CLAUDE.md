# CLAUDE.md — Daily Command Center

Project context for Claude Code. Read this first before editing anything.

## Key documentation (read for any non-trivial task)

- [`docs/CONTINUE.md`](docs/CONTINUE.md) — current implementation state, what's done, what's next, active blockers
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — architectural decision records; explains the "why" behind choices that might otherwise look wrong
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — file map, data flow diagrams, SharedPreferences key map
- [`docs/superpowers/specs/2026-06-05-widget-app-design.md`](docs/superpowers/specs/2026-06-05-widget-app-design.md) — full design spec for the Flutter app
- [`docs/superpowers/plans/2026-06-05-flutter-widget-app.md`](docs/superpowers/plans/2026-06-05-flutter-widget-app.md) — implementation plan (all 12 tasks)

**The active codebase is `daily_command_center/` (Flutter app). `daily-command-center.html` is the old HTML version — do not edit it for new features.**

---

## What this is

The project is transitioning from a single-file HTML dashboard to a Flutter Android app.
The Flutter app (`daily_command_center/`) replaces `daily-command-center.html` and adds
a native Android home screen widget. Phase 1 is complete. See `docs/CONTINUE.md` for status.

The original HTML file combined three things in one screen:

1. A **fitness plan** — a 1-month home training program (recomposition for a
   skinny-fat beginner) that transitions to a gym afterward.
2. A **daily routine** built around real constraints (job, study, training, meals).
3. A **progress tracker** with per-workout logging.

It is meant to be opened on a phone every day. No build step, no framework,
no server — just open the file in a browser.

## The owner (so advice stays relevant)

- 5'7", ~67 kg, skinny-fat, beginner lifter. Based in Pune, India.
- Equipment: two 5 kg dumbbells at home, a bench machine + treadmill in the
  society gym.
- Job: 2:00–8:00 PM, office is 10 min away, works from home 1 day/week.
- Wakes ~8 AM (nudging sleep earlier), sharpest focus in the morning.
- Wants to build AI projects + practice DSA (data structures & algorithms),
  aiming to switch careers by end of year. Self-described beginner — keep
  explanations in plain language, avoid heavy jargon.
- Goal physique: lean & defined (~12–14% body fat), NOT big/bulky.

## How the file is structured

It's one HTML file with three parts inside:
- `<style>` — all CSS. Uses CSS custom properties (variables) in `:root` for
  the color palette. Fonts are Fraunces (serif display) + Spline Sans (sans).
- HTML body — header, a "now" banner, the week planner, day tabs, the
  timeline container, and two reference cards (goal + rep decisions).
- `<script>` — all logic, vanilla JS, no libraries.

### Key JS pieces (search for these)
- `WORKOUTS` — object holding the 4 workouts (A, B, BENCH, CARDIO), each with
  a title, a "why" explanation, and an exercise list `[name, sets/reps, cue]`.
- Reusable block constants (`WAKE`, `FOCUS`, `BRUNCH`, `LUNCH3`, etc.) — the
  building blocks of a day's timeline.
- `plan` — the user's editable week, saved to localStorage key `weekPlan`.
  Each day maps to a type: `rest`, `office`, `wfh`, or `weekend`.
- `buildTimeline(day, type)` — returns the ordered list of blocks for a day.
- `buildTimes(blocks)` — resolves each block's display time (e.g. "8:30") into
  a 24-hour decimal, walking forward so evening times correctly read as PM.
  **This was a real bug once** — do not revert to naive hour parsing.
- `renderNow()` — the live "right now" banner; reads device clock vs today's
  timeline to show current + next action.
- `renderTabsTimelineMeta()` — renders the day tabs and the selected day's
  timeline, including the inline workout drawers.
- Logger functions (`loggerHTML`, `attachLoggers`, `renderHist`) — per-workout
  progress logging, saved to localStorage keys `log_A`, `log_B`, etc.

## Important design decisions (don't undo these by accident)

- **Calorie approach: a gentle deficit (~200–400 below maintenance), NOT a
  surplus.** This was deliberately changed after research — for a skinny-fat
  beginner, a small deficit + high protein drives recomposition. Do not switch
  back to "eat big / bulk" advice.
- **Protein target: ~130–145 g/day.** Higher than a maintenance figure because
  the user is in a deficit (protein protects muscle when cutting).
- **Soya chunks** are a cheap protein anchor but capped ~50 g dry/day and
  rotated with other sources — don't make it the sole protein.
- **Training progression = "double progression"**: add reps within a range,
  then make the exercise harder (or add weight on the bench machine) once the
  top of the range is hit on all sets. The decision rules live in the
  "Rep Decisions" card and must stay consistent with this.
- **Meals reflect the real day**: big-protein brunch ~11:30, lunch at the
  office at 3 PM, light snack at 5 PM. Not a noon lunch.
- **Evening chill is protected** — intentionally no forced productivity at
  night; the user keeps that as downtime. Don't pack it with tasks.
- All data is **localStorage only** (no backend). Note this limitation when
  relevant: it doesn't sync across devices and clears with browser data.

## Health/safety note

This is general fitness information, not medical advice. Keep the disclaimer in
the file. Never add content that promotes extreme deficits, crash dieting, or
training through joint pain — the plan's cut-back rules exist for that reason.

## Conventions for editing

- Keep it a **single file** unless asked otherwise. No external dependencies,
  no build tooling. It must keep working by just opening the file.
- No browser storage APIs beyond localStorage. (Note: localStorage works when
  the file is opened directly; it does NOT work inside the claude.ai artifact
  viewer, only in a real browser.)
- Preserve the color-variable system; don't hardcode hex values in new markup.
- Keep copy in plain language with the occasional analogy — that's the
  owner's stated preference.
- After any change to time logic, sanity-check that each day's timeline is
  monotonic (times only increase) and that evening blocks read as PM.

## Common things the owner may ask for

- Add a water / sleep / steps tracker row.
- Add or swap exercises; adjust rep ranges.
- Change wake time / meal times / training times.
- A lighter color theme for bright-screen readability.
- Export/import the logged data (since it's localStorage-bound).
- A weekly summary view of logged progress.

When making changes, explain what you changed in plain terms and why.
