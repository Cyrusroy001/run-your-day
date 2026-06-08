# Local Profiles, Login, App Shell & Side Panel

**Date:** 2026-06-07
**Status:** Approved design
**Applies to:** `daily_command_center/` (Flutter app)
**Related:** [`2026-06-07-life-json-v3-drift-engine-design.md`](2026-06-07-life-json-v3-drift-engine-design.md) (the core engine). This work pulls the *onboarding* and *multi-profile* ideas (roadmap sub-projects 3–5) forward in a deliberately minimal, local-only form.
**Implementation plan:** [`../plans/2026-06-07-local-profiles-login-app-shell.md`](../plans/2026-06-07-local-profiles-login-app-shell.md)

> **Sequencing + storage update (2026-06-08).** This feature is sequenced to ship **after the v3 core**, and §3's storage approach was revised from "one JSON file per profile" to a **per-profile key prefix** (file → export/import backup) to avoid re-plumbing v3's SharedPreferences-based stores. See **ADR-019** and the plan. The §3 prose below is kept for context; the prefix approach is the one that ships.

---

## 1. Goal

Turn the single-user dashboard into a **multi-profile, login-gated app** that still runs entirely on-device:

- A **login screen** that is a local **profile picker** — no passwords, no backend.
- Logging in as **`cyrus`** lands on today's fully-seeded app.
- Any **new profile** runs a short **onboarding stub** that builds a usable plan.
- **Logout / switch profile** returns to the login screen.
- A **side panel (navigation drawer)** that splits today's single screen into focused sections and is the app's navigation hub.
- The result must be **visually polished and professionally designed** (see §7).
- The design is **scalable**: adding profiles, screens, or onboarding depth later requires no rework of the core.

### Explicit non-goals

No passwords, no backend, no cloud sync (the app stays local — consistent with the core spec's local-only constraint). No real authentication. No v3 drift engine. No real conversational interview. No editable schedule *times* (they remain hardcoded until the v3 engine lands). Placeholder screens navigate but do nothing. The stale root `daily-command-center.html` is untouched.

---

## 2. Architecture & routing

A new root widget **`AuthGate`** replaces `home: HomeScreen()` in `main.dart`.

```
main() → MaterialApp(home: AuthGate)

AuthGate
 ├─ reads activeProfileId (shared_preferences pointer)
 ├─ none      → LoginScreen
 └─ present   → load ProfileData from file → AppShell(profile)
```

- **`LoginScreen`** — the profile picker. Shows existing profiles (tap to enter) and a "New profile" name field.
  - Name matches an existing profile → enter it (set `activeProfileId`, go to `AppShell`).
  - Name is new → run the **onboarding stub** → create the profile file → enter `AppShell`.
- **Logout / switch profile** — clears `activeProfileId`, returns to `LoginScreen`. The in-memory `ProfileData` is dropped.

### The "cyrus" first-run seed

On first-ever launch (no `profiles/` directory yet) the app **seeds a `cyrus` profile** from today's hardcoded default (`PlannerLogic.defaultWeek()` + the default workouts). If legacy flat keys exist from earlier builds, they are migrated in (§3). So logging in as `cyrus` shows exactly today's app, with history intact.

Profile **id** is the lower-cased, trimmed name (`"Cyrus"` → `cyrus`); `displayName` preserves the entered casing. Two profiles cannot share an id.

---

## 3. Storage — one JSON file per profile *(SUPERSEDED — ships as a per-profile key prefix; see the update banner at top + ADR-019)*

Originally chosen over key-prefixing for clean physical isolation and trivial export/import. Reversed after reading the v3 plan (every store is SharedPreferences-key based and v3 adds another): the shipping approach is a central per-profile **key prefix** (`p_<id>__<base>`), with the JSON file kept as the export/import backup format. The original write-up follows for context.

### Layout

```
‹appDocumentsDir›/profiles/‹id›.json     # one file per profile
shared_preferences: "activeProfileId"     # tiny pointer to who is logged in
```

### `ProfileData` shape

```jsonc
{
  "meta": { "id": "cyrus", "displayName": "Cyrus",
            "archetype": "Recomp + career switch", "createdAt": "2026-06-07T..." },
  "plan":      { /* WeekPlan: { mon: {schedule, isTraining}, ... } */ },
  "logs":      { "A": [ /* WorkoutLog */ ], "B": [], "BENCH": [], "CARDIO": [] },
  "adherence": { "done":   { "2026-06-07": ["08:00|Wake ...", ...] },
                 "scores": { "2026-06-07": { "done": 4, "total": 7 } } }
  // future: "driftLog": [ ... ]  (v3 engine)
}
```

### `ProfileRepository` (new)

The single entry point for profile-level persistence:

| Method | Behavior |
|---|---|
| `listProfiles()` | enumerate `profiles/*.json`, return `[{id, displayName}]` |
| `createProfile(displayName, plan)` | write a new file, return `ProfileData` |
| `load(id)` | read + parse a file into `ProfileData` (own try-catch fallback) |
| `save(ProfileData)` | serialize + write the whole file |
| `delete(id)` | remove the file; clear `activeProfileId` if it pointed here |
| `export(id)` | return the raw JSON string |
| `import(jsonString)` | validate + write a profile file (id collision → error/suffix) |
| `activeProfileId` get/set | read/write the `shared_preferences` pointer |

The repository **owns the active `ProfileData` in memory**; mutations persist the file.

### Refactor of existing stores

`AppStore` and `AdherenceStore` stop reading flat global keys and instead **read/write through the active profile's `ProfileData`** (plan, logs, adherence). Their *public method shapes stay as close as possible* so screen code changes minimally. `writeWidgetData` still operates on whatever plan is active.

### First-run migration (one-time, throwaway-friendly)

If `profiles/` is absent but legacy keys (`weekPlan`, `log_A/B/BENCH/CARDIO`, `done_<date>`, `adherence_<date>`) exist, build `cyrus.json` from them. If no legacy data exists either, seed `cyrus` from the Dart defaults. Either way `cyrus` exists after first run.

---

## 4. Onboarding stub (new profiles only)

A short, friendly flow whose **only output is a valid plan** — so the real interview tree (roadmap sub-project 3) can replace it later without touching anything downstream.

Steps:
1. **Welcome** — one warm screen explaining the app in plain language.
2. **Confirm name** (pre-filled from what they typed on login).
3. **Weekday pattern** — for each day pick `office / wfh / weekend / off`.
4. **Training days** — choose how many days/week; the **existing `PlannerLogic`** auto-spaces them (4 days, no consecutive, etc.).

It builds a `WeekPlan` from the default template, creates the profile file, sets it active, and enters the app. Schedule **times** (wake, work, meals) are shown **read-only** with a "you'll be able to customize these later" note — they're hardcoded until the v3 engine.

---

## 5. App shell & side panel

**`AppShell`** = a `Scaffold` with an `AppBar` (hamburger + active profile name), a `Drawer`, and a body that swaps by the selected section (a `NavSection` enum + `IndexedStack`/switch). The current "Today does everything" screen splits into focused destinations:

| Group | Destination | State |
|---|---|---|
| **PLAN** | **Today** — decorative header + `NowCard` | LIVE (from existing home) |
| | **Full Day Timeline** — existing `today_screen` | LIVE |
| | **Week Planner** — 7-day grid, **pulled out of home into its own screen** | LIVE |
| **TRACK** | Workouts & Log | placeholder ("coming soon") |
| | Goals (DSA) | placeholder |
| | Nutrition | placeholder |
| **REVIEW** | Weekly Review | placeholder |
| — | **Settings** | LIVE (§6) |
| — | **Log out / Switch profile** | LIVE |

The drawer header shows avatar (initial), `displayName`, and `archetype`. Placeholder screens are real, navigable, and share one tasteful "coming soon" component (so they look intentional, not broken).

The decorative header text changes from hardcoded `CYRUS` to the **active profile's** name/archetype.

---

## 6. Settings (scope)

**Wired now:** Profile (display name; Switch profile / Log out) · **Delete this profile** (wipes the file, returns to login) · **Export / Import data** (copy out / paste in this profile's JSON — the only on-device backup) · **Reset plan to default** (re-seed plan from the template) · **Clear logged history** (wipe logs/adherence, keep the plan) · **About** (app name/version + the health disclaimer).

**Placeholder / later:** schedule times (need the v3 engine), theme toggle (optional), notifications (v3 circuit-breaker).

---

## 7. Visual design & UX (first-class requirement)

The app must look **professionally designed**, not like scaffolding. The `frontend-design` skill is applied during implementation. Constraints and intent:

- **Reuse the established design language.** Keep the existing palette (`AppColors` — deep green `bg`, terracotta `terra`, cream text, moss/amber/sky accents) and type pairing (**Fraunces** display + **Spline Sans** body). Do not introduce a second visual language.
- **Login screen** — warm, branded, calm. Profile cards/avatars with the initial, generous spacing, a clear primary action. Feels like an app's front door, not a form.
- **Onboarding** — friendly, progressive, low-friction (taps/sliders over typing), a visible progress indicator, plain-language copy matching the owner's preference, and an encouraging finish.
- **Drawer** — smooth open/close, clear active-state highlight (terracotta left-rail), grouped labels, consistent iconography, profile header at top, logout visually distinct at the bottom.
- **Placeholder screens** — one polished, reusable "coming soon" treatment so they read as intentional.
- **Micro-interactions** — tasteful transitions between destinations, button/tap feedback, loading and empty states that aren't bare spinners where it matters.
- **Consistency & hierarchy** — shared spacing scale, consistent card styling, strong typographic hierarchy. Accessible contrast and tap targets.

---

## 8. Testing strategy

- **`ProfileRepository`** — create/list/load/delete; export↔import roundtrip is lossless; **isolation** (writing profile B never affects profile A); first-run cyrus seed; legacy-key migration produces a correct `cyrus.json`.
- **`AuthGate` routing** — no active profile → `LoginScreen`; active → `AppShell`; logout → `LoginScreen`.
- **Login / new-profile** — existing name enters that profile; new name routes to onboarding then into the app; id normalization + collision handling.
- **Onboarding stub** — produces a valid `WeekPlan`; a brand-new profile lands on a working Today; training-day spacing still satisfied by `PlannerLogic`.
- **Settings** — delete removes the file and logs out; reset restores the default plan; clear-history empties logs/adherence but keeps the plan.
- **Regression** — all existing tests (planner, timeline, models, now_card, week_planner, adherence) stay **green**; the storage refactor preserves behavior for the active profile.

---

## 9. Success criteria

- Launch with no data → seeded `cyrus` profile; login as `cyrus` → today's app, history intact.
- A new name → onboarding stub → working personalized Today, fully isolated from `cyrus`.
- Drawer navigates all destinations; placeholders look intentional.
- Logout/switch works; deleting a profile removes only its data.
- Export then import on a fresh install restores a profile exactly.
- The UI reads as a polished, professionally designed product using the existing design language.
- Adding a new profile or a new drawer destination later needs no core rework.
