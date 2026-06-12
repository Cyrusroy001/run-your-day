# CLAUDE.md — ketchup (daily planner)

Project context for Claude Code. Read this first; for live status read `docs/CONTINUE.md`.

## Key documentation

- [`docs/CONTINUE.md`](docs/CONTINUE.md) — **read first**: current state, what's next, blockers.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Flutter file map, data flow, storage.
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — ADR-001…021 (the "why" behind non-obvious choices).
- [`docs/superpowers/specs/2026-06-11-ketchup-full-visual-spec-v2.html`](docs/superpowers/specs/2026-06-11-ketchup-full-visual-spec-v2.html) + [`plans/2026-06-12-ketchup-v1-rebrand.md`](docs/superpowers/plans/2026-06-12-ketchup-v1-rebrand.md) — current design (ketchup v1). Earlier specs/plans are listed in CONTINUE's spec/plan stack.

**Active codebase: `daily_command_center/` (Flutter), branded `ketchup`.** `daily-command-center.html` at the repo root is the retired HTML original — do not edit it.

## What this is

A Flutter Android app, **ketchup** — "the day planner that catches you up." A rich **Life JSON** plan + a drift-aware engine: when you fall behind, ketchup *squeezes* the flexible blocks and protects the locked (anchor) ones. One merged "Today" surface, a week planner, per-day adherence, a Sunday catch-up. Product direction (post-v1): a configurable life-execution app with AI-synthesized routines + a conversational onboarding interview. v1 ships for Cyrus only as a release APK.

## The owner (so advice stays relevant)

- 5'7", ~67 kg, skinny-fat beginner lifter. Pune, India.
- Equipment: two 5 kg dumbbells at home; bench machine + treadmill in the society gym.
- Job 2:00–8:00 PM, office 10 min away, WFH 1 day/week. Wakes ~8 AM, sharpest in the morning.
- Building AI projects + practicing DSA to switch careers by year-end. Self-described beginner — **plain language, minimal jargon.** Wants token-frugal, high-signal work.
- Goal physique: lean & defined (~12–14% BF), NOT big/bulky.

## Product decisions — don't undo by accident

- **Gentle calorie deficit (~200–400 below maintenance), NOT a surplus** — deliberate; small deficit + high protein drives recomposition for a skinny-fat beginner.
- **Protein ~130–145 g/day** (higher because cutting protects muscle).
- **Soya chunks** capped ~50 g dry/day, rotated with other sources — not the sole protein.
- **Double progression**: add reps within range, then make it harder (or add bench-machine weight) once the top of the range is hit on all sets. The app's rep-decision rules must stay consistent.
- **Meals reflect the real day**: big-protein brunch ~11:30, office lunch at 3 PM, light snack at 5 PM — not a noon lunch.
- **Evening chill is protected** — no forced night productivity; don't pack it.
- **Storage is local** (file-per-profile JSON; no backend/cloud sync) — note this when relevant.

## Health/safety

General fitness info, not medical advice — keep the in-app disclaimer. Never promote extreme deficits, crash dieting, or training through joint pain; the plan's cut-back rules exist for that reason.

## Working conventions

- Explain changes in plain terms; keep copy plain with the occasional analogy.
- **Minimize tokens, maximize accuracy + design.** Lead with the answer; prune dead docs rather than let them grow.
- Architecture/invariants live in ARCHITECTURE.md + CONTINUE.md — follow them (file-per-profile storage, `TimelineAssembler` is the only block source, all color via `context.c` tokens, golden test is the net).
