# Plan — Ketchup v1 (rebrand + ship, Cyrus-only)

**Created:** 2026-06-12
**Spec:** [`specs/2026-06-11-ketchup-full-visual-spec-v2.html`](../specs/2026-06-11-ketchup-full-visual-spec-v2.html)
**Branch base:** `feat/local-profiles` (current integration head). New work on `feat/ketchup-v1`.

---

## Goal

Ship a **v1 for Cyrus only**: the ketchup presentation-layer rebrand on top of the
already-complete v3 engine + data layers, delivered as a **signed release APK** installed
on the phone. The current UI is the "v1 build" the ketchup spec's BAN LIST rejects
(stat tiles, "Reflowed" jargon, Fraunces, terra/moss/amber, two Today surfaces) — this
plan replaces that presentation layer wholesale.

## Explicitly OUT of scope (deferred past v1)

- **Android home-screen widget redesign** — current widget code stays untouched; it is the
  first post-v1 task. (Broken on Samsung One UI / Android 16, unconfirmed root cause — ADR-010.
  The ketchup spec itself gates the new widget to "phase 2.")
- **Interview tree, AI generation, full onboarding, in-app Life-JSON editor, continual
  refinement loop** — the entire "for other people" product stack. `OnboardingLogic.commit`
  stays the seam they'll later replace. (The Sunday "Give it more time" write in K7 is the
  one feedback-loop hook we keep, because it's part of this spec.)
- **Cloud sync / backup** — stated non-goal. Data stays local (file-per-profile + clipboard
  export). v1 surfaces a one-line "your data is local only" note; nothing more.

## Unchanged (do not touch)

`lib/logic/` (engine A–D: assembler, DriftEngine, drift_runner, weekly_review, priority_level,
home_now_state, drift_copy) and `lib/data/` (ProfileRepository, StateStore, AdherenceStore,
notifications, recurring_store, teaching_flags). The **only** content change is K1
(label/duration split in `seed_plan.json`), which re-baselines the golden test.

---

## Phases (TDD; keep every guard test green)

### K0 — Brand foundation *(blocks everything)*
- Rewrite [`lib/theme/app_palette.dart`](../../../daily_command_center/lib/theme/app_palette.dart):
  token set → `char/raise/raise2/salt/dim/line` + `tomato/tomatoDim/mustard/mustardDim/leaf/leafDim`,
  hexes from spec §0 (dark default + light). Keep `ThemeExtension` shape + `context.c`.
  Drop unused `sky`/`muted` if nothing needs them.
- Fonts: `GoogleFonts.fraunces` → `bricolageGrotesque` (display); keep `splineSans` (body);
  add `splineSansMono` (data — every time/duration/delta string). google_fonts 6.3.3 has all three.
- Migrate **all** callsites (every `c.terra/c.moss/c.amber/bg/panel/panel2/cream`, every Fraunces).
  Use `flutter analyze` to enumerate breakage; fix to green.
- Rename app label → `ketchup` (in-app lowercase): `android/.../strings.xml`, `pubspec.yaml`,
  `main.dart`. Store label string "Ketchup — flexible day planner" noted for K-ship.
- Regenerate icon: update [`tool/make_icon.py`](../../../daily_command_center/tool/make_icon.py)
  with the §4 squiggle path; adaptive fg = squiggle on transparent; monochrome = char squiggle on salt.
- Contrast check: tomato-on-white button text ≥ 4.5:1; darken to `#A63A27` if it fails.
- **Done when:** app builds, runs, all existing tests green with renamed tokens; no Fraunces left.

### K1 — Content fix (Life-JSON labels)
- In [`assets/seed_plan.json`](../../../daily_command_center/assets/seed_plan.json) strip durations
  from labels: "BIG Project Block (2 hrs)" → "Big project"; "DSA Practice (45 min)" → "DSA practice";
  "Walk to office (10 min)" → "Walk to office"; "Work — 2:00 to 8:00" → "Work" (duration stays in
  `idealDuration`/anchor end).
- Re-baseline the golden test (`test/logic/golden_timeline_test.dart`) — it will fail; that's the net.

### K2 — `elastic_rail.dart` (signature widget)
- New `lib/widgets/elastic_rail.dart`. Spine height ∝ duration (clamp 56–120 dp). Variants:
  normal / squeeze (dashed mustard spine + one mono delta) / anchor (◉, solid salt spine) /
  skip (line-through, 0.45 opacity) / done (leaf tint). Tap card = toggle done (no checkbox chrome).
- Replaces `budget_bar` + `anchor_wall` + the per-row ⚠/checkbox stacks. TDD widget tests first.

### K3 — Merged Today surface (`today_screen.dart`)
- Recreate `lib/screens/today_screen.dart` (name was deleted in U7.2) as ONE widget tree:
  past-pill → hero (enlarged first stop: NOW pill, range, big block name, squeeze/ok chip,
  thin progress, minutes-left + Done) → one whisper (from `DriftCopy`) → optional teach caption →
  elastic rail ("Rest of today") → ADJUST entry. States: caughtUp / squeezed / adjusting from
  `ResolvedDay` + `isAdjusting`.
- Fold `home_screen` + `live_timeline_view` into this. Header = date + avatar **only**
  (delete "Run the day." slogan, delete `_miniStrip` stat tiles + "Reflowed" pill).

### K4 — Adjust mode (state of Today)
- Two-row card: name + drag handle (top); priority segmented (Protect/Normal/Drop first) +
  "✕ skip" button (bottom). Flex layout, **no** Positioned/Stack (fixes the v1 overlap bug),
  targets ≥ 44 dp. Words map to numeric via existing `PriorityLevel`. Reorder + skip-for-today
  write **DailyState only**; anchors are read-only (point to Plan my week). Session-persistent Undo bar.

### K5 — Teach captions + "How ketchup works"
- `lib/widgets/teach_caption.dart` — one dismissible caption ≤ 90 chars, seen-flags via existing
  `teaching_flags.dart`, max one visible at a time. First-squeeze + first-anchor copy from §2.
- `lib/screens/how_it_works_screen.dart` — six static captions from S9. **Replaces**
  `glossary_screen.dart`.

### K6 — Off-Home screens
- `lib/screens/week_screen.dart` — "Plan my week" off Home; day templates as user-named
  Life-JSON strings (no hardcoded Train/Rest toggle); inline leaf captions (no toasts).
  Migrate `WeekPlanner` here.
- `avatar_menu_sheet.dart` → five items (Plan my week / Sunday catch-up / Appearance & text size /
  Heads-up notifications / How ketchup works); "new" badge on the catch-up row on Sundays only.
- `settings_screen.dart` rework — theme seg (Light/Dark/Auto), text-size slider (drives
  textScaleFactor app-wide), two notification toggles, About (version "1.0 · made in Pune").
  Keep the PROFILE/DATA sections (export/import/reset/clear/delete) — they're personal-v1 useful.

### K7 — Sunday catch-up
- `lib/screens/catchup_screen.dart` over `WeeklyReview.summarize`: headline, kept-count, day bars,
  one insight, "Give it more time" / "Keep as is". "Give it more time" writes `+idealMinutes` into
  the Plan — the only review→Plan write path (the one feedback hook we keep). Surfaced via the
  avatar Sunday badge.

### K8 — Motion + guards + retire
- Exactly three animations: squeeze compress (350 ms ease-out, mustard delta counts up);
  Done → leaf tint + collapse into past-pill; sheet/mode transitions (standard). Respect
  `prefers-reduced-motion`.
- New guard tests (add to `test/guard/`): (a) no `Color(0x…)`/`Colors.` literal outside
  `app_palette.dart`; (b) no "⚠" / "budget" / "Reflowed" / "engine" string anywhere in `lib/`.
  Keep `no_hardcoded_life_strings_test.dart`.
- textScale 1.3× survival test (nothing truncates).
- Delete after migration: `now_card`(gone already), `now_hero_card`, `live_timeline_view`,
  `glossary_screen`, `budget_bar`, `anchor_wall`, `weekly_review_card`, on-Home `week_planner` usage.

### K-notify — The one notification (ship-blocker)
- Wire S7's two toggles to real scheduling on top of the existing `NotificationService`
  (ADR-014 built the channel): one opt-in heads-up per block ("{label} in 10 — you're all caught up"
  / "…running ~15 behind. I'll catch you up."), plus the Sunday 7pm nudge. Verify delivery on device.

### K-ship — Release APK (ship-blocker)
- Create a release keystore (`key.properties`, not committed); replace the debug-signing TODO in
  `android/app/build.gradle.kts` release block. `flutter build apk --release`, install on the S21 FE.
- Real-device QA pass: drift across a real day, profile switch/onboarding, midnight rollover,
  empty-evening + no-plan states, light/dark/auto, 1.3× text. ≥44 dp targets, ≥4.5:1 contrast,
  reduced-motion.

---

## Sequencing

K0 → K1 first (foundations). K2–K7 can interleave (K3 depends on K2; K4 depends on K3).
K8 closes the rebrand. K-notify and K-ship run last. Widget stays deferred.

## Invariants (unchanged from CONTINUE.md)

File-per-profile storage · `TimelineAssembler` is the only block source · golden test is the
correctness net · `buildTimes` monotonic + PM disambiguation · adherence counts trackable blocks
only · `home_widget` raw keys · `writeWidgetData` stays try-catch.
