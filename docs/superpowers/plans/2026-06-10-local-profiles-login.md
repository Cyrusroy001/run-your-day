# Local Profiles & Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the single-user app into a local, login-gated multi-profile app: a profile-picker login screen, an onboarding stub for new profiles, per-profile data (already isolated), and profile management (switch / logout / delete / export / import / reset / clear history) — all on-device, no backend.

**Architecture:** A new root widget `AuthGate` listens to a `ValueNotifier<String?> activeProfile` and shows `LoginScreen` when it is null, `HomeScreen` when it is a profile id. The existing **file-per-profile** `ProfileRepository` (which already namespaces every store via `AppStore.repo`) gains the multi-profile API it lacks: create, delete, list-with-names, export/import, reset, clear-history, and a *nullable* active pointer so "logged out" is representable. New profiles run an `OnboardingScreen` that clones the bundled seed `Plan`, applies week + training-day choices, and saves. The app's existing **avatar-menu** navigation (not a drawer) is wired up: its already-present `onSwitchProfile`/`onLogout` callbacks become real, and Settings grows Account + Data sections.

**Tech Stack:** Flutter/Dart, `shared_preferences` (active pointer), `path_provider` (profile files), `google_fonts`, `intl`. No new packages.

---

## Reference docs (read before starting)

- Design spec: [`../specs/2026-06-07-local-profiles-login-app-shell-design.md`](../specs/2026-06-07-local-profiles-login-app-shell-design.md)
- Superseded prior plan (do **not** execute): [`2026-06-07-local-profiles-login-app-shell.md`](2026-06-07-local-profiles-login-app-shell.md)
- Decisions: ADR-018/019 in [`../../DECISIONS.md`](../../DECISIONS.md)
- Status: [`../../CONTINUE.md`](../../CONTINUE.md)

---

## Reconciliation with shipped code (why this plan differs from the 2026-06-07 plan)

The 2026-06-07 plan was written before the v3 + UX-layer + custom-tasks work shipped. It is stale in three load-bearing ways; this plan supersedes it:

| Old plan assumed | Reality on `feat/custom-tasks` | This plan |
|---|---|---|
| Build `ProfileScope` key-prefixing + refactor every store (Phases 0–1) | **`ProfileRepository` already does file-per-profile** isolation; `StateStore`/`AdherenceStore`/`AppStore` all route through `AppStore.repo.loadActive()/save()` | **No `ProfileScope`.** Extend the existing repo only. |
| `AppColors.bg/.terra/.cream` constants | `AppColors` **deleted**; theme is `AppPalette` via `context.c` (light+dark, so colors are runtime, not `const`) | All new UI uses `context.c`; no `const` color widgets. |
| Drawer-based `AppShell` splitting Today/Timeline/Week + `ComingSoon` placeholder sections | Navigation is an **avatar menu** (`showAvatarMenu`) over Home (today+week inline) + `LiveTimelineView`. `onSwitchProfile`/`onLogout` are **already stubbed** in `home_screen.dart` | **No Drawer / AppShell / placeholder sections.** Wire the existing avatar menu. (If a drawer is wanted later, it is additive and out of scope here.) |
| `SettingsScreen` is created | `settings_screen.dart` **already exists** (theme + text-size) | **Modify** it; add Account + Data sections. |
| Active pointer always resolvable | `ProfileRepository.activeProfileId()` defaults to `'cyrus'` — no logged-out state | Add a **nullable** active pointer + a `ValueNotifier` so logout works. |

**Dropped from the old plan (explicit non-goals here):** `ProfileScope`, store key-prefixing/migration, `AppShell`, navigation `Drawer`, `ComingSoon`, `TodayView` extraction, placeholder Workouts/Goals/Nutrition/Weekly-Review sections.

---

## Existing APIs this plan builds on (verified)

- `lib/data/profile_repository.dart`
  - `class ProfileDoc { id, displayName, plan, states, logs, done, adherence, recurringTasks, skippedRepeatIds; fromJson/toJson/copyWith }`
  - `class ProfileRepository` — instance, injectable `baseDir`. Has: `activeProfileId() → Future<String>` (defaults `'cyrus'`), `setActiveProfileId(id)`, `listProfiles() → Future<List<String>>` (ids), `loadActive()`, `load(id)` (seeds from `assets/seed_plan.json` if file absent), `save(doc)`. Const `defaultProfileId = 'cyrus'`, `_activeKey = 'activeProfileId'`.
- `lib/data/store.dart` — `AppStore.repo` (the shared `ProfileRepository`), `loadPlan()`, `savePlan(plan)`, `loadLogs/saveLogs`, `writeWidgetData(plan, todayKey)`, `refreshWidgetData()`.
- `lib/data/state_store.dart`, `lib/data/adherence_store.dart` — all route through `AppStore.repo`.
- `lib/theme/app_palette.dart` — `AppPalette` fields: `bg, panel, panel2, cream, muted, dim, line, terra, terraD, moss, mossD, amber, amberD, sky`; `context.c` getter; `AppPalette.lightTheme/darkTheme`.
- `lib/main.dart` — `RemindersApp` (`MaterialApp`, `home: const HomeScreen()`); `RemindersApp.of(context)` exposes `prefs`/`updatePrefs`.
- `lib/screens/home_screen.dart` — header hardcodes `'Cyrus'`/`'C'`; `showAvatarMenu(..., onSwitchProfile: () {}, onLogout: () {})` are stubs; `meta.lifestyleArchetype` is the subtitle.
- `lib/widgets/avatar_menu_sheet.dart` — `showAvatarMenu(context, {name, subtitle, onSwitchProfile, onOpenSettings, onOpenGlossary, onLogout})`.
- `lib/logic/planner.dart` — `PlannerLogic.applyBestSpacing(plan)`, `toggleTraining`, `toggleSchedule`. `WeekEntry.copyWith(templateId, training, workoutId)`. `Plan.copyWith(week, dayTemplates)`; `PlanMeta { title, timezone, lifestyleArchetype }`.

---

## File structure

**Created**

| File | Responsibility |
|---|---|
| `lib/screens/auth_gate.dart` | `AuthGate` root widget + the `activeProfile` `ValueNotifier`; routes Login vs Home. |
| `lib/screens/login_screen.dart` | `LoginScreen` — profile picker + "new profile" entry. |
| `lib/screens/onboarding_screen.dart` | `OnboardingScreen` — 3-step stub → builds + saves a new profile's plan. |
| `lib/logic/onboarding.dart` | `OnboardingLogic.buildPlan` — pure: seed `Plan` + choices → new `Plan`. |
| `test/...` | one test file per unit (named per task). |

**Modified**

| File | Change |
|---|---|
| `lib/data/profile_repository.dart` | Add `ProfileMeta`, `idFor`, `listProfileMetas`, `createProfile`, `delete`, `exportProfile`, `importProfile`, `clearHistory`, `resetPlan`, `ensureSeeded`, nullable active (`activeProfileIdOrNull`, `clearActive`); make `setActiveProfileId`/`clearActive` update `activeProfile` notifier. |
| `lib/logic/planner.dart` | Add `setTrainingFrequency(plan, n)`. |
| `lib/main.dart` | `await AppStore.repo.ensureSeeded()` + init `activeProfile` before `runApp`; `home:` → `AuthGate`. |
| `lib/screens/home_screen.dart` | Load active profile's display name; show it in header + avatar; wire `onSwitchProfile`/`onLogout`. |
| `lib/screens/settings_screen.dart` | Add ACCOUNT (switch/logout/delete) + DATA (export/import/reset/clear-history) + ABOUT (disclaimer) sections. |

---

## Conventions for every task

- **TDD:** failing test → run (confirm fail) → minimal implementation → run (confirm pass) → commit.
- **Run tests** from `daily_command_center/`: `flutter test test/path/file.dart` (one) or `flutter test` (all).
- **Repo tests** inject a temp dir: in `setUp`, `SharedPreferences.setMockInitialValues({}); AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());`. This is the established pattern from the custom-tasks tests.
- **Colors:** never `const` a widget that carries a palette color; read `final c = context.c;` in `build`.
- **Commit** after each green task with the message shown.
- **Branch:** continue on `feat/custom-tasks` (the superset branch), or branch `feat/local-profiles` off it.

---

## Phase 0 — Repository multi-profile API (data layer)

> Outcome: the repo can list profiles with names, create/delete them, represent "logged out", and export/import — with isolation already guaranteed by the file-per-profile design.

### Task L1: `ProfileMeta` + `idFor` + `listProfileMetas`

**Files:**
- Modify: `lib/data/profile_repository.dart`
- Test: `test/data/profile_meta_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
  });

  test('idFor normalizes display names', () {
    expect(ProfileRepository.idFor('  Cyrus '), 'cyrus');
    expect(ProfileRepository.idFor('Alex P'), 'alex_p');
  });

  test('listProfileMetas returns id + displayName for each profile file', () async {
    await AppStore.repo.load('cyrus');   // seeds cyrus.json (displayName "Cyrus")
    final metas = await AppStore.repo.listProfileMetas();
    expect(metas.map((m) => m.id), contains('cyrus'));
    expect(metas.firstWhere((m) => m.id == 'cyrus').displayName, 'Cyrus');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_meta_test.dart`
Expected: FAIL — `idFor` / `ProfileMeta` / `listProfileMetas` not defined.

- [ ] **Step 3: Implement.** In `profile_repository.dart`, add the `ProfileMeta` class above `ProfileRepository`:

```dart
/// Lightweight profile descriptor for the login picker / drawer header.
class ProfileMeta {
  final String id;
  final String displayName;
  final String archetype;
  const ProfileMeta({required this.id, required this.displayName, this.archetype = ''});
}
```

Add inside `ProfileRepository`:

```dart
  /// Lower-cased, trimmed, spaces→underscores. The storage id for a display name.
  static String idFor(String displayName) =>
      displayName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  /// Every profile on disk, with display name + archetype (reads each file).
  Future<List<ProfileMeta>> listProfileMetas() async {
    final ids = await listProfiles();
    final metas = <ProfileMeta>[];
    for (final id in ids) {
      final doc = await load(id);
      metas.add(ProfileMeta(
        id: doc.id,
        displayName: doc.displayName,
        archetype: doc.plan.meta.lifestyleArchetype,
      ));
    }
    return metas;
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_meta_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_meta_test.dart
git commit -m "feat(profiles): ProfileMeta + idFor + listProfileMetas"
```

### Task L2: Nullable active pointer + `activeProfile` notifier

**Files:**
- Modify: `lib/data/profile_repository.dart`
- Test: `test/data/profile_active_test.dart`

This is the gap that makes "logged out" representable. The existing `activeProfileId()` (defaults to `'cyrus'`) stays for store back-compat; we add a nullable getter and a notifier that the UI listens to.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    activeProfile.value = null;
  });

  test('fresh store → activeProfileIdOrNull is null (logged out)', () async {
    expect(await AppStore.repo.activeProfileIdOrNull(), isNull);
  });

  test('setActiveProfileId sets pointer + notifier; clearActive resets both', () async {
    await AppStore.repo.setActiveProfileId('cyrus');
    expect(await AppStore.repo.activeProfileIdOrNull(), 'cyrus');
    expect(activeProfile.value, 'cyrus');

    await AppStore.repo.clearActive();
    expect(await AppStore.repo.activeProfileIdOrNull(), isNull);
    expect(activeProfile.value, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_active_test.dart`
Expected: FAIL — `activeProfile` / `activeProfileIdOrNull` / `clearActive` not defined.

- [ ] **Step 3: Implement.** At the top of `profile_repository.dart` (after imports), add the app-wide notifier:

```dart
import 'package:flutter/foundation.dart';
// ... existing imports ...

/// The logged-in profile id, or null when logged out. [AuthGate] listens to
/// this; [ProfileRepository] keeps it in sync with the persisted pointer.
final ValueNotifier<String?> activeProfile = ValueNotifier<String?>(null);
```

Add inside `ProfileRepository`:

```dart
  /// The raw active pointer — null when logged out (unlike [activeProfileId],
  /// which defaults to [defaultProfileId] for store back-compat).
  Future<String?> activeProfileIdOrNull() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  /// Log out: clear the pointer + notifier.
  Future<void> clearActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    activeProfile.value = null;
  }
```

And update the existing `setActiveProfileId` to keep the notifier in sync:

```dart
  Future<void> setActiveProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
    activeProfile.value = id;
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_active_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_active_test.dart
git commit -m "feat(profiles): nullable active pointer + activeProfile notifier"
```

### Task L3: `createProfile` + `delete` (with isolation)

**Files:**
- Modify: `lib/data/profile_repository.dart`
- Test: `test/data/profile_crud_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    activeProfile.value = null;
  });

  test('createProfile writes a file, sets active, and seeds a plan', () async {
    final doc = await AppStore.repo.createProfile('Alex P');
    expect(doc.id, 'alex_p');
    expect(doc.displayName, 'Alex P');
    expect(await AppStore.repo.activeProfileIdOrNull(), 'alex_p');
    expect((await AppStore.repo.listProfiles()), contains('alex_p'));
    expect(doc.plan.schemaVersion, 3);
  });

  test('profiles are isolated — logs under one are invisible to another', () async {
    await AppStore.repo.createProfile('Cyrus');
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '10')]);

    await AppStore.repo.createProfile('Alex');
    expect(await AppStore.loadLogs('A'), isEmpty);

    await AppStore.repo.setActiveProfileId('cyrus');
    expect((await AppStore.loadLogs('A')).single.reps, '10');
  });

  test('delete removes the file and clears active if it pointed there', () async {
    await AppStore.repo.createProfile('Cyrus');
    await AppStore.repo.delete('cyrus');
    expect(await AppStore.repo.listProfiles(), isNot(contains('cyrus')));
    expect(await AppStore.repo.activeProfileIdOrNull(), isNull);
  });
}
```

> Confirm `WorkoutLog`'s constructor params (`date`, `reps`) against `lib/data/models.dart`; if they differ, adjust the literals. The custom-tasks tests already construct `WorkoutLog` — copy from there if unsure.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_crud_test.dart`
Expected: FAIL — `createProfile` / `delete` not defined.

- [ ] **Step 3: Implement.** Add inside `ProfileRepository`:

```dart
  /// Create a new profile, make it active, and persist it. If [plan] is null the
  /// profile is seeded from the bundled blueprint (via [load]); onboarding passes
  /// a customized plan. An existing id is overwritten.
  Future<ProfileDoc> createProfile(String displayName, {Plan? plan}) async {
    final id = idFor(displayName);
    final ProfileDoc doc;
    if (plan != null) {
      doc = ProfileDoc(id: id, displayName: displayName.trim(), plan: plan);
      await save(doc);
    } else {
      // load() seeds + saves a fresh doc from the asset when the file is absent.
      final seeded = await load(id);
      doc = seeded.copyWith(displayName: displayName.trim());
      await save(doc);
    }
    await setActiveProfileId(id);
    return doc;
  }

  /// Delete a profile's file. If it was the active profile, log out.
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
    if (await activeProfileIdOrNull() == id) await clearActive();
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_crud_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_crud_test.dart
git commit -m "feat(profiles): createProfile + delete with isolation"
```

### Task L4: `exportProfile` / `importProfile`

**Files:**
- Modify: `lib/data/profile_repository.dart`
- Test: `test/data/profile_export_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    activeProfile.value = null;
  });

  test('export then import restores a profile losslessly', () async {
    await AppStore.repo.createProfile('Cyrus');
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '12')]);
    final blob = await AppStore.repo.exportProfile('cyrus');

    // Fresh store (new temp dir), then import.
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    final meta = await AppStore.repo.importProfile(blob);
    expect(meta.id, 'cyrus');
    expect(await AppStore.repo.listProfiles(), contains('cyrus'));

    await AppStore.repo.setActiveProfileId('cyrus');
    expect((await AppStore.loadLogs('A')).single.reps, '12');
  });

  test('exported blob is valid JSON carrying the ProfileDoc', () async {
    await AppStore.repo.createProfile('Cyrus');
    final blob = await AppStore.repo.exportProfile('cyrus');
    final decoded = jsonDecode(blob) as Map<String, dynamic>;
    expect(decoded['id'], 'cyrus');
    expect(decoded['plan'], isA<Map>());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_export_test.dart`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Implement.** Add inside `ProfileRepository` (note: a profile *is* its JSON file, so export = the file's contents):

```dart
  /// The profile's full JSON document (the export/import backup format).
  Future<String> exportProfile(String id) async =>
      jsonEncode((await load(id)).toJson());

  /// Recreate a profile from an exported blob. Overwrites an existing id.
  /// Returns its meta. Does NOT change the active pointer.
  Future<ProfileMeta> importProfile(String blob) async {
    final doc = ProfileDoc.fromJson(jsonDecode(blob) as Map<String, dynamic>);
    await save(doc);
    return ProfileMeta(
      id: doc.id, displayName: doc.displayName, archetype: doc.plan.meta.lifestyleArchetype,
    );
  }
```

> `jsonEncode` / `jsonDecode` need `import 'dart:convert';` — already imported in this file.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_export_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_export_test.dart
git commit -m "feat(profiles): export/import a profile document"
```

### Task L5: `clearHistory` + `resetPlan` + `ensureSeeded`

**Files:**
- Modify: `lib/data/profile_repository.dart`
- Test: `test/data/profile_actions_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    activeProfile.value = null;
  });

  test('clearHistory wipes logs/done/adherence/states but keeps the plan', () async {
    await AppStore.repo.createProfile('Cyrus');
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '9')]);
    final planBefore = await AppStore.loadPlan();

    await AppStore.repo.clearHistory('cyrus');

    expect(await AppStore.loadLogs('A'), isEmpty);
    expect((await AppStore.loadPlan()).schemaVersion, planBefore.schemaVersion); // plan survives
  });

  test('ensureSeeded creates cyrus on a fresh store but leaves you logged out', () async {
    await AppStore.repo.ensureSeeded();
    expect(await AppStore.repo.listProfiles(), contains('cyrus'));
    expect(await AppStore.repo.activeProfileIdOrNull(), isNull); // login still shown
  });

  test('ensureSeeded is idempotent and never duplicates cyrus', () async {
    await AppStore.repo.ensureSeeded();
    await AppStore.repo.ensureSeeded();
    expect((await AppStore.repo.listProfiles()).where((id) => id == 'cyrus').length, 1);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_actions_test.dart`
Expected: FAIL — `clearHistory` / `ensureSeeded` not defined.

- [ ] **Step 3: Implement.** Add inside `ProfileRepository`:

```dart
  /// Wipe a profile's logged history (logs, done sets, adherence, daily states),
  /// keeping the plan and recurring tasks.
  Future<void> clearHistory(String id) async {
    final doc = await load(id);
    await save(doc.copyWith(states: {}, logs: {}, done: {}, adherence: {}));
  }

  /// Re-seed a profile's plan from the bundled blueprint, keeping history.
  Future<void> resetPlan(String id) async {
    final seedRaw = await rootBundle.loadString(seedAsset);
    final plan = Plan.fromJson(jsonDecode(seedRaw) as Map<String, dynamic>);
    final doc = await load(id);
    await save(doc.copyWith(plan: plan));
  }

  /// First-run: ensure the default `cyrus` profile exists on disk WITHOUT
  /// logging in (so the login picker shows it). Idempotent.
  Future<void> ensureSeeded() async {
    if ((await listProfiles()).isNotEmpty) return;
    await load(defaultProfileId); // load() seeds + saves cyrus.json when absent
  }
```

> `rootBundle` is already imported in this file (`package:flutter/services.dart`).

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_actions_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_actions_test.dart
git commit -m "feat(profiles): clearHistory + resetPlan + ensureSeeded"
```

---

## Phase 1 — AuthGate routing

### Task L6: `AuthGate` + main.dart wiring

**Files:**
- Create: `lib/screens/auth_gate.dart`
- Modify: `lib/main.dart`
- Test: `test/screens/auth_gate_test.dart`

`AuthGate` is a `ValueListenableBuilder` over `activeProfile`: null → `LoginScreen`, id → `HomeScreen`. No `findAncestorState` plumbing — logout/login just mutate the notifier (and pop pushed routes). This sidesteps the Navigator-ancestor problem (pushed Settings is a sibling of `AuthGate`, not a descendant).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/screens/auth_gate.dart';
import 'package:daily_command_center/screens/login_screen.dart';
import 'package:daily_command_center/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('null active profile → LoginScreen', (tester) async {
    activeProfile.value = null;
    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('active profile → HomeScreen', (tester) async {
    activeProfile.value = 'cyrus';
    // HomeScreen renders immediately when given a debugPlan, so inject one to
    // avoid the async dart:io load under the test clock.
    await tester.pumpWidget(MaterialApp(home: AuthGate(homeBuilder: (id) => HomeScreen(debugPlan: testPlan()))));
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

// Minimal Plan for the test. Reuse the helper from existing widget tests if one
// exists (e.g. golden_timeline_test builds a Plan from the seed asset); otherwise
// load the seed: `await AppStore.repo.load('cyrus')` then `.plan`.
Plan testPlan() => /* build or load a Plan — see note */ throw UnimplementedError();
```

> **Test note:** building a `Plan` inline is verbose. Prefer the pattern other widget tests use. If they load the seed asset, do: make this `testWidgets` `async`, `final plan = (await AppStore.repo.load('cyrus')).plan;` after setting a temp `AppStore.repo`. The assertion only needs `HomeScreen` to be found, so any valid plan works. The `homeBuilder` seam exists precisely so the test can inject `debugPlan`.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/auth_gate_test.dart`
Expected: FAIL — `AuthGate` / `LoginScreen` not defined. (Create a minimal `LoginScreen` stub in L7 first, or stub it now and flesh out in L7.)

- [ ] **Step 3: Implement `auth_gate.dart`**

```dart
import 'package:flutter/material.dart';
import '../data/profile_repository.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Root widget: shows the login picker when logged out, the app when logged in.
/// Listens to [activeProfile]; flipping that notifier (login / logout) re-routes.
class AuthGate extends StatelessWidget {
  /// Test seam: build the logged-in screen (defaults to a real [HomeScreen]).
  final Widget Function(String profileId)? homeBuilder;
  const AuthGate({super.key, this.homeBuilder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: activeProfile,
      builder: (context, id, _) {
        if (id == null) return const LoginScreen();
        return homeBuilder?.call(id) ?? const HomeScreen();
      },
    );
  }
}
```

Then update `main.dart`:

```dart
// add import:
import 'data/profile_repository.dart';
import 'screens/auth_gate.dart';
// remove (no longer the direct home): import 'screens/home_screen.dart';  // keep if referenced elsewhere
```

In `main()` (after the existing widget/notification setup, before `runApp`):

```dart
  await AppStore.repo.ensureSeeded();
  activeProfile.value = await AppStore.repo.activeProfileIdOrNull();
```

And change the `MaterialApp`:

```dart
      home: const AuthGate(),
```

> `AppStore` is already imported in `main.dart`. Keep the `home_screen.dart` import only if `main.dart` still references `HomeScreen` directly (it no longer needs to).

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/auth_gate_test.dart` → PASS
Run: `flutter test` → all green.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/auth_gate.dart daily_command_center/lib/main.dart daily_command_center/test/screens/auth_gate_test.dart
git commit -m "feat(profiles): AuthGate routing + first-run seed in main"
```

---

## Phase 2 — Login screen

### Task L7: `LoginScreen` (profile picker)

**Files:**
- Create: `lib/screens/login_screen.dart`
- Test: `test/screens/login_screen_test.dart`

Polished picker: existing profiles as tappable cards (avatar = initial), plus a "New profile" name field. Tap existing → `setActiveProfileId` (notifier routes to Home). New name → push `OnboardingScreen`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    activeProfile.value = null;
    await AppStore.repo.load('cyrus'); // seed one profile to list
  });

  testWidgets('lists existing profiles', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cyrus'), findsOneWidget);
  });

  testWidgets('tapping a profile sets it active', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cyrus'));
    await tester.pumpAndSettle();
    expect(activeProfile.value, 'cyrus');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: FAIL — `LoginScreen` not defined.

- [ ] **Step 3: Implement `login_screen.dart`** (uses `context.c`; polished per spec §7)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/profile_repository.dart';
import '../data/store.dart';
import '../theme/app_palette.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  List<ProfileMeta> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await AppStore.repo.listProfileMetas();
    if (mounted) setState(() { _profiles = p; _loading = false; });
  }

  Future<void> _enter(String id) async {
    await AppStore.repo.setActiveProfileId(id); // activeProfile notifier → AuthGate routes to Home
  }

  Future<void> _continueNew() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final id = ProfileRepository.idFor(name);
    if (_profiles.any((m) => m.id == id)) { await _enter(id); return; }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnboardingScreen(displayName: name)));
    // Onboarding sets the active profile on finish; if it didn't (user backed
    // out), refresh the list so a newly created profile still appears.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 64),
            Text('Reminders 2',
                style: GoogleFonts.fraunces(fontSize: 40, fontWeight: FontWeight.w900, color: c.cream, height: 1.0)),
            const SizedBox(height: 8),
            Text("Who's running the day?",
                style: GoogleFonts.fraunces(fontSize: 16, fontStyle: FontStyle.italic, color: c.muted)),
            const SizedBox(height: 32),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: c.terra))
                  : ListView(children: [
                      if (_profiles.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text('No profiles yet — create one below.', style: TextStyle(color: c.dim))),
                      for (final p in _profiles) _ProfileTile(meta: p, onTap: () => _enter(p.id)),
                      const SizedBox(height: 16),
                      _NewProfileField(controller: _nameCtrl, onSubmit: _continueNew),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final ProfileMeta meta;
  final VoidCallback onTap;
  const _ProfileTile({required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final initial = meta.displayName.isEmpty ? '?' : meta.displayName[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(radius: 24, backgroundColor: c.terra,
                  child: Text(initial, style: TextStyle(color: c.bg, fontWeight: FontWeight.w800, fontSize: 20))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meta.displayName, style: TextStyle(color: c.cream, fontSize: 17, fontWeight: FontWeight.w700)),
                if (meta.archetype.isNotEmpty)
                  Text(meta.archetype, style: TextStyle(color: c.muted, fontSize: 12)),
              ])),
              Icon(Icons.chevron_right, color: c.dim),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NewProfileField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  const _NewProfileField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const SizedBox(width: 8),
        Icon(Icons.add, color: c.moss),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller,
          style: TextStyle(color: c.cream),
          decoration: InputDecoration(border: InputBorder.none, hintText: 'New profile name',
              hintStyle: TextStyle(color: c.dim)),
          onSubmitted: (_) => onSubmit(),
        )),
        TextButton(onPressed: onSubmit, child: Text('Continue', style: TextStyle(color: c.terra))),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/login_screen.dart daily_command_center/test/screens/login_screen_test.dart
git commit -m "feat(profiles): LoginScreen profile picker"
```

---

## Phase 3 — Onboarding stub

### Task L8: `OnboardingLogic.buildPlan` + `PlannerLogic.setTrainingFrequency`

**Files:**
- Create: `lib/logic/onboarding.dart`
- Modify: `lib/logic/planner.dart`
- Test: `test/logic/onboarding_test.dart`

Pure logic: seed `Plan` + per-day template choices + training count → a new `Plan` with a personalized title. The training spacing uses a deterministic pattern table (keeps the test exact and avoids combinatorial code).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/logic/onboarding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
  });

  test('buildPlan clones the seed, applies week choices, title, and training count', () async {
    final seed = (await AppStore.repo.load('cyrus')).plan;
    final choices = {
      'mon': 'office', 'tue': 'wfh', 'wed': 'office', 'thu': 'wfh',
      'fri': 'office', 'sat': 'weekend', 'sun': 'weekend_sun',
    };
    final plan = OnboardingLogic.buildPlan(seed: seed, displayName: 'Alex', weekChoices: choices, trainingDays: 3);

    expect(plan.meta.title, contains('Alex'));
    expect(plan.week['tue']!.templateId, 'wfh');
    expect(plan.week.values.where((w) => w.training).length, 3);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/logic/onboarding_test.dart`
Expected: FAIL — `OnboardingLogic` / `setTrainingFrequency` not defined.

- [ ] **Step 3a: Add `setTrainingFrequency` to `planner.dart`** (inside `PlannerLogic`):

```dart
  /// Deterministic, well-spaced training-day patterns by weekly frequency.
  static const _freqPattern = {
    1: ['wed'],
    2: ['mon', 'thu'],
    3: ['mon', 'wed', 'fri'],
    4: ['mon', 'wed', 'fri', 'sun'],
    5: ['mon', 'tue', 'thu', 'fri', 'sat'],
    6: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
  };

  /// Set exactly [n] training days (1–6) across the week using a spaced pattern.
  static Plan setTrainingFrequency(Plan plan, int n) {
    final days = _freqPattern[n.clamp(1, 6)]!;
    final newWeek = Map.fromEntries(_days.map((d) {
      final entry = plan.week[d]!;
      return MapEntry(d, entry.copyWith(training: days.contains(d)));
    }));
    return plan.copyWith(week: newWeek);
  }
```

- [ ] **Step 3b: Implement `onboarding.dart`**

```dart
import '../data/models.dart';
import 'planner.dart';

class OnboardingLogic {
  /// Build a new profile's plan from the bundled [seed]: apply the chosen
  /// template per day, set a personalized title, then place [trainingDays]
  /// spaced across the week. Times/templates come from the (already authored)
  /// seed — this stub only sets the week shape + title.
  static Plan buildPlan({
    required Plan seed,
    required String displayName,
    required Map<String, String> weekChoices,
    required int trainingDays,
  }) {
    final week = <String, WeekEntry>{};
    seed.week.forEach((day, entry) {
      final templateId = weekChoices[day] ?? entry.templateId;
      week[day] = entry.copyWith(templateId: templateId, training: false);
    });

    final titled = Plan(
      schemaVersion: seed.schemaVersion,
      meta: PlanMeta(
        title: "${displayName.trim()}'s plan",
        timezone: seed.meta.timezone,
        lifestyleArchetype: seed.meta.lifestyleArchetype,
      ),
      dayTemplates: seed.dayTemplates,
      week: week,
      weekEditor: seed.weekEditor,
      training: seed.training,
      workouts: seed.workouts,
      nutrition: seed.nutrition,
      goals: seed.goals,
    );
    return PlannerLogic.setTrainingFrequency(titled, trainingDays);
  }
}
```

> Verify `PlanMeta`'s constructor params against `lib/data/models.dart` (it has `title`, `timezone`, `lifestyleArchetype`, all optional with `''` defaults — confirmed). If `PlanMeta` has more fields you want preserved (e.g. `generatedAt`, `equipment`), copy them through too.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/logic/onboarding_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/onboarding.dart daily_command_center/lib/logic/planner.dart daily_command_center/test/logic/onboarding_test.dart
git commit -m "feat(onboarding): buildPlan from seed + setTrainingFrequency"
```

### Task L9: `OnboardingScreen` (stub UI)

**Files:**
- Create: `lib/screens/onboarding_screen.dart`
- Test: `test/screens/onboarding_screen_test.dart`

Three steps (PageView + progress dots): Welcome → week shape (office/wfh chips) → training-days slider → Create. On Create: build the plan via `OnboardingLogic`, `createProfile(displayName, plan: plan)` (sets active), pop.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    activeProfile.value = null;
  });

  testWidgets('completing onboarding creates an active profile with a saved plan', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen(displayName: 'Alex')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(activeProfile.value, 'alex');
    expect(await AppStore.repo.listProfiles(), contains('alex'));
    final plan = (await AppStore.repo.load('alex')).plan;
    expect(plan.meta.title, contains('Alex'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/onboarding_screen_test.dart`
Expected: FAIL — `OnboardingScreen` not defined.

- [ ] **Step 3: Implement `onboarding_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/store.dart';
import '../logic/onboarding.dart';
import '../theme/app_palette.dart';

class OnboardingScreen extends StatefulWidget {
  final String displayName;
  const OnboardingScreen({super.key, required this.displayName});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  int _trainingDays = 4;
  final Map<String, String> _week = {
    'mon': 'office', 'tue': 'office', 'wed': 'wfh', 'thu': 'office',
    'fri': 'office', 'sat': 'weekend', 'sun': 'weekend_sun',
  };
  static const _steps = 3;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final seed = (await AppStore.repo.load('cyrus')).plan; // bundled blueprint
    final plan = OnboardingLogic.buildPlan(
        seed: seed, displayName: widget.displayName, weekChoices: _week, trainingDays: _trainingDays);
    await AppStore.repo.createProfile(widget.displayName, plan: plan); // sets active
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_index < _steps - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 16),
          _ProgressDots(count: _steps, index: _index),
          Expanded(child: PageView(
            controller: _page,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            children: [
              _Welcome(name: widget.displayName),
              _WeekStep(week: _week, onChange: (d, t) => setState(() => _week[d] = t)),
              _TrainingStep(days: _trainingDays, onChange: (n) => setState(() => _trainingDays = n)),
            ],
          )),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c.terra, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _next,
              child: Text(_index == _steps - 1 ? 'Create' : 'Next',
                  style: TextStyle(color: c.bg, fontWeight: FontWeight.w800, fontSize: 16)),
            )),
          ),
        ]),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int count, index;
  const _ProgressDots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: i == index ? 22 : 8, height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: i == index ? c.terra : c.line, borderRadius: BorderRadius.circular(4)),
        ),
    ]);
  }
}

class _Welcome extends StatelessWidget {
  final String name;
  const _Welcome({required this.name});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome, $name.', style: GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w900, color: c.cream)),
        const SizedBox(height: 12),
        Text(
          "We'll set up a starting routine you can run from day one. "
          "You can fine-tune everything later — the times come from a sensible default for now.",
          style: TextStyle(color: c.muted, fontSize: 15, height: 1.5),
        ),
      ]),
    );
  }
}

class _WeekStep extends StatelessWidget {
  final Map<String, String> week;
  final void Function(String day, String template) onChange;
  const _WeekStep({required this.week, required this.onChange});
  static const _labels = {'office': 'Office', 'wfh': 'WFH'};

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Your week', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w900, color: c.cream)),
      const SizedBox(height: 4),
      Text('Pick the shape of each weekday.', style: TextStyle(color: c.muted)),
      const SizedBox(height: 16),
      for (final d in days)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          SizedBox(width: 44, child: Text(d.toUpperCase(), style: TextStyle(color: c.cream, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          if (d == 'sat' || d == 'sun')
            Chip(label: const Text('Weekend'), backgroundColor: c.panel)
          else
            for (final t in const ['office', 'wfh'])
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: Text(_labels[t]!),
                selected: week[d] == t,
                onSelected: (_) => onChange(d, t),
              )),
        ])),
    ]);
  }
}

class _TrainingStep extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChange;
  const _TrainingStep({required this.days, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(padding: const EdgeInsets.all(28), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Training days', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w900, color: c.cream)),
        const SizedBox(height: 4),
        Text("How many days a week do you want to train? We'll space them out for you.", style: TextStyle(color: c.muted)),
        const SizedBox(height: 24),
        Text('$days days', style: GoogleFonts.fraunces(fontSize: 36, fontWeight: FontWeight.w900, color: c.terra)),
        Slider(value: days.toDouble(), min: 1, max: 6, divisions: 5, activeColor: c.terra,
            onChanged: (v) => onChange(v.round())),
      ],
    ));
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/onboarding_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/onboarding_screen.dart daily_command_center/test/screens/onboarding_screen_test.dart
git commit -m "feat(onboarding): OnboardingScreen stub → creates profile + plan"
```

---

## Phase 4 — Wire navigation + per-profile identity

### Task L10: Wire avatar menu (switch/logout) + show active profile in Home

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Test: `test/screens/home_profile_test.dart`

Home currently hardcodes `'Cyrus'`/`'C'` and stubs `onSwitchProfile`/`onLogout`. Load the active profile's display name; show it in the header label, the avatar initial, and the avatar-menu; make switch/logout call `clearActive()` (the notifier routes `AuthGate` back to `LoginScreen`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home header shows the active profile display name', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(debugPlan: /* a valid Plan */ null, debugDisplayName: 'Alex'),
    ));
    await tester.pumpAndSettle();
    // The avatar shows the initial of the active profile.
    expect(find.text('A'), findsWidgets);
  });
}
```

> Use the same `debugPlan` injection the existing home test uses (load the seed plan in the test, or reuse its helper). Add a `debugDisplayName` seam to `HomeScreen` so the name is injectable without async file I/O under the test clock (mirrors the existing `debugPlan` seam rationale).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/home_profile_test.dart`
Expected: FAIL — `debugDisplayName` not defined / header still shows 'C'.

- [ ] **Step 3: Implement.** In `home_screen.dart`:

Add the seam + state:

```dart
class HomeScreen extends StatefulWidget {
  final Plan? debugPlan;
  final String? debugDisplayName; // test seam
  const HomeScreen({super.key, this.debugPlan, this.debugDisplayName});
  // ...
}
```

In `_HomeScreenState`, add `String _displayName = 'You';` and load it in `_load()` (and honor the debug seam in `initState`):

```dart
  @override
  void initState() {
    super.initState();
    _todayKey = _days[DateTime.now().weekday % 7];
    _plan = widget.debugPlan;
    if (widget.debugDisplayName != null) _displayName = widget.debugDisplayName!;
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }
```

In `_load()`, after loading the plan, resolve the active profile's name:

```dart
  Future<void> _load() async {
    if (widget.debugPlan != null) return;
    final plan = await AppStore.loadPlan();
    final state = await StateStore.loadState(DateTime.now());
    final done = await AdherenceStore.loadDone(DateTime.now());
    final id = await AppStore.repo.activeProfileIdOrNull();
    final metas = await AppStore.repo.listProfileMetas();
    final name = metas.firstWhere((m) => m.id == id,
        orElse: () => ProfileMeta(id: id ?? '', displayName: 'You')).displayName;
    if (!mounted) return;
    setState(() { _plan = plan; _state = state; _done = done; _displayName = name; });
    AppStore.writeWidgetData(plan, _todayKey).ignore();
  }
```

> Add `import '../data/profile_repository.dart';` for `ProfileMeta`.

Update `_header` to use `_displayName`:

```dart
      // initial in the avatar:
      child: Text(_displayName.isEmpty ? '?' : _displayName[0].toUpperCase(),
          style: TextStyle(color: c.terra, fontWeight: FontWeight.w700)),
```

Update the avatar-menu call to use the real name + wire logout/switch:

```dart
      onTap: () => showAvatarMenu(context, name: _displayName, subtitle: _plan?.meta.lifestyleArchetype ?? '',
        onSwitchProfile: _logout,
        onOpenSettings: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        onOpenGlossary: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlossaryScreen())),
        onLogout: _logout),
```

Add the logout handler to `_HomeScreenState`:

```dart
  /// Switch profile / log out — clears the active pointer; AuthGate routes to Login.
  Future<void> _logout() async => AppStore.repo.clearActive();
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/home_profile_test.dart` → PASS
Run: `flutter test` → green (existing home/widget tests unaffected; they inject `debugPlan`).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/home_screen.dart daily_command_center/test/screens/home_profile_test.dart
git commit -m "feat(profiles): show active profile in Home + wire switch/logout"
```

### Task L11: Extend `SettingsScreen` — Account + Data sections

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Test: `test/screens/settings_profile_test.dart`

Add below the existing Appearance/Text-size controls: ACCOUNT (Log out / switch profile; Delete this profile) · DATA (Export data; Import data; Reset plan to default; Clear logged history) · ABOUT (health disclaimer). Logout/delete call repo methods; the `activeProfile` notifier handles routing, and we `popUntil(isFirst)` to dismiss the pushed Settings route so the gate shows.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStore.repo = ProfileRepository(baseDir: await Directory.systemTemp.createTemp());
    await AppStore.repo.createProfile('Cyrus');
  });

  testWidgets('shows the account + data + about rows', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete this profile'), findsOneWidget);
    expect(find.text('Export data'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/settings_profile_test.dart`
Expected: FAIL — rows not present.

- [ ] **Step 3: Implement.** Add imports to `settings_screen.dart`:

```dart
import 'package:flutter/services.dart';
import '../data/profile_repository.dart';
import '../data/store.dart';
```

Add these handlers as top-level helpers or private methods (the screen is a `StatelessWidget`; pass `context`):

```dart
Future<void> _logout(BuildContext context) async {
  await AppStore.repo.clearActive();
  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
}

Future<void> _delete(BuildContext context) async {
  final c = context.c;
  final id = await AppStore.repo.activeProfileIdOrNull();
  if (id == null) return;
  if (!context.mounted) return;
  final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
    backgroundColor: c.panel,
    title: Text('Delete this profile?', style: TextStyle(color: c.cream)),
    content: Text("This erases this profile's plan and history on this device. Export first if you want a backup.",
        style: TextStyle(color: c.muted)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Delete', style: TextStyle(color: c.terra))),
    ],
  ));
  if (ok == true) {
    await AppStore.repo.delete(id);
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

Future<void> _export(BuildContext context) async {
  final c = context.c;
  final id = await AppStore.repo.activeProfileIdOrNull();
  if (id == null) return;
  final blob = await AppStore.repo.exportProfile(id);
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (d) => AlertDialog(
    backgroundColor: c.panel,
    title: Text('Export data', style: TextStyle(color: c.cream)),
    content: SingleChildScrollView(child: SelectableText(blob, style: TextStyle(color: c.muted, fontSize: 11))),
    actions: [
      TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: blob)); Navigator.pop(d); }, child: const Text('Copy')),
    ],
  ));
}

Future<void> _import(BuildContext context) async {
  final c = context.c;
  final ctrl = TextEditingController();
  if (!context.mounted) return;
  final blob = await showDialog<String>(context: context, builder: (d) => AlertDialog(
    backgroundColor: c.panel,
    title: Text('Import data', style: TextStyle(color: c.cream)),
    content: TextField(controller: ctrl, maxLines: 6, style: TextStyle(color: c.cream),
        decoration: InputDecoration(hintText: 'Paste a profile JSON…', hintStyle: TextStyle(color: c.dim))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(d, ctrl.text), child: const Text('Import')),
    ],
  ));
  if (blob == null || blob.trim().isEmpty) return;
  await AppStore.repo.importProfile(blob);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile imported.')));
  }
}
```

Append the new sections inside the existing `ListView` (after the glossary `ListTile`):

```dart
        const SizedBox(height: 8),
        Text('ACCOUNT', style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.swap_horiz, color: c.muted),
            title: Text('Log out', style: TextStyle(color: c.cream)),
            subtitle: Text('Switch profile', style: TextStyle(color: c.muted)),
            onTap: () => _logout(context)),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline, color: c.terra),
            title: Text('Delete this profile', style: TextStyle(color: c.cream)),
            onTap: () => _delete(context)),
        const SizedBox(height: 8),
        Text('DATA', style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.upload_file, color: c.muted),
            title: Text('Export data', style: TextStyle(color: c.cream)), onTap: () => _export(context)),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.download, color: c.muted),
            title: Text('Import data', style: TextStyle(color: c.cream)), onTap: () => _import(context)),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.restart_alt, color: c.muted),
            title: Text('Reset plan to default', style: TextStyle(color: c.cream)),
            onTap: () async { final id = await AppStore.repo.activeProfileIdOrNull(); if (id != null) await AppStore.repo.resetPlan(id); }),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.cleaning_services, color: c.muted),
            title: Text('Clear logged history', style: TextStyle(color: c.cream)),
            onTap: () async { final id = await AppStore.repo.activeProfileIdOrNull(); if (id != null) await AppStore.repo.clearHistory(id); }),
        const SizedBox(height: 8),
        Text('ABOUT', style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Reminders 2 · personal daily dashboard.\n\nThis is general fitness information, not medical advice.',
                style: TextStyle(color: c.muted, fontSize: 12, height: 1.5))),
```

> The handlers reference `context.c`; since `app_palette.dart` is already imported in `settings_screen.dart`, `context.c` resolves. If the handlers are top-level functions, they each call `final c = context.c;` (shown above).

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/settings_profile_test.dart` → PASS
Run: `flutter test` → green.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/settings_screen.dart daily_command_center/test/screens/settings_profile_test.dart
git commit -m "feat(profiles): Settings account + data sections (logout/delete/export/import/reset/clear)"
```

---

## Phase 5 — Polish + verification

### Task L12: Visual polish pass + full verification

**Files:** `login_screen.dart`, `onboarding_screen.dart`, `home_screen.dart`, `settings_screen.dart`

Build-as-you-go already produced polished screens; this is the consistency sweep. **Invoke the `frontend-design` skill** and apply it across the new surfaces. Checklist (spec §7):

- [ ] Consistent spacing scale + card styling across login / onboarding / settings (reuse `context.c` panel/line radii used elsewhere — 16–20px).
- [ ] Login: warm, branded, calm; avatars + clear primary action; the empty state ("No profiles yet — create one") reads intentionally.
- [ ] Onboarding: friendly copy, visible progress dots, low-friction taps/slider, encouraging finish.
- [ ] Tasteful transition: wrap the `AuthGate` body in an `AnimatedSwitcher` (login ↔ home) so logout/login cross-fades rather than snaps.
- [ ] Loading/empty states aren't bare spinners where it matters.
- [ ] Accessible contrast + ≥48px tap targets (the `ListTile`/`InkWell` defaults satisfy this; verify custom rows).

- [ ] **Run the full suite:** `flutter test` → all green (expect prior 188 + the ~10 new tests).
- [ ] **Manual check on device** (per `CONTINUE.md` "How to run"): fresh-install → Login shows `Cyrus` → tap → Home shows "Cyrus" → avatar menu → Log out → back to Login → type a new name → onboarding → Create → personalized Home → Settings → Export (copy) → Delete → back to Login.
- [ ] **Update docs:** mark this feature in `CONTINUE.md`; add an ADR note that the drawer/`AppShell` from the 2026-06-07 plan was dropped in favor of the shipped avatar-menu navigation, and that storage stayed file-per-profile (ADR-019's key-prefix revision never shipped).
- [ ] **Commit**

```bash
git add -A
git commit -m "style(profiles): polish login/onboarding/settings + AnimatedSwitcher; docs"
```

---

## Self-review (against the spec)

**Spec coverage:**
- §1 login = local profile picker → L7 ✓ · cyrus seeded first-run → L5 (`ensureSeeded`) ✓ · new-profile onboarding → L8/L9 ✓ · logout/switch → L10/L11 ✓ · scalable (add profile without core rework) → repo + notifier ✓
- §2 routing / AuthGate / cyrus first-run → L6 + L5 ✓ (nullable pointer makes logged-out representable)
- §3 storage → **already shipped as file-per-profile**; export/import → L4 ✓ (the spec's key-prefix revision is explicitly *not* adopted; documented in Reconciliation + L12 ADR note)
- §4 onboarding stub produces a valid plan → L8/L9 ✓ (training spacing via `setTrainingFrequency`)
- §5 app shell / drawer / section split → **intentionally dropped** (avatar-menu navigation shipped instead; per-profile name in header → L10) — documented as a non-goal
- §6 settings (profile, delete, export/import, reset, clear, about) → L11 ✓
- §7 visual polish → L12 (+ build-as-you-go) ✓
- §8 testing (isolation, routing, login, onboarding, settings, regression green) → L1–L11 each ship tests; L12 runs the full suite ✓

**Deliberate deviations from the spec (flagged for approval):** the Drawer/`AppShell` + placeholder TRACK/REVIEW sections (§5) are dropped because the app's shipped navigation is the avatar menu; re-introducing a drawer would duplicate it. If the drawer is still wanted, it is a separate additive plan.

**Placeholder scan:** none — every step has concrete code. The only `null`/`UnimplementedError` is the `testPlan()` helper note in L6, which explicitly instructs reusing the existing test's plan-loading pattern.

**Type consistency:** `ProfileMeta{id,displayName,archetype}`, `ProfileRepository.{idFor,listProfileMetas,activeProfileIdOrNull,clearActive,setActiveProfileId,createProfile,delete,exportProfile,importProfile,clearHistory,resetPlan,ensureSeeded,load,save,listProfiles}`, `activeProfile` notifier, `AppStore.repo`, `PlannerLogic.setTrainingFrequency`, `OnboardingLogic.buildPlan`, `Plan`/`PlanMeta`/`WeekEntry` constructors — names are used consistently across tasks and match the verified existing APIs.
